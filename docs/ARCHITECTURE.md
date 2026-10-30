# Linux platform architecture

## Design principles
1. Separate platform, product and engine layers. UI/API concepts may be shared; process lifecycle, paths, GPU discovery and packaging are Linux-native.
2. Prefer upstream llama.cpp and stable-diffusion.cpp builds with GGML Vulkan. Keep patches small, isolated and documented.
3. Detect Vulkan devices and supported features at runtime. Never assume every AMD GPU or RADV version supports the same workload.
4. One heavy GPU workload at a time by default. Text and diffusion models can compete for VRAM/system memory; stop/unload the active engine before starting the other.
5. Safe local control plane: loopback-only by default; explicit LAN opt-in; authentication for remote control; canonical path validation.
6. Structured app, text-engine and image-engine logs; health endpoints; deterministic host-side tests.

## Components
- Web client: responsive browser UI; no direct filesystem access.
- Linux API service: settings, model catalog, job queue, health, logs and diagnostics.
- Text runtime adapter: starts/stops llama-server, checks readiness, maps OpenAI-compatible API.
- Image runtime adapter: starts/stops stable-diffusion.cpp server and tracks jobs/results.
- Model manager: separate catalogs for GGUF text/vision models and diffusion checkpoints/LoRA/auxiliary assets.
- Linux platform adapter: XDG paths, process supervision, GPU/VRAM probes, disk capacity and system information.

## Directory contract
- Config: `$XDG_CONFIG_HOME/ps5-ai-studio-linux` (default `~/.config/ps5-ai-studio-linux`)
- State: `$XDG_STATE_HOME/ps5-ai-studio-linux` (default `~/.local/state/ps5-ai-studio-linux`)
- Data/models: `$XDG_DATA_HOME/ps5-ai-studio-linux` (default `~/.local/share/ps5-ai-studio-linux`)
- Generated images: `$XDG_PICTURES_DIR/PS5-AI-Studio` when available, otherwise a managed data subdirectory.

Never hardcode PS5 paths such as `/data/PS5AIStudio`, `/download0` or title sandbox paths.

## GPU backend
- Vulkan loader and ICD are provided by the host distribution.
- AMDGPU + Mesa RADV is preferred on AMD hardware.
- NVIDIA and Intel may be supported when their Vulkan drivers expose required capabilities.
- CPU fallback remains available for text inference and host tests.
- Record Vulkan device name, vendor/device IDs, driver/API versions and memory heap information. Treat heap size as an estimate, not guaranteed free VRAM.

## Runtime lifecycle
The API service owns child processes. It must use argument arrays rather than shell interpolation; retain PID/process-group ownership and reap children; capture stdout/stderr to separate logs; expose starting/ready/stopping/failed states; apply timeouts and terminate process groups on shutdown; validate model paths against registered roots; and never kill arbitrary processes by broad command-line matching.

## Security
- Bind to 127.0.0.1 by default.
- LAN binding requires explicit opt-in and an API token.
- Restrict model and output paths to configured roots.
- Limit upload/request size, concurrent jobs and disk usage.
- Do not expose arbitrary shell execution or unrestricted file browsing.
