#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="${PYTORCH_SRC:-${ROCM_RESEARCH_ROOT:-$HOME/rocm-ps5-research}/pytorch-2.10.0}"
PATCH="$PROJECT_ROOT/scripts/rocm/patches/pytorch-2.10.0-gfx1013-cmake.patch"
git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1 || { echo "Missing PyTorch source checkout: $SRC" >&2; exit 2; }
[[ -f "$PATCH" ]] || { echo "Missing gfx1013 patch: $PATCH" >&2; exit 2; }
if grep -q 'CAFFE2_PERF_WITH_AVX2=1' "$SRC/caffe2/perfkernels/CMakeLists.txt" \
 && grep -q 'HIP_CXX_FLAGS_PUBLIC' "$SRC/caffe2/CMakeLists.txt" \
 && grep -q '__hip_compile_flags' "$SRC/cmake/public/utils.cmake"; then
  echo "PyTorch gfx1013 CMake compatibility patches already applied."
else
  git -C "$SRC" apply --check "$PATCH"
  git -C "$SRC" apply "$PATCH"
  echo "Applied PyTorch gfx1013 CMake compatibility patches."
fi
