#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
KERNEL="$(uname -r)"
EXPECTED="7.3.0-PinkSoup"
MODULE="$ROOT/build/rocm-gfx1013/amdgpu.ko"
BOOT="/boot/efi"
FIRMWARE="/lib/firmware/amdgpu"
CONF="/etc/modprobe.d/ps5-rocm-gfx1013.conf"
STATE="/var/lib/ps5-rocm-gfx1013-backup-path"
MODULE_DEST="/lib/modules/$KERNEL/updates/amdgpu.ko"

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die "Run as root: sudo $0"
[[ "$KERNEL" == "$EXPECTED" ]] || die "This module is built for $EXPECTED, currently running $KERNEL"
[[ -f "$MODULE" ]] || die "Missing module: $MODULE"
[[ ! -e "$STATE" ]] || die "A PS5 ROCm install is already staged; use rollback.sh before starting another install"
[[ ! -e "$BOOT/kexec-ps5-rocm.sh" && ! -e "$BOOT/kexec-fallback-7.1.7.sh" && ! -e "$BOOT/cmdline.ps5-rocm.txt" ]] || die "Generated PS5 ROCm boot files already exist; inspect or remove them before installing"
[[ -d "$BOOT" && -f "$BOOT/bzImage" && -f "$BOOT/initrd.img" && -f "$BOOT/cmdline.txt" ]] || die "PS5 kexec boot files not found under $BOOT"
[[ -f "$BOOT/bzImage.old" && -f "$BOOT/initrd.img.old" ]] || die "Preserved 7.1.7 fallback kernel/initrd not found under $BOOT"
strings "$BOOT/bzImage.old" | grep -F "7.1.7" >/dev/null || die "Fallback bzImage.old does not identify as kernel 7.1.7"
for f in cyan_skillfish2_sdma.bin.zst cyan_skillfish2_sdma1.bin.zst; do [[ -f "$FIRMWARE/$f" ]] || die "Missing current firmware: $FIRMWARE/$f"; done
for c in depmod kexec strings modinfo lsinitramfs modprobe; do command -v "$c" >/dev/null || die "$c not installed"; done
[[ -f "/boot/config-$KERNEL" ]] || die "Kernel config /boot/config-$KERNEL is missing"
grep -q '^CONFIG_DRM_AMDGPU=m$' "/boot/config-$KERNEL" || die "amdgpu is not a loadable module in this kernel"

# The PS5 initramfs is loaded by the console's kexec loader. If it already
# contains amdgpu, it could load the stock module before the real root is
# mounted; refuse rather than silently booting the wrong driver.
if lsinitramfs "$BOOT/initrd.img" | grep -Eq '(^|/)amdgpu[.]ko([.][[:alnum:]]+)?$'; then
  die "The boot initramfs contains amdgpu; a boot-time module override needs an initramfs rebuild first"
fi

vermagic="$(modinfo -F vermagic "$MODULE")"
[[ "$vermagic" == "$KERNEL "* ]] || die "Module vermagic mismatch: $vermagic"
PARAMS="$(modinfo -F parm "$MODULE")"
for p in bc250_flush_by_runlist bc250_flush_pasid_kiq ps5_cu_unlock; do
  grep -q "^$p:" <<<"$PARAMS" || die "Patched module is missing parameter $p"
