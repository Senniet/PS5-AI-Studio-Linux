#!/usr/bin/env python3
import sys
from pathlib import Path
import numpy as np
from PIL import Image
import torch
from controlnet_aux.open_pose import Body, BodyResult, Keypoint, PoseResult, draw_poses

if len(sys.argv) != 4:
    raise SystemExit("usage: openpose_detect.py input output body_model")
source, target, model = map(Path, sys.argv[1:])
if not source.is_file() or not model.is_file():
    raise SystemExit("Inputafbeelding of OpenPose body-model ontbreekt")

torch.set_num_threads(4)
torch.set_grad_enabled(False)
image = Image.open(source).convert("RGB")
image.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
pixels = np.asarray(image)
height, width = pixels.shape[:2]

detector = Body(str(model))
candidate, subset = detector(pixels[:, :, ::-1].copy())
bodies = detector.format_body_result(candidate, subset)
if not bodies:
    raise SystemExit("Geen menselijke lichaamshouding gevonden. Gebruik een foto waarop het lichaam duidelijk zichtbaar is.")

# controlnet_aux' detector returns pixel coordinates, while draw_bodypose
# expects normalized 0..1 coordinates. Normalize before drawing the preview.
poses = []
for body in bodies:
    normalized = [
        None if point is None else Keypoint(
            x=float(point.x) / width,
            y=float(point.y) / height,
            score=point.score,
            id=point.id,
        )
        for point in body.keypoints
    ]
    poses.append(PoseResult(
        BodyResult(keypoints=normalized, total_score=body.total_score, total_parts=body.total_parts),
        None, None, None,
    ))

canvas = draw_poses(poses, height, width, draw_body=True, draw_hand=False, draw_face=False)
if not np.any(canvas):
    raise SystemExit("OpenPose vond personen, maar kon geen skelet tekenen. Probeer een foto waarop het lichaam duidelijk zichtbaar is.")
Image.fromarray(canvas).save(target, format="PNG", optimize=True)
print("OK", len(poses), width, height)
