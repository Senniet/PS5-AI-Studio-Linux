#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
RESEARCH_ROOT="${ROCM_RESEARCH_ROOT:-$HOME/rocm-ps5-research}"
SRC="${PYTORCH_SRC:-$RESEARCH_ROOT/pytorch-2.10.0}"
VENV="${ROCM_BUILD_VENV:-$RESEARCH_ROOT/torch-build-venv}"
ROCM="${ROCM_ROOT:-$RESEARCH_ROOT/rocm-root/usr}"
ROCblasInstall="${ROCBLAS_INSTALL_ROOT:-$RESEARCH_ROOT/rocblas-install}"
PYDEV="${PYTHON_DEV_ROOT:-$RESEARCH_ROOT/python-dev-root/usr}"
WHEELS="${ROCM_WHEEL_DIR:-$RESEARCH_ROOT/wheels}"
LOG="$RESEARCH_ROOT/build/pytorch-2.10.0-gfx1013.log"
JOBS="${MAX_JOBS:-4}"

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ -x "$VENV/bin/python" ]] || die "Missing build venv: $VENV"
git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1 || die "Missing or invalid PyTorch source checkout: $SRC"
[[ -f "$ROCblasInstall/lib/librocblas.so" || -f "$ROCblasInstall/lib/librocblas.so.5.1" ]] || die "Custom gfx1013 rocBLAS is not installed"
[[ -f "$ROCM/lib/x86_64-linux-gnu/libMIOpen.so.1.0" ]] || die "MIOpen runtime is missing from $ROCM"
[[ -f "$PYDEV/include/python3.14/Python.h" ]] || die "Python 3.14 development headers are missing from $PYDEV"
mkdir -p "$WHEELS" "$RESEARCH_ROOT/build"

export ROCM_PATH="$ROCM" ROCM_HOME="$ROCM" HIP_PATH="$ROCM"
export HIP_CLANG_PATH="$ROCM/lib/rocm/llvm/bin" HIP_PLATFORM=amd
export CC="$ROCM/lib/rocm/llvm/bin/clang-20" CXX="$ROCM/lib/rocm/llvm/bin/clang++"
export HIP_INCLUDE_PATH="$ROCM/include" HIP_LIB_PATH="$ROCM/lib/x86_64-linux-gnu"
export HIPCC_COMPILE_FLAGS_APPEND="--rocm-device-lib-path=$ROCM/lib/rocm/llvm/lib/clang/20/amdgcn/bitcode -I$ROCM/include"
export HIPCC_LINK_FLAGS_APPEND="-L$ROCM/lib/x86_64-linux-gnu -lamdhip64 -Wl,-rpath,$ROCM/lib/x86_64-linux-gnu"
export PATH="$VENV/bin:$ROCM/bin:$ROCM/lib/rocm/llvm/bin:$PATH"
export LD_LIBRARY_PATH="$RESEARCH_ROOT/runtime-libs/usr/lib/x86_64-linux-gnu:$ROCblasInstall/lib:$ROCM/lib/rocm/llvm/lib:$ROCM/lib/x86_64-linux-gnu:$ROCM/lib:$ROCM/lib/rocm/lib:${LD_LIBRARY_PATH:-}"
export PYTHONPATH="$ROCM/lib/python3.14:${PYTHONPATH:-}"
export PYTHON_INCLUDE_DIR="$PYDEV/include/python3.14"
export C_INCLUDE_PATH="$PYDEV/include:${C_INCLUDE_PATH:-}" CPLUS_INCLUDE_PATH="$PYDEV/include:${CPLUS_INCLUDE_PATH:-}"
export CPATH="$PYDEV/include/python3.14:$PYDEV/include/x86_64-linux-gnu/python3.14:$PYDEV/include:${CPATH:-}"
export CMAKE_PREFIX_PATH="$PYDEV:$ROCblasInstall:$ROCM:$ROCM/share/rocm/cmake:$ROCM/lib/x86_64-linux-gnu/cmake:$ROCM/lib/rocm/lib/cmake:${CMAKE_PREFIX_PATH:-}"
export CMAKE_GENERATOR=Ninja CMAKE_COMMAND="$VENV/bin/cmake"
export PYTORCH_ROCM_ARCH=gfx1013
export PYTORCH_BUILD_VERSION='2.10.0+ps5gfx1013' PYTORCH_BUILD_NUMBER=1
export USE_ROCM=1 USE_CUDA=0 USE_MIOPEN=1 USE_OPENMP=0
export USE_DISTRIBUTED=0 USE_GLOO=0 USE_TENSORPIPE=0 USE_MPI=0
export USE_KINETO=0 USE_CUPTI=0 USE_NVTX=0 USE_ITT=0
export USE_MKLDNN=0 USE_MKL=0 USE_FBGEMM=0
export USE_NNPACK=0 USE_QNNPACK=0 USE_PYTORCH_QNNPACK=0 USE_XNNPACK=0
export USE_FLASH_ATTENTION=0 USE_MEM_EFF_ATTENTION=0
export USE_ROCM_CK_GEMM=0 USE_ROCM_CK_SDPA=0 USE_RCCL=0 USE_NCCL=0
export BUILD_TEST=0 BUILD_CAFFE2=0
export MAX_JOBS="$JOBS" CMAKE_BUILD_PARALLEL_LEVEL="$JOBS"

"$PROJECT_ROOT/scripts/rocm/apply-pytorch-gfx1013-patches.sh"
cd "$SRC"
FBCODE_BUILD_TOOL=buck "$VENV/bin/python" tools/amd_build/build_amd.py > "$RESEARCH_ROOT/build/hipify-gfx1013.log" 2>&1
test -f "$SRC/c10/hip/impl/hip_cmake_macros.h.in" || die "PyTorch HIPify did not generate c10/hip sources"
"$VENV/bin/python" setup.py bdist_wheel --dist-dir "$WHEELS" 2>&1 | tee "$LOG"

# PyTorch's HIP kernels and host C++ translation units use different Clang ABI
# modes on this PS5 gfx1013 build. Add the legacy gemm exports and CPU shim,
# then package the self-loading compatibility bridge into the wheel.
WHEEL="$(find "$WHEELS" -maxdepth 1 -type f -name 'torch-2.10.0+ps5gfx1013-*.whl' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)"
[[ -n "$WHEEL" ]] || die "The PyTorch wheel was not created"
"$PROJECT_ROOT/scripts/rocm/finalize-torch-hip-abi-gfx1013.sh"
"$VENV/bin/python" "$PROJECT_ROOT/scripts/rocm/patch-torch-hip-abi-gfx1013.py" \
  --wheel "$WHEEL" \
  --hip-lib "$SRC/build/lib/libtorch_hip.so" \
  --shim-lib "$RESEARCH_ROOT/build/libtorch_hip_abi_compat.so" \
  --torch-init "$SRC/torch/__init__.py"
