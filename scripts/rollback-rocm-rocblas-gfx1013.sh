#!/usr/bin/env bash
# Restore the original ROCm rocBLAS and Tensile data from the install backup.
set -euo pipefail
ROOT="/home/michel/rocm-ps5-research"
HIPROOT="$ROOT/rocm-root/usr"
MARKER="$ROOT/build/rocblas-installed-gfx1013"
[[ -f "$MARKER" ]] || { echo "No gfx1013 rocBLAS install marker found"; exit 2; }
BACKUP="$(cat "$MARKER")"
[[ -d "$BACKUP" ]] || { echo "Missing rocBLAS backup: $BACKUP"; exit 2; }

rm -f "$HIPROOT"/lib/librocblas.so* "$HIPROOT"/lib/x86_64-linux-gnu/librocblas.so*
for f in "$BACKUP"/lib/librocblas.so*; do
  [[ -e "$f" ]] && cp -a "$f" "$HIPROOT/lib/"
done
for f in "$BACKUP"/lib/x86_64-linux-gnu/librocblas.so*; do
  [[ -e "$f" ]] && cp -a "$f" "$HIPROOT/lib/x86_64-linux-gnu/"
done

for rel in lib/rocblas lib/cmake/rocblas include/rocblas; do
  if [[ -e "$BACKUP/$rel" ]]; then
    rm -rf "$HIPROOT/$rel"
    mkdir -p "$(dirname "$HIPROOT/$rel")"
    cp -a "$BACKUP/$rel" "$HIPROOT/$rel"
  fi
done

rm -f "$MARKER"
echo "Restored stock ROCm rocBLAS/Tensile files from $BACKUP"