# Freeside Package Compilation
set dotenv-load := false
set working-directory := ".."

# Compile a user-space package by name
build pkg_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    just straylight::build
    
    STRAYLIGHT_PACKAGES_ROOT="$(pwd)/packages" \
    STRAYLIGHT_BUILDER_ROOT="$(pwd)/build" \
    STRAYLIGHT_BUILDER_OUTPUT_ROOT="$(pwd)/build/packages" \
    sudo -E build/straylight build --pkg "{{pkg_name}}"

# Compile all user-space packages belonging to a specific group in topological order
build-group group_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    just straylight::build
    
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

# Clean compiled user-space packages
clean:
    @echo "=== [Root Coordinator] Purging compiled user-space packages ==="
    sudo rm -rf build/packages
