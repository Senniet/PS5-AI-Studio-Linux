#!/usr/bin/env bash
set -euo pipefail

BOOT=/boot/efi
BACKUP_ROOT="$BOOT/ps5-ai-performance-backups"
CPU_BOOST=/sys/devices/system/cpu/cpufreq/boost
CPU_SERVICE=/etc/systemd/system/ps5-ai-cpu-boost.service

usage() {
  cat <<'EOF'
PS5 hardware tuning helpers (original PS5 / PinkSoup kernel)

Read-only:
  status

Runtime CPU boost:
  enable-cpu-boost       Enable 3.3/3.4/3.5 GHz CPU boost table now
  disable-cpu-boost      Disable CPU boost table now

Persistent CPU boost:
  install-cpu-boost      Enable CPU boost at every boot (schedutil remains dynamic)
  remove-cpu-boost       Remove that service and disable CPU boost
  enable-recommended     Install CPU boost + enable 40 CUs + 8 GiB GTT ceiling
  disable-recommended    Remove 40-CU/GTT parameters + CPU boost service

Boot options (reboot required):
  enable-40cu            Set amdgpu.ps5_cu_unlock=3 (experimental, may artifact)
  disable-40cu           Remove the 40-CU parameter (returns to silicon default)
  enable-gtt-8gb         Set ttm.pages_limit=2097152 (8 GiB GTT ceiling)
  disable-gtt-8gb        Remove the GTT override (kernel default)

Run write operations with sudo. Backups are created under /boot/efi/ps5-ai-performance-backups.
EOF
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "ERROR: run this operation with sudo: sudo bash $0 $*" >&2
    exit 1
  fi
}

backup_boot_files() {
  local ts dir f
  mkdir -p "$BACKUP_ROOT"
  ts=$(date +%Y%m%d-%H%M%S)
  dir=$(mktemp -d "$BACKUP_ROOT/${ts}-XXXXXX")
  for f in "$BOOT/cmdline.txt" "$BOOT/cmdline.ps5-rocm.txt" "$BOOT/kexec-ps5-rocm.sh"; do
    [[ -f "$f" ]] && cp -a "$f" "$dir/"
  done
  echo "$dir"
}

update_file() {
  local file="$1" key="$2" value="$3" action="$4"
  [[ -f "$file" ]] || return 0
  python3 - "$file" "$key" "$value" "$action" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
key, value, action = sys.argv[2:]
s = p.read_text()
if p.name.startswith('kexec-'):
    # The kexec script stores its kernel command line with escaped spaces.
    s = re.sub(r'\\\s*' + re.escape(key) + r'=[^\s\\]+', '', s)
    if action == 'enable':
        anchor = 'amdgpu.gpu_recovery=0'
        addition = '\\ ' + key + '=' + value
        if anchor in s:
            s = s.replace(anchor, anchor + addition, 1)
        else:
            s = s.replace('--command-line=', '--command-line=' + key + '=' + value + '\\ ', 1)
else:
    tokens = s.split()
    tokens = [t for t in tokens if not t.startswith(key + '=')]
    if action == 'enable':
        tokens.append(key + '=' + value)
    s = ' '.join(tokens) + '\n'
p.write_text(s)
PY
}

update_boot_param() {
  local key="$1" value="$2" action="$3" f
  require_root "$action"
  local backup
  backup=$(backup_boot_files)
  for f in "$BOOT/cmdline.txt" "$BOOT/cmdline.ps5-rocm.txt" "$BOOT/kexec-ps5-rocm.sh"; do
    update_file "$f" "$key" "$value" "$action"
  done
  sync
  echo "Backup: $backup"
  echo "Updated $key ($action). A reboot is required for the active kernel command line."
  echo "Current loader cmdline:"
  cat "$BOOT/cmdline.txt"
}

case "${1:-status}" in
  status)
    echo "Kernel: $(uname -r)"
    echo "Active CU unlock: $(cat /sys/module/amdgpu/parameters/ps5_cu_unlock 2>/dev/null || echo unavailable)"
    echo "Active CPU boost: $(cat "$CPU_BOOST" 2>/dev/null || echo unavailable)"
    echo "CPU max: $(cat /sys/devices/system/cpu/cpufreq/policy0/cpuinfo_max_freq 2>/dev/null || echo unavailable)"
    echo "CPU boost frequencies: $(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_boost_frequencies 2>/dev/null || echo unavailable)"
    echo "TTM pages_limit: $(cat /sys/module/ttm/parameters/pages_limit 2>/dev/null || echo unavailable)"
    echo "Boot cmdline: $(cat "$BOOT/cmdline.txt" 2>/dev/null || echo unavailable)"
    ;;
  enable-recommended)
    require_root "$1"
    "$0" install-cpu-boost
    "$0" enable-gtt-8gb
    "$0" enable-40cu
    echo "Recommended tuning staged: CPU boost service, 8 GiB GTT ceiling and 40-CU unlock. Reboot to activate boot parameters."
    ;;
  disable-recommended)
    require_root "$1"
    "$0" disable-40cu
    "$0" disable-gtt-8gb
    "$0" remove-cpu-boost
    echo "Recommended tuning rolled back. Reboot to return to the default CU/GTT settings."
    ;;
  enable-cpu-boost)
    require_root "$1"
    [[ -w "$CPU_BOOST" ]] || { echo "CPU boost sysfs node unavailable: $CPU_BOOST" >&2; exit 1; }
    echo 1 > "$CPU_BOOST"
    echo "CPU boost enabled: $(cat "$CPU_BOOST")"
    echo "Boost frequencies: $(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_boost_frequencies)"
    ;;
  disable-cpu-boost)
    require_root "$1"
    echo 0 > "$CPU_BOOST"
    echo "CPU boost disabled: $(cat "$CPU_BOOST")"
    ;;
  install-cpu-boost)
    require_root "$1"
    cat > "$CPU_SERVICE" <<'EOF'
[Unit]
Description=Enable PS5 CPU boost frequencies for performance workloads
After=systemd-modules-load.service
ConditionPathExists=/sys/devices/system/cpu/cpufreq/boost

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 1 > /sys/devices/system/cpu/cpufreq/boost'
ExecStop=/bin/sh -c 'echo 0 > /sys/devices/system/cpu/cpufreq/boost'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now ps5-ai-cpu-boost.service
    echo "Persistent CPU boost enabled: $(cat "$CPU_BOOST")"
    ;;
  remove-cpu-boost)
    require_root "$1"
    systemctl disable --now ps5-ai-cpu-boost.service 2>/dev/null || true
    rm -f "$CPU_SERVICE"
    systemctl daemon-reload
    [[ -w "$CPU_BOOST" ]] && echo 0 > "$CPU_BOOST"
    echo "Persistent CPU boost service removed; boost=$(cat "$CPU_BOOST" 2>/dev/null || echo unavailable)"
    ;;
  enable-40cu)
    modinfo -p amdgpu 2>/dev/null | awk '/ps5_cu_unlock/ { found=1 } END { exit !found }' || { echo 'This kernel does not expose ps5_cu_unlock.' >&2; exit 1; }
    update_boot_param amdgpu.ps5_cu_unlock 3 enable
    ;;
  disable-40cu)
    update_boot_param amdgpu.ps5_cu_unlock 3 disable
    ;;
  enable-gtt-8gb)
    update_boot_param ttm.pages_limit 2097152 enable
    ;;
  disable-gtt-8gb)
    update_boot_param ttm.pages_limit 2097152 disable
    ;;
  *) usage; exit 2 ;;
esac