# ControlNet with Vulkan diffusion on PS5 Linux

## Root cause

ControlNet runs on the CPU while the UNet/diffusion model runs on Vulkan. This creates a mixed-backend GGML graph. Two Vulkan graph overlap checks assumed every tensor buffer had a Vulkan device-buffer context and unconditionally cast CPU/Vulkan-host buffer contexts to ggml_backend_vk_buffer_context. This corrupted the context/refcount and crashed during ggml_vk_build_graph() / ggml_vk_tensors_overlap().

## Fix

The patch checks ggml_backend_buffer_is_vk() before reading a Vulkan device-buffer context. CPU and Vulkan-host buffers are skipped in device-allocation overlap checks because they cannot alias Vulkan device allocations.

## Rebuild

Apply the patch to the GGML revision pinned by the current stable-diffusion.cpp checkout:

    cd /home/michel/ai-runtimes/stable-diffusion.cpp/ggml
    git checkout 6a89493756a18bd9cd8875bc4db17e329818b13f
    git apply /home/michel/PS5-AI-Studio-Linux/patches/ggml-vulkan-mixed-backend-controlnet.patch
    cd ..
    cmake --build build-vulkan --target sd-server -j6

## Verified configuration

- SD 1.5 checkpoint: uberRealisticPornMerge_v23Final.safetensors
- ControlNet: control_v11p_sd15_canny.pth on Vulkan0
- IP-Adapter: ipAdapterPlusSd15.safetensors on Vulkan0
- CLIP Vision: clip_vision_h_fp16.safetensors on Vulkan0
- Diffusion/UNet: Vulkan0
- VAE: Vulkan0
- Text encoder: CPU
- Runtime: --auto-fit off for conditioning jobs so explicit per-module placement is respected
- Resolution: 512x512, 4 Euler A steps

The repaired mixed-backend path (CPU ControlNet + Vulkan diffusion) completed successfully in the first tests. A further test then confirmed that ControlNet itself can also run on Vulkan0 after the buffer-context guards were fixed. The full ControlNet + IP-Adapter + CLIP Vision Vulkan combination completed end-to-end in the app at 512x512: sampling 9.85 seconds and total generation 15.17 seconds. A standalone ControlNet-only Vulkan test completed in 15.45 seconds total. The original unpatched runtime crashed in Vulkan graph construction with SIGSEGV for the same graph family.

The application now selects Vulkan0 for diffusion, VAE, ControlNet and CLIP Vision/IP-Adapter whenever conditioning is enabled, keeps the text encoder on CPU, and disables auto-fit for these jobs to prevent silent CPU offload of conditioning. Unconditioned generation retains the existing auto-fit behavior.


## Resolution benchmark (2026-11-01)

Validated on the PS5 Linux Oberon/Vulkan runtime with `uberRealisticPornMerge_v23Final.safetensors`, Canny ControlNet, IP-Adapter Plus SD1.5 and CLIP Vision all assigned to Vulkan; text encoder remains on CPU, `--auto-fit off`, VAE tiling enabled. Four sampling steps, one image, same source image supplied to ControlNet and IP-Adapter.

| Resolution | API request wall time | Result |
|---|---:|---|
| 768 × 768 | 12.34 s | Completed |
| 1024 × 1024 | 23.64 s | Completed |

The 1024 test reported 22.68 s inside `generate_image` and 11.19 s for sampling. Runtime remained healthy after both jobs (`jobStatus=completed`, no runtime error). These are short diagnostic runs, not quality/performance guarantees for normal 20–30 step production generations. Resolution increases pixel workload substantially; 1024 × 1024 is currently validated with this exact checkpoint and conditioning combination.

## Production-step benchmark (2026-11-01)

Sequential app API tests at 1024 × 1024 using the same checkpoint and Vulkan conditioning configuration above, one image per request, fixed seed 123457, Canny ControlNet strength 0.8 and IP-Adapter strength 0.7:

| Steps | API request wall time | Runtime `generate_image` | Sampling | VAE decode | Result |
|---:|---:|---:|---:|---:|---|
| 20 | 63.07 s | — | — | — | Completed |
| 30 | 87.90 s | 86.83 s | 75.50 s | 6.59 s | Completed |

Both requests returned saved PNGs and the sequential test process exited successfully. The 30-step log confirms stable sampling at approximately 2.5 s/step after conditioning was cached; VAE decode took 6.59 s. The 20-step API wall time is recorded from the test harness; its detailed runtime timing was not separately captured. These measurements are specific to this model, PS5 Linux build, and conditioning setup.

## Sampler, CPU-thread and fast-resolution benchmark (2026-11-01)

Additional sequential app API tests used the same SD 1.5 checkpoint, Canny ControlNet, IP-Adapter Plus, CLIP Vision, source image, seed 123457, CFG 6.5, conditioning strengths 0.8/0.7, VAE tiling, and 1024x1024 unless noted. Conditioning cache was warm for the sampler comparisons.

### Sampler comparison (1024x1024, 20 steps, 6 CPU threads)

| Sampler | API wall time | Sampling | `generate_image` | Result |
|---|---:|---:|---:|---|
| Euler A | 63.88 s | 50.81 s | 62.38 s | Completed |
| Euler | 63.09 s | 50.34 s | 61.71 s | Completed |
| DPM++ 2M | 63.07 s | 50.55 s | 61.95 s | Completed |

There is no material speed difference between these samplers on this PS5/Vulkan configuration. Keep Euler A as the existing default rather than changing it without a demonstrated quality advantage.

### CPU thread comparison (1024x1024, Euler A, 20 steps)

