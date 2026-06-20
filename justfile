# Freeside Workspace Master Orchestrator
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
    @echo "=== Workspace ==="
    @git status -s; echo ""
    @for dir in {{git_repos}}; do \
        if [ -d "$dir/.git" ]; then \
            echo "=== Repository: $dir ==="; \
            git -C "$dir" status -s; \
            echo ""; \
        fi \
    done

# Show git diff of all configured repositories
diff:
    @echo "=== Workspace ==="
    @git diff --stat; git diff; echo ""
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
    STRAYLIGHT_PACKAGES_ROOT="$(pwd)/packages" \
    STRAYLIGHT_BUILDER_ROOT="$(pwd)/build" \
    STRAYLIGHT_BUILDER_OUTPUT_ROOT="$(pwd)/build/packages" \
    sudo -E build/straylight build --pkg "{{pkg_name}}"

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
                    STRAYLIGHT_PACKAGES_ROOT="$(pwd)/packages" \
                    STRAYLIGHT_BUILDER_ROOT="$(pwd)/build" \
                    STRAYLIGHT_BUILDER_OUTPUT_ROOT="$(pwd)/build/packages" \
                    sudo -E build/straylight build --pkg "${pkg}"
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
    @echo "=== [Root Coordinator] Cleaning Multi-Repo Workspace ==="
    just clean-straylight
    @echo "=== [Bootstrap] Purging sandbox build artifacts ==="
    just -f bootstrap/justfile clean
    @echo "=== [Root Coordinator] Purging build logs ==="
    sudo rm -f build/*.log

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
