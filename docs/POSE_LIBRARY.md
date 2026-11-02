# Pose Library

The Image Studio Pose Library turns a reference photograph into a reusable OpenPose body-skeleton PNG and stores it locally.

## Runtime

- Detector: ControlNet OpenPose body detector from `controlnet-aux` 0.0.10.
- Inference: CPU-only PyTorch, four threads, maximum input edge 1024 px.
- Model: `~/.local/share/ps5-ai-studio/models/pose/body_pose_model.pth`.
- Model source: Hugging Face `lllyasviel/Annotators`, file `body_pose_model.pth`.
- Pose images and metadata: `~/.local/share/ps5-ai-studio/poses/`.
- Only the generated pose map is persisted; the source photo is removed after preprocessing.

## Install / repair

From the project root:

```bash
runtimes/comfy-venv/bin/pip install -r apps/server/requirements-pose.txt
mkdir -p ~/.local/share/ps5-ai-studio/models/pose
runtimes/comfy-venv/bin/python - <<'PY'
from pathlib import Path
from huggingface_hub import hf_hub_download
folder = Path.home() / '.local/share/ps5-ai-studio/models/pose'
folder.mkdir(parents=True, exist_ok=True)
hf_hub_download('lllyasviel/Annotators', 'body_pose_model.pth', local_dir=folder)
PY
```


## API

- `GET /api/poses` — list saved poses and detector availability.
- `POST /api/poses/generate` — JSON `{name, fileName, image}`; image is a PNG/JPEG/WebP data URL. The route runs the local detector and persists the pose PNG plus JSON metadata.
- `PATCH /api/poses/:uuid` — rename a saved pose.
- `DELETE /api/poses/:uuid` — delete the pose and metadata.
- `GET /poses/:uuid.png` — serve the generated PNG.

Input photos are limited to 16 MiB. Pose detection has a three-minute timeout. A photo without a detected body returns a clear validation error and is not saved.

## ControlNet

The generated map is a standard colored OpenPose skeleton map. Use it with an SD 1.5 OpenPose ControlNet. The SD 1.5 checkpoint and `control_v11p_sd15_openpose.pth` were verified to load together in stable-diffusion.cpp on the target Linux system. The Image Studio applies a saved pose as a ControlNet reference, selects OpenPose mode and loads the matching model when available.
