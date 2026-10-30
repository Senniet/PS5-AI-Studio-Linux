#!/usr/bin/env bash
set -Eeuo pipefail
section() { printf '\n== %s ==\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

section "Operating system"
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  printf 'Distribution: %s\n' "${PRETTY_NAME:-unknown}"
else
  echo "Distribution metadata unavailable"
fi
printf 'Kernel: '; uname -sr
printf 'Architecture: '; uname -m

section "CPU and memory"
if have lscpu; then lscpu | grep -E '^(Architecture|CPU\(s\)|Model name|Thread\(s\) per core|Core\(s\) per socket):' || true; fi
if have free; then free -h; fi

section "Storage"
df -hT "$HOME" 2>/dev/null || true

section "Build tools"
for tool in git cmake ninja make gcc g++ clang python3 pkg-config; do
  if have "$tool"; then printf '%-12s %s\n' "$tool" "$(command -v "$tool")"; else printf '%-12s MISSING\n' "$tool"; fi
done

section "Vulkan"
if have vulkaninfo; then vulkaninfo --summary 2>&1 | sed -n '1,100p' || true; else echo "vulkaninfo missing; install vulkan-tools."; fi

section "DRM devices"
shopt -s nullglob
cards=(/sys/class/drm/card[0-9]*)
if (("${#cards[@]}" == 0)); then echo "No DRM card devices found."; fi
for card in "${cards[@]}"; do
  [[ -e "$card/device/vendor" ]] || continue
  printf '%s vendor=%s device=%s driver=%s\n' "$card" "$(cat "$card/device/vendor" 2>/dev/null || true)" "$(cat "$card/device/device" 2>/dev/null || true)" "$(basename "$(readlink -f "$card/device/driver" 2>/dev/null || echo unknown)")"
done

section "Permissions"
id
for node in /dev/dri/renderD*; do [[ -e "$node" ]] && ls -l "$node"; done

echo
echo "Read-only host inspection completed; no system settings were changed."
