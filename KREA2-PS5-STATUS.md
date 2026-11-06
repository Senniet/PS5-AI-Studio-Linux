# Krea 2 on PS5 Linux — status 2026-11-04

## Known-good runtime
- Hardware: PS5 AMD Oberon, ROCm/HIP `gfx1013`, 7,219 MB GPU memory pool.
- ComfyUI 0.43.0, PyTorch 2.10.0+ps5gfx1013, ROCm 7.1, comfy-kitchen 0.2.40.
- Current ComfyUI flags: `--enable-dynamic-vram --fp8_e4m3fn-text-enc --force-fp16 --reserve-vram 0.5`.
- Keep `TORCH_BLAS_PREFER_HIPBLASLT=0`; installed hipBLASLt has no gfx1013 kernels.
- Primary checkpoint: `krea2Sickrealism_v40_3292927.safetensors`.
- Text encoder: `Qwen3VL-4B-Instruct-Q4_K_M.gguf` through `CLIPLoaderGGUFDynamicVRAM`.
- Alternate model: `Krea-2-Turbo-Q3_K_M-3.91bpw.gguf`; API uses `UnetLoaderGGUFDynamicVRAM` for this Q3 route.
- Current ComfyUI environment: `HSA_ENABLE_SDMA=0` (PS5-specific A/B; see current results below). Installed `cyan_skillfish2_sdma*.bin.zst` files are byte-identical to Navi12 SDMA firmware v0x2c. This firmware swap is outside AMD support.
- Turbo test adapter: `krea2_turbo_3step_rank_64_lora_comfyui.safetensors`.
- VAE: `qwen_image_vae.safetensors`.

## Measured generations
- 384x384, 3-step Turbo-distill, reserve 0.75 GiB: 216.62 s.
- 384x384, 3-step Turbo-distill, reserve 0.5 GiB: 192.37 s (11.2% faster).
- 512x512, 3-step Turbo-distill, reserve 0.5 GiB: 280.39 s.
- Krea2 Turbo Q3, 512x512, 8 steps, DynamicVRAM: 73.44 s cold and ~50.0 s warm with `HSA_ENABLE_SDMA=0`.
- Krea2 Turbo Q3, 512x512, 4-step LoRA, DynamicVRAM: ~36.0 s warm with `HSA_ENABLE_SDMA=0`.
- For comparison, earlier `HSA_ENABLE_SDMA=1` runs measured ~78 s cold / 57.8–61.6 s warm at 8 steps and 40.45 s warm at 4-step LoRA.
- Q3 loader comparison at 384x384 / 8 steps: DynamicVRAM 50.09 s vs legacy GGUF 75.17 s (different cache states; indicative, not a strict A/B).
- These were successful image generations on the GPU. 384 is best for previews; 512 for final output.
- SickRealism model guidance remains 8 steps, ER SDE Beta, CFG 1.0; 3-step adapter is experimental on this fine-tune.

## Findings / do not blindly enable
- ComfyKitchen marks gfx1013 as elementwise-only for WMMA paths; W4A4 GEMM falls back to eager PyTorch/rocBLAS.
- hipBLASLt has no gfx1013 Tensile kernels; `torch._int_mm` failed on missing `TensileLibrary_lazy_gfx1013.dat`. Int8 GEMM path is not usable yet.
- `torch.backends.cuda.is_flash_attention_available()` was false; SDPA had no memory-efficient backend. Keep ComfyUI's default sub-quadratic attention for now.
- FP16 2048x2048 matmul microbenchmark was faster than BF16 (0.0639 s vs 0.0925 s for five runs), but `--fp16-unet` was not validated end-to-end; reverted to known-good flags.
- `--fp16-text-enc` with Q4 GGUF was very slow during cold load; reverted to FP8 text encoder.
- INT8 ConvRot safetensors encoder loaded, but remained CPU-side; `CLIPLoader` accepts only `default` or `cpu` (not `cuda`). Not selected.
- Do not use ComfyUI `/free` with `free_memory:true` without further testing: it calls `torch.cuda.empty_cache()`/`ipc_collect()`, which is flagged as risky on gfx1013 in the local ROCm research notes.

## API changes
- Krea2 API now checks the ComfyUI queue before submitting; prevents duplicate jobs after an API restart.
- Memory guard: Q3 GGUF + DynamicVRAM route uses 1.8 GiB minimum free HSA pool; Sickrealism remains at 2.6 GiB. Host memory minimum remains 4 GiB. If below the model-specific threshold and queue empty, API restarts ComfyUI rather than calling `/free`.
- Host memory guard remains 4 GiB minimum.
- API status reports 0.5 GiB VRAM reserve and Q4 GGUF text encoder.

