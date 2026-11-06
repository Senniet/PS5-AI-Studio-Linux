## 2026-11-06 — exclusief modelbeheer tussen ComfyUI en llama.cpp

- Centrale modelwissel toegevoegd aan de servermodelmanager. Er wordt nooit bewust een tweede zware runtime naast de eerste gestart.
- Bij het laden van een tekstmodel controleert AI Studio de ComfyUI-queue. Zowel actieve als ingeplande workflows moeten volledig klaar zijn; de manager wacht maximaal 60 minuten en onderbreekt geen generatie.
- Na een lege queue vraagt AI Studio ComfyUI om modelgewichten/GPU-resources vrij te geven en stopt daarna de volledige `ps5-ai-studio-comfyui.service`, zodat ook het Python-proces en host-RAM vrijkomen.
- Veiligheidscontrole: als het ComfyUI-proces nog bestaat maar de API niet bereikbaar is, wordt de modelwissel afgebroken. Een onbetrouwbare queue-status leidt dus nooit tot het starten van llama.cpp.
- Terugschakelen naar Krea 2 start ComfyUI pas nadat het tekstmodel is gestopt. Native beeldmodellen stoppen eerst ComfyUI na een veilige queuecontrole. ComfyUI-gebaseerde video- en Krea-generatie controleren de modelwisselstatus en starten ComfyUI indien nodig.
- De takenlijst toont de fases van de modelwissel in het Nederlands.
- Praktijktest: Qwen3.5-9B is via `/api/runtime/text/load` opnieuw geladen; llama.cpp health is `ok`, 29 GPU-lagen actief. ComfyUI-service is `inactive` en er draait geen `ComfyUI/main.py`-proces. Geen actieve of ingeplande ComfyUI-jobs tijdens de test.
- Geheugen na de wissel: Termalin rapporteerde circa 1,83 GB gebruikt RAM en 0,84 GB swap; vóór de wissel was dat circa 10,0 GB RAM en 1,87 GB swap. Geen nieuwe OOM-kills.
- Validatie: `npm run check` en `git diff --check` geslaagd. Backup van de serverbron vóór de wijzigingen: `apps/server/server.mjs.pre-exclusive-model-switch-20261106`.
- Huidige toestand: tekstmodel Qwen3.5-9B actief; ComfyUI bewust gestopt totdat weer een ComfyUI-beeldworkflow wordt aangevraagd.


## 2026-11-06 — Qwen3.5 hybride geheugenberekening en gecontroleerde 31-laags test

- GGUF-tensorinventaris toegevoegd via `apps/server/gguf_tensor_stats.py`; voor Qwen3.5 worden de echte tensorbytes per `blk.N` gelezen, in plaats van bestandsgrootte / blokcount.
- De Defiant Qwen3.5-9B GGUF bevat 442 tensors, 33 metadata-blokken waarvan 1 MTP-blok door llama.cpp wordt genegeerd: 32 actieve transformerblokken. De actieve architectuur gebruikt 8 full-attention- en 24 recurrente blokken (interval 4).
- Bij context 4096 en Q8_0: KV-cache 68,0 MiB; recurrente state 50,2 MiB; samen circa 118,2 MiB. Werkelijke actieve blokgewichten lopen uiteen van 112,5 tot 137,9 MiB. De aparte `output.weight` is 1.940 MiB en wordt meegenomen in de GPU-budgettering.
- Automatische Qwen3.5-offload berekent nu per kandidaat het werkelijke gewicht van de GPU-blokken, outputlaag, alleen de GPU-residente full-attention-KV-cache en recurrente state. De schatting reserveert daarnaast 900 MiB voor gemeten Vulkan/runtime-overhead en 700 MiB vrije GPU-headroom. De modelbibliotheek toont nu ook de hybride cacheverdeling en het blokgewichtbereik.
- Gecontroleerde test met `n_gpu_layers=31` (29/32 actieve transformerblokken plus outputlaag) initialiseert en verwerkt een korte generation smoke test (96 tokens; tokenlimiet bereikt tijdens reasoning) zonder Vulkan-device-loss of OOM. Na de test bleef echter slechts circa 638 MiB GTT vrij, onder de ingestelde veiligheidsmarge van 700 MiB. Daarom is deze instelling niet als veilig geaccepteerd.
- Automatische terugval uitgevoerd: `n_gpu_layers=30` (28/32 actieve transformerblokken plus outputlaag; 4 actieve blokken op CPU; MTP genegeerd). De eindtest leverde een volledig Nederlands antwoord; llama health bleef `ok`, circa 876 MiB GTT bleef vrij. Dit is de actieve instelling.
- ComfyUI was tijdens de hele test gestopt; er is geen ComfyUI-proces of generatie onderbroken.
- Validatie: `npm run check`, `git diff --check`, GGUF-loadability (12 assertions), GGUF-validation-cache (7), runtime-selection en safe-file-ops (7) geslaagd. Back-ups: `server.mjs.pre-qwen35-hybrid-memory-20261106T175015Z` en `app.js.pre-qwen35-hybrid-memory-20261106T175015Z`.

---

# PS5 AI Studio progress

## 2026-11-05 — hardware audit, first image and text baselines, LoRA validation

- Confirmed Termalin connection to `ps5-linux` is online with full policy.
- Captured live hardware/runtime state in `HARDWARE-BASELINE.md`.
- Confirmed user systemd services for web UI and ComfyUI are enabled and active.
- Read-only health checks passed: Studio `/api/health`; ComfyUI `/queue` and `/system_stats`.
- Inventory confirmed the dynamic Krea2 Safetensors scan and strength validation existed in the current working tree.
- Added bounded Safetensors header, tensor shape/offset and non-overlap checks plus paired LoRA/LoKr structure validation in the Krea2 candidate filter. See `OPTIMIZATION-LOG.md`.
- Preserved a backup of the pre-existing modified backend before this change. Other pre-existing modified/untracked source files were left untouched.
- Ran three fixed-prompt/seed 384×384 image samples through Studio API. Q3 8-step/no-LoRA: 60.30 s API wall (59.10 s ComfyUI); Q3 4-step Turbo adapter: 34.21 s API wall (32.71 s ComfyUI); SickRealism 8-step/no-LoRA: 112.38 s ComfyUI execution and saved output. Details/memory samples are in `BENCHMARKS.md`.
- Termalin timed out while waiting for the SickRealism API job response, so its API wall time was not claimed. Follow-up verified both services active, Studio health OK, queue empty, and output plus metadata saved.
- Ran a SickRealism 3-step Turbo + HMNSFW AIO 0.8 chain test; 36.30 s API wall and 35.21 s ComfyUI execution, output and metadata saved.
- Ran three CPU-only Text Studio chats with Qwen2.5-VL 3B Q4_K_M, 2048 context, six threads, zero GPU layers. With `mmproj=none`: first text 0.214 s, 221.81 prompt tok/s, 21.51 output tok/s. With projector: first text 35.712–42.778 s, 1.05–1.26 prompt tok/s, about 21.2 output tok/s; RAM available after load was about 1.4 GiB lower. These are small samples with different cache conditions; details are in `BENCHMARKS.md`.
- Unloaded llama.cpp and restored SickRealism as the selected Image Studio model. Both services remained active; ComfyUI queue empty.
- Text UI source already exposes a `Geen mmproj` option, so no text UI code change was needed.
- Network review: Studio API binds all interfaces; Host/Origin checks exist but no authentication was found in inspected routes. Ollama also listens on all interfaces and `/api/tags` is unauthenticated. Firewall tools `ufw` and `nft` are absent, so external reachability is unknown. Recorded in `KNOWN-ISSUES.md`; made no network changes because intended LAN access was unclear.
- No kernel, Mesa, ROCm, PyTorch, boot, or firmware changes were made.

## Next actions

1. Confirm intended network access and router/firewall boundary before changing listeners; do not change bind addresses until the intended access scope is clear.
2. Repeat the Text Studio projector modes at least three times with controlled cache conditions, then benchmark an installed text-only GGUF if its memory budget is safe.
3. Compare a compatible GPU-offload setting only after a safe memory plan.
4. Capture settled memory/swap values and investigate retained swap.
5. Continue the API/download/file-validation and frontend error-handling audit before selecting the next implementation change.
6. Evaluate image quality separately. The fixed-prompt Q3 repeat sample and one isolated HMNSFW adapter validation are complete; details and cold-start caveats are in `BENCHMARKS.md`.


