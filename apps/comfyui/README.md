# Workflow Studio runtime

- ComfyUI core is installed separately under `runtimes/ComfyUI`; its Python environment is `runtimes/comfy-venv`. Both are ignored by Git.
- The ComfyUI user service is defined in `packaging/systemd/ps5-ai-studio-comfyui.service`.
- `extra_model_paths.yaml` maps ComfyUI model categories to the existing PS5 AI Studio image asset directories.
- `custom_nodes/ps5_ai_studio_bridge` is the tracked custom node source. It delegates image jobs to `POST /api/image/generate` on the main application, so stable-diffusion.cpp remains the image-generation engine.
- ComfyUI runs on the LAN address at port 8790. The main app remains on port 8787.

## Hardware mode

The PS5 Oberon device is exposed through Vulkan, but the installed PyTorch stack does not expose a supported ROCm/HIP backend for this GPU. ComfyUI therefore runs on CPU for graph orchestration and standard CPU nodes. Do not change this to ROCm or force a gfx target without a separately validated backend build. The PS5 bridge node sends image-generation jobs to stable-diffusion.cpp, which already uses the Vulkan backend.

## Manager security

ComfyUI-Manager 4.3 is installed as a Python package in the dedicated `runtimes/comfy-venv` environment (the supported ComfyUI 0.43+ installation method). Its source checkout is kept outside `custom_nodes`; do not clone the v4 Manager into `custom_nodes`. The active config is `runtimes/ComfyUI/user/__manager/config.ini`, mirrored by the tracked `manager-config.ini`. It uses `security_level = normal-`, with arbitrary Git URL installs, standalone pip installs and flagged packages disabled. Because the service listens on the LAN rather than loopback, Manager's high-risk installation paths remain restricted. Do not enable arbitrary Git or pip installs as a default. The application status endpoint reads the current Manager version from `/v2/manager/version`.

## Running the bridge node

1. Start/load a compatible image checkpoint in Image Studio.
2. In Workflow Studio, add **PS5 AI Studio · Generate / Edit** from the **PS5 AI Studio** node category.
3. For text-to-image, connect its IMAGE output to Preview Image or Save Image.
4. For img2img, connect a Load Image node to `source_image`; select `img2img`.
5. For inpainting, connect an image to `source_image`, a mask to `mask`, and select `inpaint`.
6. Queue the workflow. The PS5 bridge submits to the existing image API; the generated image is returned to the ComfyUI graph.

The bridge also accepts optional ControlNet and IP-Adapter reference images with independent strength controls. Load the corresponding ControlNet or IP-Adapter/CLIP Vision assets in Image Studio first; the bridge uses the currently loaded runtime configuration. It deliberately returns a clear error when a required image model or conditioning asset is not loaded, or when image/mask inputs are missing.

## Workflow monitoring and batch output

- Workflow Studio displays ComfyUI queue counts and free system memory, refreshing every five seconds while the view is open.
- **Stop actieve workflow** sends ComfyUI interrupt; **Wis wachtrij** removes pending prompts without interrupting the active prompt.
- The PS5 Bridge node supports a batch size of 1–4 and returns every generated image as a ComfyUI IMAGE batch.
