#!/usr/bin/env bash
set -Eeuo pipefail
echo "PS5 AI Studio Linux — GPU detection"
echo "Kernel: $(uname -r)"
shopt -s nullglob
cards=(/sys/class/drm/card[0-9]*)
found=0
for card in "${cards[@]}"; do
  [[ -e "$card/device/vendor" ]] || continue
  vendor="$(cat "$card/device/vendor" 2>/dev/null || true)"
  device="$(cat "$card/device/device" 2>/dev/null || true)"
  driver="$(basename "$(readlink -f "$card/device/driver" 2>/dev/null || echo unknown)")"
  printf '%s vendor=%s device=%s driver=%s\n' "$(basename "$card")" "$vendor" "$device" "$driver"
  [[ "$vendor" == "0x1002" ]] && echo "  AMD GPU detected"
  found=1
done
(( found == 1 )) || echo "No DRM GPU device found."
if command -v vulkaninfo >/dev/null 2>&1; then
  vulkaninfo --summary || { echo "Vulkan enumeration failed; check ICD and /dev/dri permissions." >&2; exit 2; }
else
  echo "vulkaninfo missing. Install package: vulkan-tools"
  exit 3
fi