## 2026-11-05 — unique-seed image repeats and memory-guard recovery

- Repeated Q3 8-step/no-LoRA and Q3 4-step/Turbo-LoRA at 384×384 using unique seeds 20261106–20261108 and the same fixed prompt. Three completed, saved runs per profile are recorded in `BENCHMARKS.md`.
- Identical prompt/seed repeats had returned in ~2.2 s from ComfyUI graph cache; excluded those cache hits and used unique seeds for valid repeats.
- The memory guard stopped the first batch before a low-memory run. During the resumed batch, two requests triggered the existing guarded ComfyUI restart at free GTT below 1.8 GiB; both completed after restart. API and ComfyUI services are active, health is OK, and queue is empty.
- Current medians are 40.25 s (Q3 8-step) and 26.24 s (Q3 4-step Turbo LoRA), based on three unique-seed samples each. Restart/cold runs are explicitly marked; this remains a small descriptive sample.



## 2026-11-05 — isolated SickRealism custom-adapter run

- Ran SickRealism at 256×256 and 3 steps with `Krea2_HMNSFW_AIO.safetensors` at 0.8 and no Turbo LoRA. Seed 20261109; output `1793837137707-krea2-9985e5b2.png` (107,115 bytes).
- The pre-run graphics pool was below the SickRealism memory guard. API-triggered ComfyUI restart changed PID 14829 → 15805; the request completed in 87.09 s including recovery. Queue was empty afterward.
- This validates the custom adapter separately from Turbo. It is one sample and includes cold-start overhead; no performance or quality improvement is claimed. Details are in `BENCHMARKS.md`.
- Current state: Studio and ComfyUI active; health check OK; queue empty.



## 2026-11-05 — Text Studio projector repeat check

- Rechecked Studio API health, Text/Image/Video runtimes stopped, ComfyUI queue empty, ~12.6 GiB RAM available, swap unused, and ~7.05 GiB GTT free before testing.
- Ran Qwen2.5-VL 3B Q4_K_M through the Studio API at context 2048, six CPU threads, zero GPU layers, q8_0 K/V cache, with projector `none` twice and the explicit f16 projector once. All requests completed; API chat wall times were 3.19 s, 3.98 s, and 5.57 s.
- llama.cpp logged first-prompt evaluation at 198.02 tok/s without projector and 214.42 tok/s with projector; output evaluation was ~21.3 tok/s. The second no-projector request was a prefix-cache hit (only one prompt token reevaluated) and is not an independent prefill sample.
- Peak observed host `MemAvailable` fell from ~12.59 GiB baseline to ~10.69 GiB without projector and ~9.31 GiB with it; swap remained unused.
- Unloaded the text runtime. Studio health remained OK; ComfyUI queue remains empty.
- Compared with earlier documented projector trials (1.05–1.26 prompt tok/s, 35–43 s first-text latency), current results differ dramatically; no speed conclusion is drawn. Next benchmark needs cache-disabled/unique prompts and log-correlated timing to investigate this discrepancy.


## 2026-11-05 — cache-disabled Text Studio comparison

- Investigated the earlier projector prefill outlier using local llama.cpp help and confirmed `--no-cache-prompt` is supported by installed llama-server 0.7.0-dev build 11845.
- Ran three 50-token equivalent prompt variants per profile directly through llama-server on loopback, prompt cache disabled: Qwen2.5-VL 3B Q4_K_M, context 2048, six threads, zero GPU layers, q8_0 K/V cache, thinking disabled. Projector was absent or the explicit f16 companion file.
- Median prompt evaluation: 215.72 tok/s without projector, 260.04 tok/s with projector (ranges overlap). Output evaluation median: 21.45 vs 21.42 tok/s. Median chat wall: 5.18 vs 5.56 s; token output lengths varied. Projector load reduced available memory by another ~1.31 GiB; swap stayed unused.
- Previous 35–43 s prefill did not reproduce. Cause remains unknown; no causal speed claim or code/config change. Full sample table is in `BENCHMARKS.md`.
- Terminated the temporary loopback inference processes. Studio API health OK, both services active, ComfyUI queue empty, all Studio runtimes stopped.


## 2026-11-05 — session reconstruction and text-only inference preflight

- Read `/home/michel/AGENTS.md`; `/home/michel/.codex/AGENTS.md` and the central `/home/michel/SESSION.md` were absent. Created the central handoff; project `SESSION.md` remains alongside it. Reconstructed prior work from project docs, Git state, build artifacts, output images and service/runtime logs.
- A Qwen3.8-27B draft Q8 CPU-only llama-server load failed before readiness. Kernel journal identifies `llama-server` SIGSEGV in `libggml-base.so.0.27.0` at address 0x10. No core dump is available (`ulimit -c` 0; `coredumpctl` absent). Project services and ComfyUI remained healthy.
- Qwen3.5 9B Q4 remained untested: conservative 2048-context projection does not preserve a full 4 GiB host reserve; therefore not loaded.
- Found installed Ollama `qwen2.5-coder:7b` and ran one bounded CPU-only request (`num_gpu=0`, ctx 2048, 64-token cap, keep_alive 0). It completed: 15.97 s load, 12.15 output tok/s, 21.83 s total wall. MemAvailable minimum 8.04 GiB from 12.56 GiB; swap unused. Ollama unloaded the model.
- Studio health OK, ComfyUI queue empty, both services active. Results and limits in `BENCHMARKS.md`.

- Additional read-only GGUF investigation: `gguf_dump.py` found only 18 tensors in Qwen3.8 draft file, all tied to `blk.64` plus token/output embeddings; metadata has `size_label=3.0B` and `nextn_predict_layers=1`. Local llama.cpp source treats MTP as an extra decoder block. Likely this is a draft-head fragment rather than a standalone base model; this likely explains the load failure but remains an inference. Recorded in `KNOWN-ISSUES.md`.
- Ollama qwen2.5-coder:7b CPU-only smoke succeeded at 12.15 tok/s after 15.97 s cold load; Ollama unloaded it. This is outside Studio Text UI; no integration claim.
- Audited Studio `/api/chat`: it only selects local GGUFs for llama.cpp and frontend shows HTTP/stream errors. Ollama is explicitly outside the app in README. No code defect was confirmed, so no untested provider integration was introduced.

## 2026-11-05 — block incomplete draft GGUF from standalone text loading

- Added apps/server/gguf-loadability.mjs: reads the GGUF tensor count from the fixed header and conservatively flags a file when it has fewer than two tensors per declared transformer block. Unknown header/layer metadata remains allowed to avoid false rejection from incomplete metadata.
- /api/models now exposes tensor count and loadability. The model library keeps a flagged file visible for diagnosis/deletion, labels it, disables its Load button, and omits it from chat/quick-load selectors. /api/runtime/text/load independently returns HTTP 422 before stopping runtimes or starting llama-server.
- The previously crashing Qwen3.8-27B-Uncensored-draft-Q8_0.gguf reports 18 tensors / 65 blocks and is blocked. The Qwen2.5-VL 3B full model reports 434 / 36 and remains loadable. Other catalog entries were checked and remain allowed (including models whose layer metadata is absent).
- Added scripts/test-gguf-loadability.mjs: 9 fixture assertions cover header parsing, malformed/truncated input, unknown metadata, incomplete and boundary cases.
- Verification passed: fixture assertions; npm run check; helper syntax check; git diff --check; live catalog classification; direct load-route rejection with 422 before spawn. Studio API health OK, both user services active, ComfyUI queue empty, runtimes stopped.
- Backups preserving the pre-existing dirty versions: apps/server/server.mjs.pre-gguf-loadability-20261105-110109 and apps/web/app.js.pre-gguf-loadability-20261105-110109.
- Heuristic limitation: this is an early lower-bound check, not full tensor-name/shape completeness validation; it does not certify that an allowed model is valid or compatible. No model was loaded during this verification.

### Next
Continue the application reliability audit at download/upload/file validation and frontend error recovery. Use the historical findings in KNOWN-ISSUES.md; only implement a small fix if there is a reproducible defect, then run focused checks and update the central/project handoff.

