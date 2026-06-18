#!/usr/bin/env bash
# setup.sh — Bootstraps the Freeside OS development workspace
set -euo pipefail

# 1. Determine if we are running inside an existing clone or bootstrapping a new folder
if [ -f "justfile" ] && grep -q "Freeside Monorepo Master Orchestrator" "justfile"; then
    echo "=== Running from within an existing Freeside workspace ==="
    WORKSPACE_DIR="."
else
    echo "=== Bootstrapping new Freeside workspace ==="
    if [ ! -d "freeside" ]; then
        echo "--> Cloning workspace configuration into ./freeside..."
        git clone git@github.com:freeside-os/freeside.git
    else
        echo "--> Directory ./freeside already exists."
    fi
    WORKSPACE_DIR="freeside"
fi

cd "${WORKSPACE_DIR}"

# 2. Create build directory
echo "--> Creating build directory..."
mkdir -p build

# 3. Clone sub-repositories
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
echo "Next steps:"
if [ "${WORKSPACE_DIR}" != "." ]; then
    echo "  cd ${WORKSPACE_DIR}"
fi
echo "  just status             - Check status of all repositories"
echo "  just build-straylight   - Compile the Straylight CLI"
echo "  just build-builder-sandbox - Build the bootstrap core sandbox"
