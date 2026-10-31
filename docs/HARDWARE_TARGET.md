# PS5 Linux hardware target

The first target environment is the user's Ubuntu installation running directly on PS5 hardware. These are live measurements from 2026-10-31, not hard-coded build assumptions. Re-detect them after kernel, Mesa or boot-memory changes.

## Measured host

- OS: Ubuntu 26.04.1 LTS.
- Kernel: Linux 7.1.7.
- CPU: AMD Custom Zen 2 (Oberon), 16 logical CPUs.
- GPU: AMD Custom Zen 2 (Oberon), PCI ID `1002:13fb`, RADV GFX1013.
- Mesa: RADV 26.2.5 (Kisak Mesa PPA).
- Vulkan: 1.4; RADV device is enumerated successfully.
- RAM: 14.1 GiB visible to Linux; approximately 11 GiB available in the initial idle sample.
- Swap: 7 GiB zram.
- Reserved VRAM: 512 MiB (`/boot/efi/vram.txt = 0x20000000`).
- GTT: 7,218.6 MiB (`/sys/class/drm/card0/device/mem_info_gtt_total`).
- Vulkan reports about 7,730 MiB on the RADV device.
- TTM `pages_limit`: 1,847,951 pages (4 KiB), which matches the current GTT budget.

The Vulkan heap is not extra physical RAM. PS5 is a unified-memory system: Linux RAM, GTT allocations and VRAM allocations all compete for the same physical memory budget.

## Runtime validation

- llama.cpp was already built with `GGML_VULKAN=ON`; its CLI reports Vulkan0 as the Oberon/RADV device.
- A Qwen3 8B Q4_K_M model loaded through llama.cpp with `-ngl 99`; one short smoke test measured 41.9 tokens/s.
- stable-diffusion.cpp was separately built with `SD_VULKAN=ON`, its patched GGML submodule, CPU fallback and examples enabled.
- `sd-cli --list-devices` reports both Vulkan0 (Oberon/RADV) and CPU.
- The image runtime compiled successfully, but no large image checkpoint was found in the checked local model paths, so generation with a real image model remains untested.

See [RUNTIME_BUILD_AND_MEMORY.md](RUNTIME_BUILD_AND_MEMORY.md) for exact build commands, runtime options, feature reporting and the proposed TTM experiment.

## Implications

1. Treat this as a unified-memory system. Never add Vulkan heap size and Linux RAM as if they were independent physical pools.
2. Query Vulkan device and memory heaps at runtime. Do not hard-code GFX1013, Oberon, heap sizes or a fixed PS5 kernel.
3. Keep CPU inference available as a fallback.
4. Keep conservative memory headroom for the desktop, kernel, display stack and other processes.
5. Keep Linux app paths, services, model storage, logs and configuration separate from the PS5 native application.
6. Do not add `mem=` or `memmap=` to the current PS5 boot command line.

## Validation checklist

- [x] Capture `uname -a`, `/etc/os-release`, `free -h` and CPU information.
- [x] Capture `vulkaninfo --summary` and Vulkan memory heaps.
- [x] Confirm render node and active Mesa/RADV driver.
- [x] Confirm llama.cpp Vulkan device and run a short text inference smoke test.
- [x] Build stable-diffusion.cpp with Vulkan and confirm its Vulkan device.
- [ ] Run an image-generation smoke test after an image checkpoint is available.
- [ ] Test a controlled `ttm.pages_limit` increase after backing up the boot command line and arranging a reboot.
