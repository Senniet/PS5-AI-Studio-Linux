#!/usr/bin/env python3
"""Deterministic photo corrections for Enhance Studio (Pillow CPU stage)."""
import json, sys
from PIL import Image, ImageEnhance, ImageFilter, ImageOps

src, dst, raw = sys.argv[1:4]
opts = json.loads(raw)
image = Image.open(src)
image = ImageOps.exif_transpose(image).convert('RGB')
if image.width * image.height > 40_000_000:
    raise SystemExit('Afbeelding is groter dan 40 megapixel; verklein de bron eerst.')

# Preserve highlights by locally compressing bright luminance; lift shadows separately.
def luminance(im):
    return im.convert('L')

exposure = max(-2.0, min(2.0, float(opts.get('exposure', 0))))
if exposure:
    image = ImageEnhance.Brightness(image).enhance(2.0 ** exposure)

highlights = max(0.0, min(1.0, float(opts.get('highlights', 0))))
if highlights:
    lum = luminance(image)
    mask = lum.point(lambda p: max(0, min(255, int((p - 142) * 255 / 113))))
    compressed = ImageEnhance.Brightness(image).enhance(1.0 - 0.72 * highlights)
    image = Image.composite(compressed, image, mask)

shadows = max(0.0, min(1.0, float(opts.get('shadows', 0))))
if shadows:
    # Luminance-only shadow recovery: keep the black point anchored and
    # lift textured shadows without independently tinting RGB channels.
    amount = 0.26 * shadows
    lift_lut = []
    for p in range(256):
        y = p / 255.0
        weight = max(0.0, min(1.0, (0.72 - y) / 0.72)) ** 2.5
        lifted = y + amount * (1.0 - y) * weight
        lift_lut.append(max(0, min(255, int(round(lifted * 255)))))
    ycc = image.convert('YCbCr')
    y, cb, cr = ycc.split()
    y = y.point(lift_lut)
    image = Image.merge('YCbCr', (y, cb, cr)).convert('RGB')

image = ImageEnhance.Contrast(image).enhance(max(0.5, min(1.8, float(opts.get('contrast', 1)))))
image = ImageEnhance.Color(image).enhance(max(0.0, min(2.0, float(opts.get('saturation', 1)))))

denoise = max(0.0, min(1.0, float(opts.get('denoise', 0))))
if denoise:
    # Mild chroma/luma smoothing before sharpening; retain most fine edges.
    smooth = image.filter(ImageFilter.MedianFilter(3))
    image = Image.blend(image, smooth, denoise * 0.45)

sharpness = max(0.0, min(2.5, float(opts.get('sharpness', 1))))
if sharpness > 1.0:
    image = image.filter(ImageFilter.UnsharpMask(radius=1.4, percent=int(min(240, (sharpness - 1.0) * 240)), threshold=3))
elif sharpness < 1.0:
    image = ImageEnhance.Sharpness(image).enhance(sharpness)
image.save(dst, format='PNG', optimize=True)
print(json.dumps({'ok': True, 'width': image.width, 'height': image.height, 'pixels': image.width * image.height}))