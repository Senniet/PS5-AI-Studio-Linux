# Video Studio en PS5 AI Studio Linux

## Architectuur

Video Studio heeft twee afzonderlijke engines:

- **PS5 AI Video Engine**: native videoinferentie via de bestaande build van stable-diffusion.cpp met ggml-Vulkan / RADV. Dit is de voorkeursbackend op de PS5.
- **ComfyUI**: optionele workflowbackend; bestaande API-workflows blijven beschikbaar.

De native engine gebruikt dezelfde Vulkan-runtimefamilie als Image Studio, maar draait als een afzonderlijk sd-server-proces op poort 1235. Omdat de PS5 een gedeelde geheugenpool heeft, wordt bij het laden van een video-model de tekst- en beeldruntime ontladen. Bij het laden van een tekst- of beeldmodel wordt de video-runtime gestopt. Zo concurreren modellen niet ongemerkt om hetzelfde GPU-geheugen.

## Eigen videomodellenbibliotheek

Locatie: `~/.local/share/ps5-ai-studio/models/video/`

- `diffusion_models/`: videodiffusion-modellen
- `text_encoders/`: UMT5 / andere tekstencoders
- `vae/`: video-VAE's
- `loras/`: motion- en video-LoRA's
- `clip_vision/`: vision encoders
- `interpolators/`: frame-interpolatiemodellen

De bibliotheek ondersteunt gestreamde uploads, lokale inventaris, verwijderen en een modelcatalogus die alle onderdelen van een profiel naar de juiste map downloadt.

## Native modelprofielen

### Wan 2.1 T2V 1.3B
- Text-to-video.
- Diffusion: `Wan2.1-T2V-1.3B-calibrated-Q4_K_S.gguf`
- Text encoder: `umt5-xxl-encoder-Q4_K_M.gguf`
- VAE: `wan_2.1_vae.safetensors`
- Startinstellingen: 832×480, 33 frames, 16 fps, 20 stappen, CFG 6, flow shift 3.
- Apache-2.0. De gekalibreerde Q4_K_S GGUF is circa 816 MB; samen met UMT5 Q4_K_M (3.655 GB) en VAE (254 MB) is de stack circa 4.7 GB. Dit is de eerste native testkandidaat voor de PS5.

### Wan 2.2 TI2V 5B
- Text-to-video en image-to-video.
- Diffusion: `Wan2.2-TI2V-5B-Q8_0.gguf`
- Text encoder: `umt5-xxl-encoder-Q4_K_M.gguf`
- VAE: `wan2.2_vae.safetensors`
- Startinstellingen: 832×480, 33 frames, 16 fps, 20 stappen, CFG 5, flow shift 5.
- Apache-2.0.

De catalogusdownload haalt de volledige modelstack binnen. De UI markeert een profiel pas als gereed wanneer alle drie de bestanden aanwezig zijn.

## GPU-only beleid

De PS5 gebruikt AMD Custom Zen 2 / Oberon, geïdentificeerd als RADV GFX1013. Het is een unified-memory GPU. `mem_info_vram_total` toont slechts 512 MiB dedicated geheugen; `mem_info_gtt_total` is de gedeelde GPU-geheugenpool en wordt apart weergegeven.

De native runtime start stable-diffusion.cpp met expliciete Vulkan-toewijzing voor diffusion, text encoder en VAE. Er is geen CPU-fallback in de native modelstart. ComfyUI draait daarnaast via het actieve gfx1013 ROCm/HIP-profiel voor gevalideerde Krea 2-beeldgeneratie; native video gebruikt nog steeds de afzonderlijke Vulkan-engine. Zie [ROCm gfx1013-status](ROCM_GFX1013.md).

Een compleet modelprofiel betekent nog niet automatisch dat iedere resolutie of framecount past. De beschikbare GTT-pool is beperkt. Begin met korte clips op lage resolutie en verhoog instellingen pas na een succesvolle meting. De Wan 2.2 5B stack is ongeveer 10.5 GB en wordt door de engine als te groot geblokkeerd op de huidige gemeten 7.05 GiB GTT-pool. Wan 2.1 gebruikt nu de gekalibreerde Q4_K_S GGUF-stack van ongeveer 4.7 GB; de engine markeert die als krappe geheugenmarge en begint met korte clips.

## Video-generatie

De native API gebruikt stable-diffusion.cpp:
- Modelserver op `127.0.0.1:1235`.
- `POST /sdcpp/v1/vid_gen` voor text-to-video en image-to-video.
- `GET /sdcpp/v1/jobs/<id>` voor status en resultaat.
- `POST /sdcpp/v1/jobs/<id>/cancel` om een native job te stoppen.

