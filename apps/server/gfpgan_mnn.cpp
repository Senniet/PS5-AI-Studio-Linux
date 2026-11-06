#include <MNN/Interpreter.hpp>
#include <MNN/Tensor.hpp>
#include <algorithm>
#include <chrono>
#include <fstream>
#include <iostream>
#include <memory>
#include <string>
#include <vector>
int main(int argc, char** argv) {
    if (argc != 5) { std::cerr << "usage: gfpgan-mnn model.mnn input.f32 output.f32 face_count\n"; return 2; }
    const int count = std::stoi(argv[4]);
    if (count < 1 || count > 32) { std::cerr << "invalid face count\n"; return 2; }
    std::shared_ptr<MNN::Interpreter> net(MNN::Interpreter::createFromFile(argv[1]));
    if (!net) { std::cerr << "GFPGAN model load failed\n"; return 3; }
    MNN::ScheduleConfig config; config.type = MNN_FORWARD_VULKAN; config.numThread = 2;
    MNN::BackendConfig backend; backend.precision = MNN::BackendConfig::Precision_High; config.backendConfig = &backend;
    auto* session = net->createSession(config);
    if (!session) { std::cerr << "MNN Vulkan session creation failed\n"; return 4; }
    auto* input = net->getSessionInput(session, "input");
    auto* output = net->getSessionOutput(session, "output");
    if (!input || !output || input->elementSize() != 3u*512u*512u || output->elementSize() != input->elementSize()) {
        std::cerr << "unexpected GFPGAN input/output tensor shape\n";
        net->releaseSession(session); return 5;
    }
    constexpr size_t elements = 3u*512u*512u;
    std::vector<float> source(elements), result(elements);
    std::ifstream in(argv[2], std::ios::binary);
    if (!in) { std::cerr << "face tensor input could not be opened\n"; net->releaseSession(session); return 6; }
    std::ofstream out(argv[3], std::ios::binary);
    if (!out) { std::cerr << "face tensor output could not be opened\n"; net->releaseSession(session); return 7; }
    MNN::Tensor hostInput(input, MNN::Tensor::CAFFE), hostOutput(output, MNN::Tensor::CAFFE);
    const auto allStart = std::chrono::steady_clock::now();
    for (int n=0; n<count; ++n) {
        in.read(reinterpret_cast<char*>(source.data()), static_cast<std::streamsize>(elements*sizeof(float)));
        if (in.gcount() != static_cast<std::streamsize>(elements*sizeof(float))) { std::cerr << "face tensor input size mismatch at face " << n+1 << "\n"; net->releaseSession(session); return 8; }
        std::copy(source.begin(), source.end(), hostInput.host<float>());
        input->copyFromHostTensor(&hostInput);
        const auto status = net->runSession(session);
        if (status != MNN::NO_ERROR) { std::cerr << "GFPGAN Vulkan inference failed status=" << status << " face=" << n+1 << "\n"; net->releaseSession(session); return 9; }
        output->copyToHostTensor(&hostOutput);
        std::copy(hostOutput.host<float>(), hostOutput.host<float>()+elements, result.begin());
        out.write(reinterpret_cast<const char*>(result.data()), static_cast<std::streamsize>(elements*sizeof(float)));
        if (!out) { std::cerr << "face tensor output write failed\n"; net->releaseSession(session); return 10; }
        std::cout << "FACE " << n+1 << "/" << count << " done" << std::endl;
    }
    const double ms = std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-allStart).count();
    std::cout << "GFPGAN_MNN_VULKAN_OK faces=" << count << " elapsed_ms=" << ms << std::endl;
    net->releaseSession(session);
    return 0;
}
