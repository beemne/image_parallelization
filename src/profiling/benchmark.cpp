#include "benchmark.h"
#include "../openmp/pipeline_omp.cpp"
#include <getopt.h>
#include <iostream>
#include <fstream>
#include <iomanip>

void printUsage() {
    std::cout << "Usage: benchmark [options]\n"
              << "Options:\n"
              << "  --seq               Run sequential baseline\n"
              << "  --omp               Run OpenMP benchmarks\n"
              << "  --all               Run all CPU benchmarks\n"
              << "  --size WxH          Image size (default: 3840x2160)\n"
              << "  --threads N1,N2,... Thread counts for OpenMP\n"
              << "  --output FILE       Output CSV file\n"
              << "  --help              Show this help\n";
}

int main(int argc, char** argv) {
    bool runSeq = false, runOMP = false;
    std::string sizeStr = "3840x2160";
    std::string threadStr = "1,2,4,8,16,32";
    std::string outputFile = "benchmark_results.csv";
    
    static struct option long_options[] = {
        {"seq", no_argument, 0, 's'},
        {"omp", no_argument, 0, 'o'},
        {"all", no_argument, 0, 'a'},
        {"size", required_argument, 0, 'z'},
        {"threads", required_argument, 0, 't'},
        {"output", required_argument, 0, 'p'},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}
    };
    
    int opt;
    while ((opt = getopt_long(argc, argv, "soaz:t:p:h", long_options, NULL)) != -1) {
        switch (opt) {
            case 's': runSeq = true; break;
            case 'o': runOMP = true; break;
            case 'a': runSeq = runOMP = true; break;
            case 'z': sizeStr = optarg; break;
            case 't': threadStr = optarg; break;
            case 'p': outputFile = optarg; break;
            case 'h': printUsage(); return 0;
        }
    }
    
    int width, height;
    sscanf(sizeStr.c_str(), "%dx%d", &width, &height);
    
    std::vector<int> threads;
    std::stringstream ss(threadStr);
    std::string token;
    while (std::getline(ss, token, ',')) {
        threads.push_back(std::stoi(token));
    }
    
    std::cout << "=== Image Processing Pipeline Benchmark (CPU Only) ===\n"
              << "Image size: " << width << "x" << height << "\n\n";
    
    PerformanceProfiler profiler;
    std::ofstream csv(outputFile);
    csv << "Implementation,Threads,Width,Height,Time_ms,Speedup,Efficiency\n";
    
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
        csv << "Sequential,1," << width << "," << height << "," << timeMs << ",1.0,100.0\n";
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
            pipeline.process(input, output, t, 1);
            auto end = std::chrono::high_resolution_clock::now();
            double timeMs = std::chrono::duration<double, std::milli>(end - start).count();
            
            if (t == 1) baselineTime = timeMs;
            double speedup = baselineTime / timeMs;
            double efficiency = speedup / t * 100;
            
            csv << "OpenMP_Tiled," << t << "," << width << "," << height << ","
                << timeMs << "," << speedup << "," << efficiency << "\n";
            
            std::cout << "Threads: " << t << "\tTime: " << std::fixed 
                      << std::setprecision(2) << timeMs << " ms"
                      << "\tSpeedup: " << std::setprecision(2) << speedup << "\n";
        }
    }
    
    csv.close();
    std::cout << "\nResults saved to: " << outputFile << std::endl;
    return 0;
}
