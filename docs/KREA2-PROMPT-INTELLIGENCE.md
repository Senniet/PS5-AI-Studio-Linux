# Krea 2 Prompt Intelligence

Updated: 2026-11-05

## User flow

Krea 2 keeps the entered prompt in its editor. The prompt controls are grouped beside that field and expose three workflows:

- **Automatisch**: improve the prompt, then start Krea 2.
- **Eerst goedkeuren**: improve the prompt, compare it with the original, then choose which one to generate.
- **Handmatig aanpassen**: compare both versions, edit the improved version, and generate the edited text.
- **Genereer met origineel · één keer**: skip optimization for this generation without changing the selected mode.
- **Prompt verbeteren vóór generatie** can be turned off. Automatic mode then generates the original; approval/manual mode shows the original for review.

The review panel keeps the original immutable, supports restoring it into the candidate field, and offers a direct original-prompt action. Provider, model, fallback, manual edits, mode, source, and safe warning text appear in status/result attribution. The original prompt is not copied into the generation sidecar; the final prompt and non-secret optimizer metadata are retained for reproducibility.

## Provider flow

The server accepts text prompts only. It never sends an image to OpenRouter.

- OpenRouter is the default provider. With an empty preset slug, the model is `openrouter/free`.
- With a preset slug, the server fetches its configuration and submits `@preset/<slug>`. It preserves the preset's provider preferences and system prompt while adding the Krea prompt rules and enforcing the privacy fields on the completion request.
- Current routing (changed 2026-11-05 at the user's request): OpenRouter requests omit `provider.zdr` so ZDR is not required. `provider.data_collection="deny"` remains mandatory. Only catalogued `:free` text models are offered for direct selection; the automatic option uses `openrouter/free`.
- A single retry is allowed for transient 5xx/network failures. Authentication, rate limiting, timeouts, and invalid responses do not retry.
- OpenRouter failure falls back to the local Qwen3-4B text prompt model; if that path is unavailable or its RAM reserve fails, the original prompt is returned.
- Explicit local-Qwen selection skips OpenRouter. Local Qwen failure also returns the original prompt.
- A cancelled browser request aborts its server-side operation where possible.

ZDR is temporarily not required at the request level. `data_collection=deny` remains active, which filters providers according to OpenRouter's data-collection policy, but this is not a zero-retention guarantee. Prompts are still sent to OpenRouter and a selected inference provider for processing; provider/account policies may have additional effects. A user or account guardrail may independently enforce ZDR.

## Local Qwen fallback

The local prompt fallback now uses Qwen3-4B-Instruct-2507 Q4_K_M as a text-only specialist. It runs on Vulkan through a temporary loopback llama-server, uses the existing RAM/GPU exclusivity guards, is not started if another model runtime is active, and is terminated after the request. Qwen2.5-VL-3B remains installed as a fallback asset but is no longer the default prompt model. This is distinct from Qwen3-VL-4B, which handles actual image understanding and is also used as Krea 2's image-generation text encoder.

## API-key handling

The OpenRouter key is accepted only by the server-side settings route and stored in the private settings file. Public settings responses delete both OpenRouter and Civitai key values and return only configured booleans. An empty key field retains the stored value; explicit clear deletes it. `OPENROUTER_API_KEY` can be provided through the server environment and takes precedence over the saved value. Logs do not include prompts or the key. The API key is never embedded in browser code.

The preset field takes the slug only, without `@preset/`. Presets containing tools/plugins are rejected because this feature is text-only. Preset content is user-configured and therefore reviewed server-side only for supported text/provider settings.

## Integration details

- `apps/server/krea-prompt-optimizer.mjs`: request shaping, preset lookup, privacy overlay, bounded retry/timeouts, response validation, and fallback orchestration.
- `apps/server/settings-secrets.mjs`: strips API-key values from public settings.
- `apps/web/krea-prompt-flow.mjs`: pure mode/review/restore/selection state.
- `apps/web/app.js` and `apps/web/index.html`: controls, status, review and generation metadata.
- Browser script is loaded as an ES module. The server serves `.mjs` files with a JavaScript MIME type.
- Krea generation still uses its existing ComfyUI workflow and ROCm/gfx1013 route. No generation graph, image models, or GPU settings were changed.

## Verification on 2026-11-05

- `npm run check`: passed.
- `scripts/test-krea-prompt-optimizer.mjs`: 107 assertions passed, including mocked preset/free requests, mandatory privacy, 401/429/5xx, timeout, invalid response, fallback, key-redaction, no-log, Qwen cleanup scope guard and static generation guardrails.
- `scripts/test-krea-prompt-flow.mjs`: 57 assertions passed, covering modes, approval, manual edits, restore/original, input limits, UI IDs, ES-module loading and .mjs serving.
- Remaining Node regression scripts: Comfy job status (23), download record (7), download validation (19), GGUF loadability (12), GGUF cache (7), runtime selection (28), safe file ops (7), upload guard (3) — all passed.
- GGUF structure Python fixture: 3 tests passed with the existing `comfy-rocm-venv`. The first attempt via system Python lacked NumPy; no dependencies were installed.
- `git diff --check`: passed.
- Restarted only `ps5-ai-studio-linux.service`. Live HTTP checks passed for `/api/health`, module HTML, `.mjs` JavaScript MIME and API-key redaction. Browser accessibility tree/screenshot confirmed the Krea prompt controls and panel layout; browser console showed no errors. Live Krea status reported `generationReady=true`, active gfx1013 ROCm profile, ComfyUI queue 0 running/0 pending.
- Live key verification: the public settings API returned `openrouterApiKeyConfigured=true` and no key value. A real request using the default `openrouter/free` returned HTTP 429; the exact account/provider quota cause is not exposed by the API and was not inferred. The UI warning now says the request was rate-limited and suggests retrying later or entering an available preset slug. OpenRouter documents free-model limits and separate provider-level limits ([free models](https://openrouter.ai/collections/free-models/)). The request then used local Qwen successfully in 6.55 seconds. It exposed a cleanup bug (`abortChild` was scoped inside `try` but referenced in `finally`); moved the handler to the enclosing function scope and added two regression assertions. The later live fallback exited cleanly: no llama-server process, port 8083 closed, Krea ready, RAM 7.12 GiB, ComfyUI queue 0/0. No image/GPU generation was run.

## Official references

- [OpenRouter provider routing](https://openrouter.ai/docs/guides/routing/provider-selection)
- [OpenRouter Zero Data Retention](https://openrouter.ai/docs/guides/features/zdr)
- [OpenRouter provider logging and data retention](https://openrouter.ai/docs/guides/privacy/provider-logging)
- [OpenRouter free models and rate limits](https://openrouter.ai/collections/free-models/)
- [OpenRouter presets](https://openrouter.ai/docs/guides/features/presets)
- [OpenRouter model list API](https://openrouter.ai/docs/api/api-reference/models/list-all-models-and-their-properties)


## 2026-11-05 — OpenRouter connection diagnostics and live ZDR catalog

- Added a no-inference “Test OpenRouter connection” action. It checks `/api/v1/key` server-side and returns only valid/limit/usage/remaining metadata; the credential is never returned. Live settings UI reports the connection and 50/50 remaining quota.
- Added an optional free-model selector sourced from `/api/v1/endpoints/zdr`, not the broader model-list `zdr=true` filter. The broader filter had exposed models whose endpoint-list showed no ZDR endpoint; selecting those produced 404. The corrected catalog currently exposes one free text model endpoint (XingChen via Phala). Paid model IDs are rejected, `openrouter/free` remains the default, and presets still take precedence.
- Tested a real prompt against `openrouter/free` and the one catalogued free ZDR model. Both provider calls returned HTTP 429; the local Qwen fallback generated an improved prompt and cleaned up. No paid inference, privacy relaxation, or Krea image generation was performed. This is consistent with OpenRouter's documentation that 429 may mean provider capacity/rate limiting; see [free-model limits](https://openrouter.ai/collections/free-models/) and [ZDR endpoints](https://openrouter.ai/docs/guides/features/zdr).
- Latest checks: optimizer 107 assertions; prompt flow 57; remaining Node regressions 106; GGUF structure 3; syntax, live connection check, live settings selector, browser console, key redaction, Krea readiness and empty ComfyUI queue all passed. Studio service restarted; ComfyUI remained active.
- Remaining limitation: OpenRouter authenticates successfully but the available free ZDR provider returns 429. No paid request was made.


## 2026-11-05 — 429 oorzaak vastgesteld en automatische ZDR-routering hersteld

- Live OpenRouter-keycheck slaagt; `/api/v1/key` had eerder 50/50 verzoeken beschikbaar. Eén gecontroleerde completions-probe met `openrouter/free` gaf HTTP 404: geen endpoint voldoet aan de ingestelde Zero Data Retention-policy. De actuele `/endpoints/zdr`-catalogus bevat één gratis tekstmodel dat `max_tokens` ondersteunt: `xingchen-agi/xing4.0-29b-a4b:free` via Phala.
- De gecontroleerde request naar dat model gaf HTTP 429 met `Provider returned error` en provider `Phala`. Dit is een provider-capaciteitslimiet, geen afgewezen API-key. De catalogus en response zijn gecontroleerd met `data_collection=deny` en `zdr=true`; geen betaalde modelaanvraag of privacyversoepeling.
- Aangepast: de automatische `openrouter/free`-keuze resolveert nu naar het eerste gratis, tekstgeschikte model uit de echte ZDR-endpointcatalogus. Preset en handmatig gekozen model blijven leidend. 429-classificatie bewaart alleen status en providernaam (geen prompt of ruwe response) en de gebruikerswaarschuwing noemt de daadwerkelijke providerlimiet. De bestaande automatische Qwen-fallback blijft actief. Selectorcopy verduidelijkt dat automatische keuze uit de ZDR-catalogus komt.
- End-to-end app-POST na Studio-restart gaf HTTP 200 en bruikbare geoptimaliseerde prompt via lokale Qwen; fallbackwaarschuwing meldde Phala 429. Runtime 10,4 s. De cloudaanbieder zelf blijft tijdelijk 429 geven; die upstream capaciteit kunnen we niet op de client afdwingen.
- Validatie: optimizer 108 assertions, prompt flow 57 assertions, `node --check` voor server/optimizer/UI en `git diff --check` geslaagd. Krea status generationReady=true. Geen Krea GPU/image-generatie gestart. Back-ups van de vijf aangepaste bron/testbestanden staan naast de bestanden met suffix `.pre-429-zdr-routing-<UTC timestamp>`.


## 2026-11-05 — OpenRouter works with ZDR paused

- At the user's request, removed the request-level ZDR requirement while retaining `data_collection="deny"`, the free-only model guard, key redaction and local Qwen fallback. Preset provider configuration is also stripped of `zdr` and still forced to `data_collection="deny"`.
- Replaced the ZDR endpoint catalog with `/api/v1/models`, filtering for `:free`, zero prompt/completion pricing, text input/output, and `max_tokens`. Current live selector returned 12 models. Automatic mode sends `openrouter/free` to OpenRouter's free router rather than pinning the only ZDR endpoint.
- Live direct probe with `openrouter/free` and only `data_collection="deny"` returned HTTP 200 via Cohere with zero reported inference cost. Live app end-to-end POST returned HTTP 200, provider `openrouter`, model `cohere/north-mini-code:free`, a nonempty improved prompt, and no fallback. The service is active. No paid request or Krea GPU generation.
- Verification after changes: optimizer 107 assertions; prompt flow 57; server/optimizer/UI syntax and `git diff --check` passed.
- Privacy boundary: ZDR is off for these requests, so this does not promise that an inference provider deletes prompts after processing. `data_collection=deny` is still sent. OpenRouter's current descriptions distinguish these controls: [ZDR guide](https://openrouter.ai/docs/guides/features/zdr), [provider selection](https://openrouter.ai/docs/guides/routing/provider-selection).


## 2026-11-05 — automatic prompt preview always visible

- Changed automatic mode to display the original and optimized prompts side by side after optimization. The improved prompt stays visible during GPU setup, generation, and completion; automatic mode continues without requiring an approval click. Manual/approve retain their existing review actions. The one-time original path remains available.
- Added a visual state label and hides review action buttons only for automatic preview to prevent accidental duplicate generation; prompt fields remain read-only in that mode.
- Prompt-flow checks: 60 assertions; optimizer checks: 107; JS syntax and `git diff --check` passed. Studio service restarted and is active.