# PS5 40-CU probe — staged, not executed

The current PS5 Oberon/GFX1013 driver reports 36 active CUs out of 40. The running kernel exposes `amdgpu.ps5_cu_unlock` and the local kernel patch has these modes:

- `0`: disabled (current state)
- `1`: probe first SE/SH, restore registers
- `2`: enable first SE/SH only
- `3`: enable all SE/SH (actual unlock)
- `4`: probe all SE/SH, restore registers (safe probe)

The first step is mode `4`, not mode `3`. It records the CC shader-array and SPI WGP-mask values before and after the test, then restores them. It does not enable additional compute units. If the readbacks are sensible, a separate mode-3 test could theoretically expose 40 instead of 36 CUs, a maximum theoretical CU-count increase of 11.1% before other bottlenecks.

A staged script is available at `firmware-experiments/kexec-ps5-cu-probe.sh`. It:

- requires root and the existing PS5 kernel/initrd files;
- verifies the module parameter is present and currently 0;
- refuses to interrupt a non-empty ComfyUI queue;
- uses kexec with the current kernel command line plus the existing ROCm parameters and `amdgpu.ps5_cu_unlock=4`;
- asks for an explicit `YES` before stopping AI services and executing kexec;
- does not edit `/boot/efi/cmdline.txt` or any persistent boot configuration.

**Not executed:** the current session does not need a reboot/kexec transition, and no CU unlock has been applied. Do not run mode 3 without a successful mode-4 probe and a recovery path.
