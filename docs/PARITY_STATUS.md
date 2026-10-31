# Feature parity: Linux edition vs native PS5 app

Last updated: 2026-10-31

This is a functional parity tracker, not a claim that the two platforms share code. The Linux implementation is independent and uses Ubuntu, Node.js, Ollama, llama.cpp, stable-diffusion.cpp and Vulkan/RADV. Prospero-specific code stays in the native repository.

| Area | Linux status | Notes |
|---|---|---|
| Text chat | Implemented | Streaming through Ollama or llama.cpp |
| Vision chat | Implemented in UI/API | Requires a vision model and matching mmproj |
| Text-file attachments | Implemented | Bounded text/JSON/CSV/code attachments |
| Conversation history | Implemented | Persistent, load, delete and Markdown export |
| Hugging Face GGUF search | Implemented | Search repositories and list compatible files |
| GGUF downloads | Implemented | Queue, pause/resume, size and SHA-256 validation |
| GGUF metadata | Implemented | Header-based architecture, parameter, layer, head and context data |
| KV-cache planning | Implemented | Context- and cache-type-aware estimate |
| GPU layer planning | Implemented | Auto estimate plus all/CPU-only/manual selection |
| mmproj pairing | Implemented | Automatic unique match and manual selection |
| llama.cpp runtime | Implemented; hardware validation pending | Local server auto-loads on first chat |
| Ollama model management | Implemented | Pull, list, delete and chat |
| Image checkpoint search | Implemented | Hugging Face image-asset categories |
| Image downloads | Implemented | Category-specific directories and resumable queue |
| Checkpoint/VAE/LoRA management | Implemented | Scan, select and delete |
| Text-to-image | Validated | SD1.5 512×512 generation on Vulkan; VAE also on Vulkan |
| Image-to-image | Validated | SD1.5 img2img with source image and denoising strength |
| Inpainting | Validated | SD1.5 masked img2img with uploaded mask; brush mask wired |
| Image progress and interrupt | Wired; hardware validation pending | SD API progress and interrupt endpoints |
| Image gallery | Implemented | Browse, reuse as source and delete |
| ControlNet inference | CPU generation validated; Vulkan crashes on this PS5 | App forces CPU backend for conditioned sessions |
| IP-Adapter | CPU generation validated | SD1.5 classic adapter + FP16 CLIP Vision H installed; conditioned sessions use CPU fallback |
| Upscaling workflow | Validated | RealESRGAN_x4plus on Vulkan; gallery action, status and cancel |
| Hardware dashboard | Implemented | CPU, RAM/swap, GPU, GTT/TTM, temperature and disk |
| Runtime exclusivity | Implemented | GPU-heavy runtimes are stopped before switching |
| Settings and logs | Implemented | Persisted settings and service logs |
| Scratch files | Implemented | Bounded create/read/delete workspace |

## Validation performed

- Node syntax checks pass.
- HTML/JavaScript ID reference audit reports no duplicate IDs and no missing references.
- Authenticated health, diagnostics, model, image model, conversation and scratch-file API routes have been exercised.
- Host allow-list and Origin checks return 403 for invalid hosts/origins.
- Ollama Qwen3 8B streaming chat was exercised successfully; the test model was unloaded afterward.
- GGUF metadata parsing was validated with a synthetic fixture, which was removed afterward.
- Hugging Face repository search and GGUF/SDXL file listings were exercised.
- A Stable Diffusion 1.5 checkpoint and RealESRGAN_x4plus upscaler are installed. SD1.5 text-to-image and masked img2img/inpainting passed; ESRGAN upscaling passed on Vulkan. Vulkan VAE decode takes about 1.7 seconds for 512×512.

## Next parity milestones

1. Validate additional SDXL/SD1.5 checkpoints and refine high-resolution img2img/inpainting workflows.
2. Improve conditioned-generation performance and test additional ControlNet/IP-Adapter variants; improve upscale options and batch reliability.
3. Add model conversion/quantization helpers for memory-constrained checkpoints.
4. Expand prompt presets into reusable end-to-end image workflow templates.
5. Add richer chat/tool workflows and model-specific vision capability detection.

### v0.4 additions

- ControlNet model discovery, download category, runtime loading and reference-image/strength controls: end-to-end validated on CPU; Vulkan ControlNet crashes on this PS5, so conditioned image sessions automatically use CPU.
- IP-Adapter + CLIP Vision discovery, download categories, paired runtime loading and reference-image/strength controls: end-to-end SD1.5 CPU generation validated with the classic adapter and FP16 CLIP Vision H. Conditioning sessions use CPU for compatibility.
- Multi-LoRA selection with shared multiplier: implemented.
- ESRGAN upscale job using sd-cli, with status, logs and cancellation: validated on Vulkan with RealESRGAN_x4plus.
- Generation prompt/settings sidecars and gallery prompt restoration: implemented.
- Combined checkpoint/conditioning memory planner, server-side load preflight and built-in/custom prompt presets: implemented.
- Batch generation (1–4 images) with batch-aware prompt presets and gallery metadata: implemented.
- SD 1.5 txt2img and img2img/inpainting: tested on PS5 Vulkan; 512×512 smoke generations completed and saved.
- Native asynchronous ControlNet/IP-Adapter job path, job progress, preview metadata and cancellation: implemented. ControlNet and IP-Adapter end-to-end generation passed on CPU individually and together; the IP-Adapter-only 512×512 one-step smoke job completed in 54.3 seconds and the combined conditioning job completed in 78.7 seconds. Vulkan conditioning crashes in the SD1.5 UNet path on this PS5, so conditioned jobs automatically use the CPU backend for reliability.
- Uploaded inpainting masks are normalized to grayscale and source dimensions before generation; optional mask inversion is available.
- Marketplace excludes `.pt` and `.pth` pickle-based image model downloads; `.onnx` support added to the download allow-list.