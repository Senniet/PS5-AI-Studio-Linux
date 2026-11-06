#!/usr/bin/env python3
import json
import os
import re
import sys
from collections import defaultdict
from gguf import GGUFReader


def inspect(path):
    reader = GGUFReader(path, mode="r")
    layers = defaultdict(int)
    output_bytes = 0
    embedding_bytes = 0
    other_global_bytes = 0
    tensor_count = 0
    for tensor in reader.tensors:
        name = str(tensor.name)
        size = int(tensor.n_bytes)
        tensor_count += 1
        match = re.match(r"^blk\.(\d+)\.", name)
        if match:
            layers[int(match.group(1))] += size
        elif name == "output.weight":
            output_bytes += size
        elif name == "token_embd.weight":
            embedding_bytes += size
        else:
            other_global_bytes += size
    return {
        "ok": True,
        "fileSize": os.path.getsize(path),
        "tensorCount": tensor_count,
        "layers": [layers.get(i, 0) for i in range(max(layers, default=-1) + 1)],
        "outputBytes": output_bytes,
        "embeddingBytes": embedding_bytes,
        "otherGlobalBytes": other_global_bytes,
    }


if __name__ == "__main__":
    try:
        print(json.dumps(inspect(sys.argv[1]), separators=(",", ":")))
    except Exception as exc:
        print(f"{type(exc).__name__}: {exc}", file=sys.stderr)
        sys.exit(1)
