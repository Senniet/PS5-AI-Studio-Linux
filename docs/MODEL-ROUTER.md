# PS5 AI Studio — model router

Updated: 2026-11-06

## Roles

PS5 AI Studio uses separate specialist models instead of asking one small model to perform every task.

| Role | Model | Local file | Notes |
|---|---|---|---|
| Prompt writing and quality review | Huihui Qwen3-4B-Instruct-2507 Abliterated Q4_K_M | `~/.local/share/ps5-ai-studio/models/text/Huihui_Qwen3-4B-Instruct-2507-Abliterated-Q4_K_M.gguf` | Local uncensored/abliterated prompt specialist; temporary llama.cpp service on port 8083; text-only (`--no-mmproj`). Supports adult consensual NSFW/erotic prompt editing without sanitizing those details. |
| Image understanding and vision chat | Qwen3-VL-4B-Instruct Q4_K_M | `models/text/vision/qwen3vl-4b/Qwen3VL-4B-Instruct-Q4_K_M.gguf` | Hard link to the existing Krea/ComfyUI encoder file in `models/image/clip`; separate chat runtime on port 8081. |
| Vision projector for Qwen3-VL | Q8_0 mmproj | `models/text/vision/qwen3vl-4b/mmproj-Qwen3VL-4B-Instruct-Q8_0.gguf` | Downloaded from the official Qwen GGUF repository; size 453,974,304 bytes; SHA-256 `30ba2c7dd3127a4561b6cba9d13d0f711c91bdb38742e2f56d73c8cb596bd06d`. |

The Qwen3-VL model SHA-256 is `66358cb18bb6b3b1b6675aa412c7a88ef01d228f481184d13668e5201c730a0a`; this matches the official Qwen repository revision `1cd86afb9a95c410a6038ab3b40d8b578c892266`. The Qwen3-VL model and its matching projector are discovered by the existing local model inventory. The projector is in the same directory as the model, so `mmproj: "auto"` resolves it automatically. The Chat model picker labels models with a projector as `Vision`; image attachments in local chat therefore work when Qwen3-VL is loaded.

## Routing and GPU exclusivity

- `/api/image/prompt-optimize` uses Huihui Qwen3-4B-Instruct-2507 Abliterated as the local prompt specialist. The original Qwen3-4B file remains installed as a fallback/reference and is not overwritten. It runs the existing model-family prompt writer and independent quality-review pass.
- Local image understanding is performed by loading Qwen3-VL-4B with its mmproj in the ordinary text/chat runtime. The existing chat composer sends image attachments as `image_url` content.
- The models are not resident together. The prompt service uses the existing `prepareGpuForQwen()` exclusivity checks and frees ComfyUI model residency before loading. The normal text/vision runtime uses `loadText()`, which stops conflicting model runtimes. Unload the active text/vision model after use to return to the idle GPU baseline.
- Existing Qwen2.5-VL files remain installed as a fallback; no existing model was deleted or overwritten.

## Uncensored adult prompt editing

- Model: `Huihui_Qwen3-4B-Instruct-2507-Abliterated-Q4_K_M.gguf` (2,497,281,312 bytes).
- Source: `mradermacher/Huihui-Qwen3-4B-Instruct-2507-abliterated-GGUF`, Q4_K_M; Apache-2.0.
- SHA-256: `b1324e2f1bd2e0610d591f54f93e38d90b187f69d1f215f4cace349eade678d7`.
- The existing non-abliterated Qwen3-4B file remains untouched.
- Both prompt passes explicitly preserve consensual adult NSFW/erotic details; minors and non-consensual sexual content are excluded. The second pass is a semantic-quality check, not an adult-content moderation filter. If its candidate fails the semantic integrity check, the first-pass result is retained.
- Live PS5 test on 2026-11-06: a Dutch prompt for a nude 30-year-old adult woman was translated and expanded in English; adult age, nudity, visible breasts and erotic context were all preserved. The original Krea2 SickRealism runtime was restored afterwards. The quality-review candidate was rejected by the semantic guard, so the first-pass prompt was used.

## Verified on PS5 Linux

- llama.cpp build: `9ff0d7e90f0faaa7c16017e6dcf9cf91c50a100e` (2026-10-23), Vulkan device `Vulkan0`.
- Qwen3-4B prompt specialist: loaded with all 36 layers on Vulkan; the production prompt endpoint returned HTTP 200, completed both passes, and accepted the safety-checked review (`reviewed=true`, `reviewAccepted=true`). The Dutch term `kinderkopjes` was correctly rendered as `wet cobblestones`. Adult consensual NSFW/erotic details are explicitly preserved by both prompt passes; minors and non-consensual sexual content remain excluded.
- Qwen3-VL-4B: model and Q8_0 projector loaded together; actual image input was accepted and described through the OpenAI-compatible chat API. The normal `/api/runtime/text/load` and `/api/chat` paths were also tested with the image attached.
- Qwen3-VL loaded with 36 GPU layers at context 4096. After `/api/runtime/text/unload`, GPU usage returned to approximately 0.30 GiB used / 6.75 GiB free; ComfyUI stayed online and idle.
- Qwen3.5-4B was not selected for vision: although a community GGUF repository publishes a matching mmproj, the local llama.cpp Qwen3.5 implementation at this build is text-only. A successful model load alone would not prove image embeddings are consumed.

## User workflow

1. For Krea prompt optimization, use **Prompt verbeteren**. The app automatically uses Qwen3-4B-Instruct-2507 and then performs its safety-gated review pass.
2. For image understanding, open local Chat, choose `Qwen3VL-4B-Instruct-Q4_K_M.gguf · Vision`, leave the projector on **Automatisch**, load it, and attach an image.
3. When finished, unload the text/vision model before starting a different GPU-heavy model.
