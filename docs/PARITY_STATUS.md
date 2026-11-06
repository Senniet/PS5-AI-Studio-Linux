# Feature parity: Linux edition vs native PS5 app

Last updated: 2026-10-31

This is a functional parity tracker, not a claim that the two platforms share code. The Linux implementation is independent and uses Ubuntu, Node.js, llama.cpp, stable-diffusion.cpp and Vulkan/RADV. Ollama may remain installed on the host but is no longer an application dependency. Prospero-specific code stays in the native repository.

| Area | Linux status | Notes |
|---|---|---|
| Text chat | Implemented | Streaming through llama.cpp OpenAI-compatible API |
| Vision chat | Implemented in UI/API | Requires a vision model and matching mmproj |
| Text-file attachments | Implemented | Bounded text/JSON/CSV/code attachments |
| Conversation history | Implemented | Persistent, load, delete and Markdown export |
| Hugging Face GGUF search | Implemented | Search repositories and list compatible files |
| GGUF downloads | Implemented | Queue, pause/resume, duplicate-target protection, verified HTTP range-resume, atomic state persistence, size and SHA-256 validation |
| GGUF metadata | Implemented | Header-based architecture, parameter, layer, head and context data |
| KV-cache planning | Implemented | Context- and cache-type-aware estimate |
| GPU layer planning | Implemented | Auto estimate plus all/CPU-only/manual selection |
| mmproj pairing | Implemented | Automatic unique match and manual selection |
| llama.cpp runtime | Implemented; hardware validation pending | Local server auto-loads on first chat |
| Ollama model management | Removed in 0.5.17 | App no longer manages or calls Ollama; host installation and model files are untouched |
| Image checkpoint search | Implemented | Hugging Face image-asset categories |
| Image downloads | Implemented | Category-specific directories; shared queue with duplicate-target protection, verified range-resume, atomic state persistence and SHA-256 validation |
| Checkpoint/VAE/LoRA management | Implemented | Scan, select and delete |
| Text-to-image | Validated | SD1.5 512×512 generation on Vulkan; VAE also on Vulkan |
| Image-to-image | Validated | SD1.5 img2img with source image and denoising strength |
| Inpainting | Validated | SD1.5 masked img2img with uploaded mask; brush mask wired |
| Image progress and interrupt | Wired; hardware validation pending | SD API progress and interrupt endpoints |
| Image gallery | Implemented | Browse, reuse as source and delete; clear result preview independently; save complete image workflows and import/export workflow bundles |
| Visual workflow graph | Implemented in UI/API | Drag nodes, add/remove nodes, connect nodes, validate Prompt → Sampler → Output paths, apply connected nodes to Image Studio; graph layout persists in workflow presets and JSON bundles |
| ControlNet inference | CPU generation validated; Vulkan crashes on this PS5 | App forces CPU backend for conditioned sessions |
| IP-Adapter | CPU generation validated | SD1.5 classic adapter + FP16 CLIP Vision H installed; conditioned sessions use CPU fallback |
| Upscaling workflow | Validated | RealESRGAN_x4plus on Vulkan; gallery action, status and cancel |
| Hardware dashboard | Implemented | CPU, RAM/swap, GPU, GTT/TTM, temperature and disk |
| Runtime exclusivity | Implemented | GPU-heavy runtimes are stopped before switching |
| Settings and logs | Implemented | Persisted settings and service logs |
| Scratch files | Implemented | Bounded create/read/delete workspace |

## Linux 0.5.5 additions

- Image presets now persist the complete workflow configuration: checkpoint, VAE, multi-LoRA selection and weight, ControlNet, IP-Adapter, CLIP Vision, upscaler, tile/repeat settings, dimensions, sampler, scheduler and prompts.
- Workflow bundles can be exported to JSON and imported again on another Linux installation. Existing workflows can be updated in place instead of creating duplicates. Model paths are preserved as local references; the model files themselves are not copied into the workflow bundle.
- Workflow import is bounded to 2 MB and 100 entries per file; server-side preset limits and prompt validation remain in force.

## Linux 0.5.7 additions