De native engine begrenst iedere afzonderlijke render tot maximaal 81 frames (4n+1). De UI kan een doellengte van 1 tot 60 seconden aannemen, verdeelt dit in opeenvolgende renders en voegt meerdere WebM-segmenten samen met GStreamer (VP9). De segmentvoortgang wordt per render bijgehouden en annuleren stuurt een stopverzoek naar de actieve segmentjob. De huidige Wan 2.1 T2V-stack genereert elk segment zelfstandig met dezelfde prompt en opeenvolgende seeds: dit levert een langere samengestelde video op, maar garandeert nog geen doorlopende actie of exact aansluitende cameracontinuïteit. Lange native image-to-video is bewust geblokkeerd zolang geen passende I2V/VACE-stack met betrouwbare eindframe-overdracht beschikbaar is. ComfyUI blijft beschikbaar voor eigen I2V-workflows.

## API van PS5 AI Studio

- `GET /api/video/native/status`: GPU-geheugen, backend, runtime, profielen en gereedheid.
- `GET /api/video/native/models`: eigen modelbibliotheek.
- `GET /api/video/native/catalog`: beschikbare modelstacks.
- `POST /api/video/native/catalog/install`: modelstack in downloadwachtrij plaatsen.
- `POST /api/video/native/models/upload?folder=<category>`: gestreamde upload.
- `DELETE /api/video/native/models`: verwijderen met `{category,name}`.
- `POST /api/video/native/load`: native Vulkan-model laden.
- `POST /api/video/native/unload`: native model ontladen.
- `POST /api/video/native/generate`: native videojob starten.
- `GET /api/video/jobs/:id`: status voor native en ComfyUI jobs.
- `POST /api/video/cancel`: actieve job stoppen.
- `GET /api/videos`: opgeslagen videobibliotheek.

## Nog te valideren op hardware

De server-, API-, modelcatalogus- en frontend-syntaxchecks slagen. Wan 2.1 T2V 1.3B is op de PS5 geïnstalleerd en de native Vulkan-runtime is succesvol gestart. De eerste echte hardwaretest is uitgevoerd op 256×256, 9 frames en 2 sampling-stappen; het resultaat is opgeslagen als WebM. GStreamer VP9/WebM-concatenatie is afzonderlijk getest met twee WebM-inputs. Een volledige multi-segment modelgeneratie is nog niet end-to-end gevalideerd. Hardware-encoding, audio-muxing en interpolatie zijn niet gevalideerd en worden niet als gereed beschouwd.


## Native long-video validation (2026-11-02)

- Wan 2.1 T2V 1.3B Q4 stack loaded successfully on Vulkan0.
- Native async job coordinator completed a real 1-second, 9-frame, 2-step generation and stored the WebM in the video library.
- The model log confirms the diffusion model, UMT5 encoder and VAE were all allocated to Vulkan0; the native server reported approximately 4.5 GB model parameter memory.
- GStreamer VP9/WebM concatenation was separately exercised with two WebM inputs.
- A full multi-segment model generation has not yet been run end-to-end; cross-segment action continuity is not guaranteed by the current T2V profile.

## Explicit capability boundaries

The native Wan 2.1 profile is text-to-video only. The API rejects image-to-video for this profile rather than pretending it is supported. Multi-segment T2V currently repeats the prompt with incremented seeds; it does not pass the previous segment's final frame into the next segment. This is concatenation, not temporal continuation. The current UI may expose roadmap labels for video-to-video, interpolation, upscaling and audio; those functions are not yet validated by the native engine. ComfyUI remains available for separately configured workflows and currently uses the active gfx1013 ROCm/HIP backend for tested Krea 2 image workflows. This does not validate the listed video roadmap features on ComfyUI; see [ROCm gfx1013 status](ROCM_GFX1013.md).

## Video Studio 2.0: lokale verbetering en AI-upscaling

De zelfstandige werkruimte **Video verbeteren** gebruikt de lokale FFmpeg/RIFE-pipeline en optioneel SeedVR2 via ComfyUI. Bronnen en exports staan apart; het origineel wordt nooit overschreven.

- FFmpeg: trim, snelheid, rotatie, kleurcorrectie, ruisreductie, verscherping, stabilisatie, deinterlace en Lanczos-scaling.
- RIFE v4.6: echte AI-frame-interpolatie via ncnn Vulkan op AMD Oberon.
- SeedVR2 3B Q4: AI-videoherstel en -upscaling via PyTorch ROCm/HIP, BlockSwap 32, CPU-offload en VAE-tegels van 192 px (128 px bij lagere vrije GTT).
- SeedVR2-uitvoer is op de PS5 begrensd op Full HD (1920 × 1080); QHD en 4K zijn geblokkeerd om geheugenproblemen te voorkomen.
- SeedVR2 en RIFE zijn niet combineerbaar in één taak. ComfyUI moet idle zijn en andere AI-runtimes moeten ontladen zijn.
- Het gemeten SeedVR2-testtempo was circa 0,21 fps op vijf synthetische frames van 320 × 180. Dit is zwaar en kan voor lange video's uren betekenen.
- Audio wordt na AI-frameverwerking opnieuw gemuxed en behouden; de bronvideo blijft intact.

Zie [SeedVR2 PS5-profiel](SEEDVR2_PS5.md) voor modelhashes, geheugengrenzen, installatie en testresultaten.
