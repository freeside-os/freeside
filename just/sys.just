# Freeside System and Workspace Orchestration
set dotenv-load := false
set working-directory := ".."

# Bootstrap the developer workspace (clone repositories, create directories)
setup:
    @./setup.sh

# Build the compiler sandbox: compile packages using straylight and assemble the final rootfs
build-sandbox:
    #!/usr/bin/env bash
    set -euo pipefail
    
    just straylight::build

    echo "=== [Root Coordinator] Cleaning previous Sandbox ==="
    sudo rm -rf build/sandbox
    mkdir -p build/packages

    echo "=== [Root Coordinator] Building base packages inside sandbox ==="
    STRAYLIGHT_PACKAGES_ROOT="$(pwd)/packages" \
    STRAYLIGHT_BUILDER_ROOT="$(pwd)/build" \
    STRAYLIGHT_BUILDER_OUTPUT_ROOT="$(pwd)/build/packages" \
    sudo -E build/straylight build --group base

    echo "=== [Root Coordinator] Building builder packages inside sandbox ==="
    STRAYLIGHT_PACKAGES_ROOT="$(pwd)/packages" \
    STRAYLIGHT_BUILDER_ROOT="$(pwd)/build" \
    STRAYLIGHT_BUILDER_OUTPUT_ROOT="$(pwd)/build/packages" \
    sudo -E build/straylight build --group builder

    echo "=== [Root Coordinator] Creating final sandbox tarball ==="
    OUTPUT="$(pwd)/build/sandbox-root.tgz"
    sudo tar -czf "${OUTPUT}" -C "$(pwd)/build/sandbox" .
    
    USER_UID="${SUDO_UID:-$(id -u)}"
    USER_GID="${SUDO_GID:-$(id -g)}"
    sudo find "$(pwd)/build" -xdev -exec chown -h "${USER_UID}:${USER_GID}" {} +

    tarball_size="$(du -h "${OUTPUT}" | awk '{print $1}')"
    echo "================================================================"
    echo "Sandbox rootfs assembled successfully!"
    echo "  Tarball:   ${OUTPUT}"
    echo "  Size:      ${tarball_size}"
    echo "================================================================"

# Clean all subprojects and local build workspaces recursively
clean:
    @echo "=== [Root Coordinator] Cleaning Multi-Repo Workspace ==="
    just straylight::clean
    @echo "=== [Bootstrap] Purging sandbox build artifacts ==="
    just bootstrap::clean
    @echo "=== [Root Coordinator] Purging build logs ==="
    sudo rm -f build/*.log