## 2026-11-05 — close download resume and Civitai URL validation gaps

- The reliability audit found that queue creation allowed .pt/.pth files, but server resume validation and the web queue hid the Resume action for those same files. Added shared extension validation; add and resume now agree, and the UI offers resume for those supported files.
- The generic download API previously trusted a caller-provided URL whenever source began with civitai. This allowed the Studio host to fetch an arbitrary address. Civitai sources are now limited to exactly civitai/civitai-red, require a positive safe-integer model version ID, and reconstruct URLs only on the respective official domain. Persisted/legacy entries are canonicalized before fetching too.
- Added fixture assertions covering extension policy, resume formats, canonical Civitai domains, query parameters and invalid source/version IDs.
- Live check: arbitrary localhost Civitai URL without a version ID receives HTTP 400; no queue entry was created and no fetch was initiated. Existing queue remained unchanged.
- Verification: download fixture (13 assertions), GGUF fixture (9 assertions), npm run check, node syntax checks and git diff --check passed. Studio and ComfyUI active; Studio health OK; ComfyUI queue empty.
- Backup of server.mjs before this change: apps/server/server.mjs.pre-civitai-url-guard-20261105-110810. Earlier resume-only backup: apps/server/server.mjs.pre-download-resume-ext-20261105-110627.
- Remaining: review upload validation and frontend queue error recovery. The listener/firewall exposure is still unknown and unchanged.

## 2026-11-05 — validate uploaded GGUF header and expose queue failures

- GGUF uploads now capture only the first 24 bytes while streaming and reject files with invalid magic/version/tensor/metadata counts before renaming into the model library. Invalid uploads delete the temporary .uploading file.
- The catalog and text-load route independently check the fixed header; malformed GGUF files are marked non-loadable and blocked before inference startup. This remains a fixed-header check, not full tensor-directory integrity validation.
- Frontend queue refresh failures now replace stale content with a visible error and a prompt to retry via the existing Refresh button.
- Live upload test sent 24 zero bytes named as a .gguf: HTTP 400; neither final nor partial file remained. All 7 current catalog GGUF headers passed; the known 18/65 draft remained blocked.
- Verification passed: 13 download fixtures, 12 GGUF fixtures, npm run check, helper/server syntax checks, git diff --check. Studio and ComfyUI active; health OK; queue empty; runtimes stopped.
- Backup before these edits: apps/server/server.mjs.pre-gguf-upload-header-20261105-111044.
- Next: investigate whether a full tensor-directory completeness check is practical in the existing parser, then add browser-level/error-path coverage if available. Do not change the network boundary.

## 2026-11-05 — full GGUF tensor-directory validation at upload and load

- Reused the installed gguf Python reader via apps/server/validate_gguf.py. It parses the complete GGUF metadata and tensor directory, checks declared/parsed tensor counts, names and positive dimensions (reader checks duplicate names/types), validates tensor-data alignment and file bounds, and rejects overlapping tensor ranges.
- GGUF upload now runs the structural validator on the completed .uploading file before the final rename. Text-model load runs it before stopping any runtime or starting llama-server. Header validation remains the fast catalog screen; the draft/MTP count heuristic still rejects the known 18/65 fragment.
- Ran the structural validator read-only on all 11 GGUF files under the model directory. All declared tensor counts matched and all ranges fit within each file.
- Python fixture tests passed for valid two-tensor GGUF, a truncated final tensor payload, and overlapping tensor offsets (3 tests). Live upload accepted a valid synthetic file and it was deleted through the app; the truncated variant received HTTP 422 and left no final/partial file. Direct draft load also returned 422 without starting inference.
- One initial live fixture uncovered a redundant file-handle close after validation; fixed it immediately. The repeated valid/truncated upload integration then passed.
- Existing test suites/checks also pass: 13 download fixtures; 12 GGUF header/classification fixtures; npm run check; git diff --check. Studio health OK, Studio/ComfyUI active, ComfyUI queue empty, runtimes stopped.
- Runtime dependency: structural checks use gguf from runtimes/comfy-rocm-venv/bin/python; this is verified on ps5-linux. A moved checkout must retain that runtime or configure an equivalent before structural load/upload checks work.
- Limits: structure validation does not prove model architecture compatibility or expected parameter completeness. It correctly accepts the structurally valid MTP file; the separate conservative layer/tensor heuristic blocks it as a standalone text model. Browser automation for the queue-error UI has not been run.

### Next
Continue the original PS5 AI Studio audit with frontend recovery verification and the next safe, measured optimization. Keep network exposure unchanged; preserve all pre-existing worktree modifications.

## 2026-11-05 — handoff status after reliability continuation

- Core code and live API verifications are complete as documented above.
- Browser-level queue-error verification was attempted, but the Computer Use helper returned “Computer Use app approval timed out” before a screenshot was provided. No form was submitted and no browser data was changed. The UI code change remains syntax-checked only.
- Continue with browser UI verification if a working harness is available; otherwise continue the measured PS5 performance/reliability audit without changing the network boundary.

## 2026-11-05 — cache successful GGUF structure scans by file identity

- Read-only timing of the complete validator on 11 files: small/tiny models 0.03–0.05 s; main text models about 5.56–9.26 s each. The MTP draft file also takes about 9 s to structurally verify because it is internally well-formed.
- Added an in-process LRU cache (256 entries) and concurrent request coalescing. Successful scans are keyed by device, inode, size, mtime-ns and ctime-ns; the fingerprint is checked again after parsing. Failures are never cached. Upload validation benefits again at later load because atomic rename preserves file identity.
- Live API measurement after service restart: first draft check (full structure scan, then expected HTTP 422) 9.396 s; repeat on unchanged file 0.022 s, about 99.8% lower latency. No inference process started.
- Added 7 cache fixture assertions (concurrent coalescing, repeat hit, failure retry, bounded LRU). All cache, download, GGUF and tensor-structure fixtures pass; npm run check, syntax and diff checks pass. Studio/ComfyUI active, health OK, queue empty.
- Cache is process-local and intentionally invalidated on service restart; first access to an existing large model pays the full scan. Upload-installed models are scanned before installation and reused without another scan in the same process.

## 2026-11-05 — model catalog latency check

- Timed six local /api/models?context=2048 requests with seven files. 7,084-byte response each; wall times 0.0847, 0.0404, 0.0276, 0.0280, 0.0274, 0.0277 s; median 0.02785 s.
- No catalog performance defect was demonstrated, so no code change was made. Full measurement and GGUF scan/cache timings are in BENCHMARKS.md.
- Continue the audit on the next concrete issue; avoid speculative optimization.

## 2026-11-05 — cover remaining GGUF ingress/load paths

- GGUF downloads now run the complete tensor-directory validator on the finished .part file before atomic installation. On structural failure the invalid part is removed and the queue records an error instead of marking it done.
- Image Studio GGUF loads and direct Krea 2 GGUF requests now call the same validator before contacting/stopping runtimes or submitting ComfyUI workflows. The validator cache makes unchanged files cheap after their first check.
- This closes the audited GGUF paths: upload, download, text load, image load and direct Krea 2 API. No external download or ComfyUI generation was started for testing.
- Verification: 7 cache, 13 download and 12 GGUF classification assertions; 3 structure fixtures; npm run check; git diff --check. Studio health OK; both services active; queue empty; runtimes stopped.
- Backup before the direct image/Krea guard: apps/server/server.mjs.pre-image-gguf-structure-guard-20261105-114006. Download guard backup: apps/server/server.mjs.pre-gguf-download-validation-20261105-113833.

## 2026-11-05 — sampled local read endpoints

- Five reads each: /api/diagnostics median 9.7 ms (8.5–37.1 ms); /api/market/queue 2.2 ms; /api/image/models 48.4 ms (46.3–75.7 ms); /api/tasks 0.8 ms.
- No material API latency issue was indicated by these small local samples. No speculative optimization was applied. Full numbers are added to BENCHMARKS.md.

## 2026-11-05 — bound native video model uploads

