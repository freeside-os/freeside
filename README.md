# Freeside OS Workspace

Freeside is a next-generation, independent Linux distribution engineered for resilience, absolute predictability, and zero-maintenance overhead. It utilizes a declarative, stateless core, a modern systemd stack, and isolated compiler sandboxes to prevent dynamic host library contamination.

---

## Workspace Layout

```text
freeside/ (Workspace Root)
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
Freeside OS bootstrapping is a two-stage process:

* **Stage 0: Alpine Host Sandbox (One-time Setup)**
  Build the initial musl-based compiler sandbox core inside a Docker container:
  ```bash
  just bootstrap::build-sandbox
  ```
  This generates `build/bootstrap/sandbox-root.tgz`.

* **Stage 0 to Stage 1 Promotion (Manual Step)**
  Since Straylight expects the sandbox core at the root of the builder output, manually copy the sandbox tarball:
  ```bash
  cp build/bootstrap/sandbox-root.tgz build/sandbox-root.tgz
  ```

* **Stage 1: Pure Sandbox Recompilation**
  To rebuild the base and builder packages inside the isolated Freeside sandbox (rebuilding a pure environment):
  ```bash
  just sys::build-sandbox   # Or use alias: just build-sandbox
  ```
  This compiles the packages inside the sandbox and generates the final, pure `build/sandbox-root.tgz`.
  *(To skip cleaning the existing `build/sandbox` directory, pass the `keep_sandbox=true` variable: `just keep_sandbox=true build-sandbox`)*

### 2. Build the Straylight CLI
To build the `straylight` package manager CLI:
From the root of the monorepo, execute:
```bash
just straylight::build    # Or use alias: just build-straylight
```
This compiles the Rust binary and copies it to `build/straylight`.

### 3. Running Straylight Build
You can use `straylight` to compile packages:
```bash
STRAYLIGHT_PACKAGES_ROOT="$(pwd)/packages" \
STRAYLIGHT_BUILDER_ROOT="$(pwd)/build" \
STRAYLIGHT_BUILDER_OUTPUT_ROOT="$(pwd)/build/packages" \
sudo -E build/straylight build --pkg <package-name>
```
* By default, the temporary build workspaces are located under `build/workspace/`.
* The successfully built package tarball is saved under the central directory `build/packages/`.
* **Incremental Builds / Debugging**: You can keep the build sandbox and workspace directories to speed up iterative recompilation by passing the `keep_sandbox=true` flag via `just`:
  ```bash
  just keep_sandbox=true build <package-name>
  ```
  Or by passing the `--keep-sandbox` flag directly to straylight:
  ```bash
  sudo -E build/straylight build --pkg <package-name> --keep-sandbox
  ```

### 4. Output Artifacts
Once completed, the final package will be created in:
* **Bootstrap Core Tarball**: `build/sandbox-root.tgz` *(ownership is automatically assigned back to the host user)*
* **Straylight CLI Binary**: `build/straylight`
* **Compiled User-space Packages**: `build/packages/`

### 5. Cleaning the Workspace
To purge transient workspaces, Cargo target directories, build cache, and intermediate build directories (excluding compiled packages):
```bash
just sys::clean           # Or use alias: just clean
```

To purge compiled user-space packages:
```bash
just pkg::clean           # Or use alias: just clean-packages
```


