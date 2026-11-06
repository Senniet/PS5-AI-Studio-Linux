#!/usr/bin/env python3
"""YuNet face/eye detection and feathered inpainting mask generation."""
import json
import sys
from pathlib import Path

import cv2
from PIL import Image, ImageDraw, ImageFilter

if len(sys.argv) not in (3, 6, 9, 10):
    raise SystemExit("usage: adetailer_detect.py image yunet_model [mask_output padding include_eyes]")
image_path, model_path = map(Path, sys.argv[1:3])
mask_path = Path(sys.argv[3]) if len(sys.argv) in (6, 9, 10) else None
padding = max(0.0, min(0.4, float(sys.argv[4]) / 100.0)) if mask_path else 0.12
include_eyes = bool(int(sys.argv[5])) if mask_path else False
confidence = max(0.05, min(0.99, float(sys.argv[6]))) if len(sys.argv) == 9 else 0.65
blur = max(0, min(32, int(float(sys.argv[7])))) if len(sys.argv) == 9 else 4
dilate = max(0, min(64, int(float(sys.argv[8])))) if len(sys.argv) in (9, 10) else 4
detector_type = sys.argv[9] if len(sys.argv) == 10 else "yunet"
image = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
if image is None:
    raise SystemExit("Afbeelding kon niet worden gelezen")
height, width = image.shape[:2]
scale = min(1.0, 1600.0 / max(width, height))
if scale < 1.0:
    image = cv2.resize(image, (round(width * scale), round(height * scale)), interpolation=cv2.INTER_AREA)
h, w = image.shape[:2]
result_faces, result_eyes = [], []
if detector_type == "yolov8":
    input_size = 640
    ratio = min(input_size / w, input_size / h)
    nw, nh = round(w * ratio), round(h * ratio)
    resized = cv2.resize(image, (nw, nh), interpolation=cv2.INTER_LINEAR)
    canvas = __import__("numpy").full((input_size, input_size, 3), 114, dtype=__import__("numpy").uint8)
    px, py = (input_size - nw) // 2, (input_size - nh) // 2
    canvas[py:py + nh, px:px + nw] = resized
    net = cv2.dnn.readNetFromONNX(str(model_path))
    net.setPreferableBackend(cv2.dnn.DNN_BACKEND_OPENCV)
    net.setPreferableTarget(cv2.dnn.DNN_TARGET_CPU)
    blob = cv2.dnn.blobFromImage(canvas, 1.0 / 255.0, (input_size, input_size), swapRB=True, crop=False)
    net.setInput(blob)
    output = net.forward()
    predictions = output[0].T
    boxes, scores = [], []
    for row in predictions:
        score = float(row[4])
        if score < confidence:
            continue
        cx, cy, bw, bh = [float(v) for v in row[:4]]
        x1 = max(0, (cx - bw / 2 - px) / ratio)
        y1 = max(0, (cy - bh / 2 - py) / ratio)
        x2 = min(w, (cx + bw / 2 - px) / ratio)
        y2 = min(h, (cy + bh / 2 - py) / ratio)
        if x2 > x1 and y2 > y1:
            boxes.append([round(x1), round(y1), round(x2 - x1), round(y2 - y1)])
            scores.append(score)
    indices = cv2.dnn.NMSBoxes(boxes, scores, confidence, 0.45)
    for idx in (indices.flatten().tolist() if len(indices) else []):
        x, y, fw, fh = boxes[idx]
        result_faces.append({"x": round(x / scale), "y": round(y / scale), "w": round(fw / scale), "h": round(fh / scale), "confidence": round(scores[idx], 4)})
else:
    detector = cv2.FaceDetectorYN_create(str(model_path), "", (w, h), confidence, 0.3, 5000)
    _, faces = detector.detect(image)
inv = 1.0 / scale
mask = Image.new("L", (width, height), 0) if mask_path else None
draw = ImageDraw.Draw(mask) if mask is not None else None
for row in (faces if detector_type == "yunet" and faces is not None else []):
    x, y, fw, fh = [float(v) for v in row[:4]]
    box = {"x": round(x * inv), "y": round(y * inv), "w": round(fw * inv), "h": round(fh * inv), "confidence": round(float(row[14]), 4)}
    result_faces.append(box)
    if draw is not None:
        cx, cy = (x + fw / 2) * inv, (y + fh / 2) * inv
        rx, ry = fw * 0.64 * (1 + padding) * inv, fh * 0.70 * (1 + padding) * inv
        draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
    if include_eyes:
        for ex, ey in ((row[4], row[5]), (row[6], row[7])):
            ew, eh = fw * 0.25, fh * 0.19
            eye = {"x": round((ex - ew / 2) * inv), "y": round((ey - eh / 2) * inv), "w": round(ew * inv), "h": round(eh * inv), "face": len(result_faces) - 1}
            result_eyes.append(eye)
            if draw is not None:
                ecx, ecy = (ex * inv), (ey * inv)
                erx, ery = ew * 0.78 * (1 + padding) * inv, eh * 0.9 * (1 + padding) * inv
                draw.ellipse((ecx - erx, ecy - ery, ecx + erx, ecy + ery), fill=255)
if mask is not None and detector_type == "yolov8":
    for box in result_faces:
        cx = (box["x"] + box["w"] / 2)
        cy = (box["y"] + box["h"] / 2)
        rx = box["w"] * 0.58 * (1 + padding)
        ry = box["h"] * 0.62 * (1 + padding)
        draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
if mask is not None:
    # Feather the mask edge for a less visible transition into the generated face.
    if dilate > 0:
        import numpy as np
        import cv2 as cv
        kernel = cv.getStructuringElement(cv.MORPH_ELLIPSE, (dilate * 2 + 1, dilate * 2 + 1))
        expanded = cv.dilate(np.array(mask), kernel, iterations=1)
        mask = Image.fromarray(expanded)
    if blur > 0:
        mask = mask.filter(ImageFilter.GaussianBlur(radius=blur))
    mask.save(mask_path, format="PNG")
print(json.dumps({"ok": True, "width": width, "height": height, "faces": result_faces, "eyes": result_eyes, "detector": "YOLOv8 face_yolov8n" if detector_type == "yolov8" else "OpenCV YuNet", "device": "CPU", "mask": str(mask_path) if mask_path else None}, separators=(",", ":")))