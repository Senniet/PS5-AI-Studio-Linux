#!/usr/bin/env python3
import argparse
from pathlib import Path
import torch
import onnx
from RetinexFormer_arch import RetinexFormer

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--weights", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()
    out = Path(args.output)
    out.mkdir(parents=True, exist_ok=True)
    torch.set_num_threads(4)
    model = RetinexFormer(in_channels=3, out_channels=3, n_feat=40, stage=1, num_blocks=[1, 2, 2]).eval()
    checkpoint = torch.load(args.weights, map_location="cpu", weights_only=False)
    state = checkpoint.get("params", checkpoint)
    model.load_state_dict(state, strict=True)
    for tile in (128, 256, 512):
        dummy = torch.zeros(1, 3, tile, tile, dtype=torch.float32)
        target = out / f"retinexformer_{tile}.onnx"
        torch.onnx.export(model, dummy, str(target), input_names=["input"], output_names=["output"],
                          opset_version=17, dynamo=False, do_constant_folding=True)
        graph = onnx.load(str(target))
        onnx.checker.check_model(graph)
        print(f"EXPORTED tile={tile} bytes={target.stat().st_size} nodes={len(graph.graph.node)}", flush=True)

if __name__ == "__main__":
    main()