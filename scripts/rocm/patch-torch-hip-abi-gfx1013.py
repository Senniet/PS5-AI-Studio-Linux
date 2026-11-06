#!/usr/bin/env python3
"""Install the PS5 gfx1013 dual-ABI HIP library and its early-load shim in a wheel."""
from __future__ import annotations
import argparse
import base64
import csv
import hashlib
import io
import os
from pathlib import Path
import shutil
import tempfile
import time
import zipfile


def record_entry(data: bytes) -> tuple[str, str]:
    digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).decode("ascii").rstrip("=")
    return "sha256=" + digest, str(len(data))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--wheel", required=True, type=Path)
    ap.add_argument("--hip-lib", required=True, type=Path)
    ap.add_argument("--shim-lib", required=True, type=Path)
    ap.add_argument("--torch-init", required=True, type=Path)
    args = ap.parse_args()
    for p in (args.wheel, args.hip_lib, args.shim_lib, args.torch_init):
        if not p.is_file():
            raise SystemExit(f"Missing required file: {p}")

    replacements = {
        "torch/lib/libtorch_hip.so": args.hip_lib.read_bytes(),
        "torch/lib/libtorch_hip_abi_compat.so": args.shim_lib.read_bytes(),
        "torch/__init__.py": args.torch_init.read_bytes(),
    }
    tmp = args.wheel.with_name(args.wheel.name + ".ps5-tmp")
    with zipfile.ZipFile(args.wheel, "r") as zin:
        infos = zin.infolist()
        names = {i.filename for i in infos}
        record_names = [n for n in names if n.endswith(".dist-info/RECORD")]
        if len(record_names) != 1:
            raise SystemExit(f"Expected one wheel RECORD file, found {len(record_names)}")
        record_name = record_names[0]
        for name in ("torch/lib/libtorch_hip.so", "torch/__init__.py"):
            if name not in names:
                raise SystemExit(f"Wheel is missing expected entry: {name}")

        old_rows = list(csv.reader(io.StringIO(zin.read(record_name).decode("utf-8"))))
        row_by_name = {row[0]: row for row in old_rows if row}
        for name, data in replacements.items():
            h, size = record_entry(data)
            row_by_name[name] = [name, h, size]
        row_by_name[record_name] = [record_name, "", ""]
        ordered_names = [row[0] for row in old_rows if row]
        if "torch/lib/libtorch_hip_abi_compat.so" not in ordered_names:
            ordered_names.append("torch/lib/libtorch_hip_abi_compat.so")
        record_buffer = io.StringIO()
        writer = csv.writer(record_buffer, lineterminator="\n")
        for name in ordered_names:
            writer.writerow(row_by_name[name])
        record_bytes = record_buffer.getvalue().encode("utf-8")

        with zipfile.ZipFile(tmp, "w", allowZip64=True) as zout:
            for info in infos:
                name = info.filename
                if name == record_name:
                    continue
                if name in replacements:
                    zout.writestr(info, replacements[name])
                else:
                    with zin.open(info, "r") as src, zout.open(info, "w") as dst:
                        shutil.copyfileobj(src, dst, 1024 * 1024)
            if "torch/lib/libtorch_hip_abi_compat.so" not in names:
                shim_info = zipfile.ZipInfo("torch/lib/libtorch_hip_abi_compat.so", time.localtime()[:6])
                shim_info.compress_type = zipfile.ZIP_STORED
                shim_info.create_system = 3
                shim_info.external_attr = 0o100644 << 16
                zout.writestr(shim_info, replacements["torch/lib/libtorch_hip_abi_compat.so"])
            zout.writestr(zin.getinfo(record_name), record_bytes)

    with zipfile.ZipFile(tmp, "r") as check:
        bad = check.testzip()
        if bad:
            raise SystemExit(f"Wheel integrity check failed at {bad}")
        for name, expected in replacements.items():
            if hashlib.sha256(check.read(name)).digest() != hashlib.sha256(expected).digest():
                raise SystemExit(f"Wheel verification failed for {name}")
    os.replace(tmp, args.wheel)
    print(f"Patched wheel: {args.wheel}")
    print("Included dual-ABI libtorch_hip.so, ABI compatibility shim, and automatic torch startup loader.")


if __name__ == "__main__":
    main()