- Added the visual Workflow Builder with editable Prompt, Negative Prompt, Checkpoint, LoRA, Sampler/settings and Output nodes. Nodes can be repositioned, added and removed; directed links can be created and deleted. Applying a graph validates that Prompt and Sampler are connected to Output before syncing node values to Image Studio controls.
- Saved workflow presets now retain the node graph and its positions/connections. Existing JSON workflow import/export carries the graph with the workflow; model weights remain separate local files.

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

- ControlNet model discovery, download category, runtime loading and reference-image/strength controls: end-to-end validated on CPU; ControlNet Vulkan crashes on this PS5; IP-Adapter Vulkan is not yet verified, so both conditioning workflows automatically use CPU.
- IP-Adapter + CLIP Vision discovery, download categories, paired runtime loading and reference-image/strength controls: end-to-end SD1.5 CPU generation validated with the classic adapter and FP16 CLIP Vision H. Conditioning sessions use CPU for compatibility.
- Multi-LoRA selection with shared multiplier: implemented.
- ESRGAN upscale job using sd-cli, with status, logs and cancellation: validated on Vulkan with RealESRGAN_x4plus.
- Generation prompt/settings sidecars and gallery prompt restoration: implemented.
- Combined checkpoint/conditioning memory planner, server-side load preflight and built-in/custom prompt presets: implemented.
- Batch generation (1–4 images) with batch-aware prompt presets and gallery metadata: implemented.
- SD 1.5 txt2img and img2img/inpainting: tested on PS5 Vulkan; 512×512 smoke generations completed and saved.
- Native asynchronous ControlNet/IP-Adapter job path, job progress, preview metadata and cancellation: implemented. ControlNet and IP-Adapter end-to-end generation passed on CPU individually and together; the IP-Adapter-only 512×512 one-step smoke job completed in 54.3 seconds and the combined conditioning job completed in 78.7 seconds. A ControlNet-conditioned Vulkan job crashes in the SD1.5 UNet path on this PS5; IP-Adapter Vulkan remains unverified, so both conditioning workflows currently use the CPU backend for reliability.
- Uploaded inpainting masks are normalized to grayscale and source dimensions before generation; optional mask inversion is available.
- Marketplace excludes `.pt` and `.pth` pickle-based image model downloads; `.onnx` support added to the download allow-list.


## Linux 0.5.9 additions

- Download queue writes are serialized and atomically renamed to prevent partially written queue state.
- Duplicate downloads targeting the same model-library file are rejected before a second writer can corrupt the partial file.
- HTTP range responses are checked against the requested resume offset and catalogued file size; incomplete files retain their partial data for retry.
- Removing an active download waits for the stream to close before deleting its partial file.
- Completed queue entries whose files have disappeared are surfaced as missing instead of falsely appearing completed; obsolete file types cannot be resumed.
- Queue statuses are localized and completed downloads trigger model-library refresh when the relevant view is open.

## Linux 0.5.8 additions

- Visual workflow graph now includes explicit Text-to-image, Image-to-image and Inpainting operation nodes.
- Inpainting workflows require both a source image and a mask; Image-to-image requires a source image and does not send a mask.
- Added an optional ESRGAN node. When enabled, each saved generation is passed sequentially through the existing local upscale runtime, and the final upscaled files are shown in the result panel.
- Workflow graph persistence and import/export retain the new operation and upscale node values.
- Generation metadata records the selected operation mode.


## Linux 0.5.10 additions

- Added a unified Image Studio asset inventory covering checkpoints, VAE, LoRA, CLIP/text encoders, ControlNet, upscalers, IP-Adapter and CLIP Vision. Active runtime assets are marked and cannot be deleted until the image runtime is unloaded.
- Workflow Builder now rejects cycles, duplicate critical nodes, disconnected prompt/sampler/output paths, and invalid mode/upscale ordering before applying a graph.
- Download queue removal now distinguishes a completed model deletion from removing an incomplete or missing queue item.


## Linux 0.5.11 additions

- Text runtime detects KV-cache block-size incompatibilities from GGUF attention head dimensions. Q4/Q8 cache requests automatically fall back to F16 only for incompatible K/V dimensions, without changing the saved global preference.
- Runtime errors now retain the last relevant process output lines and return actionable startup diagnostics instead of only `exit 1`.


## Linux 0.5.12 additions