- Found that `/api/video/native/models/upload` enforced its 80 GiB maximum only from `Content-Length`; a chunked request could omit that header and stream without an actual byte cap.
- Added `apps/server/upload-stream-guard.mjs` and connected it to the route. The stream now aborts above 80 GiB, removes the incomplete target through the existing error path, and rejects a received-byte count that differs from a declared length.
- Added `scripts/test-upload-stream-guard.mjs`: 3 assertions cover exact-limit acceptance, over-limit HTTP 413 semantics, and invalid limit rejection. All GGUF/download fixtures, Python structural fixtures, `npm run check`, and `git diff --check` pass.
- Live smoke test on the normal Studio user service: 1 KiB chunked upload returned HTTP 201; DELETE returned 200 and the temporary file was confirmed absent. `systemctl --user` service is active and `/api/health` reports version 0.6.0. A backup checkpoint is `apps/server/server.mjs.pre-video-upload-stream-limit-20261105-120500`.
- Initial observation corrected below: the Studio API had one pre-existing failed Civitai download; ComfyUI uses a different user-unit name.

Next: continue the reliability audit, starting with the inactive ComfyUI service and the existing market-download 401 without removing or retrying user queue data.

## 2026-11-05 — clarify download authorization failures

- Inspected the existing failed queue item read-only: source `civitai-red`, HTTP 401, 0 of 590,058,832 bytes received. The sanitized settings API reports that no Civitai API key is configured. The item remains untouched and was not retried; configure an authorized key in Studio settings if this download is intended.
- Fixed the HTTP error wording to say “downloaden” for a fresh request and “hervatten” only when resuming from a nonzero offset; 401/403 now include a generic API-key/access hint. `scripts/test-download-validation.mjs` now has 16 assertions and passes. App syntax and diff checks pass; Studio user service restarted and health is OK.
- Correction to the service observation above: ComfyUI is active under the user unit `ps5-ai-studio-comfyui.service`; its `/system_stats` endpoint is reachable. The earlier inactive result queried the wrong unit name.

Next: continue the audit without retrying the credential-gated download or changing credentials. Preserve the queue and installed files.

## 2026-11-05 — enforce streamed limits on both video model upload routes

- Extended the shared upload-byte guard to `/api/video/models/upload` (40 GiB maximum), alongside `/api/video/native/models/upload` (80 GiB). Both now count streamed bytes and reject a declared-length mismatch; the existing 100 GiB text/image model upload already counts actual bytes.
- Live chunked upload to the ComfyUI video route returned HTTP 201 for 1 KiB; the exact temporary file was verified and removed. Native video chunked upload also returned 201 and was deleted through its API.
- Verification passed after the change: upload stream guard 3 assertions; download validation 16; GGUF cache 7; GGUF loadability 12; Python structure fixture 3; `npm run check`; `git diff --check`. Studio and ComfyUI user-services active; Studio health OK.
- Backups: `apps/server/server.mjs.pre-video-upload-stream-limit-20261105-120500` and `apps/server/server.mjs.pre-comfy-video-upload-stream-limit-20261105-122000`.

Next: continue reviewing remaining upload and file-write routes for actual-byte limits, path containment, and safe cleanup. Preserve the user queue and all model data.

## 2026-11-05 — listener exposure confirmed, firewall unknown

Read-only audit confirms Studio listens on `0.0.0.0:8787`. The server rejects mismatched browser Origin headers, but has no application authentication and accepts requests without an Origin header; Origin validation is not authentication. `ufw`, `nft`, and `iptables` are unavailable to this session, so host firewall policy could not be verified. No listener or firewall settings were changed, per the existing network-boundary constraint. This remains an explicit security decision before exposing the host to untrusted networks.

Next: continue read-only audit of the remaining server upload, queue, and runtime paths. Keep network exposure unchanged; do not retry the credential-gated Civitai item.

## 2026-11-05 — video API timing check

Five local requests each: `/api/video/native/models` median 2.5 ms (2.1–13.3 ms), 2,324-byte response; `/api/video/status` median 80.8 ms (76.8–110.0 ms), 218 bytes. No material bottleneck appeared, so no code change. Full samples are in `BENCHMARKS.md`.

## 2026-11-05 — bound external model download streams

- External downloads previously compared the final file size only after the response body had been fully written. Added per-chunk byte accounting: known-size items cannot exceed their expected size; unknown-size items are capped at 80 GiB for video categories and 100 GiB otherwise. The cap is additionally limited by bytes currently free plus the existing partial-file size.
- A chunk that crosses the cap is rejected before it is written and its partial file is removed. Downloads whose known size exceeds current available capacity fail before making the upstream request. Existing resumable partials remain in place for other errors.
- Added tests for exact cap, over-limit and safe-integer overflow; download validation fixture now has 19 assertions. All GGUF/download/upload fixtures, Python structure tests, `npm run check`, and `git diff --check` pass. Both Studio/ComfyUI user-services active and health OK. No external download was initiated.
- Backup: `apps/server/server.mjs.pre-download-byte-bound-20261105-123000`.

Next: keep auditing server input and persistence paths; retain the existing failed Civitai queue entry and do not retry it without credentials.

## 2026-11-05 — block scratch symlink reads and writes

- Confirmed that `/api/files` followed a pre-existing symlink and could overwrite a file outside the scratch directory. The canary test demonstrated this before the fix; the temporary canary and link were removed afterward.
- Added `openRegularFileNoFollow` and used it for scratch reads and writes. Symlinks and non-regular files now return HTTP 403. Normal API create/read/delete still returns 201/200/200. Regression smoke tests returned 403 for both symlink POST and GET, with the outside canary unchanged.
- Added `scripts/test-safe-file-ops.mjs` (4 assertions). All upload/download/GGUF fixtures, Python structure tests, syntax checks, and `git diff --check` pass. Studio health OK and user-service active.
- Backup: `apps/server/server.mjs.pre-scratch-symlink-guard-20261105-124000`.

Next: continue applying the filesystem audit to other routes that read or write user-controlled filenames; keep installed model data and queue history intact.

## 2026-11-05 — extend no-follow protection across file APIs

- Reused the no-follow file helpers for conversation list/get/create, gallery prompt-metadata reads, pose metadata update/read, and pose image reads, in addition to scratch file read/write. These routes no longer follow a final-component symlink to an outside file.
- Live conversation API round-trip returned POST/GET/DELETE 200. A symlink POST returned 403 and left its outside canary unchanged; the conversation listing still returned 200. Scratch API normal round-trip and symlink GET/POST probes also pass with 403 on symlinks.
- Safe-file fixture now has 6 assertions. All other GGUF, download and upload fixtures, Python structure tests, app syntax, and diff checks pass. Studio health OK.
- Backup: `apps/server/server.mjs.pre-metadata-symlink-guards-20261105-130000`.

Next: continue the static audit of remaining output and inference file paths; keep data and the queue intact.

## 2026-11-05 — protect remaining output reads from symlinks

- Extended no-follow reads to gallery images, video files, and pose-sidecar metadata. Upscale input selection now uses `lstat` and rejects symlink inputs before launching the runtime.
- Live probes with symlinks in gallery-image, gallery-metadata, and video-output paths all returned 404; the outside canary stayed unchanged. `/api/poses` returned 200.
- Full test suite passes: 7 cache, 19 download, 12 GGUF loadability, 3 Python structure, 3 upload-byte-limit and 6 safe-file assertions; `npm run check`; `git diff --check`. Both services active; Studio health OK.
- Backup: `apps/server/server.mjs.pre-output-symlink-guards-20261105-131000`.

Next: continue reviewing runtime output writes and the persistent download queue; keep all existing user data intact.

## 2026-11-05 — validate persistent download queue records

- Added startup normalization for persisted queue records. It checks source, category, repo/version metadata, relative file name, expected model directory, exact `.part` path, status, checksum and byte counters. Stored URLs are rebuilt from validated Hugging Face/Civitai fields instead of trusted. Invalid records become visible blocked error entries with no URL or filesystem paths.
- Queue persistence now writes a random exclusive no-follow temporary file, syncs it, then atomically renames it. Download part files are checked as regular files and opened with `O_NOFOLLOW`; invalid restored items cannot resume or delete arbitrary paths.
- Restart integration preserved all 8 real queue items: 7 done, 1 existing HTTP 401 error, 0 blocked. The failed item was not retried. A symlink canary on the former fixed temp path survived an API persistence action unchanged.
- Added `scripts/test-download-record-validation.mjs` (7 assertions). Existing cache/download/GGUF/upload/symlink tests and Python structure tests pass; app checks pass.
- Backup: `apps/server/server.mjs.pre-download-queue-restore-guard-20261105-133000`.

