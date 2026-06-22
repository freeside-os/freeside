# Freeside Package Compilation
set dotenv-load := false
set working-directory := ".."

keep_sandbox := "false"

# Compile a user-space package by name
build pkg_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    just straylight::build
    
    FLAGS=""
    if [ "{{keep_sandbox}}" = "true" ]; then
        FLAGS="--keep-sandbox"
    fi
    
    STRAYLIGHT_PACKAGES_ROOT="$(pwd)/packages" \
    STRAYLIGHT_BUILDER_ROOT="$(pwd)/build" \
    STRAYLIGHT_BUILDER_OUTPUT_ROOT="$(pwd)/build/packages" \
    sudo -E build/straylight build --pkg "{{pkg_name}}" $FLAGS

# Compile all user-space packages belonging to a specific group inside a single sandbox
build-group group_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    just straylight::build
    
    FLAGS=""
    if [ "{{keep_sandbox}}" = "true" ]; then
        FLAGS="--keep-sandbox"
    fi

    STRAYLIGHT_PACKAGES_ROOT="$(pwd)/packages" \
    STRAYLIGHT_BUILDER_ROOT="$(pwd)/build" \
    STRAYLIGHT_BUILDER_OUTPUT_ROOT="$(pwd)/build/packages" \
    sudo -E build/straylight build --group "{{group_name}}" $FLAGS

# Clean compiled user-space packages
clean:
    @echo "=== [Root Coordinator] Purging compiled user-space packages ==="
    sudo rm -rf build/packages
