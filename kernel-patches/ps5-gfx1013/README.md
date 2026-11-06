# PS5 Cyan Skillfish gfx1013 ROCm kernel workaround

This is an experimental, reversible kernel-module workaround for the retail PS5 Linux GPU (`1002:13fb`, AMD Cyan Skillfish / gfx1013). It is adapted from the BC-250 gfx1013 investigation, but the retail PS5 is not a BC-250 board: it has a different PCI ID, firmware/boot path, memory layout and active CU count. Do not copy BC-250 BIOS or UMA instructions to the PS5.

## Target verified on this machine

- Kernel: `7.3.0-PinkSoup`
- GPU PCI ID: `1002:13fb`
- GPU target: `gfx1013`
- Active compute units reported by the current driver: 36
- Current driver: stock `amdgpu`; the patched module is built but is not loaded
- ROCm runtime: extracted ROCm 7.1.5 user-space tree under `/home/michel/rocm-ps5-research/rocm-root/usr`

## Patch set

1. `kfd-tlb-fix.patch`: on GPU-memory unmap, rebuild the HWS runlist so the firmware invalidates stale compute-TLB translations. This is gated to PCI ID `13fb` and disabled by default.
2. `kfd-tlb-fix.patch`: make the PASID KIQ flush selectable; the test configuration disables the non-acknowledging KIQ path only for PCI ID `13fb`. Other AMD GPUs retain their stock KIQ behavior.
3. `amdgpu-ttm-null-check.patch`: protect `amdgpu_ttm_tt_unpopulate()` from a NULL entry in `ttm->pages[]`, so a failed/partially-populated BO cleanup does not turn a GPU fault into a kernel NULL dereference.
4. Optional, separate SDMA firmware stage: replace the two Cyan Skillfish SDMA 5.0 firmware blobs with the matching Navi12 SDMA 5.0 blobs. This is deliberately not part of the first boot.

The KFD runlist patch is based on `GabriWar/bc250-rocm-working`; the retail PS5 PCI ID and call site were adapted locally. It has compiled against the current PS5 7.3.0 kernel, but it has **not yet been runtime-tested** on this console.

## Build artifact

The module is `../../build/rocm-gfx1013/amdgpu.ko`. It must have `vermagic` matching `7.3.0-PinkSoup` and expose `bc250_flush_by_runlist`, `bc250_flush_pasid_kiq`, and `ps5_cu_unlock` module parameters. Final SHA-256: `facb35e272012119f1b25a2c75ca2917e025d2ab6da5dddb488ebfedba00bd11`. The build log is `/home/michel/rocm-ps5-research/build/amdgpu-build-20261103-013846.log`; it confirms `amdgpu_ttm.o` and the KFD objects were recompiled before the module link.

Rebuild the module with `./build-module.sh`; set `KERNEL_SRC` or `RESEARCH_ROOT` if your paths differ. The kernel source tree at `/home/michel/linux` is restored after the module build. The patched module is not installed automatically.

## Staged installation and tests

**Do not live-unload or replace the running `amdgpu` module.** On this PS5, the module keeps a reference count of 1 even after the framebuffer console and PCI function are detached. The exact owner of that final reference is not yet identified; `rmmod -f` is unsafe and must not be used. The 2025 DRM/GEM reference issue is not a good match for this 7.3 kernel: that regression was fixed in later stable kernels, and the 2026 KFD unload hang is a separate failure mode.

Use boot-time module selection instead. The active kernel has `CONFIG_DRM_AMDGPU=m`, and inspection of `/boot/efi/initrd.img` confirmed that it contains no `amdgpu.ko`. Therefore the GPU driver is loaded after the real root filesystem is available; `depmod` can select the staged module in `/lib/modules/7.3.0-PinkSoup/updates/` without rebuilding the initramfs. `install.sh` now checks these assumptions, verifies the selected module and modprobe options, and generates a kexec script that stops AI services and syncs before switching kernels. It does not overwrite the stock kernel or initramfs.

The first stage changes only the module and its modprobe configuration. It leaves the SDMA firmware untouched so the TLB workaround can be tested independently.

1. Confirm the preserved `7.1.7` fallback files exist in `/boot/efi`.
2. Stage the kernel module only:
   ```bash
   sudo ./install.sh
   ```
3. Boot the patched kernel using the generated kexec loader:
   ```bash
   sudo /boot/efi/kexec-ps5-rocm.sh
   ```
4. Run one HIP allocation/copy/kernel/free cycle with SDMA disabled:
   ```bash
   ./kernel-patches/ps5-gfx1013/test-hip.sh once
   ```
5. If that passes, run the 30-cycle allocation/reuse test, still with SDMA disabled:
   ```bash
   ./kernel-patches/ps5-gfx1013/test-hip.sh stress
   ```
6. Only after both tests pass, stage the separate SDMA firmware fix:
   ```bash
   sudo ./kernel-patches/ps5-gfx1013/install-sdma-firmware.sh
   sudo /boot/efi/kexec-ps5-rocm.sh
   ```
7. Test both SDMA engines:
   ```bash
   ./kernel-patches/ps5-gfx1013/test-hip.sh sdma
   ```

`test-hip.sh` refuses to run unless the patched module is loaded, the runlist-flush parameter is `1`, the KIQ bypass is `0`, and ROCm exposes `gfx1013`.

## Fallback and rollback

- Fallback to the preserved stock kernel: `sudo /boot/efi/kexec-fallback-7.1.7.sh`
- Restore the original firmware, module and modprobe configuration: `sudo ./kernel-patches/ps5-gfx1013/rollback.sh`

The installer does not overwrite the stock `bzImage`, `initrd.img`, or `kexec.sh`. It does not reboot automatically. The backup directory is retained after rollback for inspection.

## Important limits

- `rocminfo` can enumerate the PS5 GPU with the current stock driver, but this alone does not prove HIP kernels execute correctly.
- The HIP test binaries have been compiled for `gfx1013`; they have not yet been run on the GPU.
- Do not run the stress test before the patched kernel is active. A stale GPU TLB can corrupt memory after a HIP allocation is freed and reused.
- The first test disables SDMA to isolate the KFD TLB fix. SDMA firmware is a separate, later test.
- No ROCm package has been installed into the host OS; the user-space runtime is isolated under `/home/michel/rocm-ps5-research`.