Next: continue the file-write audit for settings/preset and runtime-generated outputs, then check the queue UI behavior if a reliable browser harness is available.

## 2026-11-05 — harden settings, presets, and runtime output writes

- Replaced server-side direct `writeFile` calls with no-follow file-handle writes. Settings and image presets use unique exclusive temp files, `fsync`, and atomic rename. Settings, queue, and preset reads now reject final-component symlinks.
- The API settings round-trip saved the existing context unchanged and did not expose the Civitai key. A temporary preset was created with HTTP 201, deleted with HTTP 200, and the original preset count was restored.
- Existing runtime-generated image/video/metadata and temporary files now use no-follow writes. Generation itself was not launched.
- Safe-file fixture now has 7 assertions; queue-record fixture has 7. Full regression tests and syntax/diff checks pass. Both services active; health OK; queue remains 8 items (7 done, one preserved 401 error), zero blocked.
- Backup: `apps/server/server.mjs.pre-atomic-settings-output-writes-20261105-134000`; settings/preset read guard checkpoint: `apps/server/server.mjs.pre-preset-read-nofollow-20261105-135000`.

Next: continue remaining runtime-input/output audit; browser-level queue UI verification is still pending because the prior desktop harness timed out. Keep network exposure unchanged.

## 2026-11-05 — queue persistence timing and permissions

Ten no-op queue actions measured 11.87 ms median (10.02–28.34 ms) including atomic persistence; no meaningful throughput issue was indicated relative to the 800 ms progress interval. Queue, settings, and preset JSON files all remain mode 0600. Details are in `BENCHMARKS.md`.

## 2026-11-05 — finish runtime file-path and malformed URL pass

- Audited server read/write/open/stream call sites. The remaining server `writeFile` calls now use no-follow handles; configuration and presets use atomic replace. User-facing image/video/pose reads and conversation/preset/settings/queue reads reject final-component symlinks. Upload streams use exclusive creation; downloads use no-follow part-file streams.
- Added one path decoder that converts malformed percent-encoding to HTTP 400 instead of bubbling a URIError into HTTP 500. Live probes on `/api/files`, gallery metadata, Krea job, video job, and gallery image routes all returned 400 for `%ZZ`.
- Settings save preserved the current context and did not expose the Civitai key. Temporary preset create/delete restored the original preset count. Queue still has 8 entries and its 401 item was not retried.
- Queue persistence no-op timing: 11.87 ms median (10.02–28.34 ms), no material cost versus 800 ms download progress cadence. Queue/settings/preset JSON files remain mode 0600.
- Backup: `apps/server/server.mjs.pre-malformed-url-400-20261105-140000`.

Next: continue the remaining native runtime input/model-path audit and try browser-level queue verification if a harness is available. Preserve network exposure and queue data.

## 2026-11-05 — reject symlinked native video profile components

- The fixed native-video profile check used `existsSync/statSync`, so symlink placeholders could mark missing model files as ready. It now uses the shared regular-file `lstat` check; symlinks do not contribute to readiness or model size.
- Live Wan 2.2 probe temporarily placed symlinks at its two known missing file paths. The API correctly remained `ready=false` and listed both files as missing; the catalog exposed zero symlink entries. Temporary links and the outside canary were removed.
- App syntax and diff checks pass; full regression run is listed below. Backup: `apps/server/server.mjs.pre-video-profile-symlink-guard-20261105-141000`.

Next: continue auditing runtime selections and status paths; keep model data and queue untouched.

## 2026-11-05 — validate text mmproj files before runtime changes

- Text model loading now requires an mmproj candidate to be a regular non-symlink file, have a valid GGUF header, and pass the full tensor-structure validator before any runtime is stopped or spawned. Symlink mmproj entries are excluded from candidate discovery.
- The installed Qwen2.5-VL mmproj was checked read-only: 1,338,428,128 bytes, 519 tensors, complete file bounds, structurally valid. No model was loaded.
- Live request using a temporary in-directory symlink as explicit mmproj returned HTTP 400; text runtime state was unchanged (stopped). The link and canary were removed.
- Backup: `apps/server/server.mjs.pre-mmproj-structure-guard-20261105-142000`.

Next: continue auditing runtime selection and status routes, then try browser-level queue verification if the desktop harness is usable.

## 2026-11-05 — validate text runtime overrides before stopping runtimes

- Added `validateTextRuntimeOptions` ahead of model discovery, GGUF scans, and runtime stop calls. It constrains threads to 1–16, validates GPU-layer syntax and cache types, clamps context, and rejects non-string mmproj selections.
- Live API probes with invalid cache type, thread argument, and mmproj type all returned HTTP 400. `/api/runtime` was identical before and after; no runtime was stopped or spawned.
- Added `scripts/test-runtime-selection-validation.mjs` (10 assertions). Full fixtures and app checks pass.
- Backup: `apps/server/server.mjs.pre-runtime-option-validation-20261105-143000`.

Next: continue checking image/video runtime overrides and status routes for validation-before-side-effects.


## 2026-11-05 — image loader validates selections before runtime stops

- Moved upscale/text/video/image stop calls below validation of ControlNet, IP-Adapter, CLIP Vision, VAE, ControlNet compatibility, and the required IP-Adapter/CLIP Vision pair.
- Added explicit HTTP 404 checks for every requested optional asset; previously a missing IP-Adapter, CLIP Vision, or VAE could be silently ignored.
- Live API probes: missing ControlNet/IP-Adapter/CLIP Vision/VAE each returned 404; unpaired real IP-Adapter or CLIP Vision selections each returned 400. Runtime state before/after was byte-for-byte equivalent; no model runtime started.
- `npm run check`, runtime-selection (10), safe-file-ops (7), download validation (19), download-record (7), GGUF loadability (12), GGUF cache (7), upload guard (3), and `git diff --check` passed. Both user services are active; Studio health is OK.
- `scripts/test-gguf-structure.py` could not run in the host Python: `numpy` is not installed (`ModuleNotFoundError`). No package was installed.
- Backup: `apps/server/server.mjs.pre-image-loader-validation-order-20261105-120300`.

Next: continue auditing ComfyUI image/video load paths and queue/status behavior; rerun the Python GGUF fixture when its declared Python dependencies are available.


## 2026-11-05 — image selection fixture and native video preflight

- Extracted image asset selection checks into `validateImageRuntimeSelections`; the fixture now covers defaults, valid selections, all four missing asset types, adapter pairing, and malformed request bodies (20 assertions total).
- Live native-video preflight rejects an unknown profile (404) and incomplete Wan 2.2 stack (409) without runtime changes. The installed Wan 2.1 stack is complete; an accidental valid-profile probe returned ready, so I immediately unloaded that probe-started server. No generation was run; all four runtimes are now stopped, matching the pre-probe state.
- Both user services remain active and Studio health is OK.

Next: continue ComfyUI image/video route and queue/status audit; do not load a complete video profile again unless a real runtime load is explicitly part of the next chosen experiment.


## 2026-11-05 — full regression rerun and queue status snapshot

- The earlier Python test limitation was resolved by running `scripts/test-gguf-structure.py` under `runtimes/comfy-rocm-venv/bin/python`, the validator environment configured by the server. All 3 Python structural tests pass.
- Full regression suite passes: npm syntax check; runtime selection 20; safe file ops 7; download validation 19; persisted download validation 7; GGUF loadability 12; GGUF validation cache 7; upload byte guard 3; Python GGUF structure 3; `git diff --check`.
- Read-only queue/task audit: 8 preserved records (7 done, 1 error), no active transfer, task summary reports 1 error and 0 active. Four runtimes stopped after cleanup of the video loader probe; both user services active; Studio health OK.

Next: continue read-only audit of route/task reporting and ComfyUI workflow handling; no valid-profile video load until there is an actual need to test generation end-to-end.


## 2026-11-05 — ROCm runtime and Krea workflow documentation audit

