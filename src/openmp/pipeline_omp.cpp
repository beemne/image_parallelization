#include "../../include/image_processing.h"
#include "../common/image_io.h"
#include <omp.h>
#include <iostream>
#include <chrono>
#include <vector>
#include <iomanip>
#include <getopt.h>

// Optimized Gaussian Blur with OpenMP
class GaussianBlurOMP {
private:
    static constexpr int KERNEL_SIZE = 5;
    static constexpr int KERNEL_RADIUS = KERNEL_SIZE / 2;
    static constexpr int TILE_SIZE = 64;
    float kernel[KERNEL_SIZE][KERNEL_SIZE];
    
    void generateKernel(float sigma) {
        float sum = 0.0f;
        for (int i = -KERNEL_RADIUS; i <= KERNEL_RADIUS; ++i) {
            for (int j = -KERNEL_RADIUS; j <= KERNEL_RADIUS; ++j) {
                float value = expf(-(i*i + j*j) / (2.0f * sigma * sigma));
                kernel[i + KERNEL_RADIUS][j + KERNEL_RADIUS] = value;
                sum += value;
            }
        }
        for (int i = 0; i < KERNEL_SIZE; ++i)
            for (int j = 0; j < KERNEL_SIZE; ++j)
                kernel[i][j] /= sum;
    }
    
public:
    GaussianBlurOMP(float sigma = 1.4f) {
        generateKernel(sigma);
    }
    
    // Block decomposition (horizontal strips)
    void applyBlockDecomp(const Image& input, Image& output, int numThreads) {
        omp_set_num_threads(numThreads);
        
        #pragma omp parallel for schedule(static)
        for (int y = KERNEL_RADIUS; y < input.height - KERNEL_RADIUS; ++y) {
            for (int x = KERNEL_RADIUS; x < input.width - KERNEL_RADIUS; ++x) {
                for (int c = 0; c < input.channels; ++c) {
                    float sum = 0.0f;
                    for (int ky = -KERNEL_RADIUS; ky <= KERNEL_RADIUS; ++ky) {
                        for (int kx = -KERNEL_RADIUS; kx <= KERNEL_RADIUS; ++kx) {
                            sum += input.at(x + kx, y + ky, c) * 
                                   kernel[ky + KERNEL_RADIUS][kx + KERNEL_RADIUS];
                        }
                    }
                    output.at(x, y, c) = static_cast<uint8_t>(std::min(255.0f, sum));
                }
            }
        }
    }
    
    // Tiled decomposition
    void applyTiledDecomp(const Image& input, Image& output, int numThreads) {
        omp_set_num_threads(numThreads);
        
        #pragma omp parallel for collapse(2) schedule(dynamic)
        for (int tileY = 0; tileY < input.height; tileY += TILE_SIZE) {
            for (int tileX = 0; tileX < input.width; tileX += TILE_SIZE) {
                int endY = std::min(tileY + TILE_SIZE, input.height - KERNEL_RADIUS);
                int endX = std::min(tileX + TILE_SIZE, input.width - KERNEL_RADIUS);
                
                for (int y = std::max(tileY, KERNEL_RADIUS); y < endY; ++y) {
                    for (int x = std::max(tileX, KERNEL_RADIUS); x < endX; ++x) {
                        for (int c = 0; c < input.channels; ++c) {
                            float sum = 0.0f;
                            for (int ky = -KERNEL_RADIUS; ky <= KERNEL_RADIUS; ++ky) {
                                for (int kx = -KERNEL_RADIUS; kx <= KERNEL_RADIUS; ++kx) {
                                    sum += input.at(x + kx, y + ky, c) * 
                                           kernel[ky + KERNEL_RADIUS][kx + KERNEL_RADIUS];
                                }
                            }
                            output.at(x, y, c) = static_cast<uint8_t>(std::min(255.0f, sum));
                        }
                    }
                }
            }
        }
    }
    
    // SIMD optimized
    void applySIMD(const Image& input, Image& output, int numThreads) {
        omp_set_num_threads(numThreads);
        
        #pragma omp parallel for
        for (int y = KERNEL_RADIUS; y < input.height - KERNEL_RADIUS; ++y) {
            for (int x = KERNEL_RADIUS; x < input.width - KERNEL_RADIUS; ++x) {
                #pragma omp simd
                for (int c = 0; c < input.channels; ++c) {
                    float sum = 0.0f;
                    for (int ky = -KERNEL_RADIUS; ky <= KERNEL_RADIUS; ++ky) {
                        for (int kx = -KERNEL_RADIUS; kx <= KERNEL_RADIUS; ++kx) {
                            sum += input.at(x + kx, y + ky, c) * 
                                   kernel[ky + KERNEL_RADIUS][kx + KERNEL_RADIUS];
                        }
                    }
                    output.at(x, y, c) = static_cast<uint8_t>(std::min(255.0f, sum));
                }
            }
        }
    }
};

// Complete OpenMP Pipeline
class ImageProcessingPipelineOMP {
private:
    GaussianBlurOMP gaussian;
    SobelEdge sobel;
    
