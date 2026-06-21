# Straylight Package Manager compiler targets
set dotenv-load := false
set working-directory := ".."

# Build the straylight package manager CLI
build:
    @echo "=== [Root Coordinator] Building Straylight CLI ==="
    RUSTFLAGS="-L $(pwd)/straylight/lib" cargo test --manifest-path straylight/Cargo.toml -- --test-threads=1
    RUSTFLAGS="-L $(pwd)/straylight/lib" cargo build --manifest-path straylight/Cargo.toml --release
    mkdir -p build
    rm -f build/straylight
    cp straylight/target/release/straylight build/straylight
    @echo "=== Build Completed! Binary ready at build/straylight ==="

# Run the straylight package manager tests
test:
    @echo "=== [Straylight] Running Straylight CLI Tests ==="
    RUSTFLAGS="-L $(pwd)/straylight/lib" cargo test --manifest-path straylight/Cargo.toml -- --test-threads=1

# Clean straylight build artifacts and target files
clean:
    @echo "=== [Straylight] Purging Cargo target and build cache ==="
    rm -rf straylight/target
    rm -rf .straylight
    rm -rf build/straylight