- Live user service is `ps5-ai-studio-comfyui.service`, using the isolated `runtimes/comfy-rocm-venv/bin/python` on port 8790 with DynamicVRAM. `/api/krea2/status` reports ComfyUI 0.43.0, PyTorch `2.10.0+ps5gfx1013`, HIP/gfx1013 ready, Krea nodes and required assets present. Startup logs report ROCm 7.1 and the `comfy_kitchen` HIP ConvRot backend.
- Existing PNGs and sidecars confirm earlier Krea Sickrealism safetensors and Q3 GGUF Turbo outputs on HIP. Newest Sickrealism record: 256×256, 3 steps; recent Turbo records: 384×384, 4 steps. Existing comparative timing/memory measurements remain in `docs/KREA2-OPTIMIZATION-RESULTS-20261104.md`. No inference was queued during this audit.
- Audited both checked-in API workflows against live `/object_info`: all node classes and required fields exist. The official-FP8 Turbo template references a model absent from the installed PS5 catalog; clarified that the usable installed Turbo path is Studio’s Q3 GGUF DynamicVRAM route.
- Updated `workflows/KREA2.md` and `PLAN.md`; marked old CPU-only ROCm bring-up notes as historical. Startup still has a ComfyUI-Manager “PyTorch is not installed” message despite live HIP status, now tracked in `KNOWN-ISSUES.md`.
- Full code regression suite remains green from the prior run; both Studio services are active and all runtimes are stopped.

Next: continue reviewing Krea2 route preconditions and ComfyUI task/status error reporting, distinguishing documented readiness from live completed-generation evidence.


## 2026-11-05 — Krea 2 default resolution preflight

- Found that omitted width/height were nominally defaulted to 384, then rejected because the later validation compared the defaults against `NaN`. Extracted `validateKrea2Dimensions`, call it immediately after prompt validation, and preserve the 384×384 default while rejecting non-square/out-of-range/non-64-aligned dimensions before queue, memory recovery or ComfyUI calls.
- Added fixture coverage; runtime-selection fixture now passes 28 assertions. A live 384×512 request returned HTTP 400 with no queue or runtime changes. A valid generation was not submitted.
- Full regression suite passed: Node syntax; runtime validation 28; safe-file 7; download validation 19; persisted queue records 7; GGUF loadability 12; GGUF cache 7; upload cap 3; Python GGUF structure 3; diff whitespace check. Both user services active and Studio health OK.
- Backup: `apps/server/server.mjs.pre-krea-dimension-default-20261105-122000`.

Next: continue checking Krea 2 preflight model/LoRA coupling and the ComfyUI error-to-job-state path; keep testing rejected requests without enqueuing inference.


## 2026-11-05 — synchronize ComfyUI ROCm status across project docs

- Updated README, ComfyUI bridge guide, Architecture, Web Interface, Video Studio, and parity notes: the active ComfyUI service uses `comfy-rocm-venv` with ROCm/HIP gfx1013 and validated Krea 2 image generation. Native video remains on the separate stable-diffusion.cpp Vulkan engine. Removed obsolete CPU-only/not-enabled descriptions.
- The current readiness and prior output evidence are described with route-specific limits; no claim is made that every ComfyUI graph or video workflow is GPU-validated.
- Created dated `.pre-rocm-live-status-20261105-123000` documentation backups before editing.
- `git diff --check` passes; application syntax and full fixture suite passed after the Krea dimensions change.

Next: continue Krea2 LoRA/model preflight and ComfyUI job-state review.


## 2026-11-05 — Krea LoRA symlink guard

- Krea 2 user LoRA selection now accepts only a regular file before parsing Safetensors metadata; this matches the symlink-free model catalog. Explicit LoRA selection is checked before the Turbo/Sickrealism step compatibility check.
- Live API probe used a temporary link to a known-good Krea LoRA. It returned HTTP 400 for invalid LoRA metadata selection; temporary link was removed; Studio runtime, Studio download queue, and ComfyUI queue were unchanged.
- Full regression suite passes: runtime validation 28; safe file operations 7; download validation 19; persisted download validation 7; GGUF loadability 12; GGUF cache 7; upload byte guard 3; Python GGUF structure 3; `npm run check`; `git diff --check`. Both user services are active, all runtimes stopped, queue has 8 records with no active transfer.
- Backup: `apps/server/server.mjs.pre-krea-lora-nofollow-20261105-123200` and validation-order snapshot `apps/server/server.mjs.pre-krea-lora-validation-order-20261105-123300`.

Next: continue read-only Krea job completion/error reporting audit and persisted queue/task consistency checks.


## 2026-11-05 — Krea completion and partial-output error states

- Krea job polling now marks a completed ComfyUI history entry with no output image as an explicit error instead of leaving it queued/running. Terminal ComfyUI errors are honored even if a partial image output exists. Transient status-fetch/output-fetch failures remain retryable unless the output itself is invalid.
- Added `apps/server/comfy-job-status.mjs` and `scripts/test-comfy-job-status.mjs` (6 assertions) for successful output, completed-without-output, failed-with-partial-output, and nonterminal cases.
- Full suite passes: runtime selection 28; Comfy job status 6; safe file ops 7; download validation 19; persisted queue records 7; GGUF loadability 12; GGUF cache 7; upload byte guard 3; Python GGUF structure 3; app syntax and `git diff --check`.
- Studio and ComfyUI user services are active; all four native runtimes are stopped; ComfyUI queue is empty; the Studio queue remains 8 records with no active transfer.
- Backup: `apps/server/server.mjs.pre-krea-completion-state-20261105-123500` and partial-output ordering snapshot `apps/server/server.mjs.pre-krea-partial-output-error-20261105-123700`.

Next: continue ComfyUI job-state/API error handling audit and verify the UI presents terminal errors without requiring a destructive queue action.


## 2026-11-05 — confirm ComfyUI cancellation before changing job state

- Krea cancellation now returns HTTP 503 when ComfyUI queue status cannot be read and HTTP 502 when ComfyUI rejects interrupt/removal. Studio sets `cancelled` only after a successful ComfyUI response.
- Added queue/action result fixture coverage; `scripts/test-comfy-job-status.mjs` now passes 9 assertions, including no-output completion, partial-output failure, queue unavailable and cancel action rejected. Frontend polling already stops on terminal `error` and shows the returned message.
- Full regression suite passes again (runtime 28, Comfy status/cancel 9, safe file 7, download validation 19, record validation 7, GGUF loadability 12, GGUF cache 7, upload guard 3, Python structure 3, syntax and diff check).
- Studio and ComfyUI services active; four native runtimes stopped; Studio queue has 8 saved items, none active; ComfyUI queue empty.
- Backup: `apps/server/server.mjs.pre-krea-cancel-http-check-20261105-123900`.

Next: continue the remaining ComfyUI route/error audit with read-only checks and keep terminal job outcomes and user-visible messages aligned.


## 2026-11-05 — include Krea jobs in the task dashboard

- `/api/tasks` now includes queued/running Krea 2 jobs and terminal Krea errors, with model, resolution/step or error detail and an Images target. This also makes Krea failures contribute to the shared `errors` count. Completed/cancelled jobs stay out of the active task list.
- Added `kreaJobTask` fixtures to `scripts/test-comfy-job-status.mjs`; job-state/cancel/task tests now pass 12 assertions.
- Full regression suite is green after restart. Both user services active; all runtimes stopped; ComfyUI queue empty; eight Studio download records preserved, no active transfer.
- Backup: `apps/server/server.mjs.pre-krea-task-summary-20261105-124100`.

Next: continue the remaining ComfyUI task/error reporting checks and inspect the current documented queue error without retrying or deleting it.


## 2026-11-05 — include terminal video and Enhance errors in task summary

- The shared task dashboard now retains queued/running/error states for Krea, native/Comfy video, and Enhance jobs. Error details are shown directly; completed and cancelled jobs are omitted. Errors from those jobs now contribute to the shared count.
- `taskStateVisible` fixture added; Comfy job/status/cancel/task tests pass 15 assertions. Full regression suite passes after restart.
- Live task summary remains one error and zero active: the existing failed Civitai item is preserved; there is no active Studio download or ComfyUI workflow. No retry or deletion was issued. Both user services are active; all native runtimes stopped.
- Backup: `apps/server/server.mjs.pre-task-terminal-errors-20261105-124300`.

Next: continue with static/live API consistency checks around task detail and job lifecycle; preserve the existing Civitai error record.


## 2026-11-05 — reconcile shared task error count with media jobs

