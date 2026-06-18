#!/usr/bin/env bash
# setup.sh — Bootstraps the Freeside OS development workspace
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "=== Bootstrapping Freeside OS Development Workspace ==="

# 1. Create build directory
echo "--> Creating build directory..."
mkdir -p build

# 2. Clone sub-repositories
REPOS=(
    "git@github.com:freeside-os/bootstrap.git"
    "git@github.com:freeside-os/packages.git"
    "git@github.com:freeside-os/straylight.git"
    "git@github.com:freeside-os/docs.git"
)

for repo in "${REPOS[@]}"; do
    dir_name=$(basename "${repo}" .git)
    if [ ! -d "${dir_name}" ]; then
        echo "--> Cloning ${dir_name}..."
        git clone "${repo}"
    else
        echo "--> ${dir_name} already exists. Skipping."
    fi
done

echo ""
echo "=== Workspace Setup Complete ==="
echo "You can now run: "
echo "  just status             - Check status of all repositories"
echo "  just build-straylight   - Compile the Straylight CLI"
echo "  just build-bootstrap    - Build the bootstrap core sandbox"
