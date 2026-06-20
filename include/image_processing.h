#ifndef IMAGE_PROCESSING_H
#define IMAGE_PROCESSING_H

#include <cstdint>
#include <vector>
#include <cmath>
#include <algorithm>
#include <chrono>

// Image structure
struct Image {
    int width;
    int height;
    int channels;
    std::vector<uint8_t> data;
    
    Image() : width(0), height(0), channels(0) {}
    Image(int w, int h, int c) : width(w), height(h), channels(c), data(w * h * c) {}
    
    size_t size() const { return width * height * channels; }
    uint8_t* ptr() { return data.data(); }
    const uint8_t* ptr() const { return data.data(); }
    
    uint8_t& at(int x, int y, int c) {
        return data[(y * width + x) * channels + c];
    }
    
    const uint8_t& at(int x, int y, int c) const {
        return data[(y * width + x) * channels + c];
    }
};

// Gaussian Blur Kernel (5x5 for higher computational density)
class GaussianBlur {
private:
    static constexpr int KERNEL_SIZE = 5;
    static constexpr int KERNEL_RADIUS = KERNEL_SIZE / 2;
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
        // Normalize
        for (int i = 0; i < KERNEL_SIZE; ++i)
            for (int j = 0; j < KERNEL_SIZE; ++j)
                kernel[i][j] /= sum;
    }
    
public:
    GaussianBlur(float sigma = 1.4f) {
        generateKernel(sigma);
    }
    
    void apply(const Image& input, Image& output) const {
        #pragma omp parallel for collapse(2) if(false)  // Sequential for baseline
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
};

// Sobel Edge Detection
class SobelEdge {
private:
    static constexpr int SOBEL_X[3][3] = {{-1, 0, 1}, {-2, 0, 2}, {-1, 0, 1}};
    static constexpr int SOBEL_Y[3][3] = {{-1, -2, -1}, {0, 0, 0}, {1, 2, 1}};
    
public:
    void apply(const Image& input, Image& output) {
        // Convert to grayscale if needed
        Image gray(input.width, input.height, 1);
        if (input.channels == 3) {
            for (int y = 0; y < input.height; ++y) {
                for (int x = 0; x < input.width; ++x) {
                    float r = input.at(x, y, 0);
                    float g = input.at(x, y, 1);
                    float b = input.at(x, y, 2);
                    gray.at(x, y, 0) = static_cast<uint8_t>(0.299f * r + 0.587f * g + 0.114f * b);
                }
            }
        } else {
            gray = input;
        }
        
        // Apply Sobel
        for (int y = 1; y < gray.height - 1; ++y) {
            for (int x = 1; x < gray.width - 1; ++x) {
                float gx = 0.0f, gy = 0.0f;
                for (int ky = -1; ky <= 1; ++ky) {
                    for (int kx = -1; kx <= 1; ++kx) {
                        float pixel = gray.at(x + kx, y + ky, 0);
                        gx += pixel * SOBEL_X[ky + 1][kx + 1];
                        gy += pixel * SOBEL_Y[ky + 1][kx + 1];
                    }
                }
                float magnitude = sqrtf(gx * gx + gy * gy);
                output.at(x, y, 0) = static_cast<uint8_t>(std::min(255.0f, magnitude));
            }
        }
    }
};

// Complete Pipeline: Gaussian Blur + Sobel Edge Detection
class ImageProcessingPipeline {
private:
    GaussianBlur gaussian;
    SobelEdge sobel;
    
public:
    ImageProcessingPipeline(float sigma = 1.4f) : gaussian(sigma) {}
    
    void process(const Image& input, Image& output) {
        // Step 1: Apply Gaussian blur
        Image blurred(input.width, input.height, input.channels);
        gaussian.apply(input, blurred);
        
        // Step 2: Apply Sobel edge detection
        sobel.apply(blurred, output);
    }
    
    void processSequential(const Image& input, Image& output) {
        // Force sequential execution for baseline
        auto old_state = omp_get_max_threads();
        omp_set_num_threads(1);
        process(input, output);
        omp_set_num_threads(old_state);
    }
};

#endif // IMAGE_PROCESSING_H