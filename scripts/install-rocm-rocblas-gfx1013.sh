#!/usr/bin/env bash
# Install the custom gfx1013 rocBLAS build into the isolated extracted ROCm tree.
set -Eeuo pipefail
ROOT="/home/michel/rocm-ps5-research"
BUILD="$ROOT/rocblas-build2"
HIPROOT="$ROOT/rocm-root/usr"
CMAKE="$ROOT/torch-build-venv/bin/cmake"
BACKUP="$ROOT/build/stock-rocm-rocblas"
LOG="$ROOT/build/rocblas-install.log"
MARKER="$ROOT/build/rocblas-installed-gfx1013"

[[ -x "$CMAKE" ]] || { echo "Build-venv CMake not found: $CMAKE"; exit 1; }
[[ -f "$BUILD/library/src/librocblas.so" || -f "$BUILD/library/src/librocblas.so.5.1" ]] || {
  echo "rocBLAS build output missing; finish ninja build first"; exit 1;
}
[[ -f "$ROOT/rocblas-install/lib/rocblas/library/TensileLibrary_lazy_gfx1013.dat" ]] || {
  echo "Expected gfx1013 Tensile library missing from completed build/install"; exit 1;
}

mkdir -p "$BACKUP"
backup_path(){
  local source="$1" relative="$2"
  [[ -e "$source" ]] || return 0
  [[ -e "$BACKUP/$relative" ]] && return 0
  mkdir -p "$BACKUP/$(dirname "$relative")"
  cp -a "$source" "$BACKUP/$relative"
}
for f in "$HIPROOT"/lib/x86_64-linux-gnu/librocblas.so*; do
  [[ -e "$f" ]] && backup_path "$f" "lib/x86_64-linux-gnu/$(basename "$f")"
done
for f in "$HIPROOT"/lib/librocblas.so*; do
  [[ -e "$f" ]] && backup_path "$f" "lib/$(basename "$f")"
done
backup_path "$HIPROOT/lib/rocblas" "lib/rocblas"
backup_path "$HIPROOT/lib/cmake/rocblas" "lib/cmake/rocblas"
backup_path "$HIPROOT/include/rocblas" "include/rocblas"
printf '%s\n' "$BACKUP" > "$MARKER"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROLLBACK_ACTIVE=1
rollback_on_error(){
  rc=$?
  trap - ERR
  if [[ "$ROLLBACK_ACTIVE" == "1" ]]; then
    "$SCRIPT_DIR/rollback-rocm-rocblas-gfx1013.sh" || true
  fi
  exit "$rc"
}
trap rollback_on_error ERR

"$CMAKE" --install "$BUILD" --prefix "$HIPROOT" > "$LOG" 2>&1

# PyTorch and the PS5 rocBLAS smoke test search the multiarch library directory.
# CMake's isolated install prefix uses lib/, so mirror its rocBLAS SONAME links
# into lib/x86_64-linux-gnu while keeping Tensile data at lib/rocblas/library.
mkdir -p "$HIPROOT/lib/x86_64-linux-gnu"
shopt -s nullglob
for f in "$HIPROOT"/lib/librocblas.so*; do
  cp -a "$f" "$HIPROOT/lib/x86_64-linux-gnu/"
done

CUSTOM_LIB="$HIPROOT/lib/x86_64-linux-gnu/librocblas.so.5.1"
TENSILE="$HIPROOT/lib/rocblas/library/TensileLibrary_lazy_gfx1013.dat"
[[ -f "$CUSTOM_LIB" ]] || { echo "Custom multiarch librocblas.so.5.1 missing"; tail -60 "$LOG"; exit 1; }
[[ -f "$TENSILE" ]] || { echo "Install did not place gfx1013 Tensile library at $TENSILE"; tail -60 "$LOG"; exit 1; }
cmp -s "$CUSTOM_LIB" "$HIPROOT/lib/librocblas.so.5.1" || {
  echo "Multiarch rocBLAS copy differs from the built library"; exit 1;
}

export LD_LIBRARY_PATH="$HIPROOT/lib/x86_64-linux-gnu:$HIPROOT/lib/rocm/llvm/lib:$HIPROOT/lib:$HIPROOT/lib/rocm/lib:${LD_LIBRARY_PATH:-}"
ldd "$CUSTOM_LIB" | tee "$ROOT/build/rocblas-ldd.txt"
if grep -q 'not found' "$ROOT/build/rocblas-ldd.txt"; then
  echo "Unresolved rocBLAS shared-library dependency"; exit 1
fi
sha256sum "$CUSTOM_LIB" "$TENSILE" | tee "$ROOT/build/rocblas-gfx1013-sha256.txt"
ROLLBACK_ACTIVE=0
trap - ERR
echo "gfx1013 rocBLAS installed in isolated ROCm root: $CUSTOM_LIB"
echo "Tensile data: $TENSILE"
echo "Stock backup: $BACKUP"