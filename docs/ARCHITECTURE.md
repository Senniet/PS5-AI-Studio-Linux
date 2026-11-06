# Linux platform architecture

Last updated: 2026-11-02

## Project boundary

PS5 AI Studio Linux is a standalone Ubuntu/Linux application for the PS5 Linux environment. It is separate from the native Prospero application in Senniet/PS5-AI-Studio. It does not use the Prospero SDK, title IDs, PS5 payload deployment, FTP deployment or native application paths.

## Runtime architecture

- Web/API: Node.js service in apps/server/server.mjs; browser client in apps/web/; default listener 0.0.0.0:8787.
- Text inference: upstream llama.cpp server, loopback port 8081; GGUF text/vision models, streaming chat and conversation storage.
- Image inference: stable-diffusion.cpp server, loopback port 1234; GGML Vulkan/RADV for supported diffusion and VAE operations, with conservative CPU placement for conditioning paths that are not validated on Vulkan.
- Native video inference: stable-diffusion.cpp server, loopback port 1235; dedicated video model library and Vulkan0 allocation for diffusion, text encoder and VAE. Wan 2.1 T2V 1.3B Q4 is the first validated profile.
- Workflow orchestration: optional ComfyUI service on port 8790. The active service uses the isolated gfx1013 ROCm/HIP environment; Krea 2 image generation has been validated there. This is separate from the native Vulkan video engine. The PS5 AI Studio bridge can delegate supported image work to the native image runtime. See [ROCm gfx1013 status](ROCM_GFX1013.md).
- Model manager: shared resumable download queue plus separate text, image and video asset categories.
- Diagnostics: CPU, RAM/swap, AMDGPU VRAM/GTT/TTM, temperature, storage and process/runtime state.

## GPU and runtime lifecycle

The target PS5 exposes AMD Custom Zen 2 / Oberon through Mesa RADV (GFX1013). It uses unified memory: dedicated VRAM reporting is only 512 MiB, while the practical GPU budget is represented by the AMDGPU GTT/TTM pool. Vulkan heap figures are estimates and are not additional physical RAM.

Text, image and native video inference are mutually exclusive. Before loading one of these heavy runtimes, the service unloads the other GPU-heavy runtimes to reduce memory contention. Model fit checks are conservative preflight estimates; a complete model stack does not guarantee that every resolution, frame count or batch size will fit.

Native video currently supports the Wan 2.1 T2V profile. Individual renders are limited to 81 frames (4n+1). Longer text-to-video requests are orchestrated as multiple generations and concatenated as WebM with GStreamer. This produces a longer file, but does not yet provide temporal continuity between independently generated segments. Native Wan 2.1 is T2V-only; image-to-video requires a different compatible model profile.

## Data and model directories

- Config: ~/.config/ps5-ai-studio-linux
- Application data: ~/.local/share/ps5-ai-studio
- Text models: models/text
- Image assets: models/image/{checkpoints,vae,loras,clip,controlnet,upscalers,ipadapter,clipvision}
- Video assets: models/video/{diffusion_models,text_encoders,vae,loras,clip_vision,interpolators}
- Generated images: outputs/images
- Generated videos: outputs/videos
- Logs, conversations, queue state and scratch files: under application data.

Model weights, generated media, runtime checkouts, Python virtual environments, credentials and machine-specific logs are not source-controlled. See the repository .gitignore.

## Network and security model

The web/API listener is currently bound to 0.0.0.0:8787 for the user's private LAN workflow. Basic Auth is intentionally disabled by explicit user choice. Host and Origin validation, CSP and same-origin response policies provide request/browser protections but are not authentication or encryption. Do not expose the service directly to the internet. For remote access, use a VPN or an authenticated TLS reverse proxy.

Inference servers bind to loopback. ComfyUI is a separate LAN service on port 8790 and should also remain on a trusted private network. The app does not expose arbitrary shell execution or unrestricted filesystem access; model paths are resolved through known model roots and uploads use constrained names/categories.

## Development and validation

Run npm run check for JavaScript syntax validation. The PS5 hardware smoke tests have confirmed llama.cpp Vulkan inference, Stable Diffusion 1.5 image generation/inpainting and upscaling paths, and a real Wan 2.1 Vulkan video generation (1 second, 9 frames, 2 steps). GStreamer WebM concatenation has been exercised separately. A complete multi-segment model generation, cross-segment continuity, native long I2V, audio, interpolation and video upscaling are not yet validated.

See docs/WEB_INTERFACE.md, docs/VIDEO_STUDIO.md, docs/PARITY_STATUS.md and docs/RUNTIME_BUILD_AND_MEMORY.md for implementation and measured hardware details.
