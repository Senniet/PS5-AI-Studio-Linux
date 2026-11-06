#!/usr/bin/env bash
# Build the PS5 gfx1013 amdgpu module without leaving patched source files behind.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
KERNEL_SRC="${KERNEL_SRC:-/home/michel/linux}"
RESEARCH_ROOT="${RESEARCH_ROOT:-$HOME/rocm-ps5-research}"
PATCHDIR="$SCRIPT_DIR"
OUT="$PROJECT_ROOT/build/rocm-gfx1013/amdgpu.ko"
BACKUP_ROOT="$RESEARCH_ROOT/build/source-backup"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUP_ROOT/ps5gfx1013-$STAMP"
LOG="$RESEARCH_ROOT/build/amdgpu-build-$STAMP.log"

FILES=(
  drivers/gpu/drm/amd/amdgpu/gmc_v10_0.c
  drivers/gpu/drm/amd/amdgpu/amdgpu_ttm.c
  drivers/gpu/drm/amd/amdkfd/kfd_chardev.c
  drivers/gpu/drm/amd/amdkfd/kfd_device_queue_manager.c
  drivers/gpu/drm/amd/amdkfd/kfd_device_queue_manager.h
)

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ -d "$KERNEL_SRC/.git" ]] || die "Missing kernel source tree: $KERNEL_SRC"
[[ -f "$KERNEL_SRC/.config" ]] || die "Kernel source tree has no .config"
[[ -f "$OUT" ]] || die "Missing previous module artifact: $OUT"
KERNEL_RELEASE="$(make -s -C "$KERNEL_SRC" kernelrelease)"
[[ "$KERNEL_RELEASE" == "7.3.0-PinkSoup" ]] || die "Expected kernelrelease 7.3.0-PinkSoup, got $KERNEL_RELEASE"
mkdir -p "$BACKUP"
for f in "${FILES[@]}"; do
  [[ -f "$KERNEL_SRC/$f" ]] || die "Missing source file: $KERNEL_SRC/$f"
  mkdir -p "$BACKUP/$(dirname "$f")"
  cp -a "$KERNEL_SRC/$f" "$BACKUP/$f"
done

cd "$KERNEL_SRC"
patch --dry-run -p1 < "$PATCHDIR/kfd-tlb-fix.patch"
patch --dry-run -p1 < "$PATCHDIR/amdgpu-ttm-null-check.patch"

restore_sources(){
  local rc=$?
  for f in "${FILES[@]}"; do cp -a "$BACKUP/$f" "$KERNEL_SRC/$f"; done
  rm -f \
    "$KERNEL_SRC/drivers/gpu/drm/amd/amdgpu/gmc_v10_0.o" \
    "$KERNEL_SRC/drivers/gpu/drm/amd/amdgpu/amdgpu_ttm.o" \
    "$KERNEL_SRC/drivers/gpu/drm/amd/amdgpu/amdgpu.o" \
    "$KERNEL_SRC/drivers/gpu/drm/amd/amdgpu/amdgpu.ko" \
    "$KERNEL_SRC/drivers/gpu/drm/amd/amdgpu/amdgpu.mod" \
    "$KERNEL_SRC/drivers/gpu/drm/amd/amdgpu/amdgpu.mod.c" \
    "$KERNEL_SRC/drivers/gpu/drm/amd/amdgpu/amdgpu.mod.o" \
    "$KERNEL_SRC/drivers/gpu/drm/amd/amdkfd/kfd_chardev.o" \
    "$KERNEL_SRC/drivers/gpu/drm/amd/amdkfd/kfd_device_queue_manager.o"
  rm -f \
    "$KERNEL_SRC/drivers/gpu/drm/amd/amdgpu/.gmc_v10_0.o.cmd" \
    "$KERNEL_SRC/drivers/gpu/drm/amd/amdgpu/.amdgpu_ttm.o.cmd" \
    "$KERNEL_SRC/drivers/gpu/drm/amd/amdgpu/.amdgpu.o.cmd" \
    "$KERNEL_SRC/drivers/gpu/drm/amd/amdgpu/.amdgpu.ko.cmd" \
    "$KERNEL_SRC/drivers/gpu/drm/amd/amdgpu/.amdgpu.mod.o.cmd" \
    "$KERNEL_SRC/drivers/gpu/drm/amd/amdkfd/.kfd_chardev.o.cmd" \
    "$KERNEL_SRC/drivers/gpu/drm/amd/amdkfd/.kfd_device_queue_manager.o.cmd"
  return "$rc"
}
trap restore_sources EXIT

cp -a "$OUT" "$RESEARCH_ROOT/build/amdgpu-ps5-gfx1013-pre-$STAMP.ko"
patch -p1 < "$PATCHDIR/kfd-tlb-fix.patch"
patch -p1 < "$PATCHDIR/amdgpu-ttm-null-check.patch"
make LLVM=1 M=drivers/gpu/drm/amd/amdgpu modules -j4 2>&1 | tee "$LOG"

BUILT="$KERNEL_SRC/drivers/gpu/drm/amd/amdgpu/amdgpu.ko"
[[ -f "$BUILT" ]] || die "Kernel build completed without amdgpu.ko"
cp -a "$BUILT" "$OUT"
cp -a "$BUILT" "$RESEARCH_ROOT/build/amdgpu-ps5-gfx1013-final.ko"

VERMAGIC="$(modinfo -F vermagic "$OUT")"
[[ "$VERMAGIC" == "$KERNEL_RELEASE "* ]] || die "Unexpected module vermagic: $VERMAGIC"
PARAMS="$(modinfo -F parm "$OUT")"
for p in bc250_flush_by_runlist bc250_flush_pasid_kiq ps5_cu_unlock; do
  grep -q "^$p:" <<<"$PARAMS" || die "Patched module missing parameter $p"
done
grep -q 'amdgpu_ttm.o' "$LOG" || die "Build log does not show amdgpu_ttm.o recompilation"

echo "Built module: $OUT"
echo "vermagic: $VERMAGIC"
modinfo -F parm "$OUT" | grep -E '^(bc250_flush_by_runlist|bc250_flush_pasid_kiq|ps5_cu_unlock):'
sha256sum "$OUT"
echo "Build log: $LOG"
echo "Source restoration and patched-object cleanup run automatically on exit."