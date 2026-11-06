# Krea 2 encoder A/B-test — 2026-11-06

## Doel en opzet

Vergelijk de twee aanwezige Qwen3-VL 4B-encoders in de PS5 AI Studio Krea 2-workflow:

- **Q4 GGUF:** `Qwen3VL-4B-Instruct-Q4_K_M.gguf`
- **INT8 ConvRot:** `qwen3vl_4b_int8_convrot.safetensors`

Alle runs gebruikten dezelfde Krea 2 Turbo Q3 GGUF-checkpoint, dezelfde 4-step Turbo-LoRA, VAE, prompt, resolutie en samplinginstellingen. Per seed is Q4 en INT8 met dezelfde seed uitgevoerd.

| Instelling | Waarde |
|---|---|
| Checkpoint | Krea-2-Turbo-Q3_K_M-3.91bpw.gguf |
| Resolutie | 768 × 768 |
| Stappen | 4 |
| Turbo-LoRA | krea2_turbo_4step_rank_64_lora_comfyui.safetensors |
| Sampler / scheduler | euler / simple |
| CFG | 1.0 |
| Prompt | A small red fox sitting in a snowy pine forest at blue hour, cinematic natural photography, detailed fur, realistic lighting |
| Seeds | 20261106 en 20261107 |
| Backend | ComfyUI 0.43.0 · ROCm/HIP · gfx1013 |

## Resultaten

De runtimes hieronder zijn de ComfyUI `Prompt executed in` tijden uit de servicejournal. Dit meet de volledige workflow, inclusief encoder laden, diffusion en VAE-decode.

| Ronde | Encoder | Seed | Tijd | PNG-grootte | Visuele uitkomst |
|---:|---|---:|---:|---:|---|
| 1 | Q4 GGUF | 20261106 | 76.51 s | 716,152 B | Geslaagde, duidelijke vos |
| 1 | INT8 ConvRot | 20261106 | 62.72 s | 724,031 B | Geslaagde vos; sterk vergelijkbaar met Q4 |
| 2 | Q4 GGUF | 20261106 | 72.45 s | 742,489 B | Geslaagde, duidelijke vos |
| 2 | INT8 ConvRot | 20261106 | 61.15 s | 763,048 B | Vos/compositie wijkt duidelijk af; minder geslaagd |
| 3 | Q4 GGUF | 20261107 | 75.09 s | 772,844 B | Geldige afbeelding |
| 3 | INT8 ConvRot | 20261107 | 59.96 s | 1,795 B | Volledig zwart beeld |

### Snelheid

- Q4 gemiddelde: **74.68 s**
- INT8 gemiddelde: **61.28 s**
- INT8 is in deze drie runs gemiddeld circa **18.0% sneller**.

### Kwaliteit en stabiliteit

- Q4 leverde in alle drie de runs een geldige, zichtbare afbeelding.
- INT8 leverde twee zichtbare afbeeldingen, waarvan één sterk op Q4 leek en één een afwijkende compositie had.
- De derde INT8-run leverde een volledig zwart PNG-bestand op. Pixelanalyse: RGB-gemiddelde en standaardafwijking beide exact 0.
- In de ComfyUI-log bij die INT8-run staat: `RuntimeWarning: invalid value encountered in cast` in de afbeeldingsconversie. Dit wijst op ongeldige numerieke waarden (NaN/Inf) in de beeldtensor vóór het casten naar 8-bit pixels.

## Conclusie

**Q4 GGUF blijft de standaard en aanbevolen encoder.** INT8 is circa 18% sneller in deze beperkte test, maar de zichtbare kwaliteitsvariatie en één volledig zwart resultaat maken hem op dit moment niet betrouwbaar genoeg voor normaal gebruik.

De A/B-keuze blijft beschikbaar in de Krea 2-instellingen voor verder onderzoek. Gebruik INT8 voorlopig alleen bewust voor tests; Q4 blijft geselecteerd als standaard.

## Uitvoerbestanden

- Q4 seed 20261106, run 1: `1793991394337-krea2-7fb6b8c2.png`
- INT8 seed 20261106, run 1: `1793991490394-krea2-9386da5f.png`
- Q4 seed 20261106, run 2: `1793991649566-krea2-f5791edb.png`
- INT8 seed 20261106, run 2: `1793991722029-krea2-c64bdf42.png`
- Q4 seed 20261107: `1793991834950-krea2-1db598e8.png`
- INT8 seed 20261107: `1793991917687-krea2-36cb4c22.png`

Alle uitvoerbestanden en JSON-metadata staan in `~/.local/share/ps5-ai-studio/outputs/images/`.

## Beperkingen

Dit is een kleine A/B-steekproef op één checkpoint, één resolutie, één prompt en twee seeds. De test bewijst geen algemene encoderkwaliteit voor andere prompts, modellen of resoluties. Er is geen kernelpatch toegepast en de TTM-instelling is niet gewijzigd.