    void handleBoundary(Image& img) {
        // Mirror extension for boundaries
        int radius = 2;
        for (int y = 0; y < radius; ++y) {
            for (int x = 0; x < img.width; ++x) {
                for (int c = 0; c < img.channels; ++c) {
                    img.at(x, y, c) = img.at(x, radius * 2 - y - 1, c);
                    img.at(x, img.height - 1 - y, c) = img.at(x, img.height - radius * 2 + y, c);
                }
            }
        }
        for (int y = 0; y < img.height; ++y) {
            for (int x = 0; x < radius; ++x) {
                for (int c = 0; c < img.channels; ++c) {
                    img.at(x, y, c) = img.at(radius * 2 - x - 1, y, c);
                    img.at(img.width - 1 - x, y, c) = img.at(img.width - radius * 2 + x, y, c);
                }
            }
        }
    }
    
public:
    ImageProcessingPipelineOMP(float sigma = 1.4f) : gaussian(sigma) {}
    
    void process(const Image& input, Image& output, int numThreads, 
                 int decompositionType = 1) {
        Image blurred(input.width, input.height, input.channels);
        
        switch(decompositionType) {
            case 0:
                gaussian.applyBlockDecomp(input, blurred, numThreads);
                break;
            case 1:
                gaussian.applyTiledDecomp(input, blurred, numThreads);
                break;
            case 2:
                gaussian.applySIMD(input, blurred, numThreads);
                break;
            default:
                gaussian.applyTiledDecomp(input, blurred, numThreads);
        }
        
        handleBoundary(blurred);
        sobel.apply(blurred, output);
    }
};

// Main function
void printUsage(const char* progName) {
    std::cout << "Usage: " << progName << " [options]\n"
              << "Options:\n"
              << "  -i, --input FILE      Input PPM file\n"
              << "  -o, --output FILE     Output PPM file\n"
              << "  -t, --threads N       Number of threads (default: 4)\n"
              << "  -d, --decomp TYPE     Decomposition: block, tiled, simd (default: tiled)\n"
              << "  -s, --size WxH        Generate synthetic image\n"
              << "  -g, --generate FILE   Generate gradient image\n"
              << "  --sigma FLOAT         Gaussian sigma (default: 1.4)\n"
              << "  -h, --help            Show this help\n";
}

int main(int argc, char** argv) {
    std::string inputFile, outputFile = "output_omp.ppm";
    std::string generateFile;
    std::string sizeStr;
    std::string decompStr = "tiled";
    int numThreads = 4;
    float sigma = 1.4f;
    
    static struct option long_options[] = {
        {"input", required_argument, 0, 'i'},
        {"output", required_argument, 0, 'o'},
        {"threads", required_argument, 0, 't'},
        {"decomp", required_argument, 0, 'd'},
        {"size", required_argument, 0, 's'},
        {"generate", required_argument, 0, 'g'},
        {"sigma", required_argument, 0, 1},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}
    };
    
    int opt;
    while ((opt = getopt_long(argc, argv, "i:o:t:d:s:g:h", long_options, NULL)) != -1) {
        switch (opt) {
            case 'i': inputFile = optarg; break;
            case 'o': outputFile = optarg; break;
            case 't': numThreads = std::stoi(optarg); break;
            case 'd': decompStr = optarg; break;
            case 's': sizeStr = optarg; break;
            case 'g': generateFile = optarg; break;
            case 1: sigma = std::stof(optarg); break;
            case 'h': printUsage(argv[0]); return 0;
            default: printUsage(argv[0]); return 1;
        }
    }
    
    // Map decomp string to int
    int decompType = 1;
    if (decompStr == "block") decompType = 0;
    else if (decompStr == "tiled") decompType = 1;
    else if (decompStr == "simd") decompType = 2;
    
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
        std::cout << "Generated gradient image: " << generateFile << std::endl;
        generated = true;
    }
    
    if (!generated && !inputFile.empty()) {
        if (!PPMImageIO::read(inputFile, input)) {
            std::cerr << "Failed to read input file" << std::endl;
            return 1;
        }
    } else if (!generated) {
        // Generate default test image
        input = ImageGenerator::generateGradient(1920, 1080);
        std::cout << "Using generated test image (1920x1080)" << std::endl;
    }
    
    std::cout << "Processing " << input.width << "x" << input.height 
              << " with " << numThreads << " threads (" << decompStr << ")" << std::endl;
    
    Image output(input.width, input.height, 1);
    ImageProcessingPipelineOMP pipeline(sigma);
    
    auto start = std::chrono::high_resolution_clock::now();
    pipeline.process(input, output, numThreads, decompType);
    auto end = std::chrono::high_resolution_clock::now();
    
    double timeMs = std::chrono::duration<double, std::milli>(end - start).count();
    std::cout << "Time: " << timeMs << " ms" << std::endl;
    
    PPMImageIO::write(outputFile, output);
    std::cout << "Saved: " << outputFile << std::endl;
    
    return 0;
}