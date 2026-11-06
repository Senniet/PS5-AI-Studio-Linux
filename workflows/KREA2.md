# Krea 2 in PS5 AI Studio Linux

## Runtime

The bundled ComfyUI checkout is 0.43.0 and includes native Krea 2 DiT support:
- UNETLoader for the Krea 2 transformer
- CLIPLoader with type `krea2` for Qwen3-VL 4B
- VAELoader for Qwen-Image VAE
- native Krea 2 model detection, sampling defaults and `convrot_w4a4` quant format support

The shared model paths expose the image checkpoint directory as both `checkpoints` and `diffusion_models`, and the shared `clip` directory as `text_encoders`.

## Official model assets

From `Comfy-Org/Krea-2`:
- `text_encoders/qwen3vl_4b_int8_convrot.safetensors` (4.86 GB; preferred PS5 companion encoder)
- `text_encoders/qwen3vl_4b_fp8_scaled.safetensors` (5.24 GB; alternative)
- `vae/qwen_image_vae.safetensors` (254 MB)
- `diffusion_models/krea2_turbo_fp8_scaled.safetensors` (13.1 GB; standard Turbo alternative, not needed for the existing Sickrealism checkpoint)

RAW can be installed alongside Turbo:
- `diffusion_models/krea2_raw_fp8_scaled.safetensors`

Place the files in the shared library:
- Transformer: `~/.local/share/ps5-ai-studio/models/image/checkpoints/`
- Text encoder: `~/.local/share/ps5-ai-studio/models/image/clip/`
- VAE: `~/.local/share/ps5-ai-studio/models/image/vae/`

## Recommended settings

- Official Turbo template: 8 steps, Euler, Simple, CFG 1, batch 1.
- BabeGen Sickrealism v4.0 (the user's checkpoint): ER SDE, Beta scheduler, 8 steps, CFG 1, blank/zeroed negative conditioning.
- RAW: use the official RAW workflow defaults; do not apply Turbo settings to RAW.
- Use natural-language prompts. Krea 2 uses multi-layer Qwen3-VL conditioning.
- The user's ready-to-submit API graph is `krea2-sickrealism-api.json`.

## Workflow

Open Workflow Studio, then open ComfyUI. In ComfyUI choose Workflow → Browse Templates and search `Krea-2`. `krea2-turbo-api.json` is an API-format template for the official `krea2_turbo_fp8_scaled.safetensors` model, which is not installed on this PS5. The installed Turbo model is Q3 GGUF; use PS5 AI Studio’s Krea 2 route, which builds the `UnetLoaderGGUFDynamicVRAM` graph. The Sickrealism API graph matches the installed safetensors checkpoint.

## Current PS5 runtime status (verified 2026-11-05)

The active user service is `ps5-ai-studio-comfyui.service`, launched from `runtimes/comfy-rocm-venv/bin/python` on port 8790 with DynamicVRAM enabled. The live `/api/krea2/status` reports ComfyUI 0.43.0, PyTorch `2.10.0+ps5gfx1013`, AMD Oberon/gfx1013 as a CUDA-compatible HIP device, `gpuReady: true`, the native Krea 2 nodes, and all required model assets. ComfyUI startup logs report ROCm 7.1 and an available `comfy_kitchen` HIP backend with ConvRot W4A4/INT8 operations.

Existing output files provide end-to-end generation evidence: a Sickrealism safetensors 256×256 3-step HIP output at 2026-11-05 00:05 UTC, plus Q3 GGUF Turbo 384×384 outputs at 2–8 steps shortly beforehand. Comparative timing and memory results are recorded in `docs/KREA2-OPTIMIZATION-RESULTS-20261104.md`. Those outputs predate the current ComfyUI process start at 01:24 CET; this audit confirmed current backend readiness but did not queue a new generation. `generationReady` is a capability/readiness signal, not a guarantee of quality or that every model fits at every resolution.

The Studio memory guard uses ROCm/HSA global free memory as the pool metric, accounts for host RAM and swap, and applies the route-specific thresholds recorded in the optimization results. PyTorch allocator-free memory and sysfs GTT are shown as separate diagnostics because allocator reservations can make them differ from globally free GPU memory.

## Historical PS5 gfx1013 ROCm bring-up notes (2026-11-03; superseded by current status above)

The actual PS5 APU is PCI 1002:13fb, KFD node `cyan_skillfish`, gfx1013, 36 CUs (18 WGPs). The live system exposes `/dev/kfd` and the current user can read/write it. A locally extracted ROCm 7.1.1 runtime successfully enumerates this GPU with `rocminfo`; a separate HIP runtime probe also reports one AMD GPU with 7,219 MB local memory. These checks prove HSA/HIP discovery, not that compute dispatch is safe/correct.

A patched `amdgpu` module was built for the exact running kernel `7.3.0-PinkSoup`. It contains:
- `bc250_flush_pasid_kiq=0`: bypass the broken gfx10 PASID/KIQ flush path
- `bc250_flush_by_runlist=1`: rebuild the KFD runlist on unmap to invalidate stale compute-TLB translations
- `gpu_recovery=0`: avoid the known unreliable GPU reset path during the first test

At the time of this 2026-11-03 note, the patched module was **not loaded** and the stock module and initramfs had not been changed. Current kernel/service state is not inferred from that historical record. `scripts/enable-ps5-rocm-gpu.sh` is a one-boot, in-memory activation test. It stops GDM, loads the patched module with the above parameters, checks HSA enumeration, then runs a 1024-element HIP vector-add correctness test. On failure it attempts to reload the stock module and restart the desktop. On success it keeps the patched module active only until reboot. This activation step requires a local administrator action: `sudo ./scripts/enable-ps5-rocm-gpu.sh`.

This paragraph records the earlier isolated rocBLAS/PyTorch build plan, dual-venv setup, and staged service. It is historical rather than a description of the active service: the current default user service now launches the ROCm venv on port 8790. Retain the rollback scripts and verify the live service before changing kernel, package, or system configuration.

The current ComfyUI startup log reports the `comfy_kitchen` HIP backend as available, including ConvRot W4A4 and INT8 operations. One inconsistency remains: ComfyUI-Manager logs `PyTorch is not installed` during startup, while the Studio status endpoint reports PyTorch `2.10.0+ps5gfx1013` and HIP-ready generation assets. Reconcile whether this is limited to Manager dependency detection before changing packages.

## User checkpoint

`krea2Sickrealism_v40_3292927.safetensors` is a custom INT4 W4A4 ConvRot merge. Its Safetensors header has the Krea 2 signature (`txtfusion.projector.weight` `[1, 12]`, `first.weight` `[6144, 64]`, DiT Q/K dimensions and Qwen layerwise prenorm `[2560]`); 256 quantization metadata tensors identify `convrot_w4a4`. The Qwen3-VL INT8 ConvRot encoder and Qwen-Image VAE are present in the shared model library.

End-to-end generation is no longer pending: the output directory contains PNGs and metadata sidecars for the Sickrealism HIP route and Q3 GGUF Turbo route. The newest Sickrealism record is 256×256 at 3 steps; recent Turbo records are 384×384 at 4 steps. The reproducible performance comparisons and memory observations remain in `docs/KREA2-OPTIMIZATION-RESULTS-20261104.md`. This confirms these tested settings only; it does not establish full-resolution quality, stability under low-memory conditions, or GPU residency of the complete model stack.
