#include "benchmark.h"
#include "../openmp/pipeline_omp.cpp"
#include "../cuda/pipeline_cuda.cu"
#include <getopt.h>
#include <iostream>
#include <fstream>
#include <iomanip>

void printUsage() {
    std::cout << "Usage: benchmark [options]\n"
              << "Options:\n"
              << "  --seq               Run sequential baseline\n"
              << "  --omp               Run OpenMP benchmarks\n"
              << "  --cuda              Run CUDA benchmarks\n"
              << "  --all               Run all benchmarks\n"
              << "  --size WxH          Image size (default: 3840x2160)\n"
              << "  --threads N1,N2,... Thread counts for OpenMP\n"
              << "  --output FILE       Output CSV file\n"
              << "  --help              Show this help\n";
}

int main(int argc, char** argv) {
    bool runSeq = false, runOMP = false, runCUDA = false;
    std::string sizeStr = "3840x2160";
    std::string threadStr = "1,2,4,8,16,32";
    std::string outputFile = "benchmark_results.csv";
    
    static struct option long_options[] = {
        {"seq", no_argument, 0, 's'},
        {"omp", no_argument, 0, 'o'},
        {"cuda", no_argument, 0, 'c'},
        {"all", no_argument, 0, 'a'},
        {"size", required_argument, 0, 'z'},
        {"threads", required_argument, 0, 't'},
        {"output", required_argument, 0, 'p'},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}
    };
    
    int opt;
    while ((opt = getopt_long(argc, argv, "soca", long_options, NULL)) != -1) {
        switch (opt) {
            case 's': runSeq = true; break;
            case 'o': runOMP = true; break;
            case 'c': runCUDA = true; break;
            case 'a': runSeq = runOMP = runCUDA = true; break;
            case 'z': sizeStr = optarg; break;
            case 't': threadStr = optarg; break;
            case 'p': outputFile = optarg; break;
            case 'h': printUsage(); return 0;
        }
    }
    
    // Parse image size
    int width, height;
    sscanf(sizeStr.c_str(), "%dx%d", &width, &height);
    
    // Parse thread counts
    std::vector<int> threads;
    std::stringstream ss(threadStr);
    std::string token;
    while (std::getline(ss, token, ',')) {
        threads.push_back(std::stoi(token));
    }
    
    std::cout << "=== Image Processing Pipeline Benchmark ===\n"
              << "Image size: " << width << "x" << height << "\n"
              << "Total pixels: " << (width * height / 1e6) << " MP\n\n";
    
    PerformanceProfiler profiler;
    std::ofstream csv(outputFile);
    csv << "Implementation,Threads,Width,Height,Time_ms,Speedup,Efficiency,MemoryBandwidth_MBps\n";
    
    if (runSeq) {
        std::cout << "Running sequential baseline...\n";
        Image input = ImageGenerator::generateGradient(width, height);
        Image output(width, height, 1);
        ImageProcessingPipeline pipeline(1.4f);
        
        auto start = std::chrono::high_resolution_clock::now();
        pipeline.processSequential(input, output);
        auto end = std::chrono::high_resolution_clock::now();
        
        double timeMs = std::chrono::duration<double, std::milli>(end - start).count();
        std::cout << "Sequential time: " << timeMs << " ms\n\n";
        
        csv << "Sequential,1," << width << "," << height << "," 
            << timeMs << ",1.0,100.0,0\n";
        
        PPMImageIO::write("output_sequential.ppm", output);
    }
    
    if (runOMP) {
        std::cout << "Running OpenMP benchmarks...\n";
        Image input = ImageGenerator::generateGradient(width, height);
        ImageProcessingPipelineOMP pipeline(1.4f);
        
        double baselineTime = 0.0;
        
        for (int t : threads) {
            Image output(width, height, 1);
            
            auto start = std::chrono::high_resolution_clock::now();
            pipeline.process(input, output, t, 1);  // Use tiled decomposition
            auto end = std::chrono::high_resolution_clock::now();
            
            double timeMs = std::chrono::duration<double, std::milli>(end - start).count();
            
            if (t == 1) baselineTime = timeMs;
            
            double speedup = baselineTime / timeMs;
            double efficiency = speedup / t * 100;
            double bandwidth = (width * height * 3 * 2) / (timeMs / 1000.0) / 1e6;
            
            csv << "OpenMP_Tiled," << t << "," << width << "," << height << ","
                << timeMs << "," << speedup << "," << efficiency << "," << bandwidth << "\n";
            
            std::cout << "Threads: " << t 
                      << "\tTime: " << std::fixed << std::setprecision(2) << timeMs << " ms"
                      << "\tSpeedup: " << std::fixed << std::setprecision(2) << speedup << "\n";
            
            if (t == 16) {
                PPMImageIO::write("output_omp_16t.ppm", output);
            }
        }
    }
    
    if (runCUDA) {
        std::cout << "\nRunning CUDA benchmarks...\n";
        Image input = ImageGenerator::generateGradient(width, height);
        CUDAPipeline pipeline(width, height, input.channels);
        
        pipeline.copyToDevice(input);
        
        // Warm-up
        for (int i = 0; i < 3; ++i) {
            pipeline.runCompletePipeline();
        }
        
        // Timed run
        cudaEvent_t start, stop;
        cudaEventCreate(&start);
        cudaEventCreate(&stop);
        
        cudaEventRecord(start);
        pipeline.runCompletePipeline();
        cudaEventRecord(stop);
        cudaEventSynchronize(stop);
        
        float milliseconds = 0;
        cudaEventElapsedTime(&milliseconds, start, stop);
        
        cudaEventDestroy(start);
        cudaEventDestroy(stop);
        
        csv << "CUDA,1," << width << "," << height << ","
            << milliseconds << ",0,0,0\n";
        
        std::cout << "CUDA Time: " << std::fixed << std::setprecision(2) 
                  << milliseconds << " ms\n";
        
        Image output(width, height, 1);
        pipeline.copyFromDevice(output);
        PPMImageIO::write("output_cuda.ppm", output);
    }
    
    csv.close();
    std::cout << "\nResults saved to: " << outputFile << std::endl;
    
    return 0;
}