#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="/home/michel/rocm-ps5-research"
R="$ROOT/rocm-root/usr"
g++ -O2 -std=c++17 -D__HIP_PLATFORM_AMD__=1 -I"$R/include" \
  "$ROOT/build/rocblas-smoke.cpp" \
  -L"$R/lib/x86_64-linux-gnu" -Wl,--disable-new-dtags -Wl,-rpath,"$R/lib/x86_64-linux-gnu:$R/lib" \
  -lrocblas -l:libroctx64.so.4 -lamdhip64 -o "$ROOT/build/rocblas-smoke"
echo "Built $ROOT/build/rocblas-smoke"