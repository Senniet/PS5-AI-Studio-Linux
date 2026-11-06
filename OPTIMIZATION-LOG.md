# Optimization log

## 2026-11-05 — validate Krea2 LoRA structure and Safetensors bounds

### Change

Updated `apps/server/server.mjs` so the Krea2 LoRA catalog and generation validator require:

- Safetensors header length and JSON to be valid and bounded.
- Tensor shapes and data offsets to be well-formed and within the file's data section.
- Tensor ranges not to overlap.
- Krea2 base metadata (`ss_base_model_version=krea2`).
- At least one recognized paired diffusion-model adapter structure: LoRA A/B, down/up, or LoKr W1/W2.

This retains both ordinary LoRA and LoKr formats. The installed `babegenerator.ink-realism_helper.safetensors` is a LoKr adapter and remains recognized. Turbo distillation adapters remain their separate named profiles because they carry `base_model=krea/Krea-2-Turbo` metadata rather than the regular Krea2 metadata field.

### Why

The existing code classified files using only `ss_base_model_version`. A damaged Safetensors file or one with unrelated tensors could appear in the Krea2 selector and fail only after submitting the workflow. The new guard filters malformed files before exposing them to the UI or accepting a generation.

### Verification

- `node --check apps/server/server.mjs`: passed.
- Isolated execution of the new helper: all four currently listed Krea2 adapters passed; synthetic paired LoRA passed; synthetic out-of-range tensor offsets were rejected.
- Restarted the idle Studio API service. Live `/api/image/models` still returned all four Krea2 adapters.
- End-to-end integration via Studio API passed: SickRealism 256×256, 3-step Turbo, HMNSFW AIO strength 0.8; 36.30 s API wall, 35.21 s ComfyUI time; 104,973-byte output saved. Metadata confirms both LoRAs and their settings.
- Final check: Studio health OK, ComfyUI health/queue OK, both services active, image runtime restored to SickRealism.
- No performance gain is claimed for this validation change; it improves compatibility and early rejection behavior.

### Files and rollback

- Modified: `apps/server/server.mjs`.
- Backup of the full pre-change working file: `apps/server/server.mjs.pre-krea2-safetensors-integrity-20261105`.
- Roll back with: `cp apps/server/server.mjs.pre-krea2-safetensors-integrity-20261105 apps/server/server.mjs && systemctl --user restart ps5-ai-studio-linux.service`.

The backup includes the pre-existing dirty working-tree version, not the committed repository version.

## 2026-11-05 — reject obviously incomplete draft/MTP GGUF files before loading

### Change

Added apps/server/gguf-loadability.mjs and wired its classification into the local GGUF catalog and text-model load route. The helper reads the fixed GGUF header tensor count. When both counts are present, files with fewer than two tensors per declared transformer block are marked suspicious/incomplete; unknown metadata remains allowed. The text model UI keeps the record available for inspection and deletion, explains the reason, disables loading, and excludes it from chat model selectors. The backend also rejects a direct load request with HTTP 422 before it stops any runtime or spawns llama-server.

### Why

The installed Qwen3.8-27B-Uncensored-draft-Q8_0.gguf had only 18 tensors despite metadata declaring 65 blocks, and direct standalone loading had crashed in llama.cpp before readiness. It appears to be an MTP/draft fragment rather than a complete chat model. This check prevents that observed class of clearly underfilled file from entering the standalone loader.

### Verification

- Added scripts/test-gguf-loadability.mjs; all 9 fixture assertions pass, including header parsing, malformed/truncated headers, unknown values, incomplete files, and the two-tensors-per-block boundary.
- npm run check, helper node --check, and git diff --check pass.
- Live /api/models: draft file reports 18/65 and non-loadable; Qwen2.5-VL 3B reports 434/36 and loadable. Other installed GGUF entries remained allowed.
- Direct POST to /api/runtime/text/load with the draft path returns 422 with the diagnostic before inference starts.
- Studio health OK; Studio and ComfyUI user services active; ComfyUI queue empty; all Studio runtimes stopped.

### Limits and rollback