- Failed text-runtime starts now clear the selected model from the active-runtime state instead of leaving a failed model looking loaded. Explicit unload also clears stale text runtime references.
- Runtime banners display localized state labels and the latest actionable startup error; the full error remains available as the detail tooltip.
- The text-model load notification reports when KV cache precision was automatically adjusted for compatibility.


## Linux 0.5.13 additions

- Missing queue entries now count as existing downloads for duplicate detection. Adding the same model again returns a clear conflict explaining that the old queue item must first be resumed or removed, rather than creating a second queue entry that shares the same target and partial-download file.
- Verified the local-network application shell and static assets, plus read-only API routes for health, diagnostics, runtimes, settings, text models, image models, presets, gallery, files, logs, and the download queue. Basic Auth was intentionally removed by the user and must not be reintroduced. Browser-driven navigation still needs a separate interactive pass.

## Linux 0.5.14 additions

- Added a unified overview task panel for model downloads, text/image runtimes, image-generation jobs and ESRGAN upscales, with live state, progress where available, errors and shortcuts to the relevant studio.
- Added a memory-pressure advisor showing available system RAM, GPU GTT usage and swap pressure, with normal/warning/critical states and reasons. Values are live snapshots, not guaranteed model-fit predictions.
- Expanded GGUF model planning with estimated KV-cache size, whether the estimate uses parsed GGUF metadata or fallback assumptions, and practical load advice.
- Runtime shutdown now waits for the child process close event, escalates from SIGTERM to SIGKILL, and refuses to report a clean stop if the process does not exit. Runtime output cleanup listens for close so final stderr/stdout lines are retained.
- Removed the now-unused Basic Auth verifier from the Linux server. Do not reintroduce Basic Auth; local-network access remains the user's explicit choice. The native PS5 project is separate and untouched.
- npm run check, git diff --check, and HTML ID-reference audit pass. Service restart and health check returned version 0.5.14; runtime, settings, models, image models, presets, gallery, files, logs, download queue and task API smoke checks returned HTTP 200. Interactive browser navigation was not verified.

## Linux 0.5.15 additions

- Removed the Visual Workflow Builder from the Image Studio UI and removed its script/style loading. The old graph implementation files are now inert placeholders; no node editor is shipped or loaded.
- Kept simple image-generation presets (load/save/delete), without graph/node data or workflow import/export controls.
- Reorganized Image Studio around the generation task: prompt and negative prompt first, source-image upload and preview directly below, inpainting mask/editor next, then core generation settings and the Generate/Stop/Clear actions.
- Moved checkpoint selection/loading into a separate model panel; model inventory is collapsed by default. Hugging Face image-model search is also collapsed by default.
- Moved VAE, LoRA, ControlNet, IP-Adapter and ESRGAN controls into a collapsed advanced-settings section. The result/gallery panel remains alongside the generation form on wide screens and stacks on mobile.
- Source-image selection now displays the selected filename. Generation mode is inferred directly from the presence of a source image and mask; automatic workflow/upscale chaining has been removed. Manual gallery upscaling remains available.


## 0.5.16 — Chat reasoning controls
- Added Thinking on/off and reasoning effort (low / medium / high) directly below the chat composer.
- Preferences auto-save through the existing settings API and persist in the Linux settings file across service restarts.
- Models and chat templates that do not implement thinking/reasoning controls may ignore unsupported options.


## 0.5.17 — llama.cpp als enige chatbackend
- De Linux-app gebruikt nu uitsluitend llama.cpp voor tekst- en visionchat via de OpenAI-compatible API. Backendkeuze en Ollama-modelbeheer zijn uit de interface en server-API verwijderd.
- Bestaande instellingen met een oude `backend`-waarde worden bij het starten genegeerd; alle overige instellingen, GGUF-bestanden en modellen blijven behouden.
- Thinking en reasoning blijven instelbaar en persistent.
- De Ollama-installatie, systemd-service en eventuele Ollama-modellen op Ubuntu zijn bewust niet verwijderd of aangepast; deze wijziging ontkoppelt alleen de app.


