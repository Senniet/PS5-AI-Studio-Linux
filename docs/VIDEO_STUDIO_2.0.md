# Video Studio 2.0

## Workspaces

- **Genereren**: native stable-diffusion.cpp Vulkan engine with Wan profiles. Text-to-video is supported by the installed Wan 2.1 T2V 1.3B stack. Image-to-video stays disabled until a compatible I2V profile is fully installed.
- **Verbeteren**: local FFmpeg pipeline. Original uploads are stored separately from exports; outputs never overwrite sources.
- **Videobibliotheek**: local output browser with search, format filter and sorting.

## Local video processing

`apps/server/video-processing.mjs` probes input with ffprobe and creates a controlled FFmpeg command. Supported operations:

- Trim start/end, speed 0.5x–2x, rotation and audio volume.
- HQDN3D denoise, EQ brightness/contrast/saturation/gamma and unsharp.
- YADIF deinterlace and deshake stabilization.
- Lanczos scaling to 720p, 1080p, 1440p, 2160p or 2x.
- Motion-compensated `minterpolate` up to 60 fps (CPU).
- RIFE v4.6 AI frame interpolation through ncnn Vulkan on AMD Oberon.
- SeedVR2 3B Q4 AI video restoration/upscaling through PyTorch ROCm/HIP, BlockSwap 32 and tiled VAE decode.
- Optional AAC audio preservation.

Classic FFmpeg operations are CPU-based. Lanczos scaling is not AI super-resolution; HQDN3D is not a learned denoiser; minterpolate is not RIFE. SeedVR2 is the separate learned AI upscaler and runs on AMD ROCm/HIP. The UI and capability API keep these distinctions explicit.

## Runtime

- `runtimes/video-tools/bin/ffmpeg`
- `runtimes/video-tools/bin/ffprobe`
- `runtimes/rife-ncnn-vulkan/bin/rife-ncnn-vulkan` with `models/rife-v4.6`
- `runtimes/ComfyUI/custom_nodes/seedvr2_videoupscaler` and `models/SEEDVR2`
- Reinstall FFmpeg: `scripts/install-video-tools.sh` (no root required)
- Reinstall RIFE: `scripts/install-rife-ncnn-vulkan.sh`
- Reinstall/verify SeedVR2: `scripts/install-seedvr2.sh` (keeps the existing ROCm Torch build)
- Version: FFmpeg 7.0.2 static build from johnvansickle.com (GPL build with libx264 and libx265 enabled).
- Do not redistribute these binaries without meeting the build's GPL and corresponding codec-library obligations. Preserve the source/version information in `runtimes/video-tools/README.md`.

## API

- `POST /api/video/upload`: raw file body, `X-File-Name` URL-encoded header; 4 GiB maximum.
- `GET /api/video/sources`: uploaded source inventory.
- `GET /api/video/sources/:id`: source stream with HTTP byte-range support.
- `POST /api/video/enhance`: start one local enhancement job; choose FFmpeg/Lanczos, RIFE, or SeedVR2 with `upscaleEngine: "seedvr2"`.
- `GET /api/video/jobs/:id`: progress and result.
- `POST /api/video/cancel`: cancel the active video job.
- `GET /api/videos`: output library.
- `/videos/:name`: output stream with HTTP byte-range support.

Only one video-enhancement job runs at a time. FFmpeg uses four encoder threads; RIFE uses ncnn Vulkan; SeedVR2 uses ComfyUI/PyTorch ROCm with CPU offload and 192 px VAE tiles. SeedVR2 and RIFE cannot run in the same job.

## Known limitations / next work

- SeedVR2 3B Q4 is installed and end-to-end tested. The PS5 profile is limited to Full HD (1920 × 1080), uses BlockSwap 32 and tiled VAE decode, and measured 0.21 fps at 640x360, 0.071 fps at 720p and 0.033 fps at 1080p on five-frame tests. Long videos can therefore take a long time. See `docs/SEEDVR2_PS5.md`.
- RIFE v4.6 is installed and tested on Vulkan. It is selected separately from CPU `minterpolate` and runs only when other GPU model runtimes and ComfyUI's active queue are idle.
- AI video-to-video restyling, background/object masks, a multitrack timeline, subtitles and batch render queue are not implemented yet. 4K SeedVR2 output is intentionally blocked on the PS5 memory budget.
- Native Wan 2.1 long output concatenates independent segments; it does not guarantee seamless temporal continuity.
