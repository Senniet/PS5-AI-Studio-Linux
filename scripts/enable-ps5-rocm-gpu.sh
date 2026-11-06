#!/usr/bin/env bash
# Temporary, reversible PS5 gfx1013 ROCm driver test.
# Does NOT replace the on-disk kernel module or initramfs.
set -Eeuo pipefail

echo "DEPRECATED: live amdgpu module replacement is not used on this PS5."
echo "The kernel keeps one amdgpu reference even after PCI unbind; do not force-unload it."
echo "Use the staged boot-time module path instead:"
echo "  sudo /home/michel/PS5-AI-Studio-Linux/kernel-patches/ps5-gfx1013/install.sh"
echo "  sudo /boot/efi/kexec-ps5-rocm.sh"
exit 64

ROOT="/home/michel/rocm-ps5-research"
PATCHED="$ROOT/build/amdgpu-ps5-gfx1013-final.ko"
KREL="$(uname -r)"
STOCK="/lib/modules/$KREL/kernel/drivers/gpu/drm/amd/amdgpu/amdgpu.ko"
HIPROOT="$ROOT/rocm-root/usr"
SMOKE="$ROOT/build/hip-smoke"
ENUM="$ROOT/build/hip-enumerate"
ROCBLAS_SMOKE="$ROOT/build/rocblas-smoke"
LOG="$ROOT/build/ps5-gpu-activation.log"
STOCK_UNLOADED=0
PATCHED_LOADED=0
DESKTOP_STOPPED=0
VTCON_UNBOUND=0
PCI_UNBOUND=0
GPU_BDF=""

unbind_fbcon(){
  local f=/sys/class/vtconsole/vtcon1/bind
  if [[ -w "$f" ]] && [[ "$(cat "$f")" == "1" ]]; then
    log "Unbinding framebuffer console from amdgpu before module swap"
    printf '0' > "$f"
    VTCON_UNBOUND=1
  fi
}

rebind_fbcon(){
  local f=/sys/class/vtconsole/vtcon1/bind
  if [[ $VTCON_UNBOUND -eq 1 && -w "$f" ]]; then
    printf '1' > "$f" && log "Framebuffer console rebound to the active amdgpu module" || log "WARNING: framebuffer console could not be rebound"
    VTCON_UNBOUND=0
  fi
}

log(){ printf '[%s] %s\n' "$(date -Is)" "$*" | tee -a "$LOG"; }
fail(){ log "ERROR: $*"; exit 1; }

start_desktop(){
  # Headless mode: never start GDM/GNOME; keep the AI services online over SSH/LAN.
  runuser -u michel -- env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus systemctl --user start ps5-ai-studio-linux.service ps5-ai-studio-comfyui.service 2>&1 | tee -a "$LOG" || true
  systemctl start ollama.service 2>&1 | tee -a "$LOG" || log "WARNING: Ollama did not restart; start it with systemctl start ollama.service"
  DESKTOP_STOPPED=0
}

bind_gpu(){
  if [[ $PCI_UNBOUND -eq 1 && -n "$GPU_BDF" && -e /sys/bus/pci/drivers/amdgpu/bind ]]; then
    if [[ "$(readlink -f "/sys/bus/pci/devices/$GPU_BDF/driver" 2>/dev/null || true)" == "/sys/bus/pci/drivers/amdgpu" ]]; then
      log "PS5 GPU $GPU_BDF was automatically rebound to amdgpu"
      PCI_UNBOUND=0
    elif printf '%s' "$GPU_BDF" > /sys/bus/pci/drivers/amdgpu/bind 2>>"$LOG"; then
      log "Rebound PS5 GPU $GPU_BDF to amdgpu"
      PCI_UNBOUND=0
    else
      log "WARNING: could not rebind PS5 GPU $GPU_BDF to amdgpu"
      return 1
    fi
  fi
}

load_stock(){
  if [[ $PATCHED_LOADED -eq 1 ]]; then
    if rmmod amdgpu 2>&1 | tee -a "$LOG"; then PATCHED_LOADED=0; else log "WARNING: patched module could not be unloaded"; return 1; fi
  fi
  if ! grep -q '^amdgpu ' /proc/modules; then
    local deps
    deps="$(modinfo -F depends "$STOCK" || true)"
    IFS=, read -ra dep_list <<< "$deps"
    for dep in "${dep_list[@]}"; do [[ -n "$dep" ]] && modprobe "$dep" || true; done
    insmod "$STOCK"
  fi
  STOCK_UNLOADED=0
  bind_gpu || true
}

