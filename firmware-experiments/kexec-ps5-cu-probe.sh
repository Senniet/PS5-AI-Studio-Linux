#!/usr/bin/env bash
set -euo pipefail

# Safe, non-unlocking probe for the PS5 harvested-CU patch.
# This loads the existing PS5 kernel via kexec with amdgpu.ps5_cu_unlock=4.
# Mode 4 writes and restores the register values; it does NOT enable extra CUs.

if [[ ${EUID} -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0" >&2
  exit 1
fi

KERNEL=/boot/efi/bzImage
INITRD=/boot/efi/initrd.img
PARAM=/sys/module/amdgpu/parameters/ps5_cu_unlock

for f in "$KERNEL" "$INITRD"; do
  [[ -r "$f" ]] || { echo "Missing boot file: $f" >&2; exit 1; }
done
[[ -r "$PARAM" ]] || { echo "Running amdgpu driver has no ps5_cu_unlock parameter." >&2; exit 1; }
command -v kexec >/dev/null || { echo "kexec is not installed." >&2; exit 1; }

CURRENT=$(cat "$PARAM")
ACTIVE_CU=$(journalctl -k -b -o cat 2>/dev/null | sed -n 's/.*active_cu_number \([0-9][0-9]*\).*/\1/p' | tail -1)
echo "Current ps5_cu_unlock=$CURRENT; detected active CUs=${ACTIVE_CU:-unknown}."
if [[ "$CURRENT" != "0" ]]; then
  echo "Expected the normal locked state (0) before running a probe; refusing." >&2
  exit 1
fi

if command -v curl >/dev/null && command -v python3 >/dev/null; then
  if curl -fsS --max-time 3 http://192.168.2.210:8790/queue 2>/dev/null | python3 -c 'import json,sys;x=json.load(sys.stdin);sys.exit(1 if x.get("queue_running") or x.get("queue_pending") else 0)'; then
    :
  else
    echo "ComfyUI queue is not idle or could not be checked; refusing to interrupt it." >&2
    exit 1
  fi
fi

# Preserve the active kernel command line, then explicitly preserve the PS5
# ROCm driver settings used by the existing kexec-ps5-rocm.sh workflow.
CMDLINE=$(tr -s ' ' '\n' </proc/cmdline | grep -v '^amdgpu\.' | paste -sd ' ' -)
CMDLINE="$CMDLINE amdgpu.bc250_flush_by_runlist=1 amdgpu.bc250_flush_pasid_kiq=0 amdgpu.gpu_recovery=0 amdgpu.ps5_cu_unlock=4"

printf '\nProbe command line:\n%s\n\n' "$CMDLINE"
echo "Loading $KERNEL and $INITRD into kexec (no boot transition yet)..."
kexec -l "$KERNEL" --initrd="$INITRD" --command-line="$CMDLINE"

cat <<'MSG'

READY: this is PROBE MODE 4 only. It does not enable the four harvested CUs.
After boot, inspect:
  journalctl -k -b | grep 'ps5-40cu-probe'
  journalctl -k -b | grep 'active_cu_number'
Only if the CC and SPI register readbacks are sensible should a separate
mode-3 unlock test be considered. No persistent EFI cmdline file is changed.
MSG

read -r -p "Stop AI services and kexec into the safe probe now? Type YES: " answer
if [[ "$answer" != "YES" ]]; then
  kexec -u || true
  echo "Cancelled; staged kexec image unloaded. No restart performed."
  exit 0
fi

runuser -u michel -- env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
  systemctl --user stop ps5-ai-studio-comfyui.service ps5-ai-studio-linux.service || true
systemctl stop ollama.service || true
systemctl stop gdm.service || true
sync
echo "Executing safe CU probe kexec..."
kexec -e