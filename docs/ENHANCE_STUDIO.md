# Enhance Studio

Enhance Studio is a standalone photo-correction, low-light restoration and upscaling page. It does not invoke Stable Diffusion generation or ComfyUI workflows.

## Current PS5 implementation

- Input: PNG, JPEG and WebP; 16 MiB upload limit and 40 megapixel processing limit.
- **Retinexformer LOL-v1 low-light restoration:** original pretrained checkpoint converted to MNN and executed on the AMD GPU through Vulkan (`MNN_FORWARD_VULKAN`, `Precision_High` / FP32).
- Retinexformer fixed-tile models: 128, 256 and 512 pixels. The UI defaults to 256 pixels; 128 is the faster/smaller-context option and 512 gives the largest context but is substantially slower.
- AI strength blend: 25–100%, default 100%. The model output is blended with the original image after inference; this helps moderate the effect on brighter scenes.
- Tile inference uses reflected edge padding and overlapping cosine feather blending. The source image is never overwritten.
- Deterministic controls: exposure, selective highlight compression, shadow lift, contrast, saturation, median denoising and sharpness. These currently run with Pillow on CPU.
- Optional ESRGAN upscaling runs through `stable-diffusion.cpp` `sd-cli` with `upscaler=Vulkan0` after Retinexformer and the manual corrections.
- Results are saved as new PNGs in the normal image gallery, with a JSON sidecar describing the pipeline.
- Jobs expose stage/progress and can be cancelled. Cancelling Retinexformer terminates both the Python wrapper and native MNN process.

## Retinexformer implementation

- Upstream: `https://github.com/caiyuanhao1998/Retinexformer`
- Checkpoint: official LOL-v1 pretrained weights (`LOL_v1.pth`).
- Model: `n_feat=40`, `stage=1`, `num_blocks=[1,2,2]`; approximately 1.61M parameters.
- Conversion: PyTorch -> ONNX opset 17 -> MNN 3.6.x.
- Runtime: MNN 3.6.x shared library + separate `libMNN_Vulkan.so` backend plugin.
- GPU: PS5 Linux AMD Oberon / RADV Vulkan device, exposed as Vulkan0.
- Precision: FP32 is deliberately selected. MNN's normal precision mode uses FP16 on this GPU; a comparison showed a larger output deviation, so FP32 is the default for faithful restoration.
- Export-only graph adaptations: L2 normalization is expressed as reduction + reciprocal square root, and GELU uses the standard tanh approximation so the required operators are available in the Vulkan backend. The adapted PyTorch output differs from the original upstream architecture by max 0.000203 and mean 0.000092 on the fixed 128x128 comparison input. Checkpoint weights are unchanged.
- The MNN Vulkan FP32 output matches the adapted PyTorch reference to below 0.000002 max absolute error on tested 128, 256 and 512 pixel inputs.

## PS5 verification results

| Test | Result |
|---|---:|
| 128x128, one MNN Vulkan tile | 355 ms; max abs error 0.00000084 vs adapted PyTorch |
| 256x256, one MNN Vulkan tile | 1.72 s; max abs error 0.00000089 |
| 512x512, one MNN Vulkan tile | 15.67 s; max abs error 0.00000191 |
| 512x512 image, 256px tiles | 9 tiles; 15.29 s |
| MNN normal/FP16 mode vs FP32 | Rejected as default: mean abs error 0.00606, p99 0.02062, max 0.03970 |
| Dark 1024x1024 gallery image, 256px tiles | 25 tiles; 42.42 s |
| Dark-image luminance mean | 34.53 input -> 151.84 output |
| Dark-image luminance p05 / p50 / p95 | 15 / 24 / 93 input -> 84 / 157 / 201 output |
| Bright-scene safeguard test | Mean 226 -> 231.7 at 25% strength; full strength produced mean 248.4 and 28.1% clipped white pixels |
| API end-to-end | Retinexformer -> Pillow corrections -> gallery PNG + metadata succeeded |
| Combined pipeline | Retinexformer -> Pillow -> RealESRGAN Vulkan upscaling succeeded |
| Legacy path | Pillow-only Enhance Studio request still succeeds with Retinexformer disabled |
| Cancellation | API cancel succeeded; no orphan Retinexformer process remained |

The 1024x1024 dark-image test preserved its original dimensions and did not simply clip the image to white. The result was written as a separate PNG.

### Runtime choice

NCNN + Vulkan was also tested. Its converted output could be made numerically accurate, but the required model graph included operations without NCNN Vulkan implementations, creating CPU fallback work. MNN was selected because its Vulkan backend provides the required convolution/deconvolution, matrix multiplication, softmax, layer normalization, reductions and elementwise operations. The MNN Vulkan FP32 route is the production path.

## Rebuilding on another PS5 Linux installation

The runtime and converted `.mnn` files live outside Git in the local app runtime/model directories. Rebuild with:

1. Clone MNN into `$HOME/ai-runtimes/MNN` (including submodules).
2. Ensure the PS5 AI Studio Python environment has PyTorch, ONNX, einops, NumPy and Pillow.
3. Put the official checkpoint at `~/.local/share/ps5-ai-studio/models/image/enhancers/retinexformer/LOL_v1.pth`. The official Google Drive file ID used for LOL-v1 is `1xDwQtTCj3tlAVCTJgYrzonBGVwqeOhKu`.
4. Run `scripts/build-mnn-vulkan.sh`.
5. Run `scripts/build-retinexformer-runtime.sh`. This now exports/converts all three tile sizes, builds the runner, and runs the numerical, tiled-image and alpha-preservation test suite automatically.

The build scripts create the three fixed-size MNN models, copy `libMNN.so` and `libMNN_Vulkan.so` into `runtimes/retinexformer/lib`, and compile the native tiled runner with a relocatable `$ORIGIN` RPATH. The same verification can be run independently with `scripts/test-retinexformer-runtime.py`. `runtimes/` and local `models/` are intentionally excluded from Git.

## Important limitations

- Retinexformer is a low-light enhancement network, not a general-purpose restoration model. It can brighten dark scenes and reveal existing signal, but cannot recover details that were never captured or completely clipped. Full strength can overexpose already bright scenes; the AI-strength blend is available to moderate this.
- Strongly brightening a noisy photo can also reveal sensor noise; use the existing denoise control afterward if needed.
- The deterministic tone-correction stage still runs on CPU. Retinexformer and optional ESRGAN upscaling run on Vulkan GPU.
- SUPIR and CodeFormer are not integrated. SUPIR needs a separate PS5-compatible runtime/model test; CodeFormer should remain an optional face-specific stage because it can alter facial identity/details.