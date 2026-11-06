#!/usr/bin/env bash
set -euo pipefail

# Repair the pip launcher in the dedicated PS5 ROCm venv.
# The current launcher points at the separate CPU venv. This script copies
# only pip's pure-Python package from that same-Python-version venv and creates
# launchers that execute under the ROCm interpreter. It does NOT install torch,
# Triton, or any other third-party package.

R="$HOME/PS5-AI-Studio-Linux/runtimes/comfy-rocm-venv"
C="$HOME/PS5-AI-Studio-Linux/runtimes/comfy-venv"
RS="$R/lib/python3.14/site-packages"
CS="$C/lib/python3.14/site-packages"
B="$R/bin"

[[ -x "$R/bin/python" && -d "$RS" ]] || { echo "ROCm venv not found: $R" >&2; exit 1; }
[[ -d "$CS/pip" ]] || { echo "pip package not found in CPU venv: $CS" >&2; exit 1; }
[[ -f "$CS/pip-26.2.2.dist-info/METADATA" ]] || { echo "Expected pip 26.2.2 metadata not found; refusing." >&2; exit 1; }

if ! head -1 "$B/pip" | grep -q '/comfy-venv/bin/python'; then
  echo "The pip launcher no longer has the known incorrect CPU-venv shebang; refusing to overwrite it."
  exit 1
fi

stamp=$(date +%Y%m%d-%H%M%S)
for f in pip pip3 pip3.14; do
  cp -a "$B/$f" "$B/$f.pre-rocm-fix-$stamp"
done
cp -a "$CS/pip" "$RS/"
cp -a "$CS/pip-26.2.2.dist-info" "$RS/"

for f in pip pip3 pip3.14; do
  cat > "$B/$f" <<LAUNCHER
#!$R/bin/python
# -*- coding: utf-8 -*-
import sys
from pip._internal.cli.main import main
if __name__ == '__main__':
    sys.exit(main())
LAUNCHER
  chmod 755 "$B/$f"
done

"$B/pip" --version
"$B/pip" show torch | grep -E '^(Name|Version|Location):'
echo "Pip launcher repaired. Backup suffix: pre-rocm-fix-$stamp"