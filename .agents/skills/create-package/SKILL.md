---
name: create-package
description: A workflow guide for importing Arch Linux PKGBUILD packages to Freeside format using 'fspack.py convert', editing recipes, and classifying package groups.
---

# Freeside Linux: Package Import & Classification Guide

This skill guides agents through converting Arch Linux packages to Freeside package manifests and build recipes, polishing them, and assigning them to the correct package group.

### Core Documentation References:
*   [Packaging Guide](file:///home/dq/Code/freeside/docs/guides/packaging_guide.md)
*   [Local Development Guide](file:///home/dq/Code/freeside/docs/guides/local_development.md)

---

## 1. Importing with `fspack.py convert`

Freeside provides a packaging helper script `packages/fspack.py` that can fetch and convert PKGBUILD configurations directly from Arch Linux's GitLab packaging repository.

### Workflow:
Run the conversion command inside the repository (usually as a non-privileged user):
```bash
python3 packages/fspack.py convert <pkgname>
```

This will:
1. Fetch the raw `PKGBUILD` from `https://gitlab.archlinux.org/archlinux/packaging/packages/<pkgname>/-/raw/main/PKGBUILD`.
2. Generate `./<pkgname>/PKGBUILD` (saved copy of the original).
3. Generate `./<pkgname>/package.manifest` (initial TOML manifest).
4. Generate `./<pkgname>/package.justfile` (initial build recipe).

---

## 2. Reviewing and Polishing the Conversion (CRITICAL)

The auto-converter provides a baseline, but the manifest and justfile **must** be audited and updated by the agent.

### A. Manifest Checklist (`package.manifest`):
*   **Version-Dynamic**: Verify name and version are correct.
*   **Dependencies**: Arch dependency names (e.g., `openssl-1.1`, `glibc`) must be mapped to Freeside-specific equivalent package names (e.g., `openssl`, `musl`).
*   **Group Assignment**: Assign a `group` value (see classification details in Section 3).
*   **Build Table**: Ensure the `[build]` table is declared with necessary build-time dependencies (e.g., `make`, `cmake`, `ninja`, `pkgconf`).

### B. Justfile Checklist (`package.justfile`):
*   **Metadata Variables**: Replace hardcoded versions or names with `$PKG_NAME` and `$PKG_VERSION` (exported automatically to the build environment by `straylight`).
*   **Staging Directory**: Ensure all installation commands install files relative to `DESTDIR`:
    ```just
    package:
        cd $PKG_NAME-$PKG_VERSION && make DESTDIR="$DESTDIR" install
    ```
*   **Permissions Compliance**: Enforce strict standard directory and file permissions at the end of the `package` target:
    ```just
        find "$DESTDIR" -type d -exec chmod 755 {} +
        if [ -d "$DESTDIR/usr/bin" ]; then find "$DESTDIR/usr/bin" -type f -exec chmod 755 {} +; fi
        if [ -d "$DESTDIR/usr/lib" ]; then find "$DESTDIR/usr/lib" -name "*.so*" -exec chmod 755 {} + || true; fi
    ```

---

## 3. Package Group Classification

Freeside organizes packages into distinct classification groups inside the `package.manifest` file. Assigning the correct group is vital to keeping the builder sandbox lightweight and system builds organized:

```toml
[package]
name = "example"
version = "1.0.0"
group = "server"  # <-- Group classification
```

### Classification Reference:

#### 1. `base`
*   **Description**: The absolute minimal bootstrap runtime environment. Essential for core OS startup, shell command execution, and compiler support.
*   **Examples**: `musl`, `bash`, `uutils-coreutils`, `openssl`, `ca-certificates`, `zlib`, `python3`, `readline`, `ncurses`.

#### 2. `builder`
*   **Description**: Software compilers, linkers, build systems, header environments, and development tools used exclusively to build other packages.
*   **Examples**: `llvm`, `rust`, `make`, `ninja`, `cmake`, `m4`, `pkgconf`, `ccache`, `patchelf`.

#### 3. `system`
*   **Description**: Core system management components, process managers, service managers, and device managers required for a bootable, running Freeside OS, but **not** needed during packaging or compilation inside the builder sandbox.
*   **Examples**: `systemd`, `straylight`, `libarchive`, `libcap`, `libexpat`, `util-linux`.

#### 4. `server`
*   **Description**: Backend services, network service daemons, command-line utilities, database engines, and server-focused management utilities. **Most new command-line/system utility packages belong here.**
*   **Examples**: `nginx`, `postgresql`, `docker`, `iptables`, `tmux`, `curl`, `git` (if not in base).

#### 5. `desktop`
*   **Description**: Graphical servers, window managers, desktop environment frameworks, graphics drivers, audio libraries, web browsers, and GUI applications.
*   **Examples**: `wayland`, `mesa`, `xorg`, `gtk`, `qt6`, `firefox`, `alsa-lib`.

---

## 4. UsrMerge & Musl Configuration Adjustments

Freeside implements the **UsrMerge** directory layout and compiles exclusively against **Musl-libc**. When importing standard Arch packages (which target Glibc and standard filesystem structures), the following configure flags and parameter adjustments are typically required:

### A. UsrMerge Layout Parameters
Freeside requires all binaries and libraries to reside under the `/usr` prefix. `/bin`, `/sbin`, `/lib`, and `/lib64` are system-wide symbolic links to their counterparts under `/usr`.
When writing configure arguments, always ensure the following flags are supplied (especially for GNU Autotools):
*   `--prefix=/usr`: Directs installation to the `/usr` tree.
*   `--sbindir=/usr/bin`: Merges system binaries into `/usr/bin` (preventing files from going to the dead `/usr/sbin` path).
*   `--libdir=/usr/lib`: Places libraries in `/usr/lib` (preventing them from being installed into a `/usr/lib64` folder on 64-bit platforms).
*   `--sysconfdir=/etc`: Ensures global configuration files are installed under `/etc`.
*   `--localstatedir=/var`: Directs state files to `/var`.

Example:
```toml
[build.environment]
CONFIGURE_ARGS = "--prefix=/usr --sbindir=/usr/bin --libdir=/usr/lib --sysconfdir=/etc --localstatedir=/var"
```

### B. Musl Libc Adaptations
Because Freeside uses Musl instead of Glibc:
*   **Target Triples**: Configure scripts might need to be explicitly told the target triple:
    `--host=x86_64-freeside-linux-musl` or `--target=x86_64-freeside-linux-musl`.
*   **GNU Extensions**: Musl does not include Glibc-specific GNU extensions (such as `execinfo.h` for backtraces, or `obstack.h`). Features depending on these headers must be disabled:
    *   For NLS (Native Language Support), we commonly pass `--disable-nls` to configure scripts to avoid pulling in external `libintl` dependency trees.
    *   Disable Glibc-specific debug/backtrace features via configure options (e.g., `--without-execinfo`).
*   **Static vs. Shared**: Prefer shared libraries for packaging by supplying `--enable-shared` and `--disable-static` to save disk space and support dynamic loading, unless a bootstrap package specifically needs to be statically linked.