rollback(){
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    log "Rolling back temporary driver change (exit=$rc)"
    if [[ $STOCK_UNLOADED -eq 1 ]]; then
      load_stock || log "WARNING: stock module reload failed; reboot restores the on-disk stock module"
    elif [[ $PATCHED_LOADED -eq 1 ]]; then
      # Detach the PCI function before removing the temporary module.
      if [[ $PCI_UNBOUND -eq 0 && -n "$GPU_BDF" && "$(readlink -f "/sys/bus/pci/devices/$GPU_BDF/driver" 2>/dev/null || true)" == "/sys/bus/pci/drivers/amdgpu" ]]; then
        if printf '%s' "$GPU_BDF" > /sys/bus/pci/drivers/amdgpu/unbind 2>>"$LOG"; then
          PCI_UNBOUND=1
          sleep 1
        else
          log "WARNING: could not detach GPU before patched-module rollback"
        fi
      fi
      if rmmod amdgpu 2>&1 | tee -a "$LOG"; then
        PATCHED_LOADED=0
        load_stock || log "WARNING: stock module reload failed; reboot restores the on-disk stock module"
      else
        log "WARNING: patched module remains loaded; reboot restores the on-disk stock module"
      fi
    fi
    bind_gpu || true
    rebind_fbcon
    if [[ $DESKTOP_STOPPED -eq 1 ]]; then start_desktop || log "WARNING: AI services did not restart; check their user units"; fi
  fi
}
trap rollback EXIT

if [[ $EUID -ne 0 ]]; then
  echo "Run once from a terminal with: sudo $0"
  exit 77
fi

[[ -f "$PATCHED" ]] || fail "Patched amdgpu module not found: $PATCHED"
[[ -f "$STOCK" ]] || fail "Stock amdgpu module not found: $STOCK"
[[ -x "$SMOKE" ]] || fail "HIP smoke-test binary missing: $SMOKE"
[[ -x "$ENUM" ]] || fail "HIP device-enumeration binary missing: $ENUM"
[[ -x "$ROCBLAS_SMOKE" ]] || fail "rocBLAS GEMM test binary missing: $ROCBLAS_SMOKE"
[[ "$(modinfo -F vermagic "$PATCHED" | awk '{print $1}')" == "$KREL" ]] || fail "Patched module vermagic does not match $KREL"
GPU_SYSFS="$(readlink -f /sys/class/drm/card0/device)"
[[ -r "$GPU_SYSFS/device" && "$(cat "$GPU_SYSFS/device")" == "0x13fb" ]] || fail "Expected PS5 APU PCI device 1002:13fb not found"
[[ -c /dev/kfd ]] || fail "/dev/kfd is missing"
[[ "$(cat /proc/sys/kernel/modules_disabled)" == "0" ]] || fail "Kernel module loading is disabled"
[[ -x "$HIPROOT/bin/rocminfo" ]] || fail "ROCm rocminfo missing"
[[ -f "$HIPROOT/lib/x86_64-linux-gnu/librocblas.so.5.1" ]] || fail "Custom gfx1013 rocBLAS is not installed in the ROCm root"
[[ -f "$HIPROOT/lib/rocblas/library/TensileLibrary_lazy_gfx1013.dat" ]] || fail "gfx1013 Tensile data is not installed in the ROCm root"

log "Preflight passed: kernel=$KREL, PS5 PCI=1002:13fb"
modinfo -p "$PATCHED" | grep -E 'bc250_flush|gpu_recovery|vm_fragment_size|ps5_cu_unlock' | tee -a "$LOG"

runuser -u michel -- env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus systemctl --user stop ps5-ai-studio-comfyui.service ps5-ai-studio-linux.service 2>&1 | tee -a "$LOG" || true
systemctl stop ollama.service 2>&1 | tee -a "$LOG" || fail "Could not stop system Ollama service"
systemctl is-active --quiet ollama.service && fail "Ollama is still active; refusing to unload amdgpu" || true
systemctl stop gdm.service || true
DESKTOP_STOPPED=1
sleep 3

if fuser -s /dev/dri/card0 /dev/dri/renderD128 /dev/kfd 2>/dev/null; then
  fail "GPU device is still in use after stopping GDM; refusing to unload amdgpu"
fi

unbind_fbcon
GPU_BDF="$(basename "$GPU_SYSFS")"
log "Unbinding PS5 GPU PCI function $GPU_BDF from amdgpu"
if [[ -e /sys/bus/pci/drivers/amdgpu/unbind ]]; then
  if printf '%s' "$GPU_BDF" > /sys/bus/pci/drivers/amdgpu/unbind 2>>"$LOG"; then
    PCI_UNBOUND=1
    sleep 2
  else
    fail "Could not unbind PS5 GPU PCI function $GPU_BDF from amdgpu"
  fi
else
  fail "amdgpu PCI unbind interface is missing"
