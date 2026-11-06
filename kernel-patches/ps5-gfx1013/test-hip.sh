#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-once}"
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TESTDIR="$ROOT/build/rocm-gfx1013"
ROCM="/home/michel/rocm-ps5-research/rocm-root/usr"
STATE="/var/lib/ps5-rocm-gfx1013-backup-path"
export LD_LIBRARY_PATH="$ROCM/lib/x86_64-linux-gnu:$ROCM/lib/rocm/llvm/lib:$ROCM/lib:$ROCM/lib/rocm/lib:${LD_LIBRARY_PATH:-}"
export GPU_PINNED_MIN_XFER_SIZE=16384
export TORCH_BLAS_PREFER_HIPBLASLT=0

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ -r /sys/module/amdgpu/parameters/bc250_flush_by_runlist ]] || die "Patched amdgpu module is not loaded"
[[ "$(cat /sys/module/amdgpu/parameters/bc250_flush_by_runlist)" == "1" ]] || die "Runlist TLB flush is not enabled"
[[ "$(cat /sys/module/amdgpu/parameters/bc250_flush_pasid_kiq)" == "0" ]] || die "PASID KIQ flush bypass is not enabled"
"$ROCM/bin/rocminfo" 2>/dev/null | grep -F 'gfx1013' >/dev/null || die "ROCm does not expose gfx1013"

case "$MODE" in
  once)
    [[ -x "$TESTDIR/hip-smoke-once" ]] || die "Missing hip-smoke-once binary"
    echo "Running one HIP allocation/copy/kernel/free cycle with SDMA disabled."
    HSA_ENABLE_SDMA=0 "$TESTDIR/hip-smoke-once"
    ;;
  stress)
    [[ -x "$TESTDIR/hip-smoke-stress" ]] || die "Missing hip-smoke-stress binary"
    echo "Running 30 HIP allocation/reuse cycles with SDMA disabled."
    HSA_ENABLE_SDMA=0 "$TESTDIR/hip-smoke-stress"
    ;;
  sdma)
    [[ -f "$STATE" ]] || die "No rollback state found; install.sh must run first"
    BACKUP="$(cat "$STATE")"
    [[ -f "$BACKUP/sdma-firmware-swapped" ]] || die "Navi12 SDMA firmware has not been staged"
    [[ -x "$TESTDIR/hip-smoke-stress" ]] || die "Missing hip-smoke-stress binary"
    echo "Running 30 HIP allocation/reuse cycles with Navi12 SDMA firmware enabled."
    HSA_ENABLE_SDMA=1 "$TESTDIR/hip-smoke-stress"
    ;;
  *) die "Usage: $0 [once|stress|sdma]" ;;
esac