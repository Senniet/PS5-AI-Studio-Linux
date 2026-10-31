# Linux Web Interface and Runtime

Last updated: 2026-10-31

## Separation from native PS5 app

This is the Linux edition booted by PS5 Linux Loader. Do not edit or deploy the native Prospero project while working here. The Linux application runs in Ubuntu and uses Node.js, Ollama, llama.cpp, stable-diffusion.cpp and Vulkan/RADV.

## Services

- Node server: apps/server/server.mjs
- Frontend: apps/web/index.html, apps/web/app.js, apps/web/styles.css
- Web bind: 0.0.0.0:8787
- Basic Auth credentials: ~/.config/ps5-ai-studio-linux/auth.env
- systemd user service: ps5-ai-studio-linux.service
- Ollama API: existing LAN bind on port 11434 (intentionally unchanged)
- llama.cpp server: localhost port 8081
- stable-diffusion.cpp server: localhost port 1234 (configurable)

All web UI and application API routes require Basic Auth. The Ollama API is separate and has no authentication; it remains reachable on the trusted LAN at the user's explicit request. Do not expose it to the internet.

The web server validates Host against local interface addresses and validates browser Origin against the request Host. It also sends a restrictive Content Security Policy and same-origin resource policy. Basic Auth over HTTP is not encryption.

## Frontend sections

1. Overview: RAM, GTT, GPU busy, CPU load, runtime state.
2. AI Chat: Ollama/llama.cpp selection, streaming, vision image input, text-file attachments, saved conversations, delete and Markdown export.
3. Model Library: local GGUF metadata, KV-cache estimate, context-aware memory estimate, GPU layer selection, mmproj pairing, load/unload/delete, Ollama model list/pull/delete.
4. Model Market: Hugging Face GGUF search, file listing, download queue, pause/resume, SHA-256 validation.
5. Image Studio: image checkpoint market, VAE and LoRA library, load/unload, txt2img, img2img, brush-painted or file-provided inpainting mask, progress/interrupt, local gallery.
6. Files: bounded scratch workspace for text and notes.
7. Diagnostics: CPU, RAM, swap, AMDGPU VRAM/GTT, TTM page limit, temperatures, storage and runtime status.
8. Logs and Settings.

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
The app stops the other GPU-heavy runtime before starting a text or image runtime. Ollama models are unloaded before standalone llama.cpp or stable-diffusion.cpp starts. Starting an Ollama chat stops the standalone text and image runtimes first.

## Image pipeline

The server invokes stable-diffusion.cpp on localhost with the configured Vulkan backend. The default backend assignment uses Vulkan for diffusion and CPU for text encoders/VAE, with auto-fit enabled and VAE tiling. This reduces pressure on the PS5's limited GTT budget and allows the backend to place model components in system RAM when appropriate.

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
- POST /api/ollama/pull|delete
- POST /api/chat (streaming NDJSON for Ollama or SSE for llama.cpp)
- GET|POST|DELETE /api/conversations
- GET|POST|DELETE /api/files
- GET /api/image/models, POST /api/image/models/delete
- POST /api/image/generate, POST /api/image/cancel, GET /api/image/progress, GET /api/image/options
- GET /api/gallery, DELETE /api/gallery/<filename>, authenticated /gallery/<filename> output delivery
- GET /api/logs

## Security and boundaries

- Basic Auth is required for the web UI and API.
- Host and Origin checks reject requests from unrecognized hostnames and cross-origin browser requests.
- CSP, X-Frame-Options, X-Content-Type-Options and same-origin resource policy are set.
- Basic Auth over plain HTTP is not encryption. Use only on a trusted LAN.
- Ollama port 11434 is intentionally left as the existing unauthenticated LAN API at the user's request.
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
- Image generation itself: not yet tested because no local image checkpoint is installed.

## Advanced image workflows (v0.4)

- ControlNet assets are managed in the dedicated controlnet directory. Select a ControlNet checkpoint before loading the image runtime, then provide a matching control/reference image and strength.
- IP-Adapter assets and their CLIP Vision encoder are managed separately. Both must be selected together when loading the image runtime. An IP-Adapter reference image and strength are supplied per generation.
- Multiple LoRAs can be selected simultaneously; the current UI applies one shared multiplier to the selected LoRAs.
- ESRGAN upscaling runs as a separate cancellable sd-cli job. The image runtime is stopped first to avoid competing for GTT. Results are saved to the image gallery.
- Each new generated image receives a JSON sidecar with prompt, negative prompt, model, dimensions, sampler, scheduler, seed and conditioning strengths. Gallery entries can restore the saved prompt/settings; deleting an image also deletes its sidecar.

New image model categories: ipadapter and clipvision. New API routes: GET /api/gallery/<filename>/metadata, POST /api/image/upscale, GET /api/image/upscale/status, and POST /api/image/upscale/cancel.

ControlNet, IP-Adapter and ESRGAN execution are wired to the installed stable-diffusion.cpp interfaces but remain hardware-unverified until the corresponding model assets are downloaded and a real generation/edit is run.