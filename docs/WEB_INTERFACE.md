# Linux Web Interface and Runtime

Last updated: 2026-11-02

## Separation from native PS5 app

This is the Linux edition booted by PS5 Linux Loader. Do not edit or deploy the native Prospero project while working here. The Linux application runs in Ubuntu and uses Node.js, llama.cpp, stable-diffusion.cpp and Vulkan/RADV. Ollama can remain installed as a separate host service, but the application does not depend on or call it.

## Services

- Node server: apps/server/server.mjs
- Frontend: apps/web/index.html, apps/web/app.js, apps/web/styles.css
- Web bind: 0.0.0.0:8787
- systemd user service: ps5-ai-studio-linux.service
- llama.cpp server: localhost port 8081
- stable-diffusion.cpp server: localhost port 1234 (configurable)

The web UI and application API currently have no Basic Auth by explicit user choice. The Ollama API is separate and has no authentication; keep both services on a trusted private LAN and do not expose them to the internet.

The web server validates Host against local interface addresses and validates browser Origin against the request Host. It also sends a restrictive Content Security Policy and same-origin resource policy. These controls are not authentication or encryption; use a VPN or an authenticated TLS reverse proxy for remote access.

## Frontend sections

1. Overview: RAM, GTT, GPU busy, CPU load, runtime state.
2. AI Chat: llama.cpp streaming, vision image input, text-file attachments, saved conversations, delete and Markdown export.
3. Model Library: combined inventory of local GGUF text models and image assets (checkpoints, VAE, LoRA, encoders, ControlNet, IP-Adapter and upscalers), with metadata, memory estimates, asset management and direct image-checkpoint loading.
4. Model Shop: one search and download interface for GGUF repositories and categorized image assets; both use the same repository/file panels and shared download queue.
4. Model Market: Hugging Face GGUF search, file listing, download queue, pause/resume, SHA-256 validation.
5. Image Studio: active image-runtime status, VAE and LoRA generation settings, txt2img, img2img, brush-painted or file-provided inpainting mask, progress/interrupt, local gallery.
6. Files: bounded scratch workspace for text and notes.
7. Diagnostics: CPU, RAM, swap, AMDGPU VRAM/GTT, TTM page limit, temperatures, storage and runtime status.
8. Video Studio: native stable-diffusion.cpp / Vulkan video runtime with its own model library and async jobs; optional ComfyUI API-workflow backend.
9. Logs and Settings.

## Model handling

### GGUF
The GGUF header parser reads architecture, parameter count, block count, embedding length, attention heads, KV heads, key/value head dimensions and context length when available. KV cache is estimated from the selected context and cache type. The planner compares estimated model weights + KV cache + runtime overhead with available system memory and remaining GTT.

The auto GPU-layer mode estimates a safe number of layers from remaining GTT. All and CPU-only remain available. A model can be paired with a sibling mmproj*.gguf; if more than one projector exists, the model card exposes a manual selector. The scanner and download allow-list are Linux-specific: native PS5LM model directories and the shared ai-models directory are deliberately excluded and are never modified.

### Hugging Face downloads
The download queue:
- accepts only GGUF for text models;
- uses category-specific directories and extensions for image assets;
- supports pause and resume using .part files and HTTP Range requests;
- checks known file size and SHA-256 when the repository provides it;
- persists queue state across service restarts.

### Runtime exclusivity
The app stops the other GPU-heavy runtime before starting a text, image or video runtime. Text chat and text-model loading use llama.cpp exclusively. Native video inference uses stable-diffusion.cpp on Vulkan0 for diffusion, text encoder and VAE. ComfyUI is a separate optional workflow service and currently runs CPU-only on the PS5; it is not a GPU inference backend.

## Image pipeline

The server invokes stable-diffusion.cpp on localhost with the configured Vulkan backend. The default backend assignment uses Vulkan for diffusion and VAE, CPU for text encoders, with auto-fit enabled and VAE tiling. On the PS5 this reduced a 512×512 VAE decode from roughly 50 seconds on CPU to about 1.7 seconds on Vulkan. This reduces pressure on the PS5's limited GTT budget and allows the backend to place model components in system RAM when appropriate.

