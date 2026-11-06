# PS5 AI Studio hardware baseline — 2026-11-05

Read-only inventory via the connected Termalin host `ps5-linux`, project `/home/michel/PS5-AI-Studio-Linux`. Snapshot taken around 00:10 CET. This records observed state; it does not change the system.

## Hardware and OS

- Host: PlayStation 5 APU, PCI ID `1002:13fb`, Linux driver `amdgpu`; Vulkan identifies it as AMD Custom Zen 2 (Oberon), `RADV GFX1013`.
- CPU: AMD Custom Zen 2, 8 cores / 16 threads, x86_64, AVX2/FMA available, reported max 3.2 GHz; CPU boost is disabled in the current configuration.
- Kernel: `7.3.0-PinkSoup`, build dated 2026-10-19.
- OS: Ubuntu 26.04.1 LTS (Resolute).
- RAM: 15,139,840,000 bytes (~14.1 GiB); about 8.2 GiB available in the snapshot.
- Swap: 7,392,252 KiB total, about 2.3 GiB occupied.
- Root disk: 235 GiB, 182 GiB used, 53 GiB available (78%).
- GPU sysfs reports 512 MiB VRAM aperture and 7,569,920,000 bytes (~7.05 GiB) GTT. ComfyUI reports the same 7.05 GiB shared graphics pool as its device VRAM. These are different memory views; do not add them together.
- Current Mesa Vulkan device: RADV, Mesa 26.2.6 (Kisak PPA), Vulkan 1.4.354 device API; RADV driver version 26.2.6. A CPU llvmpipe Vulkan device is also enumerated.
- Kernel GPU node: `/dev/kfd`, `/dev/dri/card0`, `/dev/dri/renderD128`.

## AI runtime and services

- Web/API: PS5 AI Studio v0.6.0, Node.js service, listening on `0.0.0.0:8787`; `/api/health` returned `{"ok":true,"version":"0.6.0"}`.
- ComfyUI: 0.43.0, listening on `192.168.2.210:8790`; queue endpoint returned empty.
- Both services are enabled and active in the `michel` user systemd manager (not the system manager).
- ComfyUI Python: 3.14.4; PyTorch: 2.10.0+ps5gfx1013; HIP/ROCm reported in the existing project status as 7.1. The runtime identifies `cuda:0 AMD Custom Zen 2 (Oberon) : native`.
- ComfyUI packages reported by `/system_stats`: comfy-kitchen 0.2.40, comfy-aimdo 0.6.0, frontend 1.57.6, workflow templates 0.11.100.
- Active ComfyUI options: `--enable-dynamic-vram --fp8_e4m3fn-text-enc --force-fp16 --fp16-intermediates --reserve-vram 0.5`.
- User service drop-in sets `HSA_ENABLE_SDMA=0`, `TORCH_BLAS_PREFER_HIPBLASLT=0`, and the PS5 ROCm research library paths.
- Standalone `rocminfo`, `hipcc`, and `glxinfo` commands are not installed on PATH. HIP is confirmed through the active PyTorch/ComfyUI runtime instead.

## Models and nodes observed

Model files live under `/home/michel/.local/share/ps5-ai-studio/models`. The current inventory includes Krea2 SickRealism safetensors (7,540,053,544 bytes), Krea2 Turbo Q3 GGUF (6,261,519,392 bytes), Qwen3VL Q4 GGUF encoder (2,497,281,664 bytes), Qwen-Image VAE (253,806,246 bytes), text GGUFs, video GGUF assets, and image LoRAs. Krea2-named adapters present include HMNSFW AIO, Better Pussy, and 2/3/4-step Turbo adapters.

ComfyUI custom nodes observed: ComfyUI-GGUF and PS5 AI Studio bridge/memory nodes. ComfyUI-GGUF is at commit `da5f435`; application changes and local experiments are present in the working tree.

The existing server code detects Krea2 LoRAs dynamically by reading Safetensors `__metadata__.ss_base_model_version` and matching `krea2`; the image API validates the selected filename and clamps the strength to 0–2. This is already implemented in the current working tree, so no duplicate frontend list was added.

## Live load and baseline status

At the snapshot, ComfyUI's queue was empty and the API and ComfyUI health endpoints responded. `ps` showed roughly 60% CPU for the ComfyUI Python process, which was its lifetime average since startup; a later 5-second `top` sample showed 0.0% current CPU with the queue still empty. Host memory showed about 2.3 GiB swap used. An inference had logged completion at 230.24 seconds shortly before the snapshot.

Existing project records contain historical Krea2 timings; see `KREA2-PS5-STATUS.md` and `docs/KREA2-OPTIMIZATION-RESULTS-20261104.md`. After the later 5-second idle sample, new image baselines were run; see `BENCHMARKS.md`. Each current profile has one run, so the results are references rather than statistical comparisons.

## Current risks / follow-up

1. Resolve the unexplained sustained ComfyUI CPU usage and confirm the process is idle before new benchmarks.
2. Swap use remains material; record a settled idle value and monitor peak swap during repeated generation before changing memory thresholds.
3. Web/API binds to all interfaces. Confirm the intended LAN exposure and firewall/authentication boundary before making any binding change.
4. Project source files have many pre-existing modifications and backups. Preserve them; inspect diffs before any source edit.
5. No kernel, Mesa, ROCm, PyTorch, boot, or firmware changes were made during this inventory.