#include "../../include/image_processing.h"
#include "../common/image_io.h"
#include <iostream>
#include <chrono>
#include <getopt.h>

void printUsage(const char* progName) {
    std::cout << "Usage: " << progName << " [options]\n"
              << "Options:\n"
              << "  -i, --input FILE      Input PPM file\n"
              << "  -o, --output FILE     Output PPM file\n"
              << "  -s, --size WxH        Generate synthetic image (WxH)\n"
              << "  -g, --generate FILE   Generate gradient image\n"
              << "  -c, --checker FILE    Generate checkerboard image\n"
              << "  --sigma FLOAT         Gaussian sigma (default: 1.4)\n"
              << "  -h, --help            Show this help\n";
}

int main(int argc, char** argv) {
    std::string inputFile, outputFile = "output.ppm";
    std::string generateFile, checkerFile;
    std::string sizeStr;
    float sigma = 1.4f;
    
    static struct option long_options[] = {
        {"input", required_argument, 0, 'i'},
        {"output", required_argument, 0, 'o'},
        {"size", required_argument, 0, 's'},
        {"generate", required_argument, 0, 'g'},
        {"checker", required_argument, 0, 'c'},
        {"sigma", required_argument, 0, 1},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}
    };
    
    int opt;
    while ((opt = getopt_long(argc, argv, "i:o:s:g:c:h", long_options, NULL)) != -1) {
        switch (opt) {
            case 'i': inputFile = optarg; break;
            case 'o': outputFile = optarg; break;
            case 's': sizeStr = optarg; break;
            case 'g': generateFile = optarg; break;
            case 'c': checkerFile = optarg; break;
            case 1: sigma = std::stof(optarg); break;
            case 'h': printUsage(argv[0]); return 0;
            default: printUsage(argv[0]); return 1;
        }
    }
    
    Image input;
    bool generated = false;
    
    // Generate synthetic image if requested
    if (!generateFile.empty()) {
        int width = 1920, height = 1080;
        if (!sizeStr.empty()) {
            sscanf(sizeStr.c_str(), "%dx%d", &width, &height);
        }
        input = ImageGenerator::generateGradient(width, height);
        PPMImageIO::write(generateFile, input);
        std::cout << "Generated gradient image: " << generateFile 
                  << " (" << width << "x" << height << ")" << std::endl;
        generated = true;
    }
    
    if (!checkerFile.empty()) {
        int width = 1920, height = 1080;
        int tileSize = 64;
        if (!sizeStr.empty()) {
            sscanf(sizeStr.c_str(), "%dx%d", &width, &height);
        }
        input = ImageGenerator::generateCheckerboard(width, height, tileSize);
        PPMImageIO::write(checkerFile, input);
        std::cout << "Generated checkerboard image: " << checkerFile 
                  << " (" << width << "x" << height << ")" << std::endl;
        generated = true;
    }
    
    // Read input if not generated
    if (!generated && !inputFile.empty()) {
        if (!PPMImageIO::read(inputFile, input)) {
            std::cerr << "Failed to read input file: " << inputFile << std::endl;
            return 1;
        }
        std::cout << "Loaded image: " << inputFile 
                  << " (" << input.width << "x" << input.height << ")" << std::endl;
    } else if (!generated) {
        std::cerr << "No input specified. Use -i, -g, or -c" << std::endl;
        printUsage(argv[0]);
        return 1;
    }
    
    // Process image
    std::cout << "Processing with Gaussian sigma=" << sigma << "..." << std::endl;
    
    Image output(input.width, input.height, 1);
    ImageProcessingPipeline pipeline(sigma);
    
    auto start = std::chrono::high_resolution_clock::now();
    pipeline.processSequential(input, output);
    auto end = std::chrono::high_resolution_clock::now();
    
    double timeMs = std::chrono::duration<double, std::milli>(end - start).count();
    double timeS = timeMs / 1000.0;
    
    std::cout << "Time: " << timeMs << " ms (" << timeS << " s)" << std::endl;
    std::cout << "Throughput: " << (input.width * input.height / 1e6) / timeS 
              << " MP/s" << std::endl;
    
    // Save output
    if (PPMImageIO::write(outputFile, output)) {
        std::cout << "Saved output: " << outputFile << std::endl;
    } else {
        std::cerr << "Failed to save output" << std::endl;
        return 1;
    }
    
    return 0;
}