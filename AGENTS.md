# Freeside OS: Agent Onboarding & Project Manual

Welcome, Agent! This document acts as your operational handbook when collaborating on the **Freeside OS** distribution. It covers the system's design tenets, workspace structure, sub-repository layout, build guidelines, and key rules of thumb established in previous development sessions.

---

## 1. Project Philosophy

Freeside is a next-generation Linux distribution designed for resilience and predictability.
*   **Stateless Core:** The active operating system runs on an immutable read-only system image (`/usr`). Machine configurations are generated from a single declarative target configuration.
*   **OverlayFS Configurations:** Runtime configurations under `/etc` are overlayed using OverlayFS (Lower layer: Stock defaults under `/usr/share/freeside/etc/`, Upper layer: User overrides under `/var/lib/freeside/mutable-etc/`).
*   **No Compilation Leakage:** Compiling packages directly in the host user space is strictly prohibited. All compilation occurs inside isolated `systemd-nspawn` container sandboxes using a Musl-libc toolchain.

---

## 2. Workspace & Repository Layout

Freeside is managed locally as a unified workspace coordinating several sub-repositories under the `freeside-os` GitHub organization:

```text
freeside/ (Local Workspace - Not in Git)
├── bootstrap/                   # git@github.com:freeside-os/bootstrap.git
│                                # Stage 0/1 compilation engine, Docker build envs, sandbox packaging
├── packages/                    # git@github.com:freeside-os/packages.git
│                                # User-space and system declarative package manifests and recipes
├── straylight/                  # git@github.com:freeside-os/straylight.git
│                                # Rust CLI client, compilation daemon (straylightd), and state sync orchestrator
└── docs/                        # git@github.com:freeside-os/docs.git
                                 # System specifications, packaging guides, and schemas reference
```

*Note: The parent workspace directory `/home/dq/Code/freeside` is not tracked by Git itself. Keep development files contained inside the appropriate sub-repository folders.*

---

## 3. Key Development Guidelines

### Git & Commit Rules
*   **Skip Commit Signing:** When making commits in any of the sub-repositories, you must skip GPG signing. Pass the `--no-gpg-sign` flag explicitly to your git commands:
    ```bash
    git commit --no-gpg-sign -m "..."
    ```

### Documentation & Reference Links
*   **Markdown Links:** When creating links to files or classes in your documentation edits or chat messages, always use absolute markdown links with the `file://` scheme:
    *   *Correct:* `[zlib](file:///home/dq/Code/freeside/packages/zlib/package.manifest)`
    *   *Incorrect:* `[zlib](packages/zlib/package.manifest)`
*   **Documentation Structure:** Do not add documentation arbitrarily. Respect the modular structure under `docs/`:
    *   `docs/specifications/` for architectural blueprints and designs.
    *   `docs/guides/` for workflows and tutorials.
    *   `docs/reference/` for configuration schemas and catalogs.

### Compilation Workflows
To compile the system locally:
1.  **Build Bootstrap Core:** Generates `build/bootstrap/sandbox-root.tgz` (Stage 0 Alpine container build and assembly):
    ```bash
    just bootstrap::build-sandbox
    ```
    *Note: Copy this to `build/sandbox-root.tgz` before building straylight packages.*
2.  **Build Straylight CLI:** Compiles the Rust utility binary and puts it in `build/straylight`:
    ```bash
    just straylight::build
    ```
3.  **Compile Packages:** Use the built `straylight` command (requires sudo for chroot containment):
    ```bash
    STRAYLIGHT_PACKAGES_ROOT="$(pwd)/packages" \
    STRAYLIGHT_BUILDER_ROOT="$(pwd)/build" \
    STRAYLIGHT_BUILDER_OUTPUT_ROOT="$(pwd)/build/packages" \
    sudo -E build/straylight build --pkg <package-name>
    ```

---

## 4. Packaging System Conventions (CRITICAL)

When creating or modifying package recipes under the `packages/` repository:

### Environment Variable Metadata Injection
*   **Do not hardcode versions or package names in build targets.** The compilation orchestrator (`straylight`) automatically exports the following metadata variables to the package shell environment when running targets:
    *   `PKG_NAME`
    *   `PKG_VERSION`
    *   `PKG_DEPENDENCIES`
    *   `PKG_GROUP`
    *   `PKG_DESCRIPTION`
*   In your `package.justfile` targets, refer to them using `{{env_var("PKG_NAME")}}` or standard environment variables (`$PKG_NAME`) to keep recipes version-dynamic:
    *   *Correct:* `cd $PKG_NAME-*` or `cd $PKG_NAME-$PKG_VERSION`
    *   *Incorrect:* `cd zlib-1.3.1`

### Destination Directory Injection
*   During the packaging target execution, the orchestrator sets the **`DESTDIR`** environment variable.
*   Make sure your packaging recipes install binaries relative to the staging destination directory `$DESTDIR`:
    ```just
    package:
        cd zlib-* && make DESTDIR="$DESTDIR" install
    ```

### Manifest Specifications
*   Do not put compiler flag overrides (like `CFLAGS` or `LDFLAGS`) in the `[package]` or `[build]` block roots in `package.manifest`.
*   Place all build environment variables under the `[build.environment]` (or `[build.env]`) table:
    ```toml
    [build.environment]
    CFLAGS = "-O3"
    CONFIGURE_ARGS = "--prefix=/usr --enable-shared"
    ```

---

## 5. Answering Questions vs. Executing Tasks

When the user asks a question, the agent must adhere strictly to the following rules:
*   **Avoid Rogue Actions:** If the user asks a question, do not perform unsolicited codebase modifications or run commands (such as builds or compiles) unless explicitly requested or strictly necessary to verify the answer. Focus on answering the question directly.
*   **Provide Grounded, Accurate Answers:** Do not provide speculative, hallucinated, or guess-based answers. Answers must be factual and grounded in the codebase, documentation, or verified external sources.
*   **Search and Verify First:** If the answer is not immediately known, use codebase search tools or web search (`search_web`) to verify the facts. If the information can be found via a web search, search for it rather than guessing.

