import base64, io, json, os, urllib.request, urllib.error
import numpy as np
import torch
from PIL import Image

API_BASE = os.environ.get("PS5_AI_STUDIO_API", "http://127.0.0.1:8787")

def _png_data_url(image):
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode("ascii")

def _tensor_image(tensor):
    array = tensor[0].detach().float().cpu().numpy()
    array = np.clip(array * 255.0, 0, 255).astype(np.uint8)
    return Image.fromarray(array[..., :3], mode="RGB")

class PS5AIGenerate:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "prompt": ("STRING", {"multiline": True, "default": ""}),
                "negative_prompt": ("STRING", {"multiline": True, "default": ""}),
                "mode": (["txt2img", "img2img", "inpaint"],),
                "width": ("INT", {"default": 1024, "min": 256, "max": 2048, "step": 64}),
                "height": ("INT", {"default": 1024, "min": 256, "max": 2048, "step": 64}),
                "steps": ("INT", {"default": 20, "min": 1, "max": 80}),
                "batch_size": ("INT", {"default": 1, "min": 1, "max": 4}),
                "cfg": ("FLOAT", {"default": 7.0, "min": 1.0, "max": 30.0, "step": 0.5}),
                "denoise": ("FLOAT", {"default": 0.65, "min": 0.0, "max": 1.0, "step": 0.05}),
                "seed": ("INT", {"default": -1, "min": -1, "max": 0xffffffffffffffff}),
                "sampler": (["euler_a", "euler", "dpm++2m", "ddim_trailing", "exponential", "ays", "sgm_uniform"],),
                "scheduler": (["discrete", "karras", "exponential", "ays", "sgm_uniform"],),
            },
            "optional": {
                "source_image": ("IMAGE",),
                "mask": ("MASK",),
                "control_image": ("IMAGE",),
                "control_strength": ("FLOAT", {"default": 0.9, "min": 0.0, "max": 2.0, "step": 0.05}),
                "ip_adapter_image": ("IMAGE",),
                "ip_adapter_strength": ("FLOAT", {"default": 1.0, "min": 0.0, "max": 2.0, "step": 0.05}),
            },
        }

    RETURN_TYPES = ("IMAGE",)
    RETURN_NAMES = ("image",)
    FUNCTION = "generate"
    CATEGORY = "PS5 AI Studio"
    OUTPUT_NODE = True

    def generate(self, prompt, negative_prompt, mode, width, height, steps, batch_size, cfg, denoise, seed, sampler, scheduler, source_image=None, mask=None, control_image=None, control_strength=0.9, ip_adapter_image=None, ip_adapter_strength=1.0):
        payload = {
            "prompt": prompt, "negative_prompt": negative_prompt, "operation_mode": mode,
            "width": int(width), "height": int(height), "steps": int(steps),
            "cfg_scale": float(cfg), "denoising_strength": float(denoise), "seed": int(seed),
            "sampler_name": sampler, "scheduler": scheduler, "batch_size": max(1, min(4, int(batch_size))),
        }
        if source_image is not None:
            payload["init_images"] = [_png_data_url(_tensor_image(source_image))]
            if mode == "txt2img":
                payload["operation_mode"] = "img2img"
        if mask is not None:
            mask_array = mask[0].detach().float().cpu().numpy()
            mask_image = Image.fromarray(np.clip(mask_array * 255.0, 0, 255).astype(np.uint8), mode="L")
            payload["mask"] = _png_data_url(mask_image)
            if source_image is not None:
                payload["operation_mode"] = "inpaint"
        if control_image is not None:
            payload["control_image"] = _png_data_url(_tensor_image(control_image))
            payload["control_strength"] = float(control_strength)
        if ip_adapter_image is not None:
            payload["ip_adapter_image"] = _png_data_url(_tensor_image(ip_adapter_image))
            payload["ip_adapter_strength"] = float(ip_adapter_strength)
        if payload["operation_mode"] in ("img2img", "inpaint") and "init_images" not in payload:
            raise RuntimeError("Img2img/Inpainting vereist een aangesloten Source Image.")
        if payload["operation_mode"] == "inpaint" and "mask" not in payload:
            raise RuntimeError("Inpainting vereist een aangesloten MASK.")
        request = urllib.request.Request(API_BASE + "/api/image/generate", data=json.dumps(payload).encode("utf-8"), headers={"Content-Type": "application/json"}, method="POST")
        try:
            with urllib.request.urlopen(request, timeout=7200) as response:
                result = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"PS5 AI Studio image API ({error.code}): {detail}") from error
        except Exception as error:
            raise RuntimeError(f"PS5 AI Studio image API niet bereikbaar: {error}") from error
        images = result.get("images") or []
        if not images:
            raise RuntimeError("De image runtime heeft geen afbeelding teruggegeven.")
        tensors = []
        output_size = None
        for index, encoded in enumerate(images):
            try:
                decoded = base64.b64decode(encoded.split(",", 1)[-1], validate=True)
                with Image.open(io.BytesIO(decoded)) as source:
                    output = source.convert("RGB")
                    if output_size is None:
                        output_size = output.size
                    elif output.size != output_size:
                        raise RuntimeError("De image runtime gaf verschillende afbeeldingsformaten terug in één batch.")
                    array = np.asarray(output).copy().astype(np.float32) / 255.0
                    tensors.append(torch.from_numpy(array).unsqueeze(0))
            except RuntimeError:
                raise
            except Exception as error:
                raise RuntimeError(f"Afbeelding {index + 1} uit de PS5 image runtime is ongeldig: {error}") from error
        if not tensors:
            raise RuntimeError("De image runtime heeft geen geldige afbeeldingen teruggegeven.")
        return (torch.cat(tensors, dim=0),)

NODE_CLASS_MAPPINGS = {"PS5AIGenerate": PS5AIGenerate}
NODE_DISPLAY_NAME_MAPPINGS = {"PS5AIGenerate": "PS5 AI Studio · Generate / Edit"}