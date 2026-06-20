# Freeside Workspace Git Management
set dotenv-load := false
set working-directory := ".."

git_repos := "bootstrap packages straylight docs .github"

# List git status of all configured repositories
status:
    @echo "=== Workspace ==="
    @git status -sb; echo ""
    @for dir in {{git_repos}}; do \
        if [ -d "$dir/.git" ]; then \
            echo "=== Repository: $dir ==="; \
            git -C "$dir" status -sb; \
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

# Create and push a git tag across all repositories (fails if there are uncommitted changes)
tag tag_name:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "=== Checking for uncommitted changes ==="
    if [ -n "$(git status --porcelain)" ]; then
        echo "Error: Parent workspace has uncommitted changes." >&2
        git status -s
        exit 1
    fi

    for dir in {{git_repos}}; do
        if [ -d "$dir/.git" ]; then
            if [ -n "$(git -C "$dir" status --porcelain)" ]; then
                echo "Error: Repository '$dir' has uncommitted changes." >&2
                git -C "$dir" status -s
                exit 1
            fi
        fi
    done
    echo "✓ All repositories are clean."

    echo "=== Creating and pushing tag: {{tag_name}} ==="
    echo "Tagging parent workspace..."
    git tag "{{tag_name}}"
    git push origin "{{tag_name}}"

    for dir in {{git_repos}}; do
        if [ -d "$dir/.git" ]; then
            echo "Tagging repository '$dir'..."
            git -C "$dir" tag "{{tag_name}}"
            git -C "$dir" push origin "{{tag_name}}"
        fi
    done
    echo "✓ Tag {{tag_name}} created and pushed successfully across all repositories."
