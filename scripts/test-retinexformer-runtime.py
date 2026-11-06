#!/usr/bin/env python3
"""Numerical and image-pipeline tests for the PS5 MNN/Vulkan Retinexformer runtime."""
import argparse
import subprocess
import sys
import tempfile
from pathlib import Path
import numpy as np
import torch
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "retinexformer"))
from RetinexFormer_arch import RetinexFormer

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--weights', default=str(Path.home()/'.local/share/ps5-ai-studio/models/image/enhancers/retinexformer/LOL_v1.pth'))
    ap.add_argument('--models', default=str(Path.home()/'.local/share/ps5-ai-studio/models/image/enhancers/retinexformer'))
    ap.add_argument('--runner', default=str(ROOT/'runtimes/retinexformer/bin/retinexformer-mnn'))
    ap.add_argument('--python', default=str(ROOT/'runtimes/comfy-venv/bin/python'))
    args = ap.parse_args()
    models, runner = Path(args.models), Path(args.runner)
    torch.set_num_threads(4)
    model = RetinexFormer(in_channels=3, out_channels=3, n_feat=40, stage=1, num_blocks=[1,2,2]).eval()
    checkpoint = torch.load(args.weights, map_location='cpu', weights_only=False)
    model.load_state_dict(checkpoint.get('params', checkpoint), strict=True)
    with tempfile.TemporaryDirectory(prefix='retinexformer-test-') as td:
        tmp = Path(td)
        for tile in (128, 256, 512):
            torch.manual_seed(4200 + tile)
            x = torch.rand(1, 3, tile, tile)
            with torch.inference_mode(): ref = model(x).numpy().reshape(-1)
            inp, out = tmp/f'in-{tile}.f32', tmp/f'out-{tile}.f32'
            x.numpy().astype(np.float32).tofile(inp)
            run = subprocess.run([str(runner), str(models/f'retinexformer-lol-v1-{tile}.mnn'), str(inp), str(out), str(tile), str(tile), str({128:16,256:24,512:32}[tile])], capture_output=True, text=True)
            if run.returncode: raise RuntimeError(run.stdout + '\n' + run.stderr)
            got = np.fromfile(out, dtype=np.float32)
            delta = np.abs(np.clip(ref, 0, 1) - got)
            print(f'PASS tile={tile} max_abs={delta.max():.9g} mean_abs={delta.mean():.9g} p99={np.quantile(delta,.99):.9g}')
            if delta.max() > 5e-5 or delta.mean() > 1e-5: raise AssertionError(f'Numerical mismatch for tile {tile}')

        # Multi-tile edge/overlap test: 512x512 input through the 256px model -> 9 tiles.
        rng = np.random.default_rng(44)
        image = rng.random((3,512,512), dtype=np.float32)
        inp, out = tmp/'multi.f32', tmp/'multi-out.f32'
        image.tofile(inp)
        run = subprocess.run([str(runner), str(models/'retinexformer-lol-v1-256.mnn'), str(inp), str(out), '512', '512', '24'], capture_output=True, text=True)
        if run.returncode: raise RuntimeError(run.stdout + '\n' + run.stderr)
        multi = np.fromfile(out, dtype=np.float32)
        if multi.size != 3*512*512 or not np.isfinite(multi).all() or 'tiles=9' not in run.stdout:
            raise AssertionError('Multi-tile test failed')
        print('PASS tiled_512x512 model=256 tiles=9 output_finite=true')

        # Alpha channel must pass through unchanged.
        rgb = (rng.random((128,128,3))*255).astype(np.uint8)
        alpha = np.tile(np.arange(128, dtype=np.uint8), (128,1)*1)
        source = Image.fromarray(np.dstack((rgb, alpha)), 'RGBA')
        source_path, output_path = tmp/'alpha.png', tmp/'alpha-out.png'
        source.save(source_path)
        run = subprocess.run([args.python, str(ROOT/'apps/server/retinexformer_enhance.py'), str(source_path), str(output_path), str(models/'retinexformer-lol-v1-128.mnn'), str(runner), '128', '100', str(tmp)], capture_output=True, text=True)
        if run.returncode: raise RuntimeError(run.stdout + '\n' + run.stderr)
        result = Image.open(output_path).convert('RGBA')
        if not np.array_equal(np.asarray(result.getchannel('A')), alpha): raise AssertionError('Alpha channel changed')
        print('PASS alpha_preserved=true')
    print('ALL RETINEXFORMER RUNTIME TESTS PASSED')

if __name__ == '__main__': main()