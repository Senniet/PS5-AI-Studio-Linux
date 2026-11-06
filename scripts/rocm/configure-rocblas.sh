#!/usr/bin/env bash
# Configure and build a fresh rocBLAS/Tensile gfx1013 tree via upstream rmake.py.
set -euo pipefail
RESEARCH_ROOT="${ROCM_RESEARCH_ROOT:-$HOME/rocm-ps5-research}"
ROCM="${ROCM_ROOT:-$RESEARCH_ROOT/rocm-root/usr}"
SRC="${ROCBLAS_SRC:-$RESEARCH_ROOT/rocmlib711/projects/rocblas}"
BUILD="${ROCBLAS_BUILD_ROOT:-$RESEARCH_ROOT/rocblas-build2}"
INSTALL="${ROCBLAS_INSTALL_ROOT:-$RESEARCH_ROOT/rocblas-install}"
VENV="${ROCM_BUILD_VENV:-$RESEARCH_ROOT/torch-build-venv}"
JOBS="${MAX_JOBS:-4}"

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ -x "$VENV/bin/python" ]] || die "Missing Python build venv: $VENV"
[[ -x "$VENV/bin/ninja" ]] || die "Missing Ninja in build venv: $VENV"
[[ -f "$SRC/rmake.py" ]] || die "Missing upstream rocBLAS rmake.py: $SRC"
[[ -x "$ROCM/lib/rocm/llvm/bin/amdclang" && -x "$ROCM/lib/rocm/llvm/bin/amdclang++" ]] || die "ROCm LLVM compiler wrappers are missing"
[[ ! -f "$BUILD/CMakeCache.txt" ]] || die "Build tree already configured at $BUILD; use build-rocblas.sh to resume it"
if pgrep -f "[n]inja -C $BUILD" >/dev/null; then die "A rocBLAS build is already running for $BUILD"; fi

export ROCM_PATH="$ROCM" HIP_PATH="$ROCM"
export HIP_CLANG_PATH="$ROCM/lib/rocm/llvm/bin"
export PATH="$VENV/bin:$ROCM/bin:$ROCM/lib/rocm/llvm/bin:$PATH"
export LD_LIBRARY_PATH="$RESEARCH_ROOT/runtime-libs/usr/lib/x86_64-linux-gnu:$ROCM/lib/rocm/llvm/lib:$ROCM/lib/x86_64-linux-gnu:$ROCM/lib:$ROCM/lib/rocm/lib:${LD_LIBRARY_PATH:-}"
export PYTHONPATH="$RESEARCH_ROOT/build/venv-bootstrap:$ROCM/lib/python3.14:${PYTHONPATH:-}"
export HIP_CLANG_NUM_PARALLEL_JOBS="$JOBS"
mkdir -p "$BUILD" "$INSTALL"

cd "$SRC"
"$VENV/bin/python" rmake.py \
  --architecture gfx1013 \
  --build_dir "$BUILD" \
  --ninja \
  --jobs "$JOBS" \
  --no_hipblaslt \
  --msgpack \
  --lazy-library-loading \
  --skipldconf \
  --cmake-darg "CMAKE_INSTALL_PREFIX=$INSTALL" \
  --cmake-darg "CMAKE_INSTALL_LIBDIR=lib" \
  --cmake-darg "ROCBLAS_TENSILE_LIBRARY_DIR=lib/rocblas" \
  --cmake-darg "BUILD_SHARED_LIBS=ON"

echo "rocBLAS gfx1013 build tree configured and built. Install with:"
echo "  ./scripts/rocm/build-rocblas.sh"