fi
log "Unloading stock amdgpu module (in-memory only)"
if ! modprobe -r -v amdgpu 2>&1 | tee -a "$LOG"; then
  log "ERROR: modprobe could not unload amdgpu; collecting module dependency/refcount diagnostics"
  lsmod | grep -E "^(amdgpu|drm|gpu_sched|ttm)" | tee -a "$LOG" || true
  cat /sys/module/amdgpu/refcnt 2>&1 | tee -a "$LOG" || true
  fail "Stock amdgpu module unload failed; see the preceding modprobe diagnostic"
fi
STOCK_UNLOADED=1

# modprobe -r may unload dependencies; load them before insmod of the test module.
deps="$(modinfo -F depends "$PATCHED" || true)"
IFS=, read -ra dep_list <<< "$deps"
for dep in "${dep_list[@]}"; do [[ -n "$dep" ]] && modprobe "$dep"; done

log "Loading PS5 gfx1013 TLB-workaround module"
insmod "$PATCHED" bc250_flush_pasid_kiq=0 bc250_flush_by_runlist=1 gpu_recovery=0 vm_fragment_size=4 ps5_cu_unlock=1
PATCHED_LOADED=1
if [[ $PCI_UNBOUND -eq 1 ]]; then
  if [[ "$(readlink -f "/sys/bus/pci/devices/$GPU_BDF/driver" 2>/dev/null || true)" == "/sys/bus/pci/drivers/amdgpu" ]]; then
    PCI_UNBOUND=0
    log "PS5 GPU $GPU_BDF automatically bound to patched amdgpu module"
  elif printf '%s' "$GPU_BDF" > /sys/bus/pci/drivers/amdgpu/bind 2>>"$LOG"; then
    PCI_UNBOUND=0
    log "Bound PS5 GPU $GPU_BDF to patched amdgpu module"
  else
    fail "Patched amdgpu loaded but PS5 GPU $GPU_BDF could not be rebound"
  fi
fi

[[ "$(cat /sys/module/amdgpu/parameters/bc250_flush_pasid_kiq)" == "0" ]] || fail "PASID/KIQ workaround did not activate"
[[ "$(cat /sys/module/amdgpu/parameters/bc250_flush_by_runlist)" == "1" ]] || fail "Runlist TLB workaround did not activate"
[[ "$(cat /sys/module/amdgpu/parameters/gpu_recovery)" == "0" ]] || fail "GPU recovery guard did not activate"
[[ "$(cat /sys/module/amdgpu/parameters/ps5_cu_unlock)" == "1" ]] || fail "PS5 CU unlock did not activate"

export ROCM_PATH="$HIPROOT" HIP_PATH="$HIPROOT" HIP_CLANG_PATH="$HIPROOT/lib/rocm/llvm/bin"
export LD_LIBRARY_PATH="$HIPROOT/lib/rocm/llvm/lib:$HIPROOT/lib/x86_64-linux-gnu:$HIPROOT/lib:$HIPROOT/lib/rocm/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export HSA_ENABLE_SDMA=0 GPU_PINNED_MIN_XFER_SIZE=16384

log "Checking ROCm/HSA device enumeration"
timeout 30s "$HIPROOT/bin/rocminfo" > "$ROOT/build/rocminfo-patched.txt" 2>&1
grep -q 'Name:.*gfx1013' "$ROOT/build/rocminfo-patched.txt" || fail "ROCm did not enumerate gfx1013 after module swap"

log "Checking HIP runtime device enumeration"
timeout 30s "$ENUM" 2>&1 | tee -a "$LOG"
grep -q "HIP devices: 1" "$LOG" || fail "HIP runtime did not expose exactly one GPU"

log "Running small HIP vector-add correctness test (1024 elements)"
timeout 45s "$SMOKE" 2>&1 | tee -a "$LOG"
grep -q 'PASS: HIP vector add exact' "$LOG" || fail "HIP vector-add test did not report PASS"

log "Running rocBLAS 16x16 SGEMM correctness test"
timeout 60s "$ROCBLAS_SMOKE" 2>&1 | tee -a "$LOG"
grep -q 'PASS: rocBLAS SGEMM exact' "$LOG" || fail "rocBLAS SGEMM test did not report PASS"

rebind_fbcon
log "GPU compute test passed. Keeping patched module active for this boot only."
log "The original module and initramfs were not changed; reboot returns to stock."
start_desktop
runuser -u michel -- env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus systemctl --user is-active --quiet ps5-ai-studio-linux.service || fail "PS5 AI Studio web service did not recover"
runuser -u michel -- env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus systemctl --user is-active --quiet ps5-ai-studio-comfyui.service || fail "ComfyUI service did not recover"
PATCHED_LOADED=0
STOCK_UNLOADED=0
trap - EXIT
exit 0