This is a conservative lower-bound screen, not complete tensor inventory/shape validation, and a positive result is not a compatibility guarantee. Unknown metadata is allowed. No model was loaded for this verification. Modified: apps/server/server.mjs, apps/web/app.js; added helper and fixture. Backups: apps/server/server.mjs.pre-gguf-loadability-20261105-110109 and apps/web/app.js.pre-gguf-loadability-20261105-110109 (both are copies of the full pre-change dirty files).

## 2026-11-05 — constrain Civitai downloads and align resume validation

### Findings and changes

The download audit found two concrete gaps. Queue creation accepted .pt/.pth model files, while resume validation and the frontend Resume button omitted those extensions. Also, the general download endpoint trusted a caller-supplied URL for any source string beginning with civitai, making the unauthenticated server a fetch proxy for arbitrary destinations.

A shared helper now defines the extension set used on queue creation and resume. The frontend uses the same supported .pt/.pth set. Civitai sources must be exactly civitai or civitai-red and carry a positive safe-integer model version ID; the URL is constructed from that ID on the matching official domain, including when a persisted queue item is retried. Caller-provided URLs are ignored.

### Verification

- Added download-validation fixtures for GGUF-only text downloads, image/control/video extensions, .pt/.pth resume support, invalid extensions, canonical Civitai domains and invalid source/version values. All 13 assertions pass.
- Live request with a caller-supplied localhost URL and no version ID returned HTTP 400. Queue IDs were identical before and after; no download/fetch was started.
- GGUF fixture (9 assertions), npm run check, helper syntax checks and git diff --check pass.
- Studio and ComfyUI active; API health OK; ComfyUI queue empty.

### Backup and next audit

Backup: apps/server/server.mjs.pre-civitai-url-guard-20261105-110810. Earlier resume-only backup: apps/server/server.mjs.pre-download-resume-ext-20261105-110627. Continue by reviewing GGUF upload validation and making queue fetch failures visible in the frontend.

## 2026-11-05 — reject invalid GGUF upload headers and show queue refresh failures

Text or image GGUF uploads now capture the first 24 bytes and reject an invalid fixed header (magic, supported version, positive tensor and metadata counts) before the .uploading file is renamed. The local GGUF catalog and text-load route also perform this header check, so malformed existing files are marked and cannot be loaded. The existing queue UI now presents API errors in place of stale queue contents and points to the existing refresh control.

A live 24-byte zero upload named .gguf returned HTTP 400 and left neither a final file nor a partial upload. All seven installed catalog headers passed; the known 18-tensor/65-block fragment remained blocked. Tests: 12 GGUF fixtures, 13 download fixtures, npm run check, syntax checks and git diff --check passed. Studio and ComfyUI remain active, health is good and queue is empty.

This validates only the fixed header. It does not walk GGUF tensor records or prove that tensor offsets/data are complete. Backup: apps/server/server.mjs.pre-gguf-upload-header-20261105-111044.

## 2026-11-05 — validate GGUF tensor directories before upload/load

Integrated the installed gguf Python reader as a strict structural check for GGUF uploads and text-model loads. The validator confirms that the declared tensor count equals the parsed count; names and tensor types parse; dimensions are positive; data offsets are aligned; tensor byte ranges fit inside the file; and ranges do not overlap. Upload checks run on the temporary file before its atomic rename. Text loading checks finish before other runtimes are stopped or llama-server is spawned. The catalog still uses a cheap fixed-header check and the separate MTP/draft lower-bound guard.

Validation evidence: all 11 installed GGUFs passed the read-only tensor-directory scan, with exact declared/parsed counts and in-file tensor ranges. Three Python fixture tests passed (valid GGUF, truncated tensor payload, overlapping offsets). A live synthetic valid upload returned 201 and was removed via the app; a truncated tensor fixture returned 422 and left no final or partial file. Direct loading of the draft file returned 422 without starting inference. The first live fixture found a redundant file-handle close in the new upload path; it was corrected and the repeated integration passed.