done
GPU_PCI=""
for d in /sys/bus/pci/devices/*; do
  [[ -r "$d/vendor" && -r "$d/device" ]] || continue
  if [[ "$(cat "$d/vendor")" == "0x1002" && "$(cat "$d/device")" == "0x13fb" ]]; then GPU_PCI="$d"; break; fi
done
[[ -n "$GPU_PCI" ]] || die "Expected PS5 Cyan Skillfish PCI device 1002:13fb not found"
strings "$BOOT/bzImage" | grep -F "$KERNEL" >/dev/null || die "EFI kernel image does not match $KERNEL"

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BOOT/ps5-rocm-backup-$STAMP"
mkdir -p "$BACKUP" "$(dirname "$MODULE_DEST")" /etc/modprobe.d /var/lib
cp -a "$FIRMWARE/cyan_skillfish2_sdma.bin.zst" "$BACKUP/"
cp -a "$FIRMWARE/cyan_skillfish2_sdma1.bin.zst" "$BACKUP/"
if [[ -e "$CONF" ]]; then cp -a "$CONF" "$BACKUP/"; fi
if [[ -e "$MODULE_DEST" ]]; then cp -a "$MODULE_DEST" "$BACKUP/amdgpu.ko"; fi
printf '%s\n' "$BACKUP" > "$STATE.tmp"
mv "$STATE.tmp" "$STATE"

install -D -m 0644 "$MODULE" "$MODULE_DEST"
cat > "$CONF" <<'EOF'
# PS5 GFX1013 ROCm workaround: runlist TLB flush on unmap; bypass PASID KIQ flush.
options amdgpu bc250_flush_by_runlist=1 bc250_flush_pasid_kiq=0 gpu_recovery=0
EOF
depmod -a "$KERNEL"
[[ "$(modinfo -k "$KERNEL" -n amdgpu)" == "$MODULE_DEST" ]] || die "depmod did not select the patched amdgpu module"
MODPROBE_OPTIONS="$(modprobe -c | grep -E '^options[[:space:]]+amdgpu([[:space:]]|$)' || true)"
grep -Fq 'bc250_flush_by_runlist=1' <<<"$MODPROBE_OPTIONS" || die "modprobe configuration did not retain the runlist-flush option"
grep -Fq 'bc250_flush_pasid_kiq=0' <<<"$MODPROBE_OPTIONS" || die "modprobe configuration did not retain the PASID KIQ bypass"
grep -Fq 'gpu_recovery=0' <<<"$MODPROBE_OPTIONS" || die "modprobe configuration did not retain the GPU recovery guard"

CMDLINE="$(cat "$BOOT/cmdline.txt")"
for token in amdgpu.bc250_flush_by_runlist=1 amdgpu.bc250_flush_pasid_kiq=0 amdgpu.gpu_recovery=0; do
  [[ " $CMDLINE " == *" $token "* ]] || CMDLINE="$CMDLINE $token"
done
printf '%s\n' "$CMDLINE" > "$BOOT/cmdline.ps5-rocm.txt"
printf -v CMDLINE_Q '%q' "$CMDLINE"
printf -v STOCK_CMDLINE_Q '%q' "$(cat "$BOOT/cmdline.txt")"
cat > "$BOOT/kexec-ps5-rocm.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
kexec -l "$BOOT/bzImage" --initrd="$BOOT/initrd.img" --command-line=$CMDLINE_Q
echo "Stopping AI services before the kexec transition..."
runuser -u michel -- env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus systemctl --user stop ps5-ai-studio-comfyui.service ps5-ai-studio-linux.service || true
systemctl stop ollama.service || true
systemctl stop gdm.service || true
sync
echo "Loading patched PS5 GFX1013 kernel. Stock boot files remain unchanged."
kexec -e
EOF
cat > "$BOOT/kexec-fallback-7.1.7.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
kexec -l "$BOOT/bzImage.old" --initrd="$BOOT/initrd.img.old" --command-line=$STOCK_CMDLINE_Q
echo "Loading the preserved stock 7.1.7 kernel."
kexec -e
EOF
chmod 0755 "$BOOT/kexec-ps5-rocm.sh" "$BOOT/kexec-fallback-7.1.7.sh"

echo
echo "Patched ROCm kernel module staged; no firmware was changed and no reboot was performed."
echo "  Module: $vermagic"
echo "  PCI: 1002:13fb"
echo "  KFD: runlist rebuild on unmap; PASID KIQ bypass"
echo "  Original SDMA firmware backed up for rollback; Navi12 firmware not installed yet."
echo "  Stock bzImage/initrd.img and kexec.sh remain unchanged."
echo
echo "First boot (kernel/TLB test only): sudo $BOOT/kexec-ps5-rocm.sh"
echo "After the HIP tests pass, stage the separate SDMA fix with:"
echo "  sudo $ROOT/kernel-patches/ps5-gfx1013/install-sdma-firmware.sh"
echo "  sudo $BOOT/kexec-ps5-rocm.sh"
echo "Fallback: sudo $BOOT/kexec-fallback-7.1.7.sh"
echo "Rollback: sudo $ROOT/kernel-patches/ps5-gfx1013/rollback.sh"
echo "Backup: $BACKUP"