## 0.5.18 — gecombineerde modellenbibliotheek en modelwinkel
- Tekst-GGUF-modellen en alle lokale beeldassets staan nu samen op de pagina Modellenbibliotheek. De beeldassetinventaris is uit Image Studio gehaald; Image Studio houdt alleen de selectie van het checkpoint dat voor genereren wordt gebruikt.
- De Modelwinkel gebruikt één zoekformulier en één resultaten-/bestandenweergave voor zowel tekstmodellen als beeldmodellen. Bij beeldmodellen kies je binnen dezelfde winkel de assetcategorie (checkpoint, VAE, LoRA, encoder, ControlNet, upscaler, IP-Adapter of CLIP Vision).
- De downloadwachtrij blijft gedeeld en behoudt categorie, voortgang, hervatten en verwijderen.


## 0.5.19 — beeldmodellen laden vanuit de bibliotheek
- Het checkpoint-laadpaneel is verplaatst van Image Studio naar de gecombineerde Modellenbibliotheek. De gebruiker kan daar een checkpoint selecteren, de geheugeninschatting bekijken en de image runtime starten.
- Elke checkpointregel in de inventaris heeft nu ook een directe knop Laden; selecteren en laden gebruiken dezelfde runtime-API en preflight.
- Image Studio toont de actieve image runtime en houdt de generatie-/bewerkingsinterface, maar bevat geen aparte checkpoint-laadbediening meer.


## 0.5.20 — lege bronafbeelding-preview verborgen houden
- CSS-regels voor flex-layout overschreven de standaardweergave van het HTML-attribuut `hidden`, waardoor de lege bronafbeelding-preview zichtbaar kon zijn met een kapotte afbeelding en de tekst “Bronafbeelding geladen”.
- `hidden` wordt nu globaal gerespecteerd met `display:none!important`; een niet-geselecteerde bronafbeelding blijft verborgen totdat een afbeelding succesvol is ingeladen.


## 0.5.21 — ChatGPT-geïnspireerde chatinterface
- AI Chat opnieuw opgebouwd met een rustige, gecentreerde conversatieweergave, assistent-/gebruikersrijen, compacte model-/gespreksbalk en een afgeronde invoercomposer.
- Thinking en Reasoning blijven direct bij het invoerveld staan en hun instellingen blijven automatisch opgeslagen.
- Contextgrootte wordt getoond in de chatbalk. De runtime rapporteert de werkelijk geladen context; zonder actieve runtime wordt de ingestelde context voor de volgende modelsessie getoond.
- De laadcontext wordt als runtime-metadata bijgehouden en via `/api/runtime` beschikbaar gemaakt; geen wijziging aan de chatprompt- of modelinference-instellingen.


## 0.5.22 — Modelkeuze uit chatbalk verwijderd
- De zichtbare modelselector is uit AI Chat gehaald. Modellen blijven uitsluitend via de Modellenbibliotheek te laden en te beheren.
- De chat behoudt de contextgrootte prominent in de bovenbalk. De interne modelreferentie blijft verborgen aanwezig voor de bestaande chatrequest-flow.

## Linux 0.6.0 — Native Video Studio and model-library expansion

- Added a separate native PS5 AI Video Engine backed by the installed stable-diffusion.cpp Vulkan build, listening only on 127.0.0.1:1235.
- Added a dedicated video-model library for diffusion weights, text encoders, VAE, LoRA, CLIP Vision and interpolation assets, including streamed uploads, inventory, deletion and profile downloads.
- Added Wan 2.1 T2V 1.3B Q4 as the first native profile. The complete model stack is checked against the current shared GTT pool before download/load; Wan 2.2 TI2V 5B is not considered loadable on the current measured PS5 GPU memory budget.
- Added mutually exclusive text/image/video runtime management, native asynchronous video jobs, progress polling, cancellation, WebM output and a local video library. Native T2V targets from 1–60 seconds are divided into segments of at most 81 frames and concatenated with GStreamer.
- Validated a real 1-second, 9-frame, 2-step Wan 2.1 generation on Vulkan0 and separately validated VP9/WebM concatenation. A full multi-segment model generation and cross-segment visual continuity remain unverified.
- Kept ComfyUI as an optional API-workflow backend. Its active gfx1013 ROCm/HIP build has validated Krea 2 image generation; native video continues to use the separate Vulkan engine.
- Corrected documentation to reflect that Basic Auth was explicitly removed and must not be described as enabled. Host/Origin checks and CSP remain, but the UI is unauthenticated and should stay on a trusted LAN.
- Validation: npm run check passes; /api/health and /api/video/native/status respond successfully; the native Wan 2.1 model loads on Vulkan0.