Also passing: 13 download fixtures, 12 header/loadability fixtures, npm run check, server/helper syntax checks, git diff --check. Studio and ComfyUI active, Studio health OK, queue empty, runtimes stopped.

The structural checker imports gguf from runtimes/comfy-rocm-venv/bin/python, verified on ps5-linux. It checks format structure, not architecture compatibility or whether all expected base-model parameters are present. The 18-tensor MTP file is structurally valid but remains blocked as a standalone text model. Browser automation for queue error rendering has not been run. Backup before validator integration: apps/server/server.mjs.pre-gguf-structure-validator-20261105-111603; upload close fix checkpoint: apps/server/server.mjs.pre-gguf-upload-close-fix-20261105-111851.

## 2026-11-05 — cache successful GGUF structure scans by file identity

- Read-only timing of the complete validator on 11 files: small/tiny models 0.03–0.05 s; main text models about 5.56–9.26 s each. The MTP draft file also takes about 9 s to structurally verify because it is internally well-formed.
- Added an in-process LRU cache (256 entries) and concurrent request coalescing. Successful scans are keyed by device, inode, size, mtime-ns and ctime-ns; the fingerprint is checked again after parsing. Failures are never cached. Upload validation benefits again at later load because atomic rename preserves file identity.
- Live API measurement after service restart: first draft check (full structure scan, then expected HTTP 422) 9.396 s; repeat on unchanged file 0.022 s, about 99.8% lower latency. No inference process started.
- Added 7 cache fixture assertions (concurrent coalescing, repeat hit, failure retry, bounded LRU). All cache, download, GGUF and tensor-structure fixtures pass; npm run check, syntax and diff checks pass. Studio/ComfyUI active, health OK, queue empty.
- Cache is process-local and intentionally invalidated on service restart; first access to an existing large model pays the full scan. Upload-installed models are scanned before installation and reused without another scan in the same process.

## 2026-11-05 — catalog API microbenchmark (no change)

Six local model-list requests, seven records each, returned 7,084 bytes in 0.0274–0.0847 s (median 0.02785 s). This did not show a material listing bottleneck, so the parser/catalog path was left unchanged. See BENCHMARKS.md for samples and scope.

## 2026-11-05 — gate GGUF download and image-load routes

Added the structural GGUF validator before completed downloads are atomically installed, and before Image Studio or direct Krea 2 GGUF paths can launch/use a workflow. Invalid downloaded partials are discarded. Text loads and uploads already used this check. Together these cover upload, download, text, image and direct Krea API paths. No upstream download or ComfyUI generation was initiated for this patch.

Checks passed: 7 validation-cache assertions, 13 download assertions, 12 GGUF classification assertions, 3 Python structure fixtures, npm run check and git diff --check. Studio/ComfyUI active, health OK, queue empty, runtimes stopped. Backups: apps/server/server.mjs.pre-gguf-download-validation-20261105-113833 and apps/server/server.mjs.pre-image-gguf-structure-guard-20261105-114006.

Read-only API samples also found no material local latency issue: diagnostics median 9.7 ms, queue 2.2 ms, image catalog 48.4 ms, task list 0.8 ms. See BENCHMARKS.md.
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

- Fixed-prompt/seed warm 512x512 Q3 Turbo 4-step: 30.19 s API / 28.32 s ComfyUI. 384x384: 21.19 s / 20.42 s (~29.8% less wall time, one sample per size). Cold 512x512 4-step: 66.05 s.
- 512x512 Q3 Turbo 2-step: 59.98 s API / 43.26 s ComfyUI, slower than 4-step. UI now avoids describing 2-step as the speed option.
- CPU boost A/B not run: sudo needs an interactive terminal. Current `boost=0`, `schedutil`; no hardware state changed.
- Visual quality not scored; use lower resolution only as a faster preview/work size until reviewed.
- Same-session standard Q3 8-step at 512x512: 54.59 s API / 54.04 s ComfyUI, no Turbo LoRA. Warm 4-step Turbo remains fastest measured at 512x512.

