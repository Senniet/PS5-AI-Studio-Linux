---
base_model: krea/Krea-2-Turbo
base_model_relation: adapter
license: other
license_name: krea-2-community-license
license_link: https://huggingface.co/lvladikov/Krea2-Turbo-Distill-4step-LoRA/blob/main/LICENSE.pdf
library_name: diffusers
tags:
  - lora
  - text-to-image
  - distillation
  - step-distillation
  - krea-2
pipeline_tag: text-to-image
---

# Krea 2 Turbo — 4-Step Distillation LoRA

> 🆕 **New: a [3-step LoRA](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-3step-LoRA)** takes Krea 2 Turbo from 8 steps down to 3, at three quarters of this LoRA's denoising time, with more fine detail (fine texture 1.23× the 8-step teacher's on its 22 test prompts). This 4-step LoRA stays the closest to Turbo's own 8-step pictures.

**Half the steps · ~1.6× faster end to end · 45% of the gap to the 8-step teacher closed · texture at 1.03× the teacher's, verified clean · teacher preferred on only 6 of 45 judged renders · 12 trained resolutions · 78,000 training samples · 21 days on one RTX 3090.**

A LoRA for **[Krea 2 Turbo](https://huggingface.co/krea/Krea-2-Turbo)** that reduces the minimum usable step count from **8 to 4** — Turbo's own model and sigmas, half the denoising passes, and the fine texture that 4-step Turbo loses put back.

- ⚡ **Half the steps** — 8 → 4, on Turbo's own deployment sigmas
- ⏱️ **~1.6× faster end to end** — 54.5 s vs 88.7 s at 1024×1024 for the whole run, model load, text encoding and VAE decode included (1.8× on denoise alone, without them)
- 🎯 **Texture as good as the teacher or better** — **1.03×** the teacher's fine-texture energy at 1280² and 1440², every frequency band within 10%; verified clean: saturation **0.96–0.97×**, **fewer** clipped highlights/shadows, skin texture **0.97–0.99×**
- 📏 **45% of the 4-step gap closed** — held-out velocity error fell from **4.70e-02** (stock Turbo at 4 steps) to **2.59e-02** with the LoRA; VLM judge preferred teacher on only **6 of 45** renders (37 ties, 2 LoRA wins)
- 🗣️ **Prompt-aware training** — critic scores images against their prompts during training
- 📐 **12 trained resolutions** — multi-aspect from 512×512 up to 1440×1440
- 🔌 **Drop-in** — plain LoRA weights for diffusers and ComfyUI. No custom nodes, no patched sampler, no code
- 🎲 **13,750 prompts** from [Lakonik's 3M-prompt dataset](https://huggingface.co/datasets/Lakonik/t2i-prompts-3m), each recorded as a full 8-step teacher trajectory
- 📷 **43,044 real-photo crops** — 25,560 from LSDIR + 17,484 from Flickr2K, captioned, in critic's real set
- 🔢 **78,000 training samples** in shipped weights
- 📅 **21 days** on a single RTX 3090
- 🔁 **16 recipe adjustments** — each made on measurement of the one before

> 💡 **Too strong on a prompt? Turn it down.** The LoRA restores fine texture, and on some subjects — stylised art, high-contrast splash pieces, very large renders — that can read as too much at strength 1.0. Effect scales smoothly: **0.75** is a good second setting, 0.6–0.9 is fair game.

[![The 15 test prompts, rendered by Krea 2 Turbo with this LoRA at 4 steps](assets/thumbs/poster.jpg)](assets/poster.jpg)

---

## Files

| file                                                 | what it is                                                     |
| ---------------------------------------------------- | -------------------------------------------------------------- |
| `krea2_turbo_4step_rank_64_lora.safetensors`         | LoRA in diffusers key format — see [diffusers](#diffusers)     |
| `krea2_turbo_4step_rank_64_lora_comfyui.safetensors` | Same weights under ComfyUI key names — see [ComfyUI](#comfyui) |
| `krea2_turbo_4step_lora_t2i.json`                    | Ready ComfyUI workflow, stock nodes only                       |
| `LICENSE.pdf`                                        | Krea 2 Community License Agreement                             |
| `NOTICE.txt`                                         | Required attribution notice                                    |

Both weight files are one adapter — only key names differ. Both carry training details in safetensors metadata.

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

lora = hf_hub_download("lvladikov/Krea2-Turbo-Distill-4step-LoRA", "krea2_turbo_4step_rank_64_lora.safetensors")
state = load_file(lora)
state = {f"transformer.{k}": v for k, v in state.items() if not k.endswith(".alpha")}
pipe.load_lora_weights(state, adapter_name="4step")

image = pipe("a fox in the snow", num_inference_steps=4, guidance_scale=0.0).images[0]
image.save("krea2_4step.png")
```

- **`num_inference_steps=4` is the whole config.** Pipeline applies Turbo's fixed timestep shift (μ = 1.15) and evaluates at σ = 1.0, 0.905, 0.760, 0.513 — exactly the four points the LoRA was trained on. Keep `guidance_scale=0.0`.
- Strength: `pipe.set_adapters(["4step"], adapter_weights=[0.75])`. Stock Turbo for comparison: `pipe.unload_lora_weights()` + `num_inference_steps=8`.

### ComfyUI

| file                                                                                                                         | put it in                          |
| ---------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| `krea2_turbo_4step_rank_64_lora_comfyui.safetensors`                                                                         | `ComfyUI/models/loras/`            |
| `krea2_turbo_bf16.safetensors` (from [Comfy-Org/Krea-2](https://huggingface.co/Comfy-Org/Krea-2/tree/main/diffusion_models)) | `ComfyUI/models/diffusion_models/` |
| `qwen3vl_4b_bf16.safetensors` (same repo)                                                                                    | `ComfyUI/models/text_encoders/`    |
| `qwen_image_vae.safetensors` (same repo)                                                                                     | `ComfyUI/models/vae/`              |

Load [`krea2_turbo_4step_lora_t2i.json`](krea2_turbo_4step_lora_t2i.json). Full bf16, no quantisation, runs on CUDA / Apple Silicon / CPU unchanged.

**Settings:** steps **4**, **cfg 1.0**, sampler `euler` / `simple`, LoRA strength **1.0**.

> ⚙️ **cfg 1.0, not 0.0.** ComfyUI expresses "no CFG" as 1.0 (one forward pass); diffusers uses 0.0. Setting 0.0 in ComfyUI is not the same thing.

---

## Performance (1024×1024, Apple Silicon MLX bf16)

|                               | load  | denoise | **total**  |
| ----------------------------- | ----- | ------- | ---------- |
| Turbo 8 steps (quality bar)   | 8.2 s | 77.5 s  | **88.7 s** |
| Turbo 4 steps, no LoRA        | 7.8 s | 38.8 s  | **49.7 s** |
| **Turbo 4 steps + this LoRA** | 7.3 s | 44.0 s  | **54.5 s** |

**4 steps with LoRA is ~1.6× faster than the 8-step bar** end to end (54.5 s vs 88.7 s): the total includes model load, text encoding and VAE decode, which take the same time at any step count. Denoise alone, without them: 1.8× (44.0 s vs 77.5 s).

Per-step cost: 9.7 s → 11.0 s (~13% slower), plus ~1.3 GB peak memory. Loading the LoRA costs nothing measurable. Halving steps wins comfortably.

---

## LoRA Strength

| strength      | what happens                                                                                                           |
| ------------- | ---------------------------------------------------------------------------------------------------------------------- |
| **below 1.0** | Correction partly applied — output between unassisted 4-step and full LoRA. **0.75** for when 1.0 is too textured/hard |
| **1.0**       | Trained point, recommended                                                                                             |
| **1.0–1.5**   | Extrapolation — surface detail denser, micro-contrast harder, coherent but stylised                                    |
| **above 1.5** | **Not recommended** — breaks into uniform speckle/noise over whole image                                               |

Reach for **steps before strength**: 1.0 at more steps is the dependable way to get more. Strength and step count trade against each other.

[![LoRA strength comparison](assets/thumbs/portrait_strength_sweep.jpg)](assets/portrait_strength_sweep.jpg)

---

## Method

**Progressive distillation** with Krea 2 Turbo as its own teacher. Teacher ran 8 steps at μ = 1.15, guidance 0.0; full trajectory recorded. Student trained to cover **two teacher steps in one**:

```
v_target = (x_{i+2} − x_i) / (σ_{i+2} − σ_i)
```

The even indices of the 8-step schedule are **precisely** the four sigmas the 4-step student deploys on — no interpolation, no schedule mismatch.

**Critic (LADD-style)** on frozen Turbo features at block 14:

- Real: teacher finals (unpaired) **or** real photographs (half the draws), re-noised to σ ∈ [0.02, 0.5]
- Fake: student's predicted clean latent
- Prompt-aware head reads pooled text vector; mismatch term forces real images under wrong prompts to read fake
- Real photos captioned so they participate in prompt-aware term

**Three key weight choices:**

- Final chord (σ = 0.513, decides fine texture) weighted **3×** in PD loss
- Low-frequency anchor on large buckets (weight 0.2) — structure held to teacher, fine band free
- Shipped adapter is **Polyak (EMA) average** (decay 0.999), not last live state

---

## What the LoRA Touches

Rank **64**, alpha = rank (scale 1.0), bf16. **228 modules**:

- **224 block linears** — all 28 transformer blocks: `to_q`, `to_k`, `to_v`, `to_gate`, `to_out.0`, `ff.gate`, `ff.up`, `ff.down`
- **4 global linears** — `time_embed.linear_1`, `time_embed.linear_2`, `time_mod_proj`, `final_layer.linear`

The global linears are included deliberately. Measuring Krea's own Raw→Turbo delta:

| layer                 | relative ‖ΔW‖/‖W‖                      |
| --------------------- | -------------------------------------- |
| `time_embed.linear_2` | **0.0777** ← largest change in network |
| `time_embed.linear_1` | 0.0429                                 |
| `final_layer.linear`  | 0.0265                                 |
| typical block linear  | ~0.014                                 |

`time_embed.linear_2` moves ~5.5× more than any block linear. Changing step count is largely a change to how the model reads the timestep — a LoRA freezing the timestep path withholds the weights the task most needs.

---

## Training Data

- **13,750 prompts** from [Lakonik/t2i-prompts-3m](https://huggingface.co/datasets/Lakonik/t2i-prompts-3m) (sampled without replacement, deduplicated, filtered), one recorded teacher trajectory each
- **203 held-out validation** + **641 OOD evaluation** — never received a gradient step
- **43,044 real-photo crops** — 25,560 LSDIR + 17,484 Flickr2K, cut at native resolution to 12 buckets, quality-gated, VAE-encoded, captioned per crop

Photos only reached the critic — never regression targets — so adapter learned detail density from reality, not content.

---

## Resolutions (12 buckets)

|           |           |           |
| --------- | --------- | --------- |
| 512×512   | 512×768   | 768×512   |
| 768×768   | 768×1024  | 1024×768  |
| 1024×1024 | 960×1280  | 1280×960  |
| 1280×1280 | 1440×1280 | 1440×1440 |

1440×1440 had a deliberately small share — enough to learn the size without spending budget there. Buckets interleaved by remaining samples, not curriculum.

---

## Hardware

Trained on **single RTX 3090 (24 GB)**. Frozen base **quantized weight-only to int8 (blockwise-64)** — ~0.007 relative error, ~3% step time cost. Teacher trajectories rolled at same precision (targets permanent, error baked in).

Every bucket trained under full int8 up to 1440×1440. Large buckets fit via:

- Checkpointed block inputs staged to pinned host memory (numerically exact)
- Discriminator pass after generator backward (peaks don't overlap)
- Trunk stopped at feature tap it actually reads

Released LoRA is **bf16** applied to unquantized base.

---

## Usage Notes

- 🎯 **Krea 2 Turbo only** — trained against Turbo's weights and schedule
- 🚫 **Keep guidance at 0.0** (ComfyUI: **cfg 1.0**, not 0.0)
- 📐 **Keep μ = 1.15** — training targets anchored to that grid
- 🔬 Training used int8 base; released LoRA is bf16 on unquantized base

---

## Examples

Every sheet below: base model (8 steps), base at 4 steps **without** LoRA, base at 4 steps **with** LoRA — same seed throughout. Compare panels 2 vs 3 to isolate LoRA effect. NFE = steps (Turbo is CFG-free).

### Portrait of a young woman with freckles and windswept auburn hair...

[![portrait comparison](assets/thumbs/portrait_compare_turbo.jpg)](assets/portrait_compare_turbo.jpg)

| Turbo 8 steps                                                                         | Turbo 4 steps, no LoRA                                                                | **Turbo 4 steps + LoRA**                                                                               |
| ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| [![8 steps](assets/thumbs/portrait_turbo_8step.jpg)](assets/portrait_turbo_8step.jpg) | [![4 steps](assets/thumbs/portrait_turbo_4step.jpg)](assets/portrait_turbo_4step.jpg) | [![4 steps + LoRA](assets/thumbs/portrait_turbo_4step_lora.jpg)](assets/portrait_turbo_4step_lora.jpg) |

---

### Kingfisher bursting out of water...

[![kingfisher comparison](assets/thumbs/kingfisher_compare_turbo.jpg)](assets/kingfisher_compare_turbo.jpg)

| Turbo 8 steps                                                                             | Turbo 4 steps, no LoRA                                                                    | **Turbo 4 steps + LoRA**                                                                                   |
| ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| [![8 steps](assets/thumbs/kingfisher_turbo_8step.jpg)](assets/kingfisher_turbo_8step.jpg) | [![4 steps](assets/thumbs/kingfisher_turbo_4step.jpg)](assets/kingfisher_turbo_4step.jpg) | [![4 steps + LoRA](assets/thumbs/kingfisher_turbo_4step_lora.jpg)](assets/kingfisher_turbo_4step_lora.jpg) |

---

### Rainy night city street with glowing neon signs...

[![neonstreet comparison](assets/thumbs/neonstreet_compare_turbo.jpg)](assets/neonstreet_compare_turbo.jpg)

| Turbo 8 steps                                                                             | Turbo 4 steps, no LoRA                                                                    | **Turbo 4 steps + LoRA**                                                                                   |
| ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| [![8 steps](assets/thumbs/neonstreet_turbo_8step.jpg)](assets/neonstreet_turbo_8step.jpg) | [![4 steps](assets/thumbs/neonstreet_turbo_4step.jpg)](assets/neonstreet_turbo_4step.jpg) | [![4 steps + LoRA](assets/thumbs/neonstreet_turbo_4step_lora.jpg)](assets/neonstreet_turbo_4step_lora.jpg) |

---

### (12 more examples in full version — see [assets/](assets/) for all 15 prompts)

---

## Resolution Sweeps

[`assets/resolution_sweeps/`](assets/resolution_sweeps/) — **this LoRA at every trained resolution for all 15 test prompts** (same prompts, seed, 4 steps, strength 1.0). Nothing cherry-picked.

[`_teacher-8step/`](assets/resolution_sweeps/_teacher-8step/) — official Krea 2 Turbo 8-step reference renders for same prompts/seeds/resolutions.

Layout:

```
assets/resolution_sweeps/
├── _teacher-8step/         8-step stock Turbo reference
│   ├── 512x512/
│   ├── 1024x1024/
│   └── ... (all 12 buckets)
├── 4step-LoRA/             Same tree, this LoRA at 4 steps
└── 2step-LoRA-extreme/     Out-of-spec 2-step strips (bonus section)
```

Two ways to read: down the sweep (does it hold across resolutions?) or against teacher (open same file in both folders).

---

## Bonus: 2-Step Extreme Test

> **Out-of-spec experiment — not for production.** Useful as **fast preview**: at 2 steps, LoRA at strength 1.0 gives reliable read on composition/look at quarter of 8 steps.

Stock Turbo ghosts/smears at 2 steps; with LoRA image stays coherent and sharp. All 15 prompts checked: extra detail is real subject detail (hair, skin, fabric) + sharper atmospheric elements where prompt calls for it. Nothing unprompted appears, nothing intrudes on faces.

Full strips: [`assets/resolution_sweeps/2step-LoRA-extreme/`](assets/resolution_sweeps/2step-LoRA-extreme/)

> 🔭 **Dedicated 2-step LoRA now published:** [lvladikov/Krea2-Turbo-Distill-2step-LoRA](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-2step-LoRA). Renders at 2 steps for fast previews/drafts. Not this adapter's quality — for quality renders, stay here.

---

## Archive

Earlier checkpoints and sweeps under [`_archive/`](_archive/) — superseded, not maintained.

---

## What's next

A **2-step LoRA** was the natural follow-on, and it is now published as its own project: [lvladikov/Krea2-Turbo-Distill-2step-LoRA](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-2step-LoRA).
It is a separate release rather than a competitor to this one: at two steps a distilled model gives up more than at four, so the aim is a _usable_ 2-step Turbo — fast previews and drafts at half this adapter's cost, a quarter of the teacher's — not the quality bar this adapter holds. It is still in training, and its page carries the measurements and the faults as they stand.

---

## Detailed Model Card

For more details, if interested, have a look at the [Detailed Model Card](DETAILED-README.md).

---

## License

This adapter is a **Derivative of Krea 2 Turbo** under the [Krea 2 Community License Agreement](LICENSE.pdf). Everything the agreement says about Krea 2 Turbo applies to this LoRA: [Acceptable Use Policy](https://krea.ai/krea-2-use-policy), revenue threshold for commercial use, content-filtering duty for deployments.

Copy of agreement: [`LICENSE.pdf`](LICENSE.pdf), required notice: [`NOTICE.txt`](NOTICE.txt). See [krea.ai/krea-2-licensing](https://krea.ai/krea-2-licensing).

**Not an official Krea product, not endorsed by Krea.** Base model is Krea's; adapter weights and everything else in this repo are mine.
