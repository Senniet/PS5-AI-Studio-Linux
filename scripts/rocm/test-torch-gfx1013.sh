#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
RESEARCH_ROOT="${ROCM_RESEARCH_ROOT:-$HOME/rocm-ps5-research}"
ROCM="${ROCM_ROOT:-$RESEARCH_ROOT/rocm-root/usr}"
ROCblasInstall="${ROCBLAS_INSTALL_ROOT:-$RESEARCH_ROOT/rocblas-install}"
VENV="${ROCM_TEST_VENV:-$RESEARCH_ROOT/torch-build-venv}"
MODE="${1:-tlb}"
shift || true

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ -x "$VENV/bin/python" ]] || die "Missing test venv: $VENV"
[[ -r /sys/module/amdgpu/parameters/bc250_flush_by_runlist ]] || die "Patched amdgpu module is not loaded"
[[ "$(cat /sys/module/amdgpu/parameters/bc250_flush_by_runlist)" == "1" ]] || die "KFD runlist TLB flush is not enabled"
[[ "$(cat /sys/module/amdgpu/parameters/bc250_flush_pasid_kiq)" == "0" ]] || die "PS5 PASID KIQ bypass is not enabled"
case "$MODE" in
  tlb|quick)
    export HSA_ENABLE_SDMA=0
    ;;
  sdma)
    [[ -f /var/lib/ps5-rocm-gfx1013-backup-path ]] || die "No staged firmware backup state"
    BACKUP="$(cat /var/lib/ps5-rocm-gfx1013-backup-path)"
    [[ -f "$BACKUP/sdma-firmware-swapped" ]] || die "Navi12 SDMA firmware has not been staged"
    export HSA_ENABLE_SDMA=1
    ;;
  *) die "Usage: $0 [tlb|quick|sdma] [--skip-torchaudio] [--skip-pinned]" ;;
esac

# rocminfo must run with the isolated ROCm runtime libraries already on the path.
export GPU_PINNED_MIN_XFER_SIZE=16384
export TORCH_BLAS_PREFER_HIPBLASLT=0
export ROCM_PATH="$ROCM" ROCM_HOME="$ROCM" HIP_PATH="$ROCM"
export LD_LIBRARY_PATH="$RESEARCH_ROOT/runtime-libs/usr/lib/x86_64-linux-gnu:$ROCblasInstall/lib:$ROCM/lib/rocm/llvm/lib:$ROCM/lib/x86_64-linux-gnu:$ROCM/lib:$ROCM/lib/rocm/lib:${LD_LIBRARY_PATH:-}"

"$ROCM/bin/rocminfo" 2>/dev/null | grep -F 'gfx1013' >/dev/null || die "ROCm does not expose gfx1013"

LOOPS=30
[[ "$MODE" == "quick" ]] && LOOPS=5
exec "$VENV/bin/python" "$PROJECT_ROOT/scripts/rocm/test-torch-gfx1013.py" --loops "$LOOPS" "$@"
