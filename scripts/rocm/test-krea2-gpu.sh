#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
VENV="${ROCM_TEST_VENV:-$ROOT/runtimes/comfy-rocm-venv}"
API="${COMFY_API:-http://192.168.2.210:8790}"
# The ROCm runtime is intentionally isolated from the host and CPU venv.
RESEARCH_ROOT="${ROCM_RESEARCH_ROOT:-$HOME/rocm-ps5-research}"
ROCM_ROOT="${ROCM_ROOT:-$RESEARCH_ROOT/rocm-root/usr}"
ROCBLAS_INSTALL="${ROCBLAS_INSTALL:-$RESEARCH_ROOT/rocblas-install}"
export ROCM_PATH="$ROCM_ROOT" ROCM_HOME="$ROCM_ROOT" HIP_PATH="$ROCM_ROOT"
export LD_LIBRARY_PATH="$RESEARCH_ROOT/runtime-libs/usr/lib/x86_64-linux-gnu:$ROCBLAS_INSTALL/lib:$ROCM_ROOT/lib/rocm/llvm/lib:$ROCM_ROOT/lib/x86_64-linux-gnu:$ROCM_ROOT/lib:$ROCM_ROOT/lib/rocm/lib:${LD_LIBRARY_PATH:-}"
WORKFLOW="$ROOT/scripts/rocm/krea2-gpu-smoke-api.json"
RESULT="$ROOT/build/krea2-gpu-smoke-result.txt"
[[ -x "$VENV/bin/python" ]] || { echo "Missing ROCm venv: $VENV" >&2; exit 2; }
[[ -f "$WORKFLOW" ]] || { echo "Missing Krea2 workflow: $WORKFLOW" >&2; exit 2; }
systemctl --user is-active --quiet ps5-ai-studio-comfyui.service || { echo "ComfyUI service is not active" >&2; exit 2; }
SERVICE_EXEC="$(systemctl --user show -p ExecStart --value ps5-ai-studio-comfyui.service)"
[[ "$SERVICE_EXEC" == *"comfy-rocm-venv"* ]] || { echo "ComfyUI is still using the CPU service; refusing to queue a Krea2 GPU test" >&2; exit 2; }

"$VENV/bin/python" - <<'PY'
import torch
assert torch.version.hip, f"Expected ROCm PyTorch, got HIP={torch.version.hip!r}"
assert torch.cuda.is_available(), "PyTorch cannot access the PS5 GPU"
p = torch.cuda.get_device_properties(0)
arch = getattr(p, "gcnArchName", "unknown")
if arch != "unknown" and "gfx1013" not in arch:
    raise RuntimeError(f"Expected PS5 gfx1013 GPU, got {arch}")
free, total = torch.cuda.mem_get_info()
print(f"ROCm PyTorch {torch.__version__}; HIP {torch.version.hip}")
print(f"GPU: {torch.cuda.get_device_name(0)}; arch={arch}")
print(f"HSA GPU memory pool: {free/2**30:.2f} GiB free / {total/2**30:.2f} GiB total")
from pathlib import Path
sysfs = Path("/sys/class/drm/card0/device")
for name, label in (("mem_info_vram_total", "local VRAM"), ("mem_info_gtt_total", "GTT/shared")):
    metric = sysfs / name
    if metric.exists():
        print(f"{label}: {int(metric.read_text())/2**30:.2f} GiB")
PY

API="$API" WORKFLOW="$WORKFLOW" RESULT="$RESULT" COMFY_OUTPUT_DIR="$ROOT/runtimes/ComfyUI/output" KREA_WIDTH="${KREA_WIDTH:-384}" KREA_HEIGHT="${KREA_HEIGHT:-384}" KREA_STEPS="${KREA_STEPS:-2}" KREA_TIMEOUT="${KREA_TIMEOUT:-1800}" "$VENV/bin/python" - <<'PY'
import json, os, time, urllib.request, urllib.error
api = os.environ["API"].rstrip("/")
def request(path, data=None, timeout=30):
    body = None if data is None else json.dumps(data).encode()
    req = urllib.request.Request(api + path, data=body,
        headers={"Content-Type":"application/json"} if body else {})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())
# Verify the live server exposes both exact files and the Krea-2 loader.
unet = request("/object_info/UNETLoader")["UNETLoader"]["input"]["required"]["unet_name"][0]
clip_info = request("/object_info/CLIPLoader")["CLIPLoader"]["input"]
clip = clip_info["required"]["clip_name"][0]
vae = request("/object_info/VAELoader")["VAELoader"]["input"]["required"]["vae_name"][0]
assert "krea2Sickrealism_v40_3292927.safetensors" in unet, "Krea2 checkpoint is not visible to ComfyUI"
assert "qwen3vl_4b_int8_convrot.safetensors" in clip, "Krea2 Qwen3-VL encoder is not visible to ComfyUI"
assert "krea2" in clip_info["required"]["type"][0], "ComfyUI does not expose the Krea2 CLIP loader type"
assert "qwen_image_vae.safetensors" in vae, "Krea2 Qwen Image VAE is not visible to ComfyUI"
workflow = json.load(open(os.environ["WORKFLOW"]))
workflow["6"]["inputs"]["width"] = int(os.environ["KREA_WIDTH"])
workflow["6"]["inputs"]["height"] = int(os.environ["KREA_HEIGHT"])
workflow["7"]["inputs"]["steps"] = int(os.environ["KREA_STEPS"])
print(f"Queueing Krea2: {workflow['6']['inputs']['width']}x{workflow['6']['inputs']['height']}, {workflow['7']['inputs']['steps']} steps")
queued = request("/prompt", {"prompt": workflow, "client_id":"ps5-krea2-gfx1013-smoke"})
if queued.get("node_errors"):
    raise RuntimeError("ComfyUI rejected workflow: " + json.dumps(queued["node_errors"], indent=2))
prompt_id = queued["prompt_id"]
print("prompt_id:", prompt_id)
deadline = time.time() + int(os.environ["KREA_TIMEOUT"])
while time.time() < deadline:
    history = request("/history/" + prompt_id, timeout=60)
    item = history.get(prompt_id)
    if item:
        status = item.get("status", {})
        if status.get("status_str") == "error":
            raise RuntimeError("Krea2 generation failed: " + json.dumps(status.get("messages", []), indent=2))
        if status.get("completed") or status.get("status_str") == "success":
            images = item.get("outputs", {}).get("9", {}).get("images", [])
            if not images:
                raise RuntimeError("Krea2 completed but SaveImage produced no image: " + json.dumps(item.get("outputs", {})))
            image = images[0]
            out = os.path.join(os.environ["COMFY_OUTPUT_DIR"],
                               image.get("subfolder",""), image["filename"])
            from PIL import Image
            with Image.open(out) as im:
                im.verify()
            with Image.open(out) as im:
                print(f"PASS: Krea2 generated {im.width}x{im.height}: {out}")
                with open(os.environ["RESULT"], "w") as f:
                    f.write(out + "\n")
            break
    time.sleep(5)
else:
    raise TimeoutError("Krea2 GPU generation exceeded the configured timeout")
stats = request("/system_stats")
print("ComfyUI system_stats:", json.dumps(stats)[:1600])
PY
