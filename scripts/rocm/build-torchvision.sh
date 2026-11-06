#!/usr/bin/env bash
set -euo pipefail
RESEARCH_ROOT="${ROCM_RESEARCH_ROOT:-$HOME/rocm-ps5-research}"
SRC="${TORCHVISION_SRC:-$RESEARCH_ROOT/torchvision-0.25.0}"
VENV="${ROCM_BUILD_VENV:-$RESEARCH_ROOT/torch-build-venv}"
ROCM="${ROCM_ROOT:-$RESEARCH_ROOT/rocm-root/usr}"
PYDEV="$RESEARCH_ROOT/python-dev-root/usr"
export C_INCLUDE_PATH="$PYDEV/include:${C_INCLUDE_PATH:-}" CPLUS_INCLUDE_PATH="$PYDEV/include:${CPLUS_INCLUDE_PATH:-}"
export CPATH="$PYDEV/include/python3.14:$PYDEV/include/x86_64-linux-gnu/python3.14:$PYDEV/include:${CPATH:-}"
ROCblasInstall="${ROCBLAS_INSTALL_ROOT:-$RESEARCH_ROOT/rocblas-install}"
WHEELS="${ROCM_WHEEL_DIR:-$RESEARCH_ROOT/wheels}"
# Load the patched ROCm PyTorch wheel before its first import check.
export ROCM_PATH="$ROCM" ROCM_HOME="$ROCM" HIP_PATH="$ROCM"
export LD_LIBRARY_PATH="$RESEARCH_ROOT/runtime-libs/usr/lib/x86_64-linux-gnu:$ROCblasInstall/lib:$ROCM/lib/rocm/llvm/lib:$ROCM/lib/x86_64-linux-gnu:$ROCM/lib:$ROCM/lib/rocm/lib:${LD_LIBRARY_PATH:-}"
export PATH="$VENV/bin:$ROCM/bin:$ROCM/lib/rocm/llvm/bin:$PATH"
LOG="$RESEARCH_ROOT/build/torchvision-0.25.0-gfx1013.log"
JOBS="${MAX_JOBS:-2}"
mkdir -p "$WHEELS" "$RESEARCH_ROOT/build"
git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1 || { echo "Missing or invalid torchvision source checkout: $SRC" >&2; exit 2; }
[[ -f "$ROCblasInstall/lib/librocblas.so" || -f "$ROCblasInstall/lib/librocblas.so.5.1" ]] || { echo "Custom gfx1013 rocBLAS is not installed" >&2; exit 2; }
"$VENV/bin/python" - <<'PY'
import torch
assert torch.version.hip is not None, f"Expected ROCm PyTorch, got {torch.__version__}"
print("Building torchvision against", torch.__version__, "HIP", torch.version.hip)
PY
export ROCM_PATH="$ROCM" ROCM_HOME="$ROCM" HIP_PATH="$ROCM"
export HIP_CLANG_PATH="$ROCM/lib/rocm/llvm/bin" HIP_PLATFORM=amd
export CC="$ROCM/lib/rocm/llvm/bin/clang-20" CXX="$ROCM/lib/rocm/llvm/bin/clang++"
export HIP_INCLUDE_PATH="$ROCM/include" HIP_LIB_PATH="$ROCM/lib/x86_64-linux-gnu"
export HIPCC_COMPILE_FLAGS_APPEND="--rocm-device-lib-path=$ROCM/lib/rocm/llvm/lib/clang/20/amdgcn/bitcode -I$ROCM/include"
export HIPCC_LINK_FLAGS_APPEND="-L$ROCM/lib/x86_64-linux-gnu -lamdhip64 -Wl,-rpath,$ROCM/lib/x86_64-linux-gnu"
# setuptools links the extension with clang++ directly, not hipcc; pass the HIP library path explicitly.
export LDFLAGS="${LDFLAGS:-} -L$ROCM/lib/x86_64-linux-gnu -Wl,-rpath,$ROCM/lib/x86_64-linux-gnu"
export LIBRARY_PATH="$ROCM/lib/x86_64-linux-gnu:${LIBRARY_PATH:-}"
export PATH="$VENV/bin:$ROCM/bin:$ROCM/lib/rocm/llvm/bin:$PATH"
export LD_LIBRARY_PATH="$RESEARCH_ROOT/runtime-libs/usr/lib/x86_64-linux-gnu:$ROCblasInstall/lib:$ROCM/lib/rocm/llvm/lib:$ROCM/lib/x86_64-linux-gnu:$ROCM/lib:$ROCM/lib/rocm/lib:${LD_LIBRARY_PATH:-}"
export PYTHONPATH="$ROCM/lib/python3.14:${PYTHONPATH:-}"
export CMAKE_PREFIX_PATH="$ROCblasInstall:$ROCM:$ROCM/share/rocm/cmake:$ROCM/lib/x86_64-linux-gnu/cmake:$ROCM/lib/rocm/lib/cmake:${CMAKE_PREFIX_PATH:-}"
export CMAKE_GENERATOR=Ninja CMAKE_COMMAND="$VENV/bin/cmake" PYTORCH_ROCM_ARCH=gfx1013
export BUILD_VERSION='0.25.0+ps5gfx1013' FORCE_CUDA=1
export MAX_JOBS="$JOBS" CMAKE_BUILD_PARALLEL_LEVEL="$JOBS"
export TORCHVISION_USE_FFMPEG=0 TORCHVISION_USE_VIDEO_CODEC=0 TORCHVISION_USE_NVJPEG=0
cd "$SRC"
"$VENV/bin/python" setup.py bdist_wheel --dist-dir "$WHEELS" 2>&1 | tee "$LOG"