- Added a one-click Q3 Turbo 384x384 4-step preview setup, with measured warm time 21.19 s API / 20.42 s ComfyUI; default settings are unchanged. Turbo step display now follows the active profile and restores the standard selection.
- Repeat 512x512 warm 4-step Turbo after other profiles: 36.23 s API / 33.21 s ComfyUI (first run 30.19/28.32 s). Report the measured 30.2–36.2 s range, not a single deterministic time.
- Post-run HSA free 2.18 GiB, host available 6.08 GiB, swap free 5.71 GiB; model staged, ~1.35 GB host offload report. Keep DynamicVRAM/memory settings unchanged pending further evidence.
- Excluded the immediate identical fixed-seed 4-step request from inference timings: ComfyUI cache hit, 0.00 s execution, identical output SHA256.
- `--reserve-vram 0.25` A/B rejected: warm speed 30.42 s API / 29.87 s ComfyUI was effectively unchanged; HSA free fell to 1.65 GiB (<1.8 guard). Restored original 0.5 setting; restart returned idle HSA free to 7.05 GiB.
- At 0.5 reserve, 384x384 4-step Turbo measured 51.75 s cold and 24.18 s warm (prior warm 21.19 s). After the second warm run HSA free was 1.40 GiB; restarted ComfyUI to clear staged model memory.
- Corrected Krea sidecar metadata: previous `model_offload` value of 1347.84 MB was hard-coded, not measured. New outputs use null; verified on real PS5 output. Historical metadata preserved.
- Added a second fail-closed Comfy queue check before automatic low-memory restart; malformed queue responses also skip restart. This narrows (but cannot eliminate) the race with workflows started directly through ComfyUI. Reserve remains 0.5 GiB; Q3 guard remains 1.8 GiB.
- Validated integrated ComfyUI `/free` recovery from HSA 1.40 GiB: API accepted in 0.66 s, 384x384 generation completed in 46.08 s, PID remained 41972, HSA after 2.18 GiB. This avoids backend downtime but the next generation still pays cold model-load cost.

- 2026-11-05: gfx1013 startup already reports async weight offloading with 2 streams. Temporary `--fast fp16_accumulation` A/B: baseline warm 21.36/20.42 s (API/Comfy), candidate 20.48/19.95 s; single ~2.3% internal improvement is inconclusive, so reverted. Backup: `docs/benchmarks/krea2-fast-fp16accum-20261105T155500Z-before/`. Keep reserve 0.5 GiB and 1.8 GiB guard.

- 2026-11-05: CPU profile: 384x384 Turbo4 cold 49.03 s / 44.15 CPU-s; warm 20.48 s / 21.14 CPU-s, only ~1 logical core average. No CPU thread cap. HIP already uses non-blocking copies (`device_supports_non_blocking(cuda:0)=True`). Tested and rejected `--fast-disk`: cold mean 47.17 s vs 47.50 s control, warm 20.64 vs 20.40 s, no memory gain. Reverted; backup `docs/benchmarks/krea2-fast-disk-20261105T161000Z-before/`.

- 2026-11-05: tried ComfyUI `/free` with executor reset but no model unload; HSA reclaimed to 6.72 GiB in 1.02 s, but following Krea job was cold (45.62 s API /44.51 s Comfy). Reverted temporary server.py patch and restarted. Explore `unload_models=true, free_memory=false` to preserve smart node cache while freeing GPU weights.

- 2026-11-05: retained cache-preserving recovery `{unload_models:true,free_memory:false}` before full-reset fallback. Two low-HSA Krea runs: 28.12/26.55 s and 25.75/24.22 s API/Comfy vs 45.62/44.51 s full-reset, saving ~18–20 s; following warm runs ~20.25/19.51 s. Guard=1.8 GiB and reserve=0.5 GiB unchanged. Tests/real PS5 health passed. Backup: `docs/benchmarks/krea2-cache-preserving-memory-recovery-20261105T164000Z-before/`.

- 2026-11-05: rejected split-cross-attention A/B (509-byte uniform black output); restored sub-quadratic, then verified a normal 185 KB nonuniform image. CK int8 and sol_attn are unavailable on gfx1013. Transfer threshold env remains 16384 pending identification; no change.
