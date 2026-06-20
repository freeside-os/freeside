---
name: distro-bootstrap-debugging
description: Guidelines and workflows for diagnosing and fixing package compilation, linking, and dependency errors in the Freeside Linux sandbox build.
---

# Freeside Linux: Distro Bootstrap & Sandbox Debugging Guide

This skill guides agents through troubleshooting, diagnosing, and fixing build errors encountered during the Stage 1 and Stage 2 sandbox packaging phases of Freeside Linux.

---

## 1. Sandbox Compilation Phases

| Phase | Host Environment | Compiler Toolchain | Storage/Permissions |
| :--- | :--- | :--- | :--- |
| **Stage 0** | Alpine Linux 3.20 (Docker) | GCC & Clang (with host headers/libs) | Writable overlay (disk) |
| **Stage 1** | Ephemeral `systemd-nspawn` container | LLVM/Clang only (pure musl, no GCC) | OverlayFS on host disk (`/workspace/build`) |
| **Stage 2** | Ephemeral `systemd-nspawn` container | Freeside-native LLVM/Clang (100% pure) | OverlayFS on host disk (`/workspace/build`) |

---

## 2. Diagnostics & Resolutions Reference

### A. Compiler Detection Errors (e.g., `gcc: command not found` or `configure` errors)
*   **Root Cause**: Package build scripts (like OpenSSL's `./config` or custom Makefiles) default to or hardcode `gcc` on Linux.
*   **Durable Fix**:
    1.  Ensure compiler wrapper symlinks (`gcc -> cc`, `g++ -> c++`) are configured inside [bootstrap/assemble-sandbox.sh](file:///home/dq/Code/freeside/bootstrap/assemble-sandbox.sh) and [packages/llvm/package.justfile](file:///home/dq/Code/freeside/packages/llvm/package.justfile).
    2.  For packages with persistent override issues, add `CC = "clang"` and/or `CXX = "clang++"` under the `[build.environment]` block in their `package.manifest`:
        ```toml
        [build.environment]
        CC = "clang"
        CXX = "clang++"
        ```

### B. Linker Errors (e.g., `ld.lld: error: unable to find library -lgcc`)
*   **Root Cause**: Precompiled compilers (such as Rust for `x86_64-unknown-linux-musl`) have target specs that explicitly pass `-lgcc` to pull in compiler runtime helpers. In a pure LLVM system, these helpers are provided by LLVM's `compiler-rt` builtins library.
*   **Durable Fix**:
    Map `libgcc.a` to the compiler-rt builtins library by adding a compatibility symlink in [bootstrap/assemble-sandbox.sh](file:///home/dq/Code/freeside/bootstrap/assemble-sandbox.sh) and [packages/llvm/package.justfile](file:///home/dq/Code/freeside/packages/llvm/package.justfile):
    ```bash
    # Locate compiler-rt builtins for the host target architecture (x86_64)
    BUILTINS_LIB=$(sudo find "${SANDBOX_DIR}/usr/lib/clang" -path "*x86_64*/libclang_rt.builtins.a" | head -n1)
    if [[ -n "${BUILTINS_LIB}" ]]; then
        REL_PATH=$(sudo realpath --relative-to="${SANDBOX_DIR}/usr/lib" "${BUILTINS_LIB}")
        sudo ln -sf "${REL_PATH}" "${SANDBOX_DIR}/usr/lib/libgcc.a"
    fi
    ```

### C. Missing Build Utilities (e.g., `m4: command not found`, `cmake: command not found`)
*   **Root Cause**: The tool was present in the Stage 0 Alpine Docker host (via `apk add`) but is missing from Freeside's `packages/` repository, preventing it from being built and included in the Stage 1 sandbox.
*   **Durable Fix**:
    1.  Create a new package recipe under `packages/<tool-name>/` with a standard `package.manifest` and `package.justfile`.
    2.  Declare the package as a build dependency in the dependent package's `package.manifest`:
        ```toml
        [build]
        dependencies = ["musl", "<tool-name>"]
        ```

### D. C++ Standard Errors (e.g., `error: ISO C++17 does not allow 'register' storage class specifier`)
*   **Root Cause**: Modern Clang compilers default to C++17 or newer, where legacy C++ features (like the `register` keyword or dynamic exception specifications) have been removed. Older software (e.g., `gperf-3.1`) fails to compile.
*   **Durable Fix**:
    Force a compatible C++ standard by adding `CXXFLAGS = "-std=gnu++14"` (or `-std=c++11`) to the `[build.environment]` block in the package's `package.manifest`:
    ```toml
    [build.environment]
    CXXFLAGS = "-std=gnu++14"
    ```

### E. Glibc-specific Sanitizers/Debug Libraries (e.g., `execinfo.h` missing, or sanitizer compile failures)
*   **Root Cause**: compiler-rt's sanitizers (ASan, TSan, GWP-ASan, etc.) or debug features in other packages often make assumptions about glibc-internal structures and header files (such as `<execinfo.h>`, `dirent64`, `fstab.h`) that are not present or differ significantly in Musl libc.
*   **Durable Fix**:
    1. For LLVM/compiler-rt, configure CMake to disable sanitizers and optional runtimes during the base toolchain build:
        ```cmake
        -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
        -DCOMPILER_RT_BUILD_GWP_ASAN=OFF \
        -DCOMPILER_RT_BUILD_XRAY=OFF \
        -DCOMPILER_RT_BUILD_ORC=OFF \
        -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
        -DCOMPILER_RT_BUILD_MEMPROF=OFF
        ```
    2. For other packages, disable features requiring glibc extensions via configure arguments (e.g., `--disable-backtrace`, `--without-execinfo`) or patch the source code to guard glibc-specific code paths behind `#if defined(__GLIBC__)`.

---

## 3. Resumable Sandbox Build Workflow

To resume a failed Stage 1 build without re-compiling already-successful packages (resumability):

1.  **Do NOT delete** `build/packages/` (this contains the built package `.tar.gz` archives).
2.  **Reset the sandbox chroot filesystem** to guarantee a clean environment before applying updates:
    ```bash
    sudo rm -rf build/sandbox
    ```
3.  **Resume building the base group**:
    ```bash
    STRAYLIGHT_BUILDER_ROOT="$(pwd)/build" sudo -E build/straylight build --group base
    ```
4.  **Resume building the builder group**:
    ```bash
    STRAYLIGHT_BUILDER_ROOT="$(pwd)/build" sudo -E build/straylight build --group builder
    ```
5.  **Reassemble the final sandbox image**:
    ```bash
    sudo tar -czf build/sandbox-root.tgz -C build/sandbox .
    ```

---

## 4. Inspecting Build Logs

When a package compilation fails, `fspack.py` captures the complete stdout/stderr of the `just build` and `just package` commands in a timestamped log file:
*   **Log Location**: `build/<pkg_name>-<timestamp>.log` (inside `/workspace/build` in the container).
*   **Automatic Cleanup**: By default, successful builds will automatically delete their log files.
*   **Preserving Logs on Success**: To keep log files even for successful builds (e.g., for profiling or verification), run the build command with the `--keep-all-logs` flag:
    ```bash
    just build-package <pkg_name> --keep-all-logs
    ```

---

## 5. Agent Interaction & Workflow Rules

When working on bootstrapping or build issues, always adhere to the following workflow preferences:

1.  **Diagnose and Propose for Non-Trivial Errors**:
    *   **Step 1**: Analyze the error log and understand the root cause.
    *   **Step 2**: Present one or more possible solutions to the user.
    *   **Wait for OK**: Do not edit any files until the user explicitly reviews the options and gives the "OK".
2.  **Auto-Implement Trivial/Simple Errors**:
    *   For simple errors (e.g., typos, checksum mismatches, missing dependencies in `package.manifest`, missing compiler flags), directly implement the fix and provide the diagnosis along with the implemented fix in a single interaction.
3.  **Avoid Shortcuts**:
    *   Keep builds reproducible. Always configure package manifests version-dynamically, staging targets to respect `$DESTDIR`, and place environment variables in `[build.environment]`.
4.  **No GPG Commit Signing**:
    *   If you need to make commits, always pass the `--no-gpg-sign` flag:
        ```bash
        git commit --no-gpg-sign -m "..."
        ```

