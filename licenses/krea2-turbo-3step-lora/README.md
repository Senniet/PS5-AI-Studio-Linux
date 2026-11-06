---
base_model: krea/Krea-2-Turbo
base_model_relation: adapter
license: other
license_name: krea-2-community-license
license_link: https://huggingface.co/lvladikov/Krea2-Turbo-Distill-3step-LoRA/blob/main/LICENSE.pdf
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

# Krea 2 Turbo — 3-Step Distillation LoRA

The third of my step-distillation LoRAs for Krea 2 Turbo, picking up where the other two left off. The [4-step LoRA](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-4step-LoRA) took Turbo from 8 steps to 4 and is still the closest to Turbo's own 8-step pictures; the [2-step LoRA](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-2step-LoRA) went down to 2 for fast previews but, despite best efforts, never quite reached the 4-step's quality. At one step fewer than the 4-step and one more than the 2-step, this one renders more fine detail than either, trained on a single cloud H100/H200 with everything the 2-step project taught me.

> 🧪 **A project still in training.** This checkpoint is shared now because it is already good enough to use; training goes on, and further updates and LoRAs will likely be published.

**Three steps instead of eight · 2.6× faster denoising (text encoding and VAE decode excluded) · fine detail at 1.26× the 8-step teacher's on the 22 test prompts, above the [4-step LoRA](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-4step-LoRA)'s 1.04× (stock Turbo at 3 steps: 0.58×) · colour at the teacher's level · 66,000 training samples on recorded teacher trajectories · one H100/H200, about 161 hours · released from settled weights.**

