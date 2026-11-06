---
base_model: krea/Krea-2-Turbo
base_model_relation: adapter
license: other
license_name: krea-2-community-license
license_link: https://huggingface.co/lvladikov/Krea2-Turbo-Distill-2step-LoRA/blob/main/LICENSE.pdf
library_name: diffusers
tags:
  - lora
  - text-to-image
  - distillation
  - step-distillation
  - distribution-matching
  - krea-2
pipeline_tag: text-to-image
---

# Krea 2 Turbo — 2-Step Distillation LoRA

> 🆕 **New: a [3-step LoRA](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-3step-LoRA)** takes Krea 2 Turbo from 8 steps down to 3, one step more than this LoRA, with more fine detail than both this and the 4-step LoRA (fine texture 1.23× the 8-step teacher's on its 22 test prompts). This 2-step LoRA stays the fastest of the three.

**A quarter of the steps · 4× faster denoising (text encoding and VAE decode excluded) · fine detail at 0.92–1.02× the teacher's across all 12 trained resolutions, the grid bands at its level · colour close to the teacher's · 1 point missing of 352 on a blind prompt-adherence rubric · teacher preferred on 12 of 66 judged renders · 51,195 training samples on recorded teacher trajectories · 32 days on one RTX 3090 · released from settled weights; the project's final checkpoint.**

A LoRA for **[Krea 2 Turbo](https://huggingface.co/krea/Krea-2-Turbo)** that takes the model from **8 steps down to 2** — Turbo's own weights and sigmas, guidance 0.0, a quarter of the denoising passes — aiming at the best quality two steps can give. It is for **fast previews and drafts**; the **[4-step LoRA](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-4step-LoRA)** remains the recommendation for quality renders.

- ⚡ **A quarter of the steps** — 8 → 2, on Turbo's own deployment sigmas `[1.0, 0.7595]`
- ⏱️ **4× faster denoising** — 56.9 s → 14.3 s at 1024×1024 (float16 compute), text encoding and VAE decode excluded, as they take the same time at any step count; the adapter's own cost per call is within measurement noise
- 🎯 **Fine detail near the teacher's level** — **0.92–1.02×** the teacher's fine-texture energy across the 12 trained resolutions (stock Turbo at 2 steps: **0.40–0.65×**), the 16- and 8-pixel grid bands at the teacher's level and ghosting closer to it at 11 of 12 sizes
- 📊 **Distribution matching, not imitation** — matches what the teacher would plausibly produce rather than its exact trajectory, so the student commits instead of averaging into blur and doubled edges
- 🗣️ **Prompt-conditioned throughout** — teacher and fake scores both read each prompt's conditioning; a blind rubric finds **1 point missing of 352** (objects, counts, attributes, relations), and a judge prefers the 8-step teacher on **12 of 66** (4-step adapter: 6 of 45, on the original 15 prompts), mostly on style
- 📐 **12 trained resolutions** — multi-aspect from 512×512 up to 1440×1440
- 🔌 **Drop-in, no exceptions** — plain LoRA, stock Euler, diffusers / ComfyUI / MLX. No custom nodes, no custom sampler
- 🧬 **Same shape as the [4-step adapter](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-4step-LoRA)** — rank 64 on the same 228 modules
- 🎲 **23,561 recorded teacher trajectories** — the 4-step project's 13,750 and 9,811 minted for this one on the same prompt bank; since 3 Oct each trained once
- 🔢 **51,195 training samples** in the 2-step stages, starting from the released 4-step adapter's weights
- 📅 **32 days** from the first 2-step launch to this final checkpoint, on a single RTX 3090
- 🔁 **More than forty recipe adjustments** across two methods — each kept only when the renders did not get worse
- 🧘 **Settled weights, not an average** — released from a 600-sample anneal in which the learning rate is taken to zero over already-trained data, so the published weights are the training weights at rest; a running average is kept only as the check that must agree with them

> 🧪 **Fast-preview adapter; the project's final checkpoint.** Subjects that are close and fill a good part of the frame — a portrait, a single figure, an object up close — hold up well at two steps. Small subjects are where it still falls short: faces in a crowd or figures in a wide scene can come out ghosted or smeared. For those, and whenever quality matters more than speed, use the [4-step LoRA](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-4step-LoRA). This checkpoint closes the project; its successor is the [3-step LoRA](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-3step-LoRA). See [Known Issues](#known-issues).
>
> 📐 **The saved steps can also go into resolution.** A larger render makes a small subject bigger, and at a quarter of the teacher's steps, renders up to 2048×2048 — Krea's published maximum recommended resolution, beyond this adapter's largest trained size — come within easy reach. Past 2048×2048, stock Krea 2 itself begins to duplicate subjects, with or without this adapter.

[![The 22 test prompts, rendered by Krea 2 Turbo with this LoRA at 2 steps](assets/thumbs/poster.jpg)](assets/poster.jpg)

---

## Files

| file                                                                                                     | what it is                                                                                     |
| -------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `krea2_turbo_2step_rank_64_lora.safetensors`                                                             | LoRA in diffusers key format — see [diffusers](#diffusers)                                     |
| `krea2_turbo_2step_rank_64_lora_comfyui.safetensors`                                                     | Same weights under ComfyUI key names — see [ComfyUI](#comfyui)                                 |
| `krea2_turbo_2step_lora_t2i.json`                                                                        | Ready ComfyUI workflow, stock nodes only                                                       |
| [`krea2_turbo_2step_rank_64_lora_checkpoint_info.md`](krea2_turbo_2step_rank_64_lora_checkpoint_info.md) | **Which checkpoint the two weight files are** — the project's final checkpoint, `chk00051195`   |
| `LICENSE.pdf`                                                                                            | Krea 2 Community License Agreement                                                             |
| `NOTICE.txt`                                                                                             | Required attribution notice                                                                    |

Both weight files are one adapter — only key names differ. Both carry training details in safetensors metadata. The file names carry no checkpoint number: both hold the project's final checkpoint, `chk00051195`, and every checkpoint published over the project's life, this one included, sits in [`_archive/checkpoints/`](_archive/checkpoints/) under its number.

---

## Quick Start

### diffusers

```bash
pip install git+https://github.com/huggingface/diffusers.git
```

```python
import torch
from diffusers import Krea2Pipeline
from huggingface_hub import hf_hub_download
from safetensors.torch import load_file

pipe = Krea2Pipeline.from_pretrained("krea/Krea-2-Turbo", torch_dtype=torch.bfloat16).to("cuda")

lora = hf_hub_download("lvladikov/Krea2-Turbo-Distill-2step-LoRA", "krea2_turbo_2step_rank_64_lora.safetensors")
state = load_file(lora)
state = {f"transformer.{k}": v for k, v in state.items() if not k.endswith(".alpha")}
pipe.load_lora_weights(state, adapter_name="2step")

image = pipe("a fox in the snow", num_inference_steps=2, guidance_scale=0.0).images[0]
image.save("krea2_2step.png")
```

- **`num_inference_steps=2` is the whole config.** Pipeline applies Turbo's fixed timestep shift (μ = 1.15) and evaluates at σ = 1.0, 0.7595 — exactly the two points the LoRA was trained on. Keep `guidance_scale=0.0`.
- Strength: `pipe.set_adapters(["2step"], adapter_weights=[0.75])`. Stock Turbo for comparison: `pipe.unload_lora_weights()` + `num_inference_steps=8`.
- Use the diffusers file, not `_comfyui` — diffusers reads Krea's own key naming, not ComfyUI's `lora_down`/`lora_up`.

### ComfyUI

| file                                                                                                                         | put it in                          |
| ---------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| `krea2_turbo_2step_rank_64_lora_comfyui.safetensors`                                                                         | `ComfyUI/models/loras/`            |
| `krea2_turbo_bf16.safetensors` (from [Comfy-Org/Krea-2](https://huggingface.co/Comfy-Org/Krea-2/tree/main/diffusion_models)) | `ComfyUI/models/diffusion_models/` |
| `qwen3vl_4b_bf16.safetensors` (same repo)                                                                                    | `ComfyUI/models/text_encoders/`    |
| `qwen_image_vae.safetensors` (same repo)                                                                                     | `ComfyUI/models/vae/`              |

Load [`krea2_turbo_2step_lora_t2i.json`](krea2_turbo_2step_lora_t2i.json). Full bf16, no quantisation, runs on CUDA / Apple Silicon / CPU unchanged. Smaller Turbo builds work too — ComfyUI's loader applies the LoRA to any build — except `fp8_scaled` on Apple Silicon (MPS has no `Float8_e4m3fn`).

**Settings:** steps **2**, **cfg 1.0**, sampler `euler` / `simple`, LoRA strength **1.0**.

> ⚙️ **cfg 1.0, not 0.0.** ComfyUI expresses "no CFG" as 1.0 (one forward pass); diffusers uses 0.0. Setting 0.0 in ComfyUI is not the same thing.

### Using it on Raw

Trained on Turbo, for Turbo — it loads on **Krea 2 Raw** because the architecture is shared, a side effect rather than a supported mode: it is neither trained nor tuned for Raw's weights, steps or guidance.

---

## Performance (1024×1024, Apple Silicon MLX, float16 compute)

|                               | denoise    | per model call | GPU peak |
| ----------------------------- | ---------- | -------------- | -------- |
| Turbo 8 steps (quality bar)   | 56.9 s     | 7.1 s          | 25.2 GiB |
| Turbo 2 steps, no LoRA        | 14.2 s     | 7.1 s          | 25.2 GiB |
| **Turbo 2 steps + this LoRA** | **14.3 s** | 7.2 s          | 25.2 GiB |

**Denoising is 4.0× faster than the 8-step bar** — two model calls instead of eight. The adapter adds no measurable cost per call and no measurable memory. Measured with the runtime's float16 compute inside attention and the feed-forward (its default since 8 Oct 2026); the previous card's 76.4 s / 19.3 s were bfloat16 compute on the same machine, the same 4.0×.

Text encoding and VAE decode are not in these timings: they take the same time at any step count, so a whole render, end to end, gains less than 4× and rises toward it as the render grows. Denoise times at every trained resolution (6.8 s at 512×512 to 37.3 s at 1440×1440, bfloat16 compute as the sweeps are rendered) are in the [Detailed Model Card](DETAILED-README.md).

---

## LoRA Strength

| strength      | what happens                                                                                                             |
| ------------- | ------------------------------------------------------------------------------------------------------------------------ |
| **below 1.0** | Correction only partly applied — softer skin and hair, less fine structure, closer to 2 steps without the adapter        |
| **1.0**       | Trained point, recommended                                                                                               |
| **1.0–1.5**   | Extrapolation — texture denser than the subject warrants, fine structure reads wiry rather than sharp. Usable per prompt |
| **above 1.5** | Not recommended, not measured                                                                                            |

At two steps the dial scales the adapter's whole job — turning two coarse calls into a finished image — so there is less reason to go below 1.0 than with a 4-step adapter. Reach for **steps before strength**: when quality matters more than speed, the [4-step adapter](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-4step-LoRA) is the better tool.

[![LoRA strength comparison](assets/thumbs/portrait_strength_sweep.jpg)](assets/portrait_strength_sweep.jpg)

---

## Released Checkpoint

**`chk00051195`** (9 Oct 2026) replaces `chk00041320` (2 Oct 2026). It is 9,875 training samples later, and the first checkpoint released from the training weights themselves rather than from their running average: its last 600 samples ran with the learning rate taken to zero over already-trained data, so the weights are at rest, and the running average kept beside them (restarted at the anneal's start) agrees with them — the doubled subject the average used to draw when the weights changed pose can no longer form. The samples before the anneal went to data this adapter had never seen (every remaining recorded trajectory, each trained once), to the distribution push projected in its layout band, and to small faces weighted up in the anchor.

| axis | `chk00041320` | `chk00051195` |
| --- | --- | --- |
| structure renders with a fault the teacher's does not have (of 21, checked at 1:1) | 0 | **0** |
| ghosting, blur-invariant index, sweep mean | 1.21× | **1.15×** |
| 16-px / 8-px grid bands vs the teacher, sweep mean | 1.02× / 1.06× | **1.00× / 1.00×** |
| small faces in crowds drawn whole (15 scenes at 1280², detector) | 0.59 | **0.63** (teacher 0.64) |
| small faces, equivalent blur | 1.30 px | **1.02 px** (teacher 0.55) |
| market faces at 1280², layout closeness to the teacher | 0.79 | 0.79 |
| fine texture vs the teacher, sweep mean | 1.02× | 0.97× |
| fine texture vs the teacher, 1440² | 1.03 | 0.97 |
| grain in flat areas, sweep mean | 1.03× | 0.97× |
| judge prefers the teacher (of 66) | 11 (same run) | 12 |
| blind adherence rubric, points missing of 352 | 2 | **1** |
| saturation vs the teacher, sweep mean | 0.99× | 0.98× |
| distance to the teacher, sweep mean | 0.41 | 0.41 |
| training samples in the 2-step stages | 41,320 | 51,195 |

Steadier at every size: the excess energy two steps put into the grid bands is gone (both bands at the teacher's level), ghosting is closer to the teacher at 11 of 12 sizes, the structure is clean, and the small faces in crowd scenes come out whole more often with less equivalent blur. The costs are stated plainly: the fine texture now sits a few percent under the teacher's where the previous checkpoint sat at it — most at the 1280-class sizes — and the judge's preference for the teacher is level with the previous checkpoint's, 12 of 66 against 11 in the same run. [`krea2_turbo_2step_rank_64_lora_checkpoint_info.md`](krea2_turbo_2step_rank_64_lora_checkpoint_info.md) always names the checkpoint in the weight files; the full comparison is in the [Detailed Model Card](DETAILED-README.md#chk00051195-vs-chk00041320).

---

## Known Issues

The usual costs of two steps, in order of how often they show:

- **Small subjects** — the weak spot, people and objects alike. Faces in a crowd, a figure in a wide scene, the machines at the back of a room can come out ghosted, smeared or misshapen; a portrait-sized face or an object up close holds up
- **Fine structure** — feathers, hair strands and signage can be soft or a few pixels out of register, most at 1280×1280 and above; a faint doubled contour can show on limbs
- **Fine texture at the large sizes** — at four of the five largest sizes the fine-texture energy sits under the teacher's (1280×960 0.92×, 1280×1280 0.95×, 1440×1280 0.96×, 1440×1440 0.97×; 960×1280 1.02×), so skin and hair read a little smoother there than in the previous checkpoint, which sat at or above the teacher's at those sizes; the grid bands at the same sizes are at the teacher's level
- **Style** — on stylised prompts, _how_ the picture should look (crisp linework, brush strokes, fingerprints in clay, a matte-painting finish) is followed less faithfully than _what_ should be in it
- **Repeats** — on busy action or crowd scenes the composition can repeat itself: an extra hand or held object, a figure duplicated in a crowd
- **Different composition** — two steps is a shorter path from the same noise, so framing, pose or arrangement can differ from the 8-step render at the same seed. Treat the teacher's render as a quality reference, not the picture two steps will reproduce
- **Skin** — smoother than the teacher's at the larger sizes, the pores softer, though its colour is now close to the teacher's; freckles come out as dots, softer than the teacher's

These are the final checkpoint's limits, stated as they are; none is hidden in the sweeps or the examples.

---

## Method

**Distribution matching (DMD2 family) with a trajectory anchor**, Krea 2 Turbo as its own teacher, on the recorded 8-step trajectories.

The student makes two calls, at σ = 1.0 and 0.7595 — the first and fifth points of the teacher's 8-step grid at μ = 1.15 — with stock Euler between them. Euler's first step lands **exactly** on the flow-matching interpolant at σ = 0.7595, so the first call's output is a legitimate image prediction and is judged as one.

- **Distribution term** — the frozen teacher and a _fake-score_ adapter (rank 32, trained online on the student's current output, 3 updates per student step, discarded at the end) each denoise a freshly noised copy of the student's image; where they disagree is the direction toward the teacher's work. Averaging is never rewarded, so the student commits
- **Trajectory anchor** — regression on the recorded chords at half weight keeps the student on the teacher's two-step grid

**On top, each capped relative to the distribution term:**

- **Spectral match** — student and teacher images compared through radial power spectra, on the whole latent and a decoded 256-px window, two-sided — the term that reached the 16/8-px grid grain at large sizes
- **Eight critics taking turns** — artefact, photo (half real photographs), large faces, the first call's layout against the teacher's own state, content, prompt, text, and the teacher's own finish, all heads on the frozen base's mid-network features; one pushes per step, each filtered and capped
- **Detail held to the teacher region by region** — the anchor counts fine-detail error twice (3.5× where the teacher is most detailed); a one-sided photo floor at 3–10 px and a per-tile ceiling at 1.3×; a direction-aware term; windows on eyes, nose and lips; the teacher's finish of the student's first call as the second call's target; a smoothness limit on the fake adapter
- **Colour band** — saturation held between the teacher's own level and 8% above it
- **Layout at the large sizes** — at every size with a 1280- or 1440-px side the distribution term pushes at half strength while the anchor keeps full weight, and the anchor counts the second call's coarse layout (64 px and up) twice
- **The push projected in its layout band** — the part of the distribution push that points along the fake score's own error is removed in the coarse layout band (64 px and up); the finer bands keep the full push
- **Small faces weighted up** — the anchor counts the error inside detected faces under 64 px four times
- **Every never-trained trajectory once** — since 3 Oct every training sample is a recorded teacher trajectory this adapter had not seen, each (prompt, call) pair trained once; the anneal replays already-trained pairs

Shipped weights are **the training weights at the end of a 600-sample anneal** — the learning rate taken to zero over already-trained data, the running average restarted at the anneal's start and agreeing with the live by its end — not a running average of training. A running average smooths single steps but, while the weights move between two layouts of the same prompt, draws both; an anneal settles the weights on one.

---

## What the LoRA Touches

Rank **64**, alpha = rank (scale 1.0), bf16 — the same **228 modules** as the [4-step adapter](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-4step-LoRA):

- **224 block linears** — all 28 transformer blocks: `to_q`, `to_k`, `to_v`, `to_gate`, `to_out.0`, `ff.gate`, `ff.up`, `ff.down`
- **4 global linears** — `time_embed.linear_1`, `time_embed.linear_2`, `time_mod_proj`, `final_layer.linear` — the ones a step-count change needs most

Nothing about the base model changes.

---

## Training Data

- **23,561 recorded teacher trajectories** — the [4-step project](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-4step-LoRA)'s 13,750 and 9,811 minted for this one, prompts from [Lakonik/t2i-prompts-3m](https://huggingface.co/datasets/Lakonik/t2i-prompts-3m) — Turbo's own 8 steps at μ = 1.15, guidance 0.0, every latent and velocity stored; a 2-step chord is two 4-step chords end to end. Since 3 Oct every training sample is a trajectory this adapter had never seen, each (prompt, call) pair trained once
- **203 held-out prompts** — measure the student–teacher gap, never receive a gradient
- **43,044 real-photo crops** from the 4-step project — set the photo floor (one precomputed statistic) and make up half of the photo critic's real examples

Only the photo critic's head sees the photos; the student and the fake adapter receive only its filtered, capped push. No new prompts or text embeddings; the trajectories minted for this project use the same teacher, settings and prompt bank.

---

## Resolutions (12 buckets)

|           |           |           |
| --------- | --------- | --------- |
| 512×512   | 512×768   | 768×512   |
| 768×768   | 768×1024  | 1024×768  |
| 1024×1024 | 960×1280  | 1280×960  |
| 1280×1280 | 1440×1280 | 1440×1440 |

Same 12 buckets as the 4-step adapter, with the larger sizes and stylised prompts drawn more often: 1440×1440 about 6% of the samples, 1024×1024 and 768×1024 12% each, stylised prompts 12%.

---

## Hardware

Trained on a **single RTX 3090 (24 GB)**. Frozen base **weight-only int8**. Every term fits up to 1440×1440 via:

- Checkpointed block inputs staged to pinned host memory above 0.3 MP
- Student, fake adapter, spectral and detail terms, critic and teacher finish each build and free their own graph — peaks never overlap
- Hard memory ceiling below the driver's paging threshold, so a step that doesn't fit fails loudly

A full step with every term live reserves ~22.4 GB at 1440×1440. Throughput is **~58 samples/hour** against the 4-step recipe's 470 — roughly a dozen model runs per sample instead of two. That is the objective's cost, not teacher generation: the trajectories were recorded once and are read from disk.

Released LoRA is **bf16**.

---

## Usage Notes

- 🎯 **Krea 2 Turbo only** — trained against Turbo's weights and schedule; on Raw it is a side effect (see [Using it on Raw](#using-it-on-raw))
- 🚫 **Keep guidance at 0.0** (ComfyUI: **cfg 1.0**, not 0.0)
- 📐 **Keep μ = 1.15** — the two training sigmas are anchored to that grid
- 🧪 **The project's final checkpoint** — for previews and drafts; the [4-step LoRA](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-4step-LoRA) remains the recommendation for quality renders
- 🔬 Training used an int8 base; released LoRA is bf16

---

## Examples

Every sheet below: base model (8 steps), base at 2 steps **without** LoRA, base at 2 steps **with** LoRA — same seed throughout. Compare panels 2 vs 3 to isolate LoRA effect; panel 1 is the quality bar, not a pixel target. NFE = steps (Turbo is CFG-free).

### Portrait of a young woman with freckles and windswept auburn hair...

[![portrait comparison](assets/thumbs/portrait_compare_turbo.jpg)](assets/portrait_compare_turbo.jpg)

| Turbo 8 steps                                                                         | Turbo 2 steps, no LoRA                                                                | **Turbo 2 steps + LoRA**                                                                               |
| ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| [![8 steps](assets/thumbs/portrait_turbo_8step.jpg)](assets/portrait_turbo_8step.jpg) | [![2 steps](assets/thumbs/portrait_turbo_2step.jpg)](assets/portrait_turbo_2step.jpg) | [![2 steps + LoRA](assets/thumbs/portrait_turbo_2step_lora.jpg)](assets/portrait_turbo_2step_lora.jpg) |

---

### Kingfisher bursting out of water...

[![kingfisher comparison](assets/thumbs/kingfisher_compare_turbo.jpg)](assets/kingfisher_compare_turbo.jpg)

| Turbo 8 steps                                                                             | Turbo 2 steps, no LoRA                                                                    | **Turbo 2 steps + LoRA**                                                                                   |
| ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| [![8 steps](assets/thumbs/kingfisher_turbo_8step.jpg)](assets/kingfisher_turbo_8step.jpg) | [![2 steps](assets/thumbs/kingfisher_turbo_2step.jpg)](assets/kingfisher_turbo_2step.jpg) | [![2 steps + LoRA](assets/thumbs/kingfisher_turbo_2step_lora.jpg)](assets/kingfisher_turbo_2step_lora.jpg) |

---

### Rainy night city street with glowing neon signs...

[![neonstreet comparison](assets/thumbs/neonstreet_compare_turbo.jpg)](assets/neonstreet_compare_turbo.jpg)

| Turbo 8 steps                                                                             | Turbo 2 steps, no LoRA                                                                    | **Turbo 2 steps + LoRA**                                                                                   |
| ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| [![8 steps](assets/thumbs/neonstreet_turbo_8step.jpg)](assets/neonstreet_turbo_8step.jpg) | [![2 steps](assets/thumbs/neonstreet_turbo_2step.jpg)](assets/neonstreet_turbo_2step.jpg) | [![2 steps + LoRA](assets/thumbs/neonstreet_turbo_2step_lora.jpg)](assets/neonstreet_turbo_2step_lora.jpg) |

---

### (19 more examples, and a two-panel sheet against the teacher for every prompt, in the [full version](DETAILED-README.md) — see [assets/](assets/) for all 22 prompts)

---

## Resolution Sweeps

[`assets/resolution_sweeps/`](assets/resolution_sweeps/) — **this LoRA at every trained resolution for all 22 test prompts** (same prompts, seed, 2 steps, strength 1.0). Nothing cherry-picked.

[`_teacher-8step/`](assets/resolution_sweeps/_teacher-8step/) — official Krea 2 Turbo 8-step reference renders for the same prompts/seeds/resolutions. [`_turbo-base-NO-LoRA-2step/`](assets/resolution_sweeps/_turbo-base-NO-LoRA-2step/) — stock Turbo at 2 steps, the floor.

Layout:

```
assets/resolution_sweeps/
├── _teacher-8step/              8-step stock Turbo reference
│   ├── 512x512/
│   ├── 1024x1024/
│   └── ... (all 12 buckets)
├── _turbo-base-NO-LoRA-2step/   Same tree, stock Turbo at 2 steps (the floor)
└── 2step-LoRA/                  Same tree, this LoRA at 2 steps (the published checkpoint)
```

---

## Archive

Every published checkpoint and its resolution sweep under [`_archive/`](_archive/) — [`checkpoints/`](_archive/checkpoints/) and [`resolution_sweeps/`](_archive/resolution_sweeps/), each under its number; the final checkpoint's sweep is `chk51195-final`, kept beside the teacher's and the stock 2-step trees it was measured against. The earlier checkpoints are superseded, not maintained.

---

## Closing note

This checkpoint closes the 2-step project. Its successor is the [3-step LoRA](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-3step-LoRA), built on what these two adapters taught. What two steps get wrong is stated under [Known Issues](#known-issues) — small subjects in wide scenes, the fine texture at the middle sizes, the finest edges and skin texture at the largest sizes, the tactile surface of stylised materials such as clay — and is left as it is. The [4-step adapter](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-4step-LoRA) remains the recommendation for quality renders; this one is the fast preview.

---

## Detailed Model Card

For more details, if interested, have a look at the [Detailed Model Card](DETAILED-README.md).

---

## License

This adapter is a **Derivative of Krea 2 Turbo** under the [Krea 2 Community License Agreement](LICENSE.pdf). Everything the agreement says about Krea 2 Turbo applies to this LoRA: [Acceptable Use Policy](https://krea.ai/krea-2-use-policy), revenue threshold for commercial use, content-filtering duty for deployments.

Copy of agreement: [`LICENSE.pdf`](LICENSE.pdf), required notice: [`NOTICE.txt`](NOTICE.txt). See [krea.ai/krea-2-licensing](https://krea.ai/krea-2-licensing).

**Not an official Krea product, not endorsed by Krea.** Base model is Krea's; adapter weights and everything else in this repo are mine.