- Queued/running/error states are now visible for Krea 2, video and Enhance tasks; terminal error details feed the same dashboard count. Completed/cancelled entries remain hidden.
- Live queue/task comparison matches: 8 persisted download records, one Civitai 401 error at 0 bytes, zero active downloads, one dashboard error, no ComfyUI jobs, and all native runtimes stopped. The failed item was not retried or removed.
- Full suite passes, including Comfy job status/cancel/task 15 assertions and runtime selection 28 assertions; all other fixture counts and Python GGUF structure tests pass. Both user services are active and `/api/health` is OK.
- Backup: `apps/server/server.mjs.pre-task-terminal-errors-20261105-124300`.

Next: continue checking lifecycle transitions and task-summary consistency for any remaining job types, preserving the Civitai record and model data.


## 2026-11-05 — target Comfy video cancellation at its own job

- `/api/video/cancel` no longer interrupts arbitrary ComfyUI work when no video job exists. It selects only an active ComfyUI video job, deletes its prompt if queued or interrupts if running, and marks it cancelled only after ComfyUI confirms. Queue read/action failures leave job state unchanged.
- Added active-Comfy-video selection fixture coverage; Comfy job/status/cancel/task fixture now passes 17 assertions. Live idle-cancel probe returns 409 and leaves ComfyUI queue and Studio runtimes unchanged.
- First probe ran before the patched Studio process had restarted and hit the old route; the ComfyUI queue was empty and no job was affected. After restart the intended 409 behavior was verified.
- Full suite passes again; both services active, native runtimes stopped, 8 Studio queue records preserved, 1 existing task error, no active ComfyUI jobs.
- Backup: `apps/server/server.mjs.pre-video-cancel-targeting-20261105-124500`.

Next: continue final route-by-route lifecycle review and ensure no remaining cancellation endpoint changes task state after an unsuccessful backend response.

## 2026-11-05 — Krea 2 Turbo warm-speed probe

- Controlled fixed-prompt/seed PS5 timings: 512x512 4-step Turbo = 30.19 s API / 28.32 s ComfyUI; 384x384 4-step = 21.19 s / 20.42 s; 512x512 2-step Turbo = 59.98 s / 43.26 s. First cold 512x512 4-step = 66.05 s.
- 384x384 ran ~29.8% faster than 512x512 (one sample each). 2-step was slower than 4-step on this PS5 route.
- Updated Q3 Krea Turbo UI timing guidance; `node --check apps/web/app.js` and targeted `git diff --check` passed. Image quality not scored.
- CPU boost test deferred because remote sudo requires an interactive terminal. Current boost remains off; no kernel or persistent power setting changed.
- Same-session Q3 standard 8-step at 512x512 completed in 54.59 s API / 54.04 s ComfyUI. Live Studio served `/api/health` and updated `/app.js` with HTTP 200.

- Added a one-click Q3 Turbo 384x384 4-step preview setup, with measured warm time 21.19 s API / 20.42 s ComfyUI; default settings are unchanged. Turbo step display now follows the active profile and restores the standard selection.
- A second 512x512 warm 4-step Turbo run took 36.23 s API / 33.21 s ComfyUI; two-run API range 30.19–36.23 s. Afterward HSA free was 2.18 GiB and host available 6.08 GiB with model still staged/offloading ~1.35 GB to host.
- Added one-click Q3 Turbo 384x384 4-step setup. No boot/kernel or memory policy changed.
- Identical 512x512 same-seed 4-step repeat was served by ComfyUI cache (0.00 s execution, identical PNG SHA256); excluded from real inference timing.
- Reserve A/B rejected: `0.25` cold/warm 512x512 = 57.69/30.42 s API, but HSA free fell to 1.65 GiB below the 1.8 GiB guard. Restored `0.5`; restart yielded 7.05 GiB free.
- New 384x384 cold/warm runs under restored reserve were 51.75/24.18 s; second warm left only 1.40 GiB free, so ComfyUI was restarted to clear model staging.
- Removed hard-coded 1347.84 MB `model_offload` metadata; new real PS5 output sidecars correctly record null. Historical sidecars unchanged.
- Hardened Krea low-memory recovery: rechecks ComfyUI queue immediately before restart and skips restart on busy/malformed queue. `comfyQueueHasWork` fixture coverage now 23 assertions.
- Added and PS5-tested non-restarting memory recovery: from HSA 1.40 GiB and host 4.24 GiB, the API used ComfyUI `/free`, accepted a job in 0.66 s, completed 384x384 in 46.08 s, and kept PID 41972. HSA recovered to 2.18 GiB. Service restart remains fallback.

- 2026-11-05: verified AMD async offload is already active with two streams; `--fast fp16_accumulation` gave only a single 0.47 s (~2.3%) warm difference at 384x384 and was inconclusive. Removed the test flag and restored default ComfyUI ExecStart / 0.5 GiB reserve. After the test HSA was 1.40 GiB, so the 1.8 GiB guard was respected. See Krea2 optimization results.

- 2026-11-05: CPU profiling found ~0.9–1.0 average CPU core per Krea2 run (16-thread pools, 16 logical CPUs); no thread cap applied. `--force-non-blocking` already returns true for HIP. `--fast-disk` cold mean 47.17 s vs default control 47.50 s, warm 20.64 vs 20.40 s; no HSA/host-memory gain, so reverted. Continue GGUF staging/cache audit.

- 2026-11-05: temporary `/free` no-unload semantics reclaimed HSA 1.40→6.72 GiB in 1.02 s, but next Krea generation remained cold at 45.62 s. Reverted the ComfyUI source patch; investigating unload-without-executor-reset as a distinct cache lifecycle path.

- 2026-11-05: Studio now unloads Comfy GPU residency while preserving PromptExecutor/node cache before using the full `/free` reset fallback. Two real low-memory runs saved ~18–20 s vs full reset (28.12/26.55 s and 25.75/24.22 s API/Comfy). HSA guard/reserve unchanged. Full fixtures, real PS5 route and health checks passed.

- 2026-11-05: split attention produced a verified all-black PNG on gfx1013; reverted. Default sub-quadratic control produced a varied valid PNG. CK int8/sol attention APIs are unavailable on this GPU. Left GPU_PINNED_MIN_XFER_SIZE=16384 unchanged because its active consumer is not yet identified.

- 2026-11-05: standard 512x512 Q3 Turbo4 Studio validation passed (31.60 s, 300,836-byte PNG); HSA 1.90 GiB after job, so no further high-res run queued below the guard margin.

 
## 2026-11-05 — Krea 2 OpenRouter prompt intelligence

- Added a pre-generation prompt optimizer to the Krea 2 panel. OpenRouter is the default; the provider selector can manually choose local Qwen Vision. If OpenRouter is missing/unavailable or returns an invalid response, local Qwen is tried automatically; if that also fails or RAM is constrained, the original prompt is sent unchanged.
- OpenRouter supports a user preset slug referenced as @preset/<slug>. The request does not override the preset's model chain, system prompt, provider routing, temperature or token limit. Without a preset slug, the integration uses openrouter/free and its built-in Krea-specific prompt instruction.
- Local fallback uses the installed Qwen2.5-VL 3B GGUF text path in a temporary CPU-only llama-server on loopback port 8083 (4 threads, 2k context). It starts only on demand, requires >=5.5 GiB available RAM before load and >=4 GiB after load, then exits. Krea's existing Qwen3-VL 4B ComfyUI encoder and ROCm generation pipeline are unchanged.
- Added secure OpenRouter key and optional preset-slug fields to Settings. The API key is stored in the mode-0600 settings file and redacted from GET responses. Original prompt, selected/actual optimizer, model and fallback state are preserved in output sidecar metadata.
- Verification: local Qwen prompt optimization passed live; automatic OpenRouter-to-Qwen fallback passed live with no key; temporary process cleaned up; ComfyUI queue stayed empty. Settings persistence/redaction/clear and Civitai-key preservation passed. Prompt optimizer unit tests pass 21 assertions; full JS/Python fixture regression suite and git diff --check pass.
- Real OpenRouter inference awaits the user's API key and optional preset slug. Backup snapshot: docs/benchmarks/krea-prompt-router-20261105T185500Z-before/. Implementation guide: docs/KREA2-PROMPT-INTELLIGENCE.md.

