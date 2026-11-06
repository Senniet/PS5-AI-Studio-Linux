#!/usr/bin/env python3
"""Run Retinexformer through the local MNN Vulkan FP32 runner."""
import argparse
import math
import os
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

child = None

def terminate_child(signum, _frame):
    global child
    if child is not None and child.poll() is None:
        try:
            child.terminate()
            child.wait(timeout=4)
        except Exception:
            try:
                child.kill()
                child.wait(timeout=2)
            except Exception:
                pass
    raise SystemExit(128 + signum)

signal.signal(signal.SIGTERM, terminate_child)
signal.signal(signal.SIGINT, terminate_child)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument("model")
    parser.add_argument("runner")
    parser.add_argument("tile", type=int, choices=(128, 256, 512))
    parser.add_argument("strength", type=int)
    parser.add_argument("temp_dir")
    args = parser.parse_args()

    for item in (args.input, args.model, args.runner):
        if not os.path.isfile(item):
            raise RuntimeError("Bestand ontbreekt: " + item)
    os.makedirs(args.temp_dir, exist_ok=True)
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)

    started = time.perf_counter()
    with Image.open(args.input) as opened:
        image = ImageOps.exif_transpose(opened)
        has_alpha = "A" in image.getbands() or "transparency" in image.info
        rgba = image.convert("RGBA") if has_alpha else None
        alpha = rgba.getchannel("A") if rgba is not None else None
        rgb = rgba.convert("RGB") if rgba is not None else image.convert("RGB")
    width, height = rgb.size
    if width < 1 or height < 1 or width * height > 40_000_000:
        raise RuntimeError("Retinexformer ondersteunt maximaal 40 megapixel per afbeelding")

    pixels = np.asarray(rgb, dtype=np.float32) / 255.0
    nchw = np.ascontiguousarray(pixels.transpose(2, 0, 1), dtype=np.float32)
    overlap = {128: 16, 256: 24, 512: 32}[args.tile]

    with tempfile.TemporaryDirectory(prefix="retinexformer-", dir=args.temp_dir) as temp:
        raw_input = os.path.join(temp, "input.f32")
        raw_output = os.path.join(temp, "output.f32")
        nchw.tofile(raw_input)
        command = [args.runner, args.model, raw_input, raw_output,
                   str(width), str(height), str(overlap)]
        global child
        child = subprocess.Popen(command, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, text=True,
                                 bufsize=1, universal_newlines=True)
        tail = []
        for line in child.stdout:
            line = line.rstrip()
            if line:
                print(line, flush=True)
                tail.append(line)
                if len(tail) > 12:
                    tail.pop(0)
        code = child.wait()
        child = None
        if code != 0:
            raise RuntimeError("MNN/Vulkan-runner mislukt (code " + str(code) + "): " + " | ".join(tail[-6:]))
        expected = 3 * width * height
        if not os.path.isfile(raw_output) or os.path.getsize(raw_output) != expected * 4:
            raise RuntimeError("Retinexformer gaf geen volledige uitvoerafbeelding terug")
        output = np.fromfile(raw_output, dtype=np.float32).reshape(3, height, width).transpose(1, 2, 0)
        if not np.isfinite(output).all():
            raise RuntimeError("Retinexformer-uitvoer bevat ongeldige pixelwaarden")
        strength = max(0.25, min(1.0, args.strength / 100.0))
        if strength < 1.0:
            output = pixels * (1.0 - strength) + output * strength
        output = np.uint8(np.clip(output, 0.0, 1.0) * 255.0 + 0.5)
        result = Image.fromarray(output, "RGB")
        if has_alpha and alpha is not None:
            result.putalpha(alpha)
        result.save(args.output, format="PNG", optimize=False)

    elapsed = time.perf_counter() - started
    print("RETINEXFORMER_OK backend=MNN_Vulkan0_FP32 width=" + str(width) +
          " height=" + str(height) + " tile=" + str(args.tile) +
          " strength=" + str(args.strength) + "% seconds=" + format(elapsed, ".2f") + " output=" + args.output,
          flush=True)

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("RETINEXFORMER_ERROR " + str(exc), file=sys.stderr, flush=True)
        sys.exit(1)