#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
RESEARCH_ROOT="${ROCM_RESEARCH_ROOT:-$HOME/rocm-ps5-research}"
SRC="${PYTORCH_SRC:-$RESEARCH_ROOT/pytorch-2.10.0}"
ROCM="${ROCM_ROOT:-$RESEARCH_ROOT/rocm-root/usr}"
VENV="${ROCM_BUILD_VENV:-$RESEARCH_ROOT/torch-build-venv}"
BUILD="$SRC/build"
CXX="$ROCM/lib/rocm/llvm/bin/clang++"
LLVM_NM="$(command -v llvm-nm)"
LLVM_OBJCOPY="$(command -v llvm-objcopy)"
OBJ_REL="caffe2/CMakeFiles/torch_hip.dir/__/aten/src/ATen/hip/HIPBlas.cpp.o"
TMP="$RESEARCH_ROOT/build/torch-hip-abi"
LEGACY_FULL="$TMP/HIPBlas-abi17-full.o"
LEGACY_GEMM="$TMP/HIPBlas-oldgemm-only.o"
LOCALIZE="$TMP/localize-symbols.txt"
SHIM="$RESEARCH_ROOT/build/libtorch_hip_abi_compat.so"

[[ -x "$CXX" ]] || { echo "Missing ROCm Clang: $CXX" >&2; exit 2; }
[[ -f "$BUILD/compile_commands.json" ]] || { echo "Missing compile_commands.json" >&2; exit 2; }
mkdir -p "$TMP" "$RESEARCH_ROOT/build"
export PATH="$VENV/bin:$ROCM/bin:$ROCM/lib/rocm/llvm/bin:$PATH"
export LD_LIBRARY_PATH="$RESEARCH_ROOT/runtime-libs/usr/lib/x86_64-linux-gnu:$RESEARCH_ROOT/rocblas-install/lib:$ROCM/lib/rocm/llvm/lib:$ROCM/lib/x86_64-linux-gnu:$ROCM/lib:$ROCM/lib/rocm/lib:${LD_LIBRARY_PATH:-}"

# Compile the same HIPBlas.cpp host TU a second time with the ABI used by HIPCC.
python3 - "$BUILD/compile_commands.json" "$OBJ_REL" "$LEGACY_FULL" <<'PY'
import json, pathlib, subprocess, sys
commands, obj_rel, output = sys.argv[1:]
for item in json.load(open(commands)):
    if item.get("output") == obj_rel:
        marker = " -o " + obj_rel + " -c "
        command = item["command"]
        if marker not in command:
            raise SystemExit("Could not locate HIPBlas.cpp compile output in compile_commands.json")
        command = command.replace(marker, " -fclang-abi-compat=17 -o " + output + " -c ", 1)
        result = subprocess.run(command, shell=True, cwd=item["directory"])
        raise SystemExit(result.returncode)
raise SystemExit("HIPBlas.cpp compile command not found")
PY

# Keep only the eight legacy gemm specializations globally visible. Other
# definitions remain local in this object so the normal ABI object can coexist.
python3 - "$LLVM_NM" "$LEGACY_FULL" "$LOCALIZE" <<'PY'
import subprocess, sys
nm, obj, out = sys.argv[1:]
text = subprocess.check_output([nm, "--defined-only", obj], text=True)
keep, local = [], []
for line in text.splitlines():
    fields = line.split()
    if len(fields) >= 3 and fields[-2].isupper():
        symbol = fields[-1]
        if symbol.startswith("_ZN2at4cuda4blas4gemm"):
            keep.append(symbol)
        else:
            local.append(symbol)
if len(keep) != 8:
    raise SystemExit(f"Expected 8 legacy gemm exports, found {len(keep)}")
path = __import__("pathlib").Path(out)
path.write_text("\n".join(local) + "\n")
print(f"Keeping {len(keep)} legacy gemm symbols; localizing {len(local)} other definitions")
PY
"$LLVM_OBJCOPY" --localize-symbols="$LOCALIZE" "$LEGACY_FULL" "$LEGACY_GEMM"
python3 - "$LLVM_NM" "$LEGACY_GEMM" <<'PY'
import subprocess, sys
nm, obj = sys.argv[1:]
text = subprocess.check_output([nm, "--defined-only", obj], text=True)
global_symbols = [line.split()[-1] for line in text.splitlines() if len(line.split()) >= 3 and line.split()[-2].isupper()]
if len(global_symbols) != 8 or any(not x.startswith("_ZN2at4cuda4blas4gemm") for x in global_symbols):
    raise SystemExit(f"Legacy gemm object has unexpected global exports: {len(global_symbols)}")
PY

# Build the CPU-side ABI bridge used by torch/__init__.py before torch._C loads.
"$CXX" -std=c++17 -O2 -fPIC -shared -fclang-abi-compat=17 -DUSE_ROCM -D__HIP_PLATFORM_AMD__=1 \
  -I"$SRC/build/aten/src" -I"$SRC/aten/src" -I"$SRC/torch/include" -I"$SRC/c10/.." \
  -I"$SRC/build" -I"$SRC" -I"$ROCM/include" \
  -Wl,-soname,libtorch_hip_abi_compat.so -o "$SHIM" \
  "$PROJECT_ROOT/scripts/rocm/torch-hip-abi-compat.cpp"

# Relink torch_hip with both ABI variants of the eight gemm specializations.
cd "$BUILD"
python3 - "$LEGACY_GEMM" "$OBJ_REL" <<'PY'
import os, shlex, subprocess, sys
legacy, obj_rel = sys.argv[1:]
command = subprocess.check_output(["ninja", "-t", "commands", "torch_hip"], text=True).splitlines()[-1]
needle = obj_rel + " "
if needle not in command:
    raise SystemExit("Could not locate HIPBlas.cpp.o in torch_hip link command")
command = command.replace(needle, needle + shlex.quote(legacy) + " ", 1)
args = shlex.split(command)
missing = [x for x in args if x.endswith(".o") and not os.path.exists(x if os.path.isabs(x) else os.path.join(os.getcwd(), x))]
if missing:
    raise SystemExit("Missing torch_hip link inputs:\n" + "\n".join(missing))
subprocess.run(command, shell=True, cwd=os.getcwd(), check=True)
PY

# Confirm every dynamic relocation can resolve with the companion CPU ABI shim.
export LD_PRELOAD="$SHIM"
if ldd -r "$BUILD/lib/libtorch_hip.so" 2>&1 | grep -E 'undefined symbol|not found'; then
  echo "torch_hip still has unresolved symbols" >&2
  exit 1
fi
unset LD_PRELOAD
echo "Finalized gfx1013 torch_hip ABI: $BUILD/lib/libtorch_hip.so"
echo "CPU compatibility shim: $SHIM"
