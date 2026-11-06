#!/usr/bin/env bash
# Canonical gfx1013 PyTorch build entry point. Uses the validated ROCm 7.1.x / PyTorch 2.10 stack.
set -euo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$PROJECT_ROOT/scripts/rocm/build-pytorch.sh" "$@"