A LoRA for **[Krea 2 Turbo](https://huggingface.co/krea/Krea-2-Turbo)** that takes the model from **8 steps down to 3** — Turbo's own weights and its own 3-step sigmas, CFG 1 (no guidance; diffusers writes it as `guidance_scale=0.0`) — aiming at the best quality three steps can give. It keeps — and passes — the 4-step LoRA's fine detail at three quarters of its denoising time, with the picture a little further from the teacher's own.

- ⚡ **8 → 3 steps** — on Turbo's own 3-step sigmas `[1.0, 0.8633, 0.6123]`
- ⏱️ **2.6× faster denoising** — 65.4 s → 24.9 s at 1024×1024 (float16 compute), text encoding and VAE decode excluded, as they take the same time at any step count; the adapter's own cost per call is within about 1%
- 🎯 **Fine detail above the teacher's** — fine texture **1.26×** and the 16- and 8-pixel bands **1.27× / 1.23×** the teacher's on the 22 test prompts (stock Turbo at 3 steps: **0.58×**; the 4-step adapter **1.04×**), colour at the teacher's level
- 📊 **Distribution matching, not imitation** — matches what the teacher would plausibly produce rather than its exact trajectory, so the student commits instead of averaging into blur and doubled edges
- 🔎 **Eight critics** — artefacts, real photographs, the first call's layout, content, prompt agreement, lettering, large faces and the whole three-call rollout, each a small head on the frozen base's own mid-network features
- 📐 **11 trained resolutions** — from 512×768 up to 1440×1440, and 1824×1024
- 🔌 **Drop-in, no exceptions** — plain LoRA, stock Euler, diffusers / ComfyUI / MLX. No custom nodes, no custom sampler (the LoRA needs none; the optional [MLX workflow for Apple Silicon](#on-apple-silicon-over-mlx) below runs it through my [LVNodes](https://huggingface.co/lvladikov/ComfyUI-Nodes-and-Workflows/blob/main/LVNodes/README.md))
- 🧬 **Same shape as the [4-step](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-4step-LoRA) and [2-step](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-2step-LoRA) adapters** — rank 64 on the same 228 modules
- 🎲 **About 30,000 recorded teacher trajectories** — Turbo's own 8-step paths at the 11 training sizes, three training samples each (one per step, about 90,000 in all); every sample outside the 11 anneals is one the adapter had not seen
- 🔢 **66,000 training samples**, starting from the released 4-step adapter's weights
- 🧘 **Settled weights, not an average** — the last 600 samples take the learning rate to zero over already-trained data, so the published weights are the training weights at rest

[![The 22 test prompts, rendered by Krea 2 Turbo with this LoRA at 3 steps](assets/thumbs/poster.jpg)](assets/poster.jpg)

---

## Files

| file | what it is |
| --- | --- |
| `krea2_turbo_3step_rank_64_lora.safetensors` | LoRA in diffusers key format — see [diffusers](#diffusers) |
| `krea2_turbo_3step_rank_64_lora_comfyui.safetensors` | Same weights under ComfyUI key names — see [ComfyUI](#comfyui) |
| `krea2_turbo_3step_lora_t2i.json` | Ready ComfyUI workflow, stock nodes only |
| `krea2_turbo_3step_lora_t2i_MLX_LVNodes.json` | The same workflow on Apple Silicon over MLX, through the LVNodes Krea 2 MLX custom node — see [On Apple Silicon, over MLX](#on-apple-silicon-over-mlx) |
| [`krea2_turbo_3step_rank_64_lora_checkpoint_info.md`](krea2_turbo_3step_rank_64_lora_checkpoint_info.md) | **Which checkpoint the two weight files are** — `chk00066000` |
| `LICENSE.pdf` | Krea 2 Community License Agreement |
| `NOTICE.txt` | Required attribution notice |

Both weight files are one adapter — only key names differ. Both carry training details in safetensors metadata. The file names carry no checkpoint number: both hold `chk00066000`, which also sits in [`_archive/checkpoints/`](_archive/checkpoints/) under its number, beside the earlier `chk00042000`, `chk00030000`, `chk00018000`, `chk00012000` and `chk00006000`.

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

lora = hf_hub_download("lvladikov/Krea2-Turbo-Distill-3step-LoRA", "krea2_turbo_3step_rank_64_lora.safetensors")
state = load_file(lora)
state = {f"transformer.{k}": v for k, v in state.items() if not k.endswith(".alpha")}
pipe.load_lora_weights(state, adapter_name="3step")

# guidance_scale=0.0 is CFG 1 in this pipeline: no guidance
image = pipe("a fox in the snow", num_inference_steps=3, guidance_scale=0.0).images[0]
image.save("krea2_3step.png")
```

### ComfyUI

| file | put it in |
| --- | --- |
| `krea2_turbo_3step_rank_64_lora_comfyui.safetensors` | `ComfyUI/models/loras/` |
| `krea2_turbo_bf16.safetensors` (from [Comfy-Org/Krea-2](https://huggingface.co/Comfy-Org/Krea-2/tree/main/diffusion_models)) | `ComfyUI/models/diffusion_models/` |
| `qwen3vl_4b_bf16.safetensors` (same repo) | `ComfyUI/models/text_encoders/` |
| `qwen_image_vae.safetensors` (same repo) | `ComfyUI/models/vae/` |

Load [`krea2_turbo_3step_lora_t2i.json`](krea2_turbo_3step_lora_t2i.json). Full bf16, no quantisation, runs on CUDA / Apple Silicon / CPU unchanged. Smaller Turbo builds load the LoRA too — ComfyUI's loader applies it to any build — except `fp8_scaled` on Apple Silicon (MPS has no `Float8_e4m3fn`). A quantised base trades some of the detail: on Comfy Cloud's 4-bit (`nvfp4`) Turbo this adapter's fine texture measured about a fifth under the full-bf16 render's.

[![The ComfyUI workflow](assets/thumbs/workflow.jpg)](assets/workflow.jpg)

**Settings:** steps **3**, **cfg 1.0**, sampler `euler` / `simple`, LoRA strength **1.0**.

> ⚙️ **cfg 1.0, not 0.0.** cfg 1.0 is "no guidance" in ComfyUI: one model call per step, the setting Turbo is made for. cfg 0.0 is not off — it keeps only the negative prompt's prediction and drops your prompt, which is why an image at 0.0 comes out broken. The diffusers example's `guidance_scale=0.0` is this same cfg 1.0, counted the diffusers way.

#### On Apple Silicon, over MLX

[`krea2_turbo_3step_lora_t2i_MLX_LVNodes.json`](krea2_turbo_3step_lora_t2i_MLX_LVNodes.json) runs the same LoRA file on **MLX** instead of PyTorch / MPS, through the **LVNodes** Krea 2 MLX custom node: **Krea 2 Model (MLX)** loads the same bf16 files, **Krea 2 Sampler (MLX)** encodes, samples and decodes. To install the custom node, see [ComfyUI-Krea2-MLX](https://huggingface.co/lvladikov/ComfyUI-Nodes-and-Workflows/blob/main/LVNodes/ComfyUI-Krea2-MLX/README.md) and [LVNodes](https://huggingface.co/lvladikov/ComfyUI-Nodes-and-Workflows/blob/main/LVNodes/README.md); its first run sets up its own MLX environment and leaves ComfyUI's packages alone.

**Settings:** steps **3**, **cfg 1.0**, scheduler `euler`; the LoRA in the model node's step-LoRA slot for 2-3 steps (`lora_2step`), **enable_step_loras** on, strength **1.0**. About 64 GB of memory suits bf16; the node's **quantize** 8 or 4 needs less. MLX reads the bf16 files only (ComfyUI's fp8 and int8 builds are for PyTorch).

### Using it on Raw

Trained on Turbo, for Turbo — but it also loads on **Krea 2 Raw**, which shares the architecture. On Raw at 13 steps with CFG 3.5, it keeps Raw's own composition and adds the detail Raw lacks at that step count: skin and freckles, fur, falling snow, a lit and signed night street. At 20 steps the pictures stay the same, with sharper lettering and fine edges. Keep Raw's CFG on: at cfg 1 or 0, Raw falls apart. It is neither trained nor tuned for Raw, so treat it as a bonus rather than a supported mode.

**Krea 2 Raw, 13 steps, CFG 3.5, this LoRA at 1.0** — the five renders in [`raw-13step-cfg3.5-lora/`](_archive/resolution_sweeps/chk00066000/raw-13step-cfg3.5-lora/)

[![Krea 2 Raw at 13 steps, CFG 3.5, with this LoRA](assets/thumbs/raw_13step_poster.jpg)](assets/raw_13step_poster.jpg)

**Krea 2 Raw, 20 steps, CFG 3.5, this LoRA at 1.0** — the five renders in [`raw-20step-cfg3.5-lora/`](_archive/resolution_sweeps/chk00066000/raw-20step-cfg3.5-lora/)

[![Krea 2 Raw at 20 steps, CFG 3.5, with this LoRA](assets/thumbs/raw_20step_poster.jpg)](assets/raw_20step_poster.jpg)

**Krea 2 Raw, 6 steps, CFG 3.5, this LoRA at 1.0** — all 22 prompts in [`raw-6step-cfg3.5-lora/`](_archive/resolution_sweeps/chk00066000/raw-6step-cfg3.5-lora/)

[![Krea 2 Raw at 6 steps, CFG 3.5, with this LoRA](assets/thumbs/raw_6step_poster.jpg)](assets/raw_6step_poster.jpg)

Six steps is an extreme, short-stepped use of Raw, and it still works for most of the 22 prompts: faces, animals, crowds and illustrations come out whole. Low light suffers most (the pianist is nearly black, the night street and the dinner table come out dark), the clay chef shrinks into an empty set, and the splash-art sorceress gains a title banner. Take it as a starting point for experimenting with Raw at fewer steps.

Rendered on Comfy Cloud with the full bf16 Raw at 1024×1024, seed 4242, euler / simple, an empty negative prompt.

---

## LoRA Strength

| strength | what happens |
| --- | --- |
| **below 1.0** | Correction only partly applied — softer skin and hair, lighter freckles, a step back toward 3 steps without the adapter (0.5 below) |
| **1.0** | Trained point, recommended |
| **1.0–1.5** | Extrapolation — texture denser than the subject warrants, freckles heavy, hair wiry, contrast up (1.5 below). Usable per prompt |
| **above 1.5** | Not recommended, not measured |

At three steps the dial scales the adapter's whole job — turning three coarse calls into a finished image — so the useful
range is narrow around 1.0. Reach for **steps before strength**: when closeness to the teacher's own picture matters more
than speed, the [4-step adapter](https://huggingface.co/lvladikov/Krea2-Turbo-Distill-4step-LoRA) is the better tool.

[![LoRA strength comparison](assets/thumbs/portrait_strength_sweep.jpg)](assets/portrait_strength_sweep.jpg)

---

## Known Issues

In order of how often they show:

- **Further from the teacher's own picture than the 4-step adapter** — distance 0.403 against 0.320, detail agreement 0.27
  against 0.39. Three steps is a shorter path from the same noise, so framing, pose or a detail can differ from the 8-step
  render at the same seed: the signs along a neon-lit street, a drone's view over a night city, the dishes on a family's
  dinner table. Treat the teacher's render as a quality reference, not the picture three steps will reproduce
- **Texture stronger than the teacher's** — fine texture 1.26×, grain in flat areas 1.86× on the 22 test prompts (the earlier release 1.74×; across the full sweep 1.70× against 1.85×):
  watercolour paper most of all, then skin pores and film grain read more pronounced than in the 8-step render, freckles
  denser. A strength under 1.0 softens it (see [LoRA Strength](#lora-strength))
- **Doubled edges** — the blur-invariant ghosting index is 1.12× the teacher's (the earlier release 1.24×, the 4-step adapter's 1.02×): a faint doubled
  contour can show on fine edges — hair, rain streaks, thin limbs — most at the middle sizes, 768×1024 and 1024×768
- **Small faces in crowds** — still the weakest spot of any few-step adapter: faces far back in a crowd can come out soft or
  smeared, where a portrait-sized face holds up

These are the published checkpoint's limits, stated as they are.

---

## Hardware

Trained on a **single NVIDIA H100** (initially) then switched to **H200** (for quicker results). The frozen base runs in **bf16** (the 4-step and 2-step adapters trained on a single RTX 3090 with a weight-only int8 base). Batches of 3 at 512×768 / 768×512, 2 at 768×1024 / 1024×768 and 1 from 1024×1024 up keep every term inside about 45–50 GB (H100) / 117–122 GB (H200); a step with every term live takes 4–24 s by size. Throughput averaged about **410 samples an hour** (66,000 in about 161 hours) — each sample costs a dozen or so passes of the 12.8B base (the fake score's three updates alone are about 40% of a step). The trajectories were recorded once and are read from disk.

Released LoRA is **bf16**.

---

## Usage Notes

- 🎯 **Made for Krea 2 Turbo** — trained against Turbo's weights and schedule; on Raw it is a bonus at 6–20 steps with CFG on, not a supported mode (see [Using it on Raw](#using-it-on-raw))
- 🚫 **No guidance: CFG 1** — **cfg 1.0** in ComfyUI (0.0 breaks the image), `guidance_scale=0.0` in diffusers (its way of writing the same setting)
- 📐 **Keep μ = 1.15** — the three training sigmas are anchored to that grid
- 🔬 Training used a bf16 base; released LoRA is bf16

---

## Examples

Every sheet below, at 1024×1024: base model (8 steps), base at 3 steps **without** LoRA, base at 3 steps **with** LoRA — same seed and prompt. Panels 2 and 3 are ComfyUI renders (full bf16; panel 3 is the published [resolution sweep](#resolution-sweeps)'s own) from the same noise, so comparing them isolates the LoRA's effect; panel 1 is the quality bar, drawn from its own noise, not a pixel target. NFE = steps (Turbo is CFG-free).

### Portrait of a young woman with freckles and windswept auburn hair...

[![portrait comparison](assets/thumbs/portrait_compare_turbo.jpg)](assets/portrait_compare_turbo.jpg)

| Turbo 8 steps | Turbo 3 steps, no LoRA | **Turbo 3 steps + LoRA** |
| --- | --- | --- |
| [![8 steps](assets/thumbs/portrait_turbo_8step.jpg)](assets/portrait_turbo_8step.jpg) | [![3 steps](assets/thumbs/portrait_turbo_3step.jpg)](assets/portrait_turbo_3step.jpg) | [![3 steps + LoRA](assets/thumbs/portrait_turbo_3step_lora.jpg)](assets/portrait_turbo_3step_lora.jpg) |

---

### Kingfisher bursting out of water...

[![kingfisher comparison](assets/thumbs/kingfisher_compare_turbo.jpg)](assets/kingfisher_compare_turbo.jpg)

| Turbo 8 steps | Turbo 3 steps, no LoRA | **Turbo 3 steps + LoRA** |
| --- | --- | --- |
| [![8 steps](assets/thumbs/kingfisher_turbo_8step.jpg)](assets/kingfisher_turbo_8step.jpg) | [![3 steps](assets/thumbs/kingfisher_turbo_3step.jpg)](assets/kingfisher_turbo_3step.jpg) | [![3 steps + LoRA](assets/thumbs/kingfisher_turbo_3step_lora.jpg)](assets/kingfisher_turbo_3step_lora.jpg) |

---

### Rainy night city street with glowing neon signs...

[![neonstreet comparison](assets/thumbs/neonstreet_compare_turbo.jpg)](assets/neonstreet_compare_turbo.jpg)

| Turbo 8 steps | Turbo 3 steps, no LoRA | **Turbo 3 steps + LoRA** |
| --- | --- | --- |
| [![8 steps](assets/thumbs/neonstreet_turbo_8step.jpg)](assets/neonstreet_turbo_8step.jpg) | [![3 steps](assets/thumbs/neonstreet_turbo_3step.jpg)](assets/neonstreet_turbo_3step.jpg) | [![3 steps + LoRA](assets/thumbs/neonstreet_turbo_3step_lora.jpg)](assets/neonstreet_turbo_3step_lora.jpg) |

---

### (19 more examples, and a two-panel sheet against the teacher for every prompt, in the [full version](DETAILED-README.md) — see [assets/](assets/) for all 22 prompts)

---

## Resolution Sweeps

[`_archive/resolution_sweeps/chk00066000/`](_archive/resolution_sweeps/chk00066000/) — **this LoRA at its 11 trained sizes
for all 22 test prompts**; 3 steps, strength 1.0, rendered on Comfy Cloud with the full bf16 Krea 2 Turbo through ComfyUI's
stock LoRA loader (the `_comfyui` file as it ships). The three `raw-` folders hold the prompts on Krea 2 Raw with this LoRA
at CFG 3.5 (see [Using it on Raw](#using-it-on-raw)). The earlier `chk00042000`, `chk00030000`, `chk00018000`, `chk00012000` and `chk00006000` keep their own sweeps beside it.

```
_archive/resolution_sweeps/chk00066000/
├── 512x768/                  <slug>.jpg for the 22 prompts
├── 768x512/
├── ...                       (the 11 trained sizes)
├── 1824x1024/
├── raw-6step-cfg3.5-lora/    the 22 prompts on Krea 2 Raw, 6 steps
├── raw-13step-cfg3.5-lora/   5 prompts on Krea 2 Raw, 13 steps
└── raw-20step-cfg3.5-lora/   the same 5 at 20 steps
```

The LoRA panels in the examples above are this sweep's 1024×1024 renders.

---

## Archive

Every published checkpoint and its resolution sweep under [`_archive/`](_archive/) — [`checkpoints/`](_archive/checkpoints/) and [`resolution_sweeps/`](_archive/resolution_sweeps/), each under its number: `chk00066000`, this release, and the earlier `chk00042000`, `chk00030000`, `chk00018000`, `chk00012000` and `chk00006000`.

---

## Detailed Model Card

The full write-up is in the [Detailed Model Card](DETAILED-README.md):

- [Where it stands](DETAILED-README.md#where-it-stands) — the release at a glance, and its [known issues](DETAILED-README.md#known-issues)
- [How I got here](DETAILED-README.md#how-i-got-here) — from the 4-step adapter to this checkpoint
- [chk00066000 vs chk00042000](DETAILED-README.md#chk00066000-vs-chk00042000) — what this release changed against the earlier one
- [Measured against the teacher](DETAILED-README.md#measured-against-the-teacher) — the 22 prompts at 768×1024, five at 1024×1024, every sweep size
- [Inference with diffusers](DETAILED-README.md#inference-with-diffusers) — the settings explained, strength, stock Turbo for comparison
- [Performance](DETAILED-README.md#performance) — the time per model call and per render
- [File format and compatibility](DETAILED-README.md#file-format-and-compatibility)
- [Method](DETAILED-README.md#method) — [the schedule and the teacher grid](DETAILED-README.md#the-schedule-and-the-teacher-grid), [the losses](DETAILED-README.md#the-losses), [the critics](DETAILED-README.md#the-critics), [settled weights](DETAILED-README.md#settled-weights)
- [What the LoRA touches](DETAILED-README.md#what-the-lora-touches) — the 228 modules
- [Training data](DETAILED-README.md#training-data) — the recorded trajectories and the photo crops
- [Resolutions and batches](DETAILED-README.md#resolutions-and-batches) — the share of training at each size
- [Hardware](DETAILED-README.md#hardware)
- [Examples](DETAILED-README.md#examples) — all 22 prompts against the teacher

---

## License

This adapter is a **Derivative of Krea 2 Turbo** under the [Krea 2 Community License Agreement](LICENSE.pdf). Everything the agreement says about Krea 2 Turbo applies to this LoRA: [Acceptable Use Policy](https://krea.ai/krea-2-use-policy), revenue threshold for commercial use, content-filtering duty for deployments.

Copy of agreement: [`LICENSE.pdf`](LICENSE.pdf), required notice: [`NOTICE.txt`](NOTICE.txt). See [krea.ai/krea-2-licensing](https://krea.ai/krea-2-licensing).

**Not an official Krea product, not endorsed by Krea.** Base model is Krea's; adapter weights and everything else in this repo are mine.