Next: enter the OpenRouter API key and preset slug in Settings, then run a real prompt through the configured OpenRouter preset and compare its output/latency with local Qwen fallback.

## 2026-11-05 — Krea 2 prompt intelligence completion pass

- Fixed the front-end module integration discovered during verification: the app is loaded as an ES module and `.mjs` dependencies are served as JavaScript. Prompt controls, review, restoration, manual edit, source/provider attribution and one-time original path are all wired; poll completion re-enables the skip-once control.
- Optimizer security/integration fixture: 85 assertions passed. Prompt mode/review/UI fixture: 57 passed. Existing Node regressions all passed (Comfy lifecycle 23, download record 7, download validation 19, GGUF loadability 12, GGUF cache 7, runtime selection 28, safe-file 7, upload guard 3). `npm run check` and `git diff --check` passed. GGUF structure fixture: 3 passed with existing ROCm venv; system Python lacked NumPy, no install performed.
- Restarted only the Studio service after tests. Live HTTP checks passed for health, module HTML, `.mjs` MIME and key redaction. Browser accessibility tree and screenshot confirmed prompt/mode/provider/skip-once controls in the Krea generation panel; no browser console errors. Krea is ready on active gfx1013 ROCm; Comfy queue is 0/0. No image generation or real OpenRouter request. No API key is configured; local Qwen was not re-run in this pass. See `docs/KREA2-PROMPT-INTELLIGENCE.md` for details, caveats and official links.


## 2026-11-05 — OpenRouter key live check and fallback fix

- Confirmed key configured, without exposing it. Real `openrouter/free` request returned HTTP 429. Local Qwen fallback optimized a neutral prompt in 6.55 s. Added status warning to preserve the safe OpenRouter failure reason alongside fallback status.
- Live test found `abortChild` block-scoped inside `try` but referenced during `finally`; moved the handler outward. Repeated real Qwen fallback succeeded and cleaned up process/port 8083.
- Regressions now: optimizer 86, prompt flow 57, other Node fixtures 106, GGUF structure 3; syntax, `git diff --check`, live Krea readiness and empty Comfy queue passed. No GPU generation.
- OpenRouter free-route 429 exact quota cause is unknown; no repeated external request. See official rate-limit reference in `docs/KREA2-PROMPT-INTELLIGENCE.md`.


- Follow-up UX: rate-limit warnings now suggest retrying later or setting an available preset slug; HTTP 401 directs users to check Settings. Updated OpenRouter fixture and ran the complete suite again (optimizer 89, prompt flow 57, existing Node 106, GGUF structure 3). Studio active, key redacted, Krea ready, queue empty, no Qwen process and no GPU job.


## 2026-11-05 — OpenRouter diagnostic and ZDR model-list correction

- Added an in-app, no-inference API-key connection check. Live check succeeded; 50/50 requests remaining, secret redacted.
- Corrected model selection to use OpenRouter's authoritative `/endpoints/zdr` list. The `models?zdr=true` response contained false positives for actual completion routing. Only one free ZDR text endpoint is currently eligible. Free-only model validation rejects paid IDs; auto router stays default, preset wins.
- Real free routes returned 429; local Qwen fallback succeeds. No paid request, ZDR relaxation, or image generation. Full suite passes: optimizer 107, UI 57, existing Node 106, GGUF structure 3; Krea ready and Comfy queue empty.


## 2026-11-05 — 429 oorzaak vastgesteld en automatische ZDR-routering hersteld

- Live OpenRouter-keycheck slaagt; `/api/v1/key` had eerder 50/50 verzoeken beschikbaar. Eén gecontroleerde completions-probe met `openrouter/free` gaf HTTP 404: geen endpoint voldoet aan de ingestelde Zero Data Retention-policy. De actuele `/endpoints/zdr`-catalogus bevat één gratis tekstmodel dat `max_tokens` ondersteunt: `xingchen-agi/xing4.0-29b-a4b:free` via Phala.
- De gecontroleerde request naar dat model gaf HTTP 429 met `Provider returned error` en provider `Phala`. Dit is een provider-capaciteitslimiet, geen afgewezen API-key. De catalogus en response zijn gecontroleerd met `data_collection=deny` en `zdr=true`; geen betaalde modelaanvraag of privacyversoepeling.
- Aangepast: de automatische `openrouter/free`-keuze resolveert nu naar het eerste gratis, tekstgeschikte model uit de echte ZDR-endpointcatalogus. Preset en handmatig gekozen model blijven leidend. 429-classificatie bewaart alleen status en providernaam (geen prompt of ruwe response) en de gebruikerswaarschuwing noemt de daadwerkelijke providerlimiet. De bestaande automatische Qwen-fallback blijft actief. Selectorcopy verduidelijkt dat automatische keuze uit de ZDR-catalogus komt.
- End-to-end app-POST na Studio-restart gaf HTTP 200 en bruikbare geoptimaliseerde prompt via lokale Qwen; fallbackwaarschuwing meldde Phala 429. Runtime 10,4 s. De cloudaanbieder zelf blijft tijdelijk 429 geven; die upstream capaciteit kunnen we niet op de client afdwingen.
- Validatie: optimizer 108 assertions, prompt flow 57 assertions, `node --check` voor server/optimizer/UI en `git diff --check` geslaagd. Krea status generationReady=true. Geen Krea GPU/image-generatie gestart. Back-ups van de vijf aangepaste bron/testbestanden staan naast de bestanden met suffix `.pre-429-zdr-routing-<UTC timestamp>`.


## 2026-11-05 — OpenRouter working, ZDR paused at user's request

- User asked to temporarily drop ZDR. Removed request `provider.zdr`; retained `data_collection="deny"`, free-only routing/selection, API-key secrecy, fallback and prompt safeguards. The UI explicitly says ZDR is temporarily off and explains prompts leave the PS5; no zero-retention claim. Account-level guardrails may still require it.
- Replaced `/endpoints/zdr` selector with `/models` filtering: `:free`, zero prompt/completion price, text input/output, `max_tokens`. Live catalog: 12 free text models. Auto selection remains OpenRouter's `openrouter/free`.
- Direct real free-model probe succeeded via Cohere (HTTP 200, reported cost 0). Live app POST succeeded via OpenRouter using `cohere/north-mini-code:free`, returned a nonempty improved prompt, and did not fall back to Qwen. No paid request or Krea image generation.
- Tests: optimizer 107 assertions, prompt flow 57, syntax checks and `git diff --check` passed. Studio service restarted and remains active.


## 2026-11-05 — stale Krea 2 generation indicator corrected

- User reported repeated “Krea 2 generation already running” while no image/task was visible. `/api/tasks` showed a tracked Krea job in `running`, but ComfyUI `/queue` had no running or pending entries. Refreshing its job history showed it had actually completed; the completed image (`1793910159334-krea2-046bab38.png`, 385,168 bytes) was imported into the Studio image gallery. The task list then reported active=0.
- Root cause: Studio retained the in-memory job state unless the browser continued polling that exact job ID. After a page interruption/reload, the duplicate-generation guard trusted the stale `running` state.
- Fix: added a deduplicated `refreshTrackedKreaJobs()` reconciler. `/api/tasks` refreshes active tracked Krea jobs against ComfyUI history/queue before showing them, and the generation route refreshes them before rejecting a new request. A truly running job remains protected; completed, failed, or disappeared jobs no longer block forever, and completed outputs are imported through the existing status path.
- Regressions: Comfy lifecycle/task assertions 25, prompt optimizer 107, prompt flow 57; `npm run check`, all Node fixture scripts, and `git diff --check` passed. Studio service restarted and is active; `/api/tasks` now reports no active Krea job; completed image is present in gallery.


## 2026-11-05 — automatic prompt preview always visible

- Changed automatic mode to display the original and optimized prompts side by side after optimization. The improved prompt stays visible during GPU setup, generation, and completion; automatic mode continues without requiring an approval click. Manual/approve retain their existing review actions. The one-time original path remains available.
- Added a visual state label and hides review action buttons only for automatic preview to prevent accidental duplicate generation; prompt fields remain read-only in that mode.
- Prompt-flow checks: 60 assertions; optimizer checks: 107; JS syntax and `git diff --check` passed. Studio service restarted and is active.