#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
RESEARCH_ROOT="${ROCM_RESEARCH_ROOT:-$HOME/rocm-ps5-research}"
ROCM="${ROCM_ROOT:-$RESEARCH_ROOT/rocm-root/usr}"
BUILD="$RESEARCH_ROOT/rocblas-build2"
INSTALL="${ROCBLAS_INSTALL_ROOT:-$RESEARCH_ROOT/rocblas-install}"
VENV="$RESEARCH_ROOT/torch-build-venv"
JOBS="${MAX_JOBS:-8}"

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ -f "$BUILD/CMakeCache.txt" ]] || die "Missing configured rocBLAS build tree: $BUILD"
grep -q '^Tensile_ARCHITECTURE:STRING=gfx1013$' "$BUILD/CMakeCache.txt" || die "rocBLAS build tree is not configured for gfx1013"
grep -q '^Tensile_LIBRARY_FORMAT:STRING=msgpack$' "$BUILD/CMakeCache.txt" || die "rocBLAS build tree is not configured for MessagePack Tensile data"
grep -q '^CMAKE_INSTALL_LIBDIR:STRING=lib$' "$BUILD/CMakeCache.txt" || die "rocBLAS install libdir is not lib"
grep -q "^CMAKE_INSTALL_PREFIX:PATH=$INSTALL$" "$BUILD/CMakeCache.txt" || die "rocBLAS install prefix does not match $INSTALL"
if pgrep -f "[n]inja -C $BUILD" >/dev/null; then
  die "A rocBLAS ninja build is already running for $BUILD"
fi

export ROCM_PATH="$ROCM" HIP_PATH="$ROCM"
export HIP_CLANG_PATH="$ROCM/lib/rocm/llvm/bin"
export PATH="$VENV/bin:$ROCM/bin:$ROCM/lib/rocm/llvm/bin:$PATH"
export LD_LIBRARY_PATH="$RESEARCH_ROOT/runtime-libs/usr/lib/x86_64-linux-gnu:$ROCM/lib/rocm/llvm/lib:$ROCM/lib/x86_64-linux-gnu:$ROCM/lib:$ROCM/lib/rocm/lib:${LD_LIBRARY_PATH:-}"
export PYTHONPATH="$RESEARCH_ROOT/build/venv-bootstrap:$ROCM/lib/python3.14:${PYTHONPATH:-}"

"$VENV/bin/ninja" -C "$BUILD" -j"$JOBS"
"$VENV/bin/cmake" --install "$BUILD"

[[ -f "$INSTALL/lib/librocblas.so" || -f "$INSTALL/lib/librocblas.so.5.1" ]] || die "rocBLAS library did not install under $INSTALL/lib"
[[ -f "$INSTALL/lib/rocblas/library/TensileLibrary_lazy_gfx1013.dat" ]] || die "gfx1013 Tensile library data did not install under $INSTALL/lib/rocblas/library"
LIB_LINK="$INSTALL/lib/librocblas.so"
[[ -e "$LIB_LINK" ]] || LIB_LINK="$INSTALL/lib/librocblas.so.5.1"
LIB="$(readlink -f "$LIB_LINK")"
[[ -f "$LIB" ]] || die "Cannot resolve installed librocblas.so"
if ldd "$LIB" | grep -q 'not found'; then die "Installed rocBLAS has unresolved shared-library dependencies"; fi
echo "Installed custom gfx1013 rocBLAS:"
ls -lh "$INSTALL/lib"/librocblas.so* 2>/dev/null
find "$INSTALL/lib/rocblas/library" -maxdepth 1 -type f | head -10
"$PROJECT_ROOT/scripts/install-rocm-rocblas-gfx1013.sh"
