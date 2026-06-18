# Freeside OS Monorepo

Freeside is a next-generation, independent Linux distribution engineered for resilience, absolute predictability, and zero-maintenance overhead. It utilizes a declarative, stateless core, a modern systemd stack, and isolated compiler sandboxes to prevent dynamic host library contamination.

---

## Workspace Layout

```text
freeside/ (Monorepo Root)
├── bootstrap/                   # Stage 0 bootstrap engine
│   ├── justfile                 # Local build/clean targets
│   ├── Stage0.sh                # Host-driven environment download & assembly
│   ├── sources.txt              # Registry of pre-compiled musl assets
│   ├── packages.sh              # Central list of packages (Stage 0 APKs)
│   └── patches/                 # Architecture or musl-specific patches
├── docs/                        # Project technical specifications & designs
├── installer/                   # Secure interactive TUI installer (Rust)
├── packages/                    # User-space packages recipes
└── straylight/                  # Custom package manager CLI and state daemon (Rust)
```

---

## Workspace Setup & Bootstrapping

To bootstrap the developer workspace (create directories and clone the sub-repositories):

### Remote Bootstrapping (One-liner)
You can bootstrap the workspace in any empty directory by running:
```bash
curl -fsSL https://raw.githubusercontent.com/freeside-os/freeside/main/setup.sh | bash
```

### Local Bootstrapping (Existing Clone)
If you already cloned this repository:
```bash
just setup
```

---

## Build Prerequisites

To run the bootstrap pipeline, your host system must satisfy the following:
* **Operating System**: Arch Linux (x86_64-pc-linux-gnu)
* **Privileges**: Root/sudo access (required for `systemd-nspawn` container sandboxing and preserving SUID/SGID metadata)
* **Required Tools**: `just` (>= 1.51.0), `systemd` (with `systemd-nspawn` support), `curl`, `tar`

---

## Build Instructions

### 1. Build the Bootstrap Core
To build the self-contained rootfs and compile the `builder` profile compiler core:
From the root of the monorepo, execute `just` as a normal user:
```bash
just build-bootstrap
```
*This command runs Stage 0 host assembly and packages the results. Privilege escalation (sudo) is managed internally within the recipes for the specific stages requiring root.*

### 2. Build the Straylight CLI
To build the `straylight` package manager CLI:
From the root of the monorepo, execute:
```bash
just build-straylight
```
This compiles the Rust binary and copies it to `build/straylight`.

### 3. Running Straylight Build
You can use `straylight` to compile packages:
```bash
sudo build/straylight build <path-to-package-dir>
```
* By default, the temporary build workspaces are located under `build/straylight/`.
* You can override this build directory path by setting the `STRAYLIGHT_CACHE_DIR` or `STRAYLIGHT_BUILD_DIR` environment variables.
* The successfully built package tarball is saved under the central directory `build/packages/`.

### 4. Output Artifacts
Once completed, the final package will be created in:
* **Bootstrap Core Tarball**: `build/sandbox-root.tgz` *(ownership is automatically assigned back to the host user)*
* **Straylight CLI Binary**: `build/straylight`
* **Compiled User-space Packages**: `build/packages/`

### 5. Cleaning the Workspace
To purge transient workspaces, Cargo target directories, build cache, and intermediate build directories (excluding compiled packages):
```bash
just clean
```

To purge compiled user-space packages:
```bash
just clean-packages
```


