#!/usr/bin/env bash
# Build a minimal PyTorch 2.9.1 ROCm wheel with gfx1013 code objects.
# Run only after the PS5 HIP/KFD activation test and custom rocBLAS build pass.
set -Eeuo pipefail

ROOT="/home/michel/rocm-ps5-research"
SRC="$ROOT/pytorch-2.9.1"
VENV="$ROOT/torch-build-venv"
HIPROOT="$ROOT/rocm-root/usr"
LOG="$ROOT/build/pytorch-gfx1013-build.log"

[[ -d "$SRC/torch" ]] || { echo "PyTorch source missing: $SRC"; exit 1; }
[[ -x "$VENV/bin/python" ]] || { echo "Build venv missing: $VENV"; exit 1; }
[[ -f "$HIPROOT/lib/x86_64-linux-gnu/librocblas.so.5.1" ]] || { echo "ROCm rocBLAS library missing"; exit 1; }
find "$HIPROOT" -type f -name 'TensileLibrary_lazy_gfx1013.dat' -print -quit | grep -q . || { echo "gfx1013 Tensile library missing; finish rocBLAS build first"; exit 1; }

export ROCM_PATH="$HIPROOT" ROCM_HOME="$HIPROOT" HIP_PATH="$HIPROOT" ROCM_SOURCE_DIR="$HIPROOT"
export HIP_CLANG_PATH="$HIPROOT/lib/rocm/llvm/bin"
export PATH="$HIPROOT/bin:$HIPROOT/lib/rocm/llvm/bin:$VENV/bin:$PATH"
export LD_LIBRARY_PATH="$HIPROOT/lib/rocm/llvm/lib:$HIPROOT/lib/x86_64-linux-gnu:$HIPROOT/lib:$HIPROOT/lib/rocm/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export CMAKE_PREFIX_PATH="$HIPROOT:$HIPROOT/lib/cmake${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
export PYTORCH_ROCM_ARCH=gfx1013
export USE_ROCM=1 USE_CUDA=0
export USE_NCCL=0 USE_RCCL=0 USE_DISTRIBUTED=0
export USE_ROCM_CK_GEMM=0 USE_ROCM_CK_SDPA=0
export USE_FLASH_ATTENTION=0 USE_MEM_EFF_ATTENTION=0
export USE_MKLDNN=0 USE_FBGEMM=0 USE_NNPACK=0 USE_QNNPACK=0 USE_XNNPACK=0
export USE_KINETO=0 BUILD_TEST=0 BUILD_CAFFE2=0
export USE_NUMA=0 USE_MPI=0 USE_TENSORPIPE=0
export MAX_JOBS=2 CMAKE_BUILD_PARALLEL_LEVEL=2
export CMAKE_BUILD_TYPE=Release
export CMAKE_CXX_FLAGS="-g0" CMAKE_C_FLAGS="-g0"
export CMAKE_HIP_FLAGS="--rocm-device-lib-path=$HIPROOT/lib/rocm/llvm/lib/clang/20/amdgcn/bitcode"
export HIPCC_COMPILE_FLAGS_APPEND="--rocm-device-lib-path=$HIPROOT/lib/rocm/llvm/lib/clang/20/amdgcn/bitcode"

cd "$SRC"
{
  echo "=== PS5 PyTorch gfx1013 build $(date -Is) ==="
  "$VENV/bin/python" -c 'import sys; print(sys.version)'
  "$HIPROOT/bin/rocminfo" | grep -E 'Name:.*gfx1013|Chip ID:.*13fb|Compute Unit:' | head -10
  "$VENV/bin/python" tools/amd_build/build_amd.py
  "$VENV/bin/python" setup.py bdist_wheel
  echo "=== build completed $(date -Is) ==="
  ls -lh dist/*.whl
} 2>&1 | tee "$LOG"