- txt2img: /sdapi/v1/txt2img
- img2img: /sdapi/v1/img2img
- progress: /sdapi/v1/progress
- interrupt: /sdapi/v1/interrupt
- options: /sdapi/v1/options, samplers and schedulers

Generated images are written to ~/.local/share/ps5-ai-studio/outputs/images. The browser gallery serves only files from this output directory. Inpainting uses a black mask canvas with white painted regions.

## API surface

- GET /api/health
- GET /api/diagnostics
- GET /api/runtime
- GET|POST /api/settings
- GET /api/models?context=...&cacheK=...
- POST /api/models/delete
- POST /api/runtime/text/load|unload
- POST /api/runtime/image/load|unload
- GET /api/market/search, GET /api/market/files, POST /api/market/download, POST /api/market/action
- GET /api/market/image-search
- GET /api/market/queue
- POST /api/chat (streaming SSE from llama.cpp)
- GET|POST|DELETE /api/conversations
- GET|POST|DELETE /api/files
- GET /api/image/models, POST /api/image/models/delete
- POST /api/image/generate, POST /api/image/cancel, GET /api/image/progress, GET /api/image/options
- GET /api/gallery, DELETE /api/gallery/<filename>, authenticated /gallery/<filename> output delivery
- GET /api/video/native/status|models|catalog
- POST /api/video/native/catalog/install|models/upload|load|unload|generate
- DELETE /api/video/native/models
- GET /api/video/jobs/:id, GET /api/videos, POST /api/video/cancel
- GET /api/logs

## Security and boundaries

- Basic Auth is intentionally disabled by explicit user choice; do not reintroduce it without asking.
- Host and Origin checks reject requests from unrecognized hostnames and cross-origin browser requests.
- CSP, X-Frame-Options, X-Content-Type-Options and same-origin resource policy are set.
- The UI is unauthenticated HTTP. Use only on a trusted LAN; use a VPN or authenticated TLS reverse proxy for remote access.
- The web server exposes no arbitrary shell or arbitrary filesystem API.
- Model paths must originate from the local model scanners; image assets are limited to the dedicated model directories.
- Scratch file names are constrained and storage has a configured cap.
- The gallery only reads generated image output files.
- Never port-forward the web UI or Ollama API to the public internet.

## Validation status

- Node syntax checks: passed during implementation.
- HTML-to-JavaScript ID reference check: passed (no missing or duplicate IDs).
- Authenticated API smoke tests: passed for health, diagnostics, models, image model scan, conversations CRUD and scratch-file CRUD.
- Host allow-list and Origin rejection: passed.
- Hugging Face search and file listing: tested for a GGUF repository and an SDXL repository.
- Ollama streaming chat: tested with qwen3:8b-16k; model unloaded after the test.
- GGUF header parser: validated against a synthetic GGUF header fixture; fixture removed afterward.
- ESRGAN upscaling: tested end-to-end with RealESRGAN_x4plus on Vulkan; a 64×64 test image was enlarged to 256×256. Temporary test images were removed.
- Stable Diffusion 1.5 checkpoint downloaded with SHA-256 validation; text-to-image and masked img2img/inpainting both passed on Vulkan. A 512×512 four-step txt2img run completed in about 4.4 seconds with Vulkan VAE decoding.
- SD1.5 Canny ControlNet and classic SD1.5 IP-Adapter conditioning both passed end-to-end CPU generation tests. Vulkan conditioning crashes in the UNet path on this PS5, so conditioned sessions use CPU automatically.

## Advanced image workflows (v0.4)

