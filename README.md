# PS5 AI Studio — Linux

A separate Linux-native edition of PS5 AI Studio for Ubuntu booted on PlayStation 5 through PS5 Linux Loader. This project is **not** the native Prospero/PS5 application and does not share its build, deployment, SDK or title-ID workflow.

## Current capabilities

- Browser UI on 0.0.0.0:8787. Basic Auth is intentionally disabled; use only on a trusted private LAN.
- Local chat using llama.cpp; streaming responses, image input for vision models, text-file attachments, saved conversations and Markdown export.
- Hugging Face text and image model search/downloads, metadata inspection, memory estimates, a shared pause/resume queue with duplicate-target protection, verified HTTP range-resume, SHA-256 validation, atomic queue persistence, automatic exclusion and matching of mmproj projectors (including names with mmproj in the middle), manual mmproj selection, model load/unload and deletion.
- Image Studio using stable-diffusion.cpp: checkpoint search/download, a unified inventory for checkpoints, VAE, LoRA, CLIP/text encoders, ControlNet, IP-Adapter, CLIP Vision and upscalers, text-to-image, image-to-image, mask painting/inpainting, generation progress/cancel, local gallery, independent preview clearing, complete image workflows, JSON import/export, in-place editing, and a visual node-based workflow builder. The inventory shows active assets and prevents deleting files currently loaded by the runtime. Workflow application validates required paths, duplicate critical nodes and cycles.
- Native PS5 AI Video Engine using stable-diffusion.cpp / ggml-Vulkan on port 1235, with its own video-model library, Wan 2.1 T2V profile, async generation jobs, cancellation, segment-based long-video orchestration (1–60 seconds), WebM output and local video gallery. ComfyUI remains an optional CPU-based workflow backend.
- Live diagnostics for CPU, RAM/swap, AMDGPU VRAM/GTT/TTM, temperatures, storage and runtime state.
- Settings, logs and a bounded scratch-file workspace.

## Platform separation

| Linux project | Native PS5 project |
|---|---|
| Senniet/PS5-AI-Studio-Linux | Senniet/PS5-AI-Studio |
| Ubuntu booted with PS5 Linux Loader | Native Prospero application |
| Node.js, llama.cpp, stable-diffusion.cpp, Vulkan/RADV | Prospero SDK and native PS5 runtime |
| Web UI and Linux services | Native PS5 UI and native deployment |
| This repository only | Never modify during Linux work |

## Runtime ports

| Service | Bind | Port | Authentication |
|---|---|---:|---|
| PS5 AI Studio web UI | 0.0.0.0 | 8787 | None (trusted LAN only) |
| Ollama API (host service, outside this app) | Existing LAN bind | 11434 | None (still installed; not used by this app) |
| llama.cpp | 127.0.0.1 | 8081 | Behind authenticated web UI |
| stable-diffusion.cpp · Image Studio | 127.0.0.1 | 1234 | Localhost only |
| stable-diffusion.cpp · Video Engine | 127.0.0.1 | 1235 | Localhost only |
| ComfyUI · optional workflows | 192.168.2.210 | 8790 | Separate backend; trusted LAN only |

Use the PS5's current LAN address, for example http://192.168.2.210:8787. The address may change if DHCP changes.

**Security:** The app currently has no Basic Auth by explicit design choice. Host/Origin validation and restrictive browser security headers are not a substitute for authentication or TLS. Keep the web UI, ComfyUI and any separately installed unauthenticated Ollama API on a trusted private network. Do not port-forward them to the public internet. Use a VPN or a TLS reverse proxy with authentication for remote access.

## Model and data directories

- Text GGUF: ~/.local/share/ps5-ai-studio/models/text
- Image checkpoints: ~/.local/share/ps5-ai-studio/models/image/checkpoints
- VAE: ~/.local/share/ps5-ai-studio/models/image/vae
- LoRA: ~/.local/share/ps5-ai-studio/models/image/loras
- CLIP/text encoders: ~/.local/share/ps5-ai-studio/models/image/clip
- CLIP Vision: ~/.local/share/ps5-ai-studio/models/image/clipvision
- IP-Adapter: ~/.local/share/ps5-ai-studio/models/image/ipadapter
- ControlNet: ~/.local/share/ps5-ai-studio/models/image/controlnet
- Upscalers: ~/.local/share/ps5-ai-studio/models/image/upscalers
- Generated images and metadata: ~/.local/share/ps5-ai-studio/outputs/images
- Video models: ~/.local/share/ps5-ai-studio/models/video/{diffusion_models,text_encoders,vae,loras,clip_vision,interpolators}
- Generated videos: ~/.local/share/ps5-ai-studio/outputs/videos
- Conversations and queue state: ~/.local/share/ps5-ai-studio
- Native Prospero model directories are deliberately excluded from Linux scanning and downloads; no native model files are moved or modified.

## Requirements

- Ubuntu 26.04 or compatible Linux distribution
- Node.js 22+
- llama.cpp built with Vulkan support
- stable-diffusion.cpp built with Vulkan support for image and native video workflows
- GStreamer tools (gst-launch-1.0) for multi-segment WebM concatenation
- ComfyUI is optional and currently runs CPU-only on this PS5; it is not advertised as a Vulkan/PyTorch GPU backend
- AMDGPU/RADV Vulkan device exposed by the PS5 Linux kernel

The runtime paths are currently configured for the PS5 development environment. See docs/WEB_INTERFACE.md for implementation and API details.

## Development

Run npm run check to validate JavaScript syntax. Run npm start to launch the service manually.

