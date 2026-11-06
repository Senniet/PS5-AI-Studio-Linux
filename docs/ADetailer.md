# ADetailer-style automatic inpainting

Image Studio includes an integrated face/eye detector and mask builder. Detection uses OpenCV YuNet locally on the CPU; facial landmarks can create separate eye regions. In txt2img mode, ADetailer automatically runs a second, targeted inpainting pass over each generated image when enabled. It builds a feathered face mask, then sends the generated image and mask through the existing Stable Diffusion img2img/inpainting endpoint. The original generation is retained if no face is detected or the repair pass fails. Diffusion inference therefore uses the currently configured image runtime/backend (Vulkan when configured).

## Current scope
- YuNet face bounding-box detection and soft elliptical face masks.
- Optional automatic post-generation face/eye correction after txt2img (enabled by default), with adjustable denoise strength and mask expansion.
- Automatic correction runs per generated image; images without a detected face are left unchanged.
- Optional eye-region masks derived from the detector's eye landmarks.
- Adjustable mask expansion and the existing feather/invert/brush controls.
- Existing inpainting settings (prompt, denoise, sampler, CFG and steps) remain in effect.
- Hand repair remains available through manual brush masking. An automatic hand detector is not bundled yet.

## Detector asset
`face_detection_yunet_2023mar.onnx` is installed under `~/.local/share/ps5-ai-studio/models/image/detectors/yunet/`. It comes from the OpenCV Zoo project (`opencv/opencv_zoo`, `models/face_detection_yunet`) and is distributed under the MIT license.

Detection is CPU-based; only the subsequent Stable Diffusion inpainting stage uses the image runtime GPU backend. The automatic post-generation pass defaults to a conservative denoise strength of 0.30 to reduce unwanted changes to the original face. YuNet is substantially more modern than Haar cascades, but can still miss very small, occluded or extreme-profile faces. Inspect the mask before generating.


## YOLOv8 ADetailer-detectie

De standaarddetector is nu het officiële `face_yolov8n.pt`-model van Bingsu/ADetailer (Apache-2.0). Het model is lokaal opgeslagen als PyTorch-checkpoint en eenmaal geëxporteerd naar ONNX. Tijdens gebruik voert OpenCV DNN de ONNX-inferentie uit op CPU; Ultralytics en PyTorch hoeven dus niet mee te draaien in de serverdetectie. De detector maakt gezichtsmaskers met confidence, dilate/erode en mask blur. YuNet blijft als selecteerbare fallback beschikbaar. De YOLOv8-face detector levert geen afzonderlijke oog-landmarks; de gezichts-inpaintmasker omvat de ogen.