# PS5 AI Studio — Linux

A separate Linux-native edition of PS5 AI Studio for Ubuntu booted on PlayStation 5 through PS5 Linux Loader. This project is **not** the native Prospero/PS5 application and does not share its build, deployment, SDK or title-ID workflow.

## Current capabilities

- Browser UI on 0.0.0.0:8787 with HTTP Basic Authentication.
- Local chat using Ollama or llama.cpp; streaming responses, image input for vision models, text-file attachments, saved conversations and Markdown export.
- Hugging Face GGUF search, metadata inspection, memory estimates, model download queue with pause/resume, SHA-256 validation, manual mmproj selection, model load/unload and deletion.
- Ollama model pull, list and deletion.
- Image Studio using stable-diffusion.cpp: checkpoint search/download, checkpoint/VAE/LoRA management, text-to-image, image-to-image, mask painting/inpainting, generation progress/cancel and local gallery.
- Live diagnostics for CPU, RAM/swap, AMDGPU VRAM/GTT/TTM, temperatures, storage and runtime state.
- Settings, logs and a bounded scratch-file workspace.

## Platform separation

| Linux project | Native PS5 project |
|---|---|
| Senniet/PS5-AI-Studio-Linux | Senniet/PS5-AI-Studio |
| Ubuntu booted with PS5 Linux Loader | Native Prospero application |
| Node.js, Ollama, llama.cpp, stable-diffusion.cpp, Vulkan/RADV | Prospero SDK and native PS5 runtime |
| Web UI and Linux services | Native PS5 UI and native deployment |
| This repository only | Never modify during Linux work |

## Runtime ports

| Service | Bind | Port | Authentication |
|---|---|---:|---|
| PS5 AI Studio web UI | 0.0.0.0 | 8787 | Basic Auth |
| Ollama API | Existing LAN bind | 11434 | None (kept open at the user's request; private LAN only) |
| llama.cpp | 127.0.0.1 | 8081 | Behind authenticated web UI |
| stable-diffusion.cpp | 127.0.0.1 | 1234 | Behind authenticated web UI |

Use the PS5's current LAN address, for example http://192.168.2.210:8787. The address may change if DHCP changes.

**Security:** Basic Auth over HTTP does not encrypt credentials. Keep the UI and the unauthenticated Ollama API on a trusted private network. Do not port-forward either service to the public internet. Use a VPN or a TLS reverse proxy for remote access.

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
- Conversations and queue state: ~/.local/share/ps5-ai-studio
- Credentials: ~/.config/ps5-ai-studio-linux/auth.env (mode 0600; never commit this file)
- Native Prospero model directories are deliberately excluded from Linux scanning and downloads; no native model files are moved or modified.

## Requirements

- Ubuntu 26.04 or compatible Linux distribution
- Node.js 22+
- Ollama (optional if using llama.cpp only)
- llama.cpp built with Vulkan support
- stable-diffusion.cpp built with Vulkan support for image workflows
- AMDGPU/RADV Vulkan device exposed by the PS5 Linux kernel

The runtime paths are currently configured for the PS5 development environment. See docs/WEB_INTERFACE.md for implementation and API details.

## Development

Run npm run check to validate JavaScript syntax. Run npm start to launch the service manually.

The systemd user service is ps5-ai-studio-linux.service. Restart it with systemctl --user restart ps5-ai-studio-linux.service. Inspect it with systemctl --user status ps5-ai-studio-linux.service and journalctl --user -u ps5-ai-studio-linux.service -f.

## Current limitations

- A Stable Diffusion 1.5 checkpoint (4.27 GB) and RealESRGAN_x4plus upscaler (about 64 MB) are installed in the Linux model library. ESRGAN upscaling has been validated end-to-end on Vulkan; SD1.5 text-to-image and masked img2img/inpainting have both been validated on the installed checkpoint; Vulkan VAE decoding reduced a 512×512 decode from about 50 seconds on CPU to about 1.7 seconds.
- Full-precision SDXL checkpoints may exceed the PS5's practical GTT budget. The image runtime uses auto-fit, CPU text-encoder placement, Vulkan VAE decoding and VAE tiling. This combination was tested successfully on the PS5; large checkpoints can still exceed available unified memory. The UI warns using a conservative estimate.
- SD1.5 ControlNet Canny inference is validated end-to-end on CPU. The PS5 Vulkan UNet path currently crashes when ControlNet is enabled, so the app automatically runs conditioned sessions on CPU; this is reliable but slower. IP-Adapter still needs compatible local assets and end-to-end validation.
- This edition is still under active development; runtime CLI options and backend API compatibility must be validated against the installed builds.

### Advanced image workflows

The Image Studio also includes optional ControlNet conditioning, IP-Adapter reference guidance (with a matching CLIP Vision encoder), multiple LoRAs, ESRGAN upscaling as a separate cancellable job, and prompt/settings sidecars for each generated image. The gallery can restore a prior prompt and generation setup. SD1.5 Canny ControlNet was tested end-to-end on CPU; the app automatically selects CPU for conditioned sessions because the PS5 Vulkan ControlNet path currently crashes. IP-Adapter awaits compatible assets and validation.

The Image Studio now includes combined model-memory planning for selected conditioning assets and reusable prompt presets (four built-in styles plus up to 100 local custom presets).

Stable Diffusion 1.5 text-to-image and image-to-image/inpainting have passed real Vulkan smoke tests on the PS5 Linux environment. ControlNet uses the native asynchronous stable-diffusion.cpp job API and has passed a CPU generation test; IP-Adapter is wired but not yet hardware-validated.