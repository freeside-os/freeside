# Freeside Monorepo Master Orchestrator
set dotenv-load := false

# List of Git repositories in the workspace
git_repos := "bootstrap packages straylight docs"


# ==============================================================================
# 1. Workspace Initialization
# ==============================================================================

# Bootstrap the developer workspace (clone repositories, create directories)
setup:
    @./setup.sh


# ==============================================================================
# 2. Workspace Git Management
# ==============================================================================

# List git status of all configured repositories
status:
    @for dir in {{git_repos}}; do \
        if [ -d "$dir/.git" ]; then \
            echo "=== Repository: $dir ==="; \
            git -C "$dir" status -s; \
            echo ""; \
        fi \
    done

# Show git diff of all configured repositories
diff:
    @for dir in {{git_repos}}; do \
        if [ -d "$dir/.git" ]; then \
            echo "=== Diff for: $dir ==="; \
            git -C "$dir" diff --stat; \
            git -C "$dir" diff; \
            echo ""; \
        fi \
    done


# ==============================================================================
# 3. Orchestrated System Builds
# ==============================================================================

# Build the builder sandbox: compile packages using straylight and assemble the final rootfs
build-builder-sandbox: build-straylight
    #!/usr/bin/env bash
    set -euo pipefail

    echo "=== [Root Coordinator] Cleaning previous packages and staging ==="
    sudo rm -rf build/packages
    sudo rm -rf build/sandbox-staging
    sudo rm -rf build/sandbox
    mkdir -p build/packages
    mkdir -p build/sandbox-staging

    if [ -f build/sandbox-root-bootstrap.tgz ]; then
        echo "=== [Root Coordinator] Restoring bootstrap sandbox-root.tgz ==="
        cp build/sandbox-root-bootstrap.tgz build/sandbox-root.tgz
    else
        echo "Error: build/sandbox-root-bootstrap.tgz not found. Cannot bootstrap package building."
        exit 1
    fi

    # Get topologically sorted packages in 'base' and 'builder' groups
    echo "=== [Root Coordinator] Resolving build order and dependencies ==="
    packages_to_build=($(python3 packages/resolve-packages.py))

    echo "=== [Root Coordinator] Building base and builder packages ==="
    for pkg in "${packages_to_build[@]}"; do
        echo "--> Building ${pkg}..."
        STRAYLIGHT_BUILDER_ROOT="$(pwd)/build" \
        sudo -E build/straylight build "packages/${pkg}"
    done

    echo "=== [Root Coordinator] Setting up essential directories and UsrMerge symlinks ==="
    SANDBOX_DIR="$(pwd)/build/sandbox-staging"
    
    # Ensure usr directories exist
    sudo mkdir -p "${SANDBOX_DIR}/usr/bin"
    sudo mkdir -p "${SANDBOX_DIR}/usr/lib"

    # Create top-level symlinks
    for link in bin sbin; do
        if [[ ! -L "${SANDBOX_DIR}/${link}" ]]; then
            sudo ln -sf usr/bin "${SANDBOX_DIR}/${link}"
        fi
    done

    for link in lib lib64; do
        if [[ ! -L "${SANDBOX_DIR}/${link}" ]]; then
            sudo ln -sf usr/lib "${SANDBOX_DIR}/${link}"
        fi
    done

    # Merge usr/sbin into usr/bin if it exists
    if [[ -d "${SANDBOX_DIR}/usr/sbin" && ! -L "${SANDBOX_DIR}/usr/sbin" ]]; then
        sudo cp -a "${SANDBOX_DIR}/usr/sbin/"* "${SANDBOX_DIR}/usr/bin/" 2>/dev/null || true
        sudo rm -rf "${SANDBOX_DIR}/usr/sbin"
    fi
    sudo ln -sf bin "${SANDBOX_DIR}/usr/sbin"

    # Create essential directories
    for dir in tmp proc sys dev run var etc root home boot; do
        sudo mkdir -p "${SANDBOX_DIR}/${dir}"
    done

    sudo chmod 1777 "${SANDBOX_DIR}/tmp"
    sudo chmod 0555 "${SANDBOX_DIR}/proc"
    sudo chmod 0555 "${SANDBOX_DIR}/sys"
    sudo chmod 0755 "${SANDBOX_DIR}/dev"
    sudo chmod 0755 "${SANDBOX_DIR}/run"
    sudo chmod 0755 "${SANDBOX_DIR}/var"
    sudo chmod 0755 "${SANDBOX_DIR}/etc"
    sudo chmod 0700 "${SANDBOX_DIR}/root"

    # var subdirectories
    sudo mkdir -p "${SANDBOX_DIR}/var/tmp"
    sudo chmod 1777 "${SANDBOX_DIR}/var/tmp"
    sudo mkdir -p "${SANDBOX_DIR}/var/log"
    sudo mkdir -p "${SANDBOX_DIR}/var/cache"

    echo "=== [Root Coordinator] Installing packages into sandbox staging using straylight ==="
    mkdir -p build/pkg-cache
    for pkg in "${packages_to_build[@]}"; do
        manifest="packages/${pkg}/package.manifest"
        pkg_version=$(grep -E '^\s*version\s*=\s*' "$manifest" | head -n1 | cut -d'"' -f2)
        tarball="build/packages/${pkg}-${pkg_version}-1.tar.gz"
        echo "--> Installing package: $(basename "${tarball}")"
        STRAYLIGHT_RW_SYSTEM_ROOT="$(pwd)/build/sandbox-staging" \
        STRAYLIGHT_PKG_CACHE_ROOT="$(pwd)/build/pkg-cache" \
        sudo -E build/straylight install-pkg "${tarball}"
    done

    # Convenience symlinks
    if [[ -f "${SANDBOX_DIR}/usr/bin/bash" && ! -e "${SANDBOX_DIR}/usr/bin/sh" ]]; then
        sudo ln -sf bash "${SANDBOX_DIR}/usr/bin/sh"
    fi
    if [[ -f "${SANDBOX_DIR}/usr/bin/python3" && ! -e "${SANDBOX_DIR}/usr/bin/python" ]]; then
        sudo ln -sf python3 "${SANDBOX_DIR}/usr/bin/python"
    fi

    echo "=== [Root Coordinator] Creating final sandbox tarball ==="
    OUTPUT="$(pwd)/build/sandbox-root.tgz"
    sudo tar -czf "${OUTPUT}" -C "${SANDBOX_DIR}" .
    
    if [[ -n "${SUDO_UID:-}" ]]; then
        sudo chown "${SUDO_UID}:${SUDO_GID:-${SUDO_UID}}" "${OUTPUT}"
    fi

    tarball_size="$(du -h "${OUTPUT}" | awk '{print $1}')"
    echo "================================================================"
    echo "Sandbox rootfs assembled successfully!"
    echo "  Tarball:   ${OUTPUT}"
    echo "  Size:      ${tarball_size}"
    echo "================================================================"

