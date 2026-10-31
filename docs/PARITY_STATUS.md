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
| Text-to-image | Wired; hardware validation pending | Requires a compatible local checkpoint |
| Image-to-image | Wired; hardware validation pending | Source image and denoising strength |
| Inpainting | Wired; hardware validation pending | White brush mask or uploaded mask |
| Image progress and interrupt | Wired; hardware validation pending | SD API progress and interrupt endpoints |
| Image gallery | Implemented | Browse, reuse as source and delete |
| ControlNet inference | Not implemented | Model category exists; generation controls still needed |
| Upscaling workflow | Not implemented | Upscaler storage exists; UI/API workflow still needed |
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
- The PS5 has no local image checkpoint in the Linux model directories yet. Real image generation and editing therefore remain unverified.

## Next parity milestones

1. Validate SDXL/SD1.5 generation, img2img and inpainting with a real checkpoint.
2. Add ControlNet conditioning and upscale workflows.
3. Add model conversion/quantization helpers for memory-constrained checkpoints.
4. Add image generation presets, reusable prompt presets and workflow templates.
5. Add richer chat/tool workflows and model-specific vision capability detection.