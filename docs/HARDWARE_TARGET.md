# PS5 Linux hardware target (initial reference)

The first target environment is the user's Ubuntu-based Linux distribution running on PS5 hardware. The values below are historical observations from the development environment and must be re-detected on every boot; they are not hard-coded build assumptions.

- CPU: AMD Zen 2 custom SoC (8-core class).
- GPU: AMD Custom Oberon / RADV, reported Vulkan device AMD Custom, architecture GFX1013.
- GPU memory: previously reported Vulkan-visible heap around 7,730 MiB.
- System memory: previously reported around 14 GiB RAM with 7 GiB swap.
- Kernel: previously reported Linux 7.1.7.
- Userspace: Ubuntu-based Linux.

## Implications

1. Treat this as a unified-memory system. Vulkan heap size, Linux available RAM and actual process headroom are different measurements; never add them together as independent physical memory.
2. Query Vulkan device and memory heaps at runtime. Do not hard-code GFX1013, Oberon, heap sizes or a fixed PS5 kernel.
3. Build CPU inference first, then validate GGML Vulkan with the installed RADV driver.
4. Keep conservative memory headroom for the desktop, kernel, display stack and other processes.
5. Do not use PS5 native-app assumptions: Linux processes have a different memory and process model.

## Validation checklist

- [ ] Capture fresh uname -a, /etc/os-release, free -h and lscpu.
- [ ] Capture vulkaninfo --summary and Vulkan memory heaps.
- [ ] Confirm render-node permissions and active Mesa/RADV driver.
- [ ] Run a small CPU inference smoke test.
- [ ] Run a small Vulkan inference smoke test and record peak memory.
- [ ] Repeat for image generation only after text-runtime memory use is characterized.