# Build the straylight package manager CLI
build-straylight:
    @echo "=== [Root Coordinator] Building Straylight CLI ==="
    RUSTFLAGS="-L $(pwd)/straylight/lib" cargo test --manifest-path straylight/Cargo.toml -- --test-threads=1
    RUSTFLAGS="-L $(pwd)/straylight/lib" cargo build --manifest-path straylight/Cargo.toml --release
    mkdir -p build
    rm -f build/straylight
    cp straylight/target/release/straylight build/straylight
    @echo "=== Build Completed! Binary ready at build/straylight ==="


# ==============================================================================
# 4. Package Compilation
# ==============================================================================

# Compile a user-space package by name
build-package pkg_name: build-straylight
    #!/usr/bin/env bash
    set -euo pipefail
    STRAYLIGHT_BUILDER_ROOT="$(pwd)/build" \
    sudo -E build/straylight build "packages/{{pkg_name}}"

# Compile all user-space packages belonging to a specific group in topological order
build-package-group group_name: build-straylight
    #!/usr/bin/env bash
    set -euo pipefail
    
    # 1. Generate dependency pairs and topologically sort all packages
    sorted_packages=$( {
        for manifest in packages/*/package.manifest; do
            pkg_name=$(grep -E '^\s*name\s*=\s*' "$manifest" | head -n1 | cut -d'"' -f2)
            deps=$(sed -n '/^\[package\]/,/^\[/p' "$manifest" | grep -E '^\s*dependencies\s*=' | grep -oE '"[^"]+"' | sed 's/"//g')
            if [ -z "$deps" ]; then
                echo "$pkg_name $pkg_name"
            else
                for dep in $deps; do
                    echo "$dep $pkg_name"
                done
            fi
        done
    } | tsort 2>/dev/null )

    # 2. Filter and build packages matching the target group
    built=0
    for pkg in $sorted_packages; do
        manifest="packages/${pkg}/package.manifest"
        if [ -f "$manifest" ]; then
            pkg_group=$(grep -E '^\s*group\s*=\s*' "$manifest" | head -n1 | cut -d'"' -f2)
            if [ "$pkg_group" = "{{group_name}}" ]; then
                pkg_version=$(grep -E '^\s*version\s*=\s*' "$manifest" | head -n1 | cut -d'"' -f2)
                archive="build/packages/${pkg}-${pkg_version}-1.tar.gz"
                if [ -f "$archive" ]; then
                    echo "=== [Group Builder] Skipping package: ${pkg} (already built) ==="
                else
                    echo "=== [Group Builder] Building package: ${pkg} (group: {{group_name}}) ==="
                    STRAYLIGHT_BUILDER_ROOT="$(pwd)/build" \
                    sudo -E build/straylight build "packages/${pkg}"
                    built=$((built + 1))
                fi
            fi
        fi
    done

    if [ "$built" -eq 0 ]; then
        echo "Warning: No packages found in group '{{group_name}}'."
    else
        echo "=== [Group Builder] Successfully built ${built} packages in group '{{group_name}}' ==="
    fi


# ==============================================================================
# 5. Workspace Cleanup
# ==============================================================================

# Clean all subprojects and local build workspaces recursively
clean:
    @echo "=== [Root Coordinator] Cleaning Monorepo Workspace ==="
    just clean-straylight
    @echo "=== [Bootstrap] Purging sandbox build artifacts ==="
    just -f bootstrap/justfile clean

# Clean straylight build artifacts and target files
clean-straylight:
    @echo "=== [Straylight] Purging Cargo target and build cache ==="
    rm -rf straylight/target
    rm -rf .straylight
    rm -rf build/straylight

# Clean compiled user-space packages
clean-packages:
    @echo "=== [Root Coordinator] Purging compiled user-space packages ==="
    sudo rm -rf build/packages