## Current state
- `ps5-ai-studio-comfyui.service`: active.
- `ps5-ai-studio-linux.service`: active, API v0.6.0.
- Krea2 generation queue: empty.
- Current Q3 Turbo loader: `UnetLoaderGGUFDynamicVRAM`; Sickrealism route unchanged.
- Current SDMA: `HSA_ENABLE_SDMA=0`; PS5 A/B showed faster 128 MiB transfers (2.09/2.18 ms vs 10.45/10.45 ms with SDMA on) and faster full Krea2 runs. Keep the 0 setting unless a new controlled test disproves it.
- Current known-good flags remain `--enable-dynamic-vram --fp8_e4m3fn-text-enc --force-fp16 --fp16-intermediates --reserve-vram 0.5`; no `--fp16-unet` or `--fp16-text-enc`.
- GPU governor watcher is active: idle `simple_ondemand` (400 MHz), queued work `performance` (up to 2.23 GHz). During ComfyUI restarts it currently falls back to `simple_ondemand` on connection errors; a root-level grace-period fix remains pending. CPU boost is still disabled (`boost=0`, `schedutil`, 3.2 GHz max); sysfs is root-only.

## Next experiments
1. Continue controlled Q3 Turbo quality tests: compare standard 8-step output with the 4-step LoRA at identical prompt/seed.
2. Investigate a native HIP K-quant backend for gfx1013. An isolated official ROCm Triton 3.6.0 wheel compiles for gfx1013 but simple kernels currently write no output, so it is not enabled; the bundled GGUF Triton backend is CUDA-SM86-only.
3. Profile Qwen3VL encoding and cache behavior without increasing RAM pressure.
4. Explore CPU boost and GPU-governor startup handling when root-level access is available; do not change experimental CU-unlock/boot parameters without a rollback plan.

## Image Studio integration (2026-11-04)
- The Q3 GGUF checkpoint is now a first-class runtime choice in the normal Image Studio editor; the standard Generate button routes to the existing Krea2 ComfyUI API instead of the old fixed 256x256 Muse stub.
- Supported from the normal editor: prompt builder, positive prompt, negative prompt (encoded through Qwen CLIP before the encoder is released), square 256–768 resolution, seed, standard 8-step mode, official 4-step Turbo-LoRA, 2-step Turbo preview, progress, cancellation and gallery output with generation metadata.
- Q3-specific controls are surfaced in the editor. Unsupported SD.cpp features are disabled while this GGUF runtime is active: img2img/inpainting, batch, CFG/sampler/scheduler overrides, regular LoRA, ControlNet, IP-Adapter, Hires Fix and ADetailer. SickRealism / stable-diffusion.cpp controls and routes remain separate and unchanged.
- The `PS5UnloadTextEncoder` custom node now accepts optional `negative_conditioning` as a dependency. This ensures both positive and negative Qwen prompt encodings finish before the Q4 text encoder is released from memory.
- Verified end-to-end through the same API route used by Image Studio: 512x512 standard 8-step generation with negative prompt; 512x512 official 4-step Turbo-LoRA; 384x384 2-step preview. All three completed and were saved to the existing image gallery with prompt, negative prompt, seed, dimensions, step profile and engine metadata.

- Follow-up fix: the normal Image Studio model loader now detects `krea2Sickrealism_v40_3292927.safetensors` as `ComfyUI-Krea2`, not as a Stable Diffusion.cpp checkpoint. Its normal generation route accepts the selected SickRealism file; Q3 remains on its separate DynamicVRAM GGUF loader.
- SickRealism Image Studio controls expose adjustable 2–12 standard steps, 3-step Turbo-LoRA and 2-step preview. The shared Krea route handles progress and cancellation for both Krea backends.
- Verified: SickRealism selected and loaded from the normal `/api/runtime/image/load` route as `ComfyUI-Krea2`; standard 384x384 / 8-step generation with negative prompt completed and saved; 384x384 / 3-step Turbo-LoRA generation also completed and saved.


## Krea2 HMNSFW AIO LoRA (4 november 2026)

- Added `Krea2_HMNSFW_AIO.safetensors` to the shared image LoRA directory (228,587,200 bytes; SHA-256 `c2e4988a775e41fd50ba1cb3a68f3b38c094a819e786ab97693f05add331f922`).
- Safetensors metadata confirms `ss_base_model_version: krea2`; tensors are Krea2 diffusion-model LoRA weights.
- Added dedicated Krea2 LoRA selector and strength (0–2, default 0.8) in the normal Image Studio generation settings. It is separate from the Stable Diffusion LoRA selector.
- ComfyUI graph applies the selected AIO LoRA to the base Krea2 model, then chains the optional 2/3/4-step Turbo LoRA after it. This supports standard and Turbo generation.
- End-to-end smoke test on SickRealism: 256×256, 3-step Turbo, AIO strength 0.8, seed 20261108; ComfyUI execution succeeded and saved a gallery image.
- The generated workflow history confirms `LoraLoaderModelOnly` loaded `Krea2_HMNSFW_AIO.safetensors` at strength 0.8 and chained the 3-step Turbo LoRA after it.