- ControlNet assets are managed in the dedicated controlnet directory. Select a ControlNet checkpoint before loading the image runtime, then provide a matching control/reference image and strength. A client-side Sobel edge-map preprocessor can turn an ordinary reference image into a basic edge map for Canny-style ControlNet checkpoints.
- IP-Adapter assets and their CLIP Vision encoder are managed separately. Both must be selected together when loading the image runtime. An IP-Adapter reference image and strength are supplied per generation.
- Multiple LoRAs can be selected simultaneously; the current UI applies one shared multiplier to the selected LoRAs. Batch generation supports one to four images; the UI warns that larger batches increase memory pressure on the PS5.
- ESRGAN upscaling runs as a separate cancellable sd-cli job. The image runtime is stopped first to avoid competing for GTT. Results are saved to the image gallery.
- Each new generated image receives a JSON sidecar with prompt, negative prompt, model, dimensions, sampler, scheduler, seed and conditioning strengths. Gallery entries can restore the saved prompt/settings; deleting an image also deletes its sidecar.

New image model categories: ipadapter and clipvision. New API routes: GET /api/gallery/<filename>/metadata, POST /api/image/upscale, GET /api/image/upscale/status, and POST /api/image/upscale/cancel.

ControlNet and IP-Adapter execution use the native stable-diffusion.cpp job API. The SD1.5 Canny ControlNet, classic SD1.5 IP-Adapter and matching FP16 CLIP Vision H encoder are installed and have passed CPU generation tests individually and in a combined ControlNet + IP-Adapter job. A ControlNet-conditioned Vulkan job reproduced a crash in the UNet path on this PS5; IP-Adapter Vulkan compatibility has not yet been tested. The app keeps the diffusion UNet and conditioning modules on CPU (the known Vulkan ControlNet UNet path crashes on this PS5) while assigning VAE decoding to Vulkan0, which has been independently smoke-tested. This hybrid placement is intended to recover faster VAE decode without re-enabling the unstable conditioned UNet Vulkan path. Standard unconditioned image generation continues to use the configured Vulkan backend. The model marketplace excludes PyTorch pickle-based `.pt` and `.pth` downloads; prefer SafeTensors, GGUF and ONNX assets from trusted model publishers. ESRGAN has passed a Vulkan smoke test.

## Image planning and prompt presets

The Image Studio calculates a combined memory estimate for the selected checkpoint, VAE, ControlNet, IP-Adapter and CLIP Vision assets. The backend repeats this preflight before spawning the runtime and refuses combinations estimated to exceed safe available memory; tight combinations are still allowed with stable-diffusion.cpp auto-fit/CPU offload. It reports estimated weight plus runtime overhead against currently free GTT and system memory. This is a conservative planning signal, not a guarantee: the backend's auto-fit and CPU component placement still determine actual allocations.

Four built-in prompt presets are provided (photorealistic, cinematic, product photography and illustration). Users can save up to 100 named local presets, reload their prompt/negative prompt and generation settings, and delete custom presets. Presets are stored locally in the application state directory and are never uploaded.

## Native conditioning jobs (v0.5)

Stable Diffusion text-to-image and img2img/inpainting were exercised end-to-end on the PS5 Linux Vulkan backend. The installed SD1.5 classic IP-Adapter weights are `h94/IP-Adapter/models/ip-adapter_sd15.safetensors` (SHA-256 `289b45f16d043d0bf542e45831f971dcdaabe18b656f11e86d9dfba7e9ee3369`); the matching CLIP Vision H encoder is an FP16 SafeTensors file (SHA-256 `5846f524f8ebf9c3092cba64d1d2ed63b0997d00e80be32b0124114a592e8474`). The adapter reports four image tokens at runtime. When ControlNet or IP-Adapter reference conditioning is supplied, the app now uses stable-diffusion.cpp's native asynchronous `/sdcpp/v1/img_gen` job API (submit, poll, preview progress and cancel), because the A1111-compatible `/sdapi/v1` routes do not expose those conditioning fields. The regular SDAPI path remains in place for standard generation and tested inpainting. Uploaded mask files are converted to a one-channel grayscale PNG and resized to the source image dimensions before submission. The mask can be inverted in the UI without changing the original uploaded mask.

A SafeTensors FP16 SD1.5 Canny ControlNet checkpoint is stored in the Linux ControlNet library; the older PyTorch `.pth` copy was removed to reduce storage and avoid duplicate choices. ControlNet loading and conditioning still require a final end-to-end GPU test on this hardware.
