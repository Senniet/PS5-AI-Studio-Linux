#include <MNN/Interpreter.hpp>
#include <MNN/Tensor.hpp>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <fstream>
#include <iostream>
#include <memory>
#include <string>
#include <vector>
static int reflectIndex(int p, int n) {
    if (n <= 1) return 0;
    while (p < 0 || p >= n) p = p < 0 ? -p : 2 * n - p - 2;
    return p;
}
static std::vector<int> tileStarts(int length, int tile, int overlap) {
    std::vector<int> v;
    if (length <= tile) return {0};
    const int stride = std::max(1, tile - 2 * overlap);
    for (int p = 0;; p += stride) {
        int s = std::min(p, length - tile);
        if (v.empty() || v.back() != s) v.push_back(s);
        if (s + tile >= length) break;
    }
    return v;
}
static float edgeWeight(int p, int tile, int overlap, bool hasBefore, bool hasAfter) {
    if (overlap <= 0) return 1.f;
    if (hasBefore && p < overlap) {
        float t = float(p + 1) / float(overlap + 1);
        return 0.5f - 0.5f * std::cos(3.14159265358979323846f * t);
    }
    if (hasAfter && p >= tile - overlap) {
        float t = float(tile - p) / float(overlap + 1);
        return 0.5f - 0.5f * std::cos(3.14159265358979323846f * t);
    }
    return 1.f;
}
int main(int argc, char** argv) {
    if (argc != 7) { std::cerr << "usage: mnn_runner model.mnn input.f32 output.f32 width height overlap\n"; return 2; }
    const int width = std::stoi(argv[4]), height = std::stoi(argv[5]), overlap = std::stoi(argv[6]);
    if (width < 1 || height < 1 || width > 12000 || height > 12000 || overlap < 0 || overlap > 128) { std::cerr << "invalid image geometry\n"; return 2; }
    std::shared_ptr<MNN::Interpreter> net(MNN::Interpreter::createFromFile(argv[1]));
    if (!net) { std::cerr << "model load failed\n"; return 3; }
    MNN::ScheduleConfig config; config.type = MNN_FORWARD_VULKAN; config.numThread = 4;
    MNN::BackendConfig backend; backend.precision = MNN::BackendConfig::Precision_High; config.backendConfig = &backend;
    auto* session = net->createSession(config);
    if (!session) { std::cerr << "Vulkan session create failed\n"; return 4; }
    auto* input = net->getSessionInput(session, "input");
    auto* output = net->getSessionOutput(session, "output");
    if (!input || !output) { std::cerr << "model input/output names are not input/output\n"; return 5; }
    const int tileW = input->width(), tileH = input->height(), channels = input->channel();
    if (channels != 3 || tileW < 32 || tileH < 32) { std::cerr << "unexpected model input shape\n"; input->printShape(); return 6; }
    input->printShape(); output->printShape();
    std::vector<float> source(size_t(3) * width * height);
    std::ifstream in(argv[2], std::ios::binary);
    if (!in) { std::cerr << "input file open failed\n"; return 7; }
    in.read(reinterpret_cast<char*>(source.data()), source.size() * sizeof(float));
    if (in.gcount() != static_cast<std::streamsize>(source.size() * sizeof(float))) { std::cerr << "input size mismatch\n"; return 8; }
    MNN::Tensor hostInput(input, MNN::Tensor::CAFFE);
    MNN::Tensor hostOutput(output, MNN::Tensor::CAFFE);
    if (hostInput.elementSize() != size_t(3) * tileW * tileH || hostOutput.elementSize() != hostInput.elementSize()) { std::cerr << "unexpected model input/output element count\n"; return 9; }
    std::vector<float> accum(source.size(), 0.f), weight(size_t(width) * height, 0.f);
    const auto xs = tileStarts(width, tileW, overlap), ys = tileStarts(height, tileH, overlap);
    const size_t totalTiles = xs.size() * ys.size();
    std::cout << "BACKEND MNN_VULKAN0_FP32 tile=" << tileW << "x" << tileH << std::endl;
    auto* tile = hostInput.host<float>();
    const auto start = std::chrono::steady_clock::now();
    size_t tileCount = 0;
    for (int y0 : ys) for (int x0 : xs) {
        for (int c = 0; c < 3; ++c) for (int y = 0; y < tileH; ++y) {
            const int sy = reflectIndex(y0 + y, height);
            for (int x = 0; x < tileW; ++x) {
                const int sx = reflectIndex(x0 + x, width);
                tile[(size_t(c) * tileH + y) * tileW + x] = source[(size_t(c) * height + sy) * width + sx];
            }
        }
        input->copyFromHostTensor(&hostInput);
        auto status = net->runSession(session);
        if (status != MNN::NO_ERROR) { std::cerr << "runSession failed status=" << status << " at tile " << tileCount << "\n"; net->releaseSession(session); return 10; }
        output->copyToHostTensor(&hostOutput);
        const auto* pred = hostOutput.host<float>();
        for (int y = 0; y < tileH; ++y) {
            const float wy = edgeWeight(y, tileH, overlap, y0 > 0, y0 + tileH < height);
            const int dy = y0 + y; if (dy >= height) continue;
            for (int x = 0; x < tileW; ++x) {
                const int dx = x0 + x; if (dx >= width) continue;
                const float w = wy * edgeWeight(x, tileW, overlap, x0 > 0, x0 + tileW < width);
                weight[size_t(dy) * width + dx] += w;
                for (int c = 0; c < 3; ++c) accum[(size_t(c) * height + dy) * width + dx] += pred[(size_t(c) * tileH + y) * tileW + x] * w;
            }
        }
        ++tileCount;
        std::cout << "TILE " << tileCount << "/" << totalTiles << std::endl;
    }
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        const float w = std::max(weight[size_t(y) * width + x], 1e-8f);
        for (int c = 0; c < 3; ++c) { auto& v = accum[(size_t(c) * height + y) * width + x]; v = std::clamp(v / w, 0.f, 1.f); }
    }
    std::ofstream out(argv[3], std::ios::binary);
    if (!out) { std::cerr << "output file open failed\n"; net->releaseSession(session); return 11; }
    out.write(reinterpret_cast<const char*>(accum.data()), accum.size() * sizeof(float));
    const auto elapsed = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
    std::cout << "MNN_VULKAN0_FP32_OK elapsed_ms=" << elapsed << " tiles=" << tileCount << " tile=" << tileW << "x" << tileH << " image=" << width << "x" << height << std::endl;
    net->releaseSession(session);
    return 0;
}