#ifndef BENCHMARK_H
#define BENCHMARK_H

#include "../../include/image_processing.h"
#include "../common/image_io.h"
#include <chrono>
#include <vector>
#include <string>
#include <fstream>
#include <cmath>
#include <numeric>

struct BenchmarkResult {
    std::string implementation;
    int threads;
    int width;
    int height;
    double timeMs;
    double speedup;
    double efficiency;
    double memoryBandwidthMBps;
    double flops;
};

class PerformanceProfiler {
private:
    std::vector<BenchmarkResult> results;
    
    double computeFlops(const Image& img, int kernelSize) {
        // Approximate FLOPs for convolution: width * height * kernelSize^2 * channels
        return static_cast<double>(img.width) * img.height * 
               kernelSize * kernelSize * img.channels * 2;  // 2 ops per multiply-add
    }
    
    double measureMemoryBandwidth(const Image& img, double timeMs) {
        // Read + write operations
        size_t bytes = img.width * img.height * img.channels * 2;
        return (bytes / 1e6) / (timeMs / 1000.0);  // MB/s
    }
    
public:
    void runStrongScaling(const Image& input, int maxThreads = 32) {
        ImageProcessingPipelineOMP pipeline(1.4f);
        double baselineTime = 0.0;
        
        std::cout << "\n=== Strong Scaling Analysis ===" << std::endl;
        std::cout << "Problem size fixed: " << input.width << "x" << input.height << std::endl;
        
        for (int threads = 1; threads <= maxThreads; threads *= 2) {
            Image output(input.width, input.height, 1);
            
            auto start = std::chrono::high_resolution_clock::now();
            pipeline.process(input, output, threads, 1);
            auto end = std::chrono::high_resolution_clock::now();
            
            double timeMs = std::chrono::duration<double, std::milli>(end - start).count();
            
            if (threads == 1) {
                baselineTime = timeMs;
            }
            
            BenchmarkResult res;
            res.implementation = "OpenMP_Tiled";
            res.threads = threads;
            res.width = input.width;
            res.height = input.height;
            res.timeMs = timeMs;
            res.speedup = baselineTime / timeMs;
            res.efficiency = res.speedup / threads * 100;
            res.memoryBandwidthMBps = measureMemoryBandwidth(input, timeMs);
            res.flops = computeFlops(input, 5);
            
            results.push_back(res);
            
            std::cout << "Threads: " << threads 
                      << "\tTime: " << std::fixed << std::setprecision(2) << timeMs << " ms"
                      << "\tSpeedup: " << std::fixed << std::setprecision(2) << res.speedup
                      << "\tEfficiency: " << std::fixed << std::setprecision(1) << res.efficiency << "%"
                      << std::endl;
        }
    }
    
    void runWeakScaling(int baseWidth, int baseHeight, double workPerThread) {
        std::cout << "\n=== Weak Scaling Analysis ===" << std::endl;
        std::cout << "Work per thread: " << workPerThread << " MPixels" << std::endl;
        
        ImageProcessingPipelineOMP pipeline(1.4f);
        double baselineTime = 0.0;
        
        for (int threads = 1; threads <= 32; threads *= 2) {
            int width = baseWidth * sqrt(threads);
            int height = baseHeight * sqrt(threads);
            
            Image input = ImageGenerator::generateGradient(width, height);
            Image output(width, height, 1);
            
            auto start = std::chrono::high_resolution_clock::now();
            pipeline.process(input, output, threads, 1);
            auto end = std::chrono::high_resolution_clock::now();
            
            double timeMs = std::chrono::duration<double, std::milli>(end - start).count();
            
            if (threads == 1) baselineTime = timeMs;
            
            std::cout << "Threads: " << threads 
                      << "\tSize: " << width << "x" << height
                      << "\tTime: " << std::fixed << std::setprecision(2) << timeMs << " ms"
                      << "\tScale: " << std::fixed << std::setprecision(2) << (baselineTime / timeMs)
                      << std::endl;
        }
    }
    
    void exportResultsCSV(const std::string& filename) {
        std::ofstream file(filename);
        file << "Implementation,Threads,Width,Height,Time_ms,Speedup,Efficiency,MemoryBandwidth_MBps,FLOPs\n";
        
        for (const auto& res : results) {
            file << res.implementation << ","
                 << res.threads << ","
                 << res.width << ","
                 << res.height << ","
                 << res.timeMs << ","
                 << res.speedup << ","
                 << res.efficiency << ","
                 << res.memoryBandwidthMBps << ","
                 << res.flops << "\n";
        }
        
        file.close();
        std::cout << "Results exported to " << filename << std::endl;
    }
    
    // Roofline model analysis
    void rooflineAnalysis(const Image& img, double timeMs, double flops, 
                          double memoryBytes) {
        double achievedFlops = flops / (timeMs / 1000.0);
        double achievedBandwidth = memoryBytes / (timeMs / 1000.0) / 1e9;
        double arithmeticIntensity = flops / memoryBytes;
        
        std::cout << "\n=== Roofline Model Analysis ===" << std::endl;
        std::cout << "Arithmetic Intensity: " << std::fixed << std::setprecision(2) 
                  << arithmeticIntensity << " FLOP/byte" << std::endl;
        std::cout << "Achieved Performance: " << std::fixed << std::setprecision(2) 
                  << achievedFlops / 1e9 << " GFLOPS" << std::endl;
        std::cout << "Achieved Bandwidth: " << std::fixed << std::setprecision(2) 
                  << achievedBandwidth << " GB/s" << std::endl;
        
        // Determine bottleneck
        if (arithmeticIntensity < 1.0) {
            std::cout << "Bottleneck: MEMORY BOUND" << std::endl;
        } else if (arithmeticIntensity > 10.0) {
            std::cout << "Bottleneck: COMPUTE BOUND" << std::endl;
        } else {
            std::cout << "Bottleneck: BALANCED" << std::endl;
        }
    }
};

#endif