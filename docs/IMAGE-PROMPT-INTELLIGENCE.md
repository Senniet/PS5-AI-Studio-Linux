# Image Studio — Model-aware Prompt Intelligence

Updated: 2026-11-05

Image Studio's local Qwen prompt optimizer is model-aware. It does more than translate: it interprets the user's request, preserves intent and constraints, and produces a polished English positive prompt tailored to the selected checkpoint family.

## Context passed to Qwen

- Selected checkpoint filename, validated against the installed checkpoint inventory.
- Active backend only when the selected checkpoint is the active runtime model; a different pending selection is classified from its own filename instead of inheriting stale runtime metadata.
- Selected standard LoRAs and Krea2 LoRA, each resolved against the installed model inventory.
- Generation width, height, steps, CFG, sampler, scheduler and Krea Turbo preset.

No arbitrary filesystem paths or unvalidated LoRA names are inserted into the system prompt. Model and LoRA filenames are length-limited and sanitized.

## Model-family guidance

- Krea 2 / SickRealism: coherent natural-language visual description, realism, composition, perspective, light and surface detail; no tag soup.
- FLUX: natural prose, explicit spatial relationships and visual hierarchy; no legacy tag piles.
- SDXL: structured visual descriptors with subject first, then scene, style, composition and light.
- Pony / Illustrious SDXL: concise character, pose, expression, clothing and art-direction descriptors.
- SD 1.5: compact high-signal prompt with the most important subject and style terms first.
- SD3, Qwen-Image, PixArt, Kolors and Hunyuan Image: family-specific natural-language guidance.
- Unknown/custom checkpoints: conservative generic guidance; no assumed trigger syntax.

## Output and safeguards

- Final generation prompt is English; explicitly requested text inside the image remains unchanged.
- The optimizer preserves subject, identity, count, relationships, pose, action, setting, framing and explicit constraints.
- It improves only relevant visual details and avoids unsupported additions, repetition, contradictions and generic filler.
- Output is positive-prompt text only; the user's existing negative prompt is not overwritten.
- Local Qwen uses a 3,072-token context and up to 384 output tokens. GPU exclusivity and existing RAM guards remain in force; if the PS5 does not have sufficient free RAM, optimization fails safely and does not start Qwen.

## Verification

- `scripts/test-image-prompt-profile.mjs`: model-family classification, profile sanitization and model-specific system prompts.
- `scripts/test-image-prompt-workflow.mjs`: request context, endpoint integration and Image Studio workflow.
- `scripts/test-krea-prompt-flow.mjs` and `scripts/test-krea-prompt-optimizer.mjs`: existing Krea workflows and provider logic.

## Comparative prompt-quality smoke test (2026-11-05)

The same Dutch scene request was passed through all five family-specific system prompts using the free OpenRouter model `recursive/flint-v1.0:free` (provider: Recursive), with the same input and generation settings. This tests the profile instructions and the resulting prompt text; it does **not** measure final image quality or local Qwen output.

- Krea 2 / SickRealism: retained all key scene constraints and produced a natural, compact photographic description.
- FLUX: produced a fluent natural-language prompt with a restrained amount of extra scene detail.
- SDXL: produced a concise, high-signal prompt without the repeated object/scene phrases seen in the first comparison.
- Pony / Illustrious: preserved the explicitly requested photorealistic style rather than forcing anime styling.
- SD 1.5: produced the shortest, most compact prompt, suitable for a model that benefits from high-signal descriptors.

The first comparison exposed irrelevant material/detail additions and repetition in some outputs. The shared system prompt was tightened to forbid invented object-design details, irrelevant material categories and repeated visual facts. The second comparison returned usable outputs for all five families.

Local Qwen was not started for this comparison: the PS5's available RAM was below its 5.5 GiB startup safety threshold during the test. No memory guard was lowered. The external comparison used the configured free OpenRouter route and did not incur model charges. Final image quality still requires actual generation on each checkpoint.

## Image runtime handoff

Image Studio uses the selected checkpoint as the source of truth for the complete prompt-optimization cycle:

1. The user selects a checkpoint and configures its VAE, conditioning assets, LoRAs and generation settings.
2. The server validates and snapshots the selected checkpoint and runtime assets.
3. To preserve GPU exclusivity, the active text and image runtimes are stopped before the temporary local Qwen prompt model starts. Active video/upscale jobs and active image-generation jobs are not interrupted; the handoff is rejected while those jobs are running.
4. Qwen receives the checkpoint-family profile and the selected generation context.
5. Qwen exits and its GPU memory is released. The server reloads the exact selected checkpoint and the captured VAE / ControlNet / IP-Adapter / CLIP Vision selections before returning the optimized prompt.
6. Automatic mode generates immediately after the restored image runtime is confirmed. Review and manual modes restore the image model first, then let the user approve or edit the prompt before generation.

The handoff is serialized. Manual model load/unload and generation requests are rejected while the temporary swap is in progress, preventing a second action from racing the restore. The same path is used for SD 1.5, SDXL, FLUX, Krea 2, Qwen-Image and other supported checkpoint families; the prompt system profile is selected from the chosen checkpoint, not from a hard-coded Krea 2 route.