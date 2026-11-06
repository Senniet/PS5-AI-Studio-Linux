#!/usr/bin/env python3
import json
import os
import sys
from gguf import GGUFReader

def validate(path):
    file_size = os.path.getsize(path)
    reader = GGUFReader(path, mode="r")
    declared = int(reader.fields["GGUF.tensor_count"].parts[-1][0])
    if declared <= 0 or len(reader.tensors) != declared:
        raise ValueError(f"tensorcount mismatch: header={declared}, parsed={len(reader.tensors)}")
    if not reader.tensors:
        raise ValueError("GGUF has no tensors")
    alignment = int(reader.alignment)
    ranges = []
    for tensor in reader.tensors:
        name = str(tensor.name)
        dims = [int(x) for x in tensor.shape]
        offset = int(tensor.data_offset)
        size = int(tensor.n_bytes)
        relative_offset = offset - int(reader.data_offset)
        if not name or not dims or any(d <= 0 for d in dims):
            raise ValueError(f"invalid name or dimensions: {name!r}")
        if size <= 0 or relative_offset < 0 or relative_offset % alignment:
            raise ValueError(f"invalid tensor offset/alignment: {name}")
        end = offset + size
        if end > file_size:
            raise ValueError(f"tensor exceeds file boundary: {name} ({end}>{file_size})")
        ranges.append((offset, end, name))
    ranges.sort()
    previous_end = int(reader.data_offset)
    previous_name = "GGUF header"
    for start, end, name in ranges:
        if start < previous_end:
            raise ValueError(f"overlapping tensor data: {previous_name} and {name}")
        previous_end, previous_name = end, name
    return {"ok": True, "tensors": declared, "fileSize": file_size, "lastTensorEnd": max(end for _, end, _ in ranges)}

if __name__ == "__main__":
    try:
        print(json.dumps(validate(sys.argv[1]), separators=(",", ":")))
    except Exception as exc:
        print(f"{type(exc).__name__}: {exc}", file=sys.stderr)
        sys.exit(1)
