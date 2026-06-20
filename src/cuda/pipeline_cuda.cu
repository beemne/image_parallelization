#include "../../include/image_processing.h"
#include "../common/image_io.h"
#include "kernels.cuh"
#include <cuda_runtime.h>
#include <cuda_profiler_api.h>
#include <iostream>
#include <chrono>
#include <vector>
#include <iomanip>
#include <getopt.h>

class CUDAPipeline {
private:
    unsigned char *d_input, *d_blurred, *d_output;
    int width, height, channels;
    size_t imageSize;
    
    void checkCudaError(cudaError_t err, const char* msg) {
        if (err != cudaSuccess) {
            std::cerr << "CUDA Error: " << msg << " - " << cudaGetErrorString(err) << std::endl;
            exit(EXIT_FAILURE);
        }
    }
    
public:
    CUDAPipeline(int w, int h, int c) : width(w), height(h), channels(c) {
        imageSize = w * h * sizeof(unsigned char);
        
        checkCudaError(cudaMalloc(&d_input, imageSize * channels), "Malloc input");
        checkCudaError(cudaMalloc(&d_blurred, imageSize * channels), "Malloc blurred");
        checkCudaError(cudaMalloc(&d_output, imageSize), "Malloc output");
    }
    
    ~CUDAPipeline() {
        cudaFree(d_input);
        cudaFree(d_blurred);
        cudaFree(d_output);
    }
    
    void copyToDevice(const Image& img) {
        checkCudaError(cudaMemcpy(d_input, img.ptr(), imageSize * channels, 
                                   cudaMemcpyHostToDevice), "Copy to device");
    }
    
    void copyFromDevice(Image& img) {
        checkCudaError(cudaMemcpy(img.ptr(), d_output, imageSize, 
                                   cudaMemcpyDeviceToHost), "Copy from device");
    }
    
    void runGaussianBlur() {
        dim3 blockDim(TILE_WIDTH, TILE_WIDTH);
        dim3 gridDim((width + TILE_WIDTH - 1) / TILE_WIDTH,
                     (height + TILE_WIDTH - 1) / TILE_WIDTH);
        
        gaussianBlurShared<<<gridDim, blockDim>>>(d_input, d_blurred, 
                                                   width, height, channels);
        checkCudaError(cudaGetLastError(), "Gaussian blur kernel");
        checkCudaError(cudaDeviceSynchronize(), "Gaussian blur sync");
    }
    
    void runSobel() {
        dim3 blockDim(TILE_WIDTH, TILE_WIDTH);
        dim3 gridDim((width + TILE_WIDTH - 1) / TILE_WIDTH,
                     (height + TILE_WIDTH - 1) / TILE_WIDTH);
        
        sobelEdgeKernel<<<gridDim, blockDim>>>(d_blurred, d_output, 
                                                width, height);
        checkCudaError(cudaGetLastError(), "Sobel kernel");
        checkCudaError(cudaDeviceSynchronize(), "Sobel sync");
    }
    
    void runCompletePipeline() {
        runGaussianBlur();
        runSobel();
    }
    
    void benchmark(const Image& input) {
        copyToDevice(input);
        
        // Warm-up
        for (int i = 0; i < 3; ++i) {
            runCompletePipeline();
        }
        
        // Timed run
        cudaEvent_t start, stop;
        cudaEventCreate(&start);
        cudaEventCreate(&stop);
        
        cudaEventRecord(start);
        runCompletePipeline();
        cudaEventRecord(stop);
        cudaEventSynchronize(stop);
        
        float milliseconds = 0;
        cudaEventElapsedTime(&milliseconds, start, stop);
        
        std::cout << "GPU Time: " << std::fixed << std::setprecision(2) 
                  << milliseconds << " ms" << std::endl;
        
        cudaEventDestroy(start);
        cudaEventDestroy(stop);
    }
    
    void printDeviceInfo() {
        cudaDeviceProp prop;
        cudaGetDeviceProperties(&prop, 0);
        
        std::cout << "\n=== GPU Device Info ===" << std::endl;
        std::cout << "Device: " << prop.name << std::endl;
        std::cout << "Compute Capability: " << prop.major << "." << prop.minor << std::endl;
        std::cout << "SM Count: " << prop.multiProcessorCount << std::endl;
        std::cout << "Max Threads per Block: " << prop.maxThreadsPerBlock << std::endl;
        std::cout << "Shared Memory per Block: " << prop.sharedMemPerBlock / 1024 << " KB" << std::endl;
        std::cout << "Total Global Memory: " << prop.totalGlobalMem / 1024 / 1024 << " MB" << std::endl;
        std::cout << "Max Grid Size: " << prop.maxGridSize[0] << "x" 
                  << prop.maxGridSize[1] << std::endl;
    }
};

void printUsage(const char* progName) {
    std::cout << "Usage: " << progName << " [options]\n"
              << "Options:\n"
              << "  -i, --input FILE      Input PPM file\n"
              << "  -o, --output FILE     Output PPM file\n"
              << "  -s, --size WxH        Generate synthetic image\n"
              << "  -b, --benchmark       Run benchmark only\n"
              << "  -h, --help            Show this help\n";
}

int main(int argc, char** argv) {
    std::string inputFile, outputFile = "output_cuda.ppm";
    std::string sizeStr;
    bool benchmarkOnly = false;
    
    static struct option long_options[] = {
        {"input", required_argument, 0, 'i'},
        {"output", required_argument, 0, 'o'},
        {"size", required_argument, 0, 's'},
        {"benchmark", no_argument, 0, 'b'},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}
    };
    
    int opt;
    while ((opt = getopt_long(argc, argv, "i:o:s:bh", long_options, NULL)) != -1) {
        switch (opt) {
            case 'i': inputFile = optarg; break;
            case 'o': outputFile = optarg; break;
            case 's': sizeStr = optarg; break;
            case 'b': benchmarkOnly = true; break;
            case 'h': printUsage(argv[0]); return 0;
            default: printUsage(argv[0]); return 1;
        }
    }
    
    Image input;
    bool generated = false;
    
    // Generate synthetic image if size specified
    if (!sizeStr.empty()) {
        int width, height;
        sscanf(sizeStr.c_str(), "%dx%d", &width, &height);
        input = ImageGenerator::generateGradient(width, height);
        generated = true;
        std::cout << "Generated " << width << "x" << height << " test image" << std::endl;
    }
    
    if (!generated && !inputFile.empty()) {
        if (!PPMImageIO::read(inputFile, input)) {
            std::cerr << "Failed to read input file" << std::endl;
            return 1;
        }
    } else if (!generated) {
        input = ImageGenerator::generateGradient(3840, 2160);
        std::cout << "Using default 4K test image" << std::endl;
    }
    
    CUDAPipeline pipeline(input.width, input.height, input.channels);
    pipeline.printDeviceInfo();
    
    if (benchmarkOnly) {
        std::cout << "\n=== Running Benchmark ===" << std::endl;
        pipeline.benchmark(input);
    } else {
        std::cout << "\n=== Processing Image ===" << std::endl;
        pipeline.copyToDevice(input);
        pipeline.runCompletePipeline();
        
        Image output(input.width, input.height, 1);
        pipeline.copyFromDevice(output);
        PPMImageIO::write(outputFile, output);
        std::cout << "Saved: " << outputFile << std::endl;
    }
    
    return 0;
}