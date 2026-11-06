#!/usr/bin/env bash
# Switch the ComfyUI user service to the separate, pre-tested ROCm venv.
# The existing CPU venv and its packages are never changed.
set -eEuo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
ROCM_VENV="$PROJECT_ROOT/runtimes/comfy-rocm-venv"
READY="$PROJECT_ROOT/build/comfy-rocm-venv-ready"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT_FILE="$UNIT_DIR/ps5-ai-studio-comfyui.service"
UNIT_TEMPLATE="$PROJECT_ROOT/packaging/systemd/ps5-ai-studio-comfyui-rocm.service"
STATE_DIR="$HOME/.local/state/ps5-ai-studio"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$STATE_DIR/comfy-unit-$STAMP"
STATE_FILE="$STATE_DIR/comfy-rocm-unit-backup-path"

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ "${1:-}" == "--apply" ]] || {
  echo "Dry run only. This switches the ComfyUI user service from the CPU venv to:"
  echo "  $ROCM_VENV"
  echo "The CPU venv remains untouched. Run with --apply only after the patched-kernel GPU tests pass."
  exit 0
}
[[ -f "$READY" ]] || die "ROCm ComfyUI venv is not marked ready; run scripts/create-comfy-rocm-venv.sh first"
[[ -x "$ROCM_VENV/bin/python" ]] || die "Missing ROCm ComfyUI venv"
[[ -f "$UNIT_FILE" && -f "$UNIT_TEMPLATE" ]] || die "ComfyUI user unit or ROCm template missing"
[[ -r /sys/module/amdgpu/parameters/bc250_flush_by_runlist ]] || die "Patched amdgpu module is not loaded"
[[ "$(cat /sys/module/amdgpu/parameters/bc250_flush_by_runlist)" == "1" ]] || die "KFD runlist TLB flush is not enabled"
[[ "$(cat /sys/module/amdgpu/parameters/bc250_flush_pasid_kiq)" == "0" ]] || die "PS5 PASID KIQ bypass is not enabled"

echo "Rechecking the ROCm ComfyUI venv before changing the service."
ROCM_TEST_VENV="$ROCM_VENV" "$PROJECT_ROOT/scripts/rocm/test-torch-gfx1013.sh" quick

mkdir -p "$STATE_DIR"
# Preserve the original CPU unit as the rollback target across repeated ROCm
# tuning attempts; never replace it with a previous ROCm unit.
if [[ -f "$STATE_FILE" ]] && [[ -f "$(cat "$STATE_FILE")/ps5-ai-studio-comfyui.service" ]] && grep -q 'comfy-rocm-venv' "$UNIT_FILE"; then
  BACKUP="$(cat "$STATE_FILE")"
else
  mkdir -p "$BACKUP"
  cp -a "$UNIT_FILE" "$BACKUP/ps5-ai-studio-comfyui.service"
  printf '%s\n' "$BACKUP" > "$STATE_FILE"
fi
ROLLBACK_NEEDED=1
rollback_on_error(){
  rc=$?
  trap - ERR
  if [[ "${ROLLBACK_NEEDED:-0}" == "1" ]]; then
    echo "ROCm service activation failed; restoring the previous CPU service unit." >&2
    systemctl --user stop ps5-ai-studio-comfyui.service >/dev/null 2>&1 || true
    cp -a "$BACKUP/ps5-ai-studio-comfyui.service" "$UNIT_FILE" || true
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user start ps5-ai-studio-comfyui.service >/dev/null 2>&1 || true
  fi
  exit "$rc"
}
trap rollback_on_error ERR

systemctl --user stop ps5-ai-studio-comfyui.service
cp -a "$UNIT_TEMPLATE" "$UNIT_FILE"
systemctl --user daemon-reload
systemctl --user start ps5-ai-studio-comfyui.service
for _ in {1..25}; do
  systemctl --user is-active --quiet ps5-ai-studio-comfyui.service && break
  sleep 1
done
systemctl --user is-active --quiet ps5-ai-studio-comfyui.service
"$ROCM_VENV/bin/python" - <<'PY'
import time
import urllib.error
import urllib.request

url = "http://192.168.2.210:8790/system_stats"
deadline = time.monotonic() + 90
last_error = None
while time.monotonic() < deadline:
    try:
        with urllib.request.urlopen(url, timeout=4) as response:
            if response.status == 200:
                print("ComfyUI ROCm API health check:", response.status)
                break
            last_error = f"HTTP {response.status}"
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        last_error = repr(exc)
    time.sleep(2)
else:
    raise RuntimeError(f"ComfyUI ROCm API did not become ready within 90 seconds: {last_error}")
PY

ROLLBACK_NEEDED=0
trap - ERR
echo "ComfyUI now uses the separate gfx1013 ROCm venv."
echo "CPU venv preserved. Service rollback backup: $BACKUP"