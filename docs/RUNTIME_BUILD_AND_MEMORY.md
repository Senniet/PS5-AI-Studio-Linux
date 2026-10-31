# Linux AI runtime build and memory notes

This document records the first real build and runtime validation on the PS5's separate Ubuntu Linux installation. It does not describe or modify the PS5 native application.

## Validated host

- Ubuntu 26.04.1 LTS
- Linux kernel 7.3.0-PinkSoup
- AMD Custom Zen 2 / Oberon APU, PCI ID `1002:13fb`
- Mesa RADV 26.2.5 (Kisak Mesa PPA), Vulkan 1.4
- Vulkan device: `AMD Custom Zen 2 (Oberon) (RADV GFX1013)`
- Linux sees about 14.1 GiB RAM; current available RAM at idle was about 11 GiB.
- PS5 boot `vram.txt`: `0x20000000` (512 MiB reserved VRAM)
- AMDGPU reports 512 MiB VRAM and 7,218.6 MiB GTT.
- Vulkan exposes about 7,730 MiB on the RADV device.
- Current TTM `pages_limit`: 1,848,125 pages (4 KiB pages), matching the 7,218.6 MiB GTT.
- Running kernel config has `CONFIG_DRM_AMDGPU_USERPTR=y`, `CONFIG_HMM_MIRROR=y`, `CONFIG_ZONE_DEVICE=y`, `CONFIG_MEMORY_HOTPLUG=y` and `CONFIG_ARCH_ENABLE_MEMORY_HOTPLUG=y`.

The Vulkan heap is not extra physical memory. This is a unified-memory APU: Linux RAM, GTT allocations and VRAM allocations ultimately compete for the same physical memory budget.

## llama.cpp (text)

The existing PS5 Linux checkout was already built with Vulkan enabled. Its CMake cache contains `GGML_VULKAN=ON`, and both CLI and server binaries are present.

Reproducible build configuration:

```bash
cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_VULKAN=ON

cmake --build build --config Release -j4
```

CPU support remains available as a fallback. Verify the selected backend with:

```bash
./build/bin/llama-cli --list-devices
```

Validated result:

- `Vulkan0: AMD Custom Zen 2 (Oberon) (RADV GFX1013)`
- Reported device budget: 7,730 MiB total, 7,495 MiB free at the time of the check.
- A Qwen3 8B Q4_K_M model loaded through the Vulkan build with `-ngl 99`.
- One short Vulkan test generated at 41.9 tokens/s.
- A CPU-only test with `-ngl 0` also completed and generated at 10.1 tokens/s.
- These are short smoke-test measurements, not benchmarks.

## stable-diffusion.cpp (image)

A separate checkout was built at `~/ai-runtimes/stable-diffusion.cpp`. It uses its own patched GGML submodule; do not replace that submodule with the GGML tree from llama.cpp.

Validated configuration:

```bash
git clone --recursive https://github.com/leejet/stable-diffusion.cpp
cd stable-diffusion.cpp

cmake -S . -B build-vulkan \
  -DCMAKE_BUILD_TYPE=Release \
  -DSD_VULKAN=ON \
  -DSD_BUILD_EXAMPLES=ON \
  -DSD_USE_UPSTREAM_GGML=OFF

cmake --build build-vulkan --config Release -j4
```

The Vulkan development prerequisites documented by the project are:

```bash
sudo apt-get install build-essential libvulkan-dev glslc spirv-headers
```

The host already had the relevant Vulkan loader/development package and `glslc`; the build completed without needing a driver replacement.

Verify the backend:

```bash
./build-vulkan/bin/sd-cli --list-devices
```

Validated result:

- Vulkan0: AMD Custom Zen 2 (Oberon) (RADV GFX1013)
- CPU: AMD Custom Zen 2 (Oberon)
- Device reports UMA and FP16 support; BF16, FP4, integer dot product and matrix cores were not reported.
- Both `sd-cli` and `sd-server` compiled successfully.
- The bundled server frontend was not built because pnpm was absent. The API server binary still built; the AI Studio can provide its own frontend.

Useful runtime controls to start with:

- `--auto-fit on`: let the runtime place weights according to available memory.
- `--max-vram -1`: reserve approximately 1 GiB of currently free device memory.
- `--offload-to-cpu` or `--params-backend cpu`: keep source weights in system RAM when that helps.
- `--params-backend disk`: reduce resident RAM at the cost of re-reading weights.
- `--vae-tiling`: reduce VAE peak memory.
- `--flash-attn auto`: use the runtime's backend-aware selection.
- `--init-img FILE --strength VALUE`: image-to-image input path.

The server defaults to `127.0.0.1:1234`. Keep it loopback-only behind the AI Studio service unless authentication and network exposure are deliberately implemented.

No large image checkpoint (`.safetensors`, `.ckpt` or model `.gguf`) was found in the checked home, /mnt, /media or /opt paths. Therefore the image backend has passed compile and Vulkan-device detection, but image generation has not yet been validated with a real checkpoint.

## PS5 shared-memory tuning

Current state:

- `/boot/efi/vram.txt` contains `0x20000000` (512 MiB).
- Current kernel command line does not contain `mem=` or `memmap=`.
- `/sys/module/ttm/parameters/pages_limit` is `1848125`.
- The AMDGPU driver logs `7218M of GTT memory ready`.

The AMDGPU initialization code derives the userspace GTT size from `ttm_tt_pages_limit()`. The legacy `amdgpu.gttsize` module parameter is deprecated in current kernel documentation/source; prefer the TTM limit.

Candidate for a controlled next-boot experiment (not applied):

```text
ttm.pages_limit=2621440
```

This is 10 GiB in 4 KiB pages. It should be tested with a backup of `/boot/efi/cmdline.txt`, followed by a cold boot and fresh checks of:

- `cat /sys/module/ttm/parameters/pages_limit`
- `cat /sys/class/drm/card0/device/mem_info_gtt_total`
- `vulkaninfo`
- `llama-cli --list-devices`
- peak system RAM and GTT use during model loading/inference

This parameter changes the GTT addressable budget; it does not reserve 10 GiB at boot. Actual allocations still consume shared physical RAM and can trigger memory pressure/OOM. The APU driver also caps GTT at physical system RAM. Do not set it to the full 16 GiB blindly, and do not add `mem=` or `memmap=` to this PS5 boot command line.

Start with 10 GiB rather than 12 GiB. Keep the current 512 MiB `vram.txt` reservation for the first comparison; changing both knobs at once would make results harder to interpret.

## Latest live verification — 2026-10-31

After the move to kernel 7.3.0-PinkSoup, the active TTM values were rechecked directly on the PS5: `pages_limit=1848125`, `page_pool_size=0`, `dma32_pages_limit=524288`. AMDGPU reports 512 MiB VRAM and 7,219 MiB GTT. These are the active values; no boot-memory setting has been changed. The read-only web dashboard also reports these values from sysfs.

## Runtime TTM changes — source-level finding

The matching local kernel source was inspected at `drivers/gpu/drm/ttm/ttm_tt.c` and `drivers/gpu/drm/amd/amdgpu/amdgpu_ttm.c`:

- `ttm.pages_limit` is a writable module parameter (mode 0644), and TTM consults its current value when accounting populated pages.
- AMDGPU separately reads `ttm_tt_pages_limit()` during `amdgpu_ttm_init()`, computes `gtt_size`, and initializes the GTT manager once with `amdgpu_gtt_mgr_init()`.
- Therefore writing a larger number to `/sys/module/ttm/parameters/pages_limit` after boot does **not** resize the already initialized GTT heap. It can change TTM's page-accounting threshold while the GPU-visible GTT heap remains the old size. Do not use a live sysfs write as a GTT expansion workaround.
- `page_pool_size` is also consumed during TTM pool initialization to set per-node pool limits; changing it after initialization does not rebuild those limits.
- The PS5's current `dma32_pages_limit=524288` is a separate allocation ceiling. The AMDGPU driver only enables the TTM DMA32 pool when the device's DMA addressing is limited; this is not a replacement for the GTT limit.

Conclusion: a real GTT size increase needs the TTM parameter set before AMDGPU initialization, which for this boot setup means changing the kexec command line and booting the kernel again. Since the console cannot currently be rebooted remotely, no live memory parameter has been changed.

## Ollama chat smoke test — 2026-10-31

The new local web API was tested with `qwen3:8b-16k` (Q4_K_M). A prompt requesting only `OK` returned the expected response. Ollama reported the model loaded with 100% GPU offload and a 4096-token context. During that loaded test, AMDGPU reported 5,896,880,128 bytes (~5.49 GiB) GTT in use; Linux reported about 7.05 GiB available RAM and 0 bytes of swap used. This is a functional smoke test, not a throughput benchmark. The standalone llama.cpp runtime was not running; the detected llama-server process belonged to Ollama's private runner and is now excluded from the standalone runtime status.

## Notes

- `vulkaninfo` emits a Mesa DRI3/presentation warning in this desktop session. Both inference runtimes nevertheless enumerate the RADV device; the warning did not prevent compute backend detection.
- GCC 15 emitted several upstream deprecation/array-bound warnings while compiling stable-diffusion.cpp. They were warnings, not build failures.
- Re-run all device and memory probes after kernel, Mesa or boot-memory changes.