| `--threads` | API wall time | Sampling | VAE decode | `generate_image` | Result |
|---:|---:|---:|---:|---:|---|
| 4 | 70.63 s | 56.35 s | 6.84 s | 69.50 s | Completed |
| 6 | 63.88 s (sampler run) | 50.81 s | — | 62.38 s | Completed |
| 8 | 71.37 s | 57.08 s | 6.93 s | 70.42 s | Completed |

Six threads were measurably faster in these runs. The application setting was restored to `imageThreads=6`, and the image runtime was reloaded successfully with the original model/conditioning combination. Do not increase thread count on this workload based on CPU core count alone; diffusion sampling is predominantly Vulkan/GPU-bound.

### Resolution comparison (Euler A, 20 steps, 6 CPU threads)

| Resolution | API wall time | Sampling | VAE decode | `generate_image` | Result |
|---|---:|---:|---:|---:|---|
| 768x768 | 39.75 s | 30.42 s | 3.74 s | 38.45 s | Completed |
| 1024x1024 | 63.88 s (sampler run) | 50.81 s | — | 62.38 s | Completed |

The 768x768 run was approximately 38% faster end-to-end than the 1024x1024 Euler A run while retaining the same 20 steps and conditioning configuration. This is a useful faster-generation option when the smaller output is acceptable. The 1024x1024, 12-step test recorded earlier completed in 41.51 s (30.36 s sampling, 6.65 s VAE decode); reducing steps is another speed/quality trade-off, not a lossless optimization.

### Optimization decision

- Keep the validated mixed-backend Vulkan fix, all conditioning modules on Vulkan, text encoder on CPU, `--auto-fit off`, and VAE tiling enabled.
- Keep `imageThreads=6`; both 4 and 8 threads were slower in the measured runs.
- Keep Euler A as default; Euler and DPM++ 2M did not reduce generation time.
- Offer 768x768/20-step or 1024x1024/12-step settings as faster-generation choices; preserve 1024x1024/20-step as the current quality/default configuration.
- Do not disable VAE tiling or force extra GPU memory allocation: the current conditioning model plan is already marked `tight` against the PS5's 7.57 GB GTT budget, so that experiment carries avoidable OOM/device-loss risk.
- Flash Attention was already enabled automatically on Vulkan. The runtime's capability probe measured approximately 3.05 ms with flash attention versus 3.43 ms without it; no manual toggle is needed.

All tests completed without runtime errors. The baseline configuration and settings were restored after the thread-count experiment.

## 4x Vulkan upscaler workflow (2026-11-01)

A 768x768, 20-step conditioned generation was followed by the existing `4xUltrasharp_v10.pt` ESRGAN upscaler on Vulkan0 (`--threads 6`, one repeat, tile size 128). The upscaler produced a verified 3072x3072 PNG successfully. Upscaler processing took 19.68 s; the preceding 768x768 generation took 39.75 s at the API level. Combined wall time is therefore approximately 59.4 s, subject to sequential-run overhead. For comparison, a direct 1024x1024, 20-step conditioned generation took 63.88 s in the sampler benchmark. This gives a practical alternative that yields a 3072x3072 output in roughly the same elapsed time as native 1024x1024 generation, although upscaling cannot recreate all details of native high-resolution diffusion.

The app's upscale route stops the image runtime while the ESRGAN process runs. After this test the image checkpoint and conditioning models were reloaded successfully, restoring the normal runtime. No default generation settings were changed.

The same 768x768 source was also tested with `RealESRGAN_x4plus.safetensors` on Vulkan using the same 128px tile size. It completed successfully at 3.32 tiles/s with 19.64 s total upscaler processing, essentially identical speed to 4x UltraSharp (19.68 s). Both upscalers are therefore viable performance-wise; choose based on the preferred image character rather than expected speed. The original image-generation runtime was reloaded successfully after the second upscaler test.

## VAE tile-size and UNET caching investigation (2026-11-01)

Two further controlled experiments were performed with the same SD 1.5 checkpoint and full Vulkan conditioning setup. Both used 1024x1024, 20 Euler A steps, seed 123457, CFG 6.5, ControlNet strength 0.8 and IP-Adapter strength 0.7.

### VAE tile size

The existing application uses `--vae-tiling` with the runtime's default 256px tile size. A separate temporary server was launched with `--vae-tile-size 512` to compare a larger tile without changing the application. The 512px run completed successfully: sampling 57.11 s, VAE decode 6.26 s, `generate_image` 68.35 s. This single run does not establish an end-to-end speed improvement because its sampling phase was slower than the warm-cache 6-thread baseline (50.81 s). The decode difference is small (a few tenths of a second) and needs repeated paired tests to establish significance. Keep the default 256px tile size; do not change production defaults on this evidence.

### UCache for SD 1.5 UNET

The runtime's UNET UCache was tested with Euler A and its documented conservative `reset=0` setting:

| UCache threshold | Steps skipped | Sampling | `generate_image` | Result |
|---:|---:|---:|---:|---|
| 1.0 | 0/20 | 56.92 s | 70.29 s | Completed |
| 2.0 | 1/20 | 54.62 s | 67.39 s | Completed |

Both runs were slightly slower than the earlier warm-cache no-UCache benchmark (50.81 s sampling, 62.38 s `generate_image`). Threshold 1.0 did not skip any steps; threshold 2.0 skipped only one, with an estimated 1.05x speedup and no convincing end-to-end gain. UCache is therefore not enabled in the app. Higher thresholds may skip more work but increase image deviation and are not justified without a quality comparison.

### Production state

Both temporary runtimes were stopped cleanly. The normal app runtime was reloaded with the original checkpoint, ControlNet, IP-Adapter and CLIP Vision; it is running with no reported error. No application defaults or model files were modified by these experiments.