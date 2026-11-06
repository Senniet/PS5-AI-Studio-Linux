# SeedVR2 on PS5 AI Studio

## Installed stack

- Integration: [ComfyUI-SeedVR2_VideoUpscaler](https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler)
- DiT: `seedvr2_ema_3b-Q4_K_M.gguf` from `AInVFX/SeedVR2_comfyUI`
- VAE: `ema_vae_fp16.safetensors` from `numz/SeedVR2_comfyUI`
- ComfyUI model directory: `runtimes/ComfyUI/models/SEEDVR2`
- Python environment: `runtimes/comfy-rocm-venv`
- Backend: PyTorch ROCm/HIP on AMD Oberon; ComfyUI exposes the GPU as `cuda:0`

The existing ROCm Torch/TorchVision build is retained. The plugin dependencies are installed with `python -m pip --no-deps`; do not run the plugin's unmodified requirements file because it may replace the PS5-specific Torch build.

## Verified model files

| File | Size (bytes) | SHA-256 |
|---|---:|---|
| `seedvr2_ema_3b-Q4_K_M.gguf` | 1,995,344,224 | `e665e3909de1a8c88a69c609bca9d43ff5a134647face2ce4497640cc3597f0e` |
| `ema_vae_fp16.safetensors` | 501,324,814 | `20678548f420d98d26f11442d3528f8b8c94e57ee046ef93dbb7633da8612ca1` |

Reinstall/verify with `scripts/install-seedvr2.sh`. The script preserves the current ROCm Torch version and refuses to overwrite a model file with an unexpected hash.

## PS5 low-memory profile

- DiT: 3B Q4_K_M, `blocks_to_swap=32`, I/O components swapped, CPU offload.
- Attention: PyTorch SDPA; Flash Attention/SageAttention are not assumed available.
- VAE: tiled encode/decode, tile size 192 px, overlap 32 px, CPU offload.
- Video batch: 5 frames (`4n+1`), temporal overlap 1.
- Maximum AI output: 1920 × 1080 (Full HD). QHD and 4K are intentionally blocked on this 7 GiB shared-GPU-memory device.
- SeedVR2 and RIFE are mutually exclusive within one job; both use the shared GPU.
- The server requires an idle ComfyUI queue, no other ComfyUI models resident, all other AI runtimes stopped, at least 4.5 GiB free GTT and 6 GiB free system RAM. Tile size drops to 128 px when free GTT is below 5.5 GiB.

## End-to-end test on PS5

A 1-second test clip (320 × 180, 5 fps, five frames, AAC audio) was uploaded through the Video Studio API and processed with `upscaleEngine=seedvr2` and `resolution=2x`.

- Output: 640 × 360, 5 fps, 1 second, H.264 + AAC.
- Audio was preserved.
- Five frames completed in about 24 seconds at 640x360 (~0.21 fps), 70 seconds at 720p (~0.071 fps), and 150 seconds at 1080p (~0.033 fps).
- The resulting MP4 was probed and then deleted as a test artifact.
- The full upload → ComfyUI → SeedVR2 → FFmpeg mux → Video Studio library path passed.

A 256 px VAE tile exceeded available GPU memory during an earlier test. A 128 px tile completed reliably; 192 px also completed and was selected as the default performance/memory compromise. A 224 px test completed but emitted HSA allocation warnings, so it is not the default.

## Runtime behavior

Video Studio exposes SeedVR2 as an optional AI-upscaling engine. It copies a preprocessed source into ComfyUI's input folder, queues a temporary workflow, collects the output frames, reassembles the video with FFmpeg, and preserves the audio stream. Temporary input, frames and scratch data are removed after the job. The original source remains untouched.

The engine is intentionally slow on this hardware. Use short clips first; long 24/30 fps footage can take a substantial amount of time. The current measured rate is a small synthetic test, not a guarantee for every codec, resolution or scene.