The systemd user service is ps5-ai-studio-linux.service. Restart it with systemctl --user restart ps5-ai-studio-linux.service. Inspect it with systemctl --user status ps5-ai-studio-linux.service and journalctl --user -u ps5-ai-studio-linux.service -f.

## Current limitations

- A Stable Diffusion 1.5 checkpoint (4.27 GB) and RealESRGAN_x4plus upscaler (about 64 MB) are installed in the Linux model library. ESRGAN upscaling has been validated end-to-end on Vulkan; SD1.5 text-to-image and masked img2img/inpainting have both been validated on the installed checkpoint; Vulkan VAE decoding reduced a 512×512 decode from about 50 seconds on CPU to about 1.7 seconds.
- Full-precision SDXL checkpoints may exceed the PS5's practical GTT budget. The image runtime uses auto-fit, CPU text-encoder placement, Vulkan VAE decoding and VAE tiling. This combination was tested successfully on the PS5; large checkpoints can still exceed available unified memory. The UI warns using a conservative estimate.
- SD1.5 Canny ControlNet and classic IP-Adapter inference are validated individually and together on CPU. A combined 512×512 ControlNet + IP-Adapter generation completed successfully. A ControlNet-conditioned Vulkan test currently crashes in the UNet path; IP-Adapter Vulkan has not yet been validated. The app therefore conservatively runs both conditioning workflows on CPU for now; this is reliable but slower.
- This edition is still under active development; runtime CLI options and backend API compatibility must be validated against the installed builds.

### Advanced image workflows

The Image Studio also includes optional ControlNet conditioning, IP-Adapter reference guidance (with a matching FP16 CLIP Vision H encoder), multiple LoRAs, ESRGAN upscaling as a separate cancellable job, and prompt/settings sidecars for each generated image. The gallery can restore a prior prompt and generation setup. SD1.5 Canny ControlNet and classic SD1.5 IP-Adapter passed end-to-end CPU generation tests individually and in a combined conditioning job; the app automatically selects CPU for conditioned sessions because ControlNet has reproduced a Vulkan UNet crash and IP-Adapter Vulkan compatibility is not yet verified.

The Image Studio now includes combined model-memory planning for selected conditioning assets and reusable prompt presets (four built-in styles plus up to 100 local custom presets).

Stable Diffusion 1.5 text-to-image and image-to-image/inpainting have passed real Vulkan smoke tests on the PS5 Linux environment. ControlNet and IP-Adapter use the native asynchronous stable-diffusion.cpp job API and have both passed CPU generation tests. A 512×512 IP-Adapter smoke generation completed in about 54 seconds on CPU; conditioned generation is functional but slower than unconditioned Vulkan generation.


## Workflow Studio / ComfyUI

Workflow Studio runs a local ComfyUI backend as a separate user service (`ps5-ai-studio-comfyui.service`). The ComfyUI checkout and Python environment live under `runtimes/` and are intentionally excluded from Git. Tracked integration files live in `apps/comfyui/` and `packaging/systemd/`.

The current PS5 Oberon GPU is exposed through Vulkan but is not available to PyTorch as a supported ROCm/HIP device. ComfyUI therefore runs its workflow graph engine on CPU. The custom **PS5 AI Studio · Generate / Edit** node delegates image generation and editing to the existing stable-diffusion.cpp Vulkan runtime through the PS5 AI Studio API. Load a checkpoint in Image Studio before executing that node. ComfyUI shares the existing image model directories through `extra_model_paths.yaml`.

ComfyUI is bound to the PS5 Linux LAN address on port `8790`; the PS5 AI Studio web application remains on port `8787`. The ComfyUI backend is not exposed on the loopback-only interface, and its UI is embedded in the Workflow Studio section.

ComfyUI-Manager is enabled for curated registry custom nodes. Its tracked configuration uses `security_level = normal-` and keeps arbitrary Git URL installs, standalone pip installs and flagged node packs disabled; high-risk installs are blocked on the LAN listener. See `apps/comfyui/README.md` for the bridge-node workflow and hardware constraints.

## Video Studio

Video Studio has two independent backends:

- **Native PS5 AI Video Engine (preferred):** stable-diffusion.cpp with ggml-Vulkan/RADV, bound to 127.0.0.1:1235. It has a separate model library and currently includes the Wan 2.1 T2V 1.3B Q4 profile. Model loading is mutually exclusive with the text and image runtimes to respect the PS5 unified-memory budget.
- **ComfyUI (optional):** import a ComfyUI API-format workflow. The current ComfyUI/PyTorch build runs on CPU; custom PS5 AI Studio bridge nodes can delegate supported image work to the native Vulkan image runtime.

The native engine has passed a real 1-second, 9-frame, 2-step Wan 2.1 Vulkan generation test. GStreamer WebM concatenation was tested separately. The UI accepts 1–60 second targets and splits native text-to-video into sequential segments of at most 81 frames each. A complete multi-segment generation has not yet been validated end-to-end, and independent T2V segments do not guarantee visual/action continuity. Long native image-to-video, frame chaining, audio, interpolation and video upscaling remain under development; do not interpret UI roadmap labels as validated capabilities. See docs/VIDEO_STUDIO.md.

## Civitai model repository

The Model Shop can search Civitai alongside Hugging Face for image checkpoints and assets. Select **Civitai**, choose an image category, search, select a model, then choose a specific version/file to enqueue. Downloads use the existing resumable queue and are placed in the corresponding Linux model directory (never the native PS5 app directories). The API integration uses Civitai's public v1 model search endpoint and version download endpoint. An optional API token can be supplied to the server process as `CIVITAI_API_KEY` for gated or rate-limited access; it is never exposed to the browser.
