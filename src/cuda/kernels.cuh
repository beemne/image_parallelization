#ifndef CUDA_KERNELS_H
#define CUDA_KERNELS_H

#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include <math.h>

#define TILE_WIDTH 16
#define KERNEL_RADIUS 2
#define KERNEL_SIZE (2 * KERNEL_RADIUS + 1)

// Gaussian kernel weights (5x5, sigma=1.4)
__constant__ float d_gaussianKernel[KERNEL_SIZE][KERNEL_SIZE] = {
    {0.014418f, 0.028084f, 0.035072f, 0.028084f, 0.014418f},
    {0.028084f, 0.054700f, 0.068312f, 0.054700f, 0.028084f},
    {0.035072f, 0.068312f, 0.085312f, 0.068312f, 0.035072f},
    {0.028084f, 0.054700f, 0.068312f, 0.054700f, 0.028084f},
    {0.014418f, 0.028084f, 0.035072f, 0.028084f, 0.014418f}
};

// Gaussian blur with shared memory
__global__ void gaussianBlurShared(const unsigned char* input, 
                                    unsigned char* output,
                                    int width, int height, 
                                    int channels) {
    __shared__ unsigned char tile[TILE_WIDTH + 2 * KERNEL_RADIUS]
                                  [TILE_WIDTH + 2 * KERNEL_RADIUS];
    
    int tx = threadIdx.x;
    int ty = threadIdx.y;
    
    int globalX = blockIdx.x * TILE_WIDTH + tx;
    int globalY = blockIdx.y * TILE_WIDTH + ty;
    
    // Load main tile
    if (globalX < width && globalY < height) {
        tile[ty + KERNEL_RADIUS][tx + KERNEL_RADIUS] = 
            input[(globalY * width + globalX) * channels];
    }
    
    // Load halo regions
    int loadX = globalX - KERNEL_RADIUS;
    int loadY = globalY - KERNEL_RADIUS;
    
    // Left halo
    if (tx < KERNEL_RADIUS && loadX >= 0 && loadY >= 0 && 
        loadX < width && loadY < height) {
        tile[ty + KERNEL_RADIUS][tx] = 
            input[(loadY * width + loadX) * channels];
    }
    
    // Right halo
    if (tx >= TILE_WIDTH - KERNEL_RADIUS && globalX < width && 
        globalY < height && (globalX + KERNEL_RADIUS) < width) {
        tile[ty + KERNEL_RADIUS][tx + KERNEL_SIZE - 1] = 
            input[(globalY * width + globalX + KERNEL_RADIUS) * channels];
    }
    
    // Top halo
    if (ty < KERNEL_RADIUS && loadX >= 0 && loadY >= 0 && 
        loadX < width && loadY < height) {
        tile[ty][tx + KERNEL_RADIUS] = 
            input[(loadY * width + loadX) * channels];
    }
    
    // Bottom halo
    if (ty >= TILE_WIDTH - KERNEL_RADIUS && globalX < width && 
        globalY < height && (globalY + KERNEL_RADIUS) < height) {
        tile[ty + KERNEL_SIZE - 1][tx + KERNEL_RADIUS] = 
            input[((globalY + KERNEL_RADIUS) * width + globalX) * channels];
    }
    
    __syncthreads();
    
    // Apply convolution
    if (globalX >= KERNEL_RADIUS && globalX < width - KERNEL_RADIUS &&
        globalY >= KERNEL_RADIUS && globalY < height - KERNEL_RADIUS) {
        
        float sum = 0.0f;
        for (int ky = 0; ky < KERNEL_SIZE; ++ky) {
            for (int kx = 0; kx < KERNEL_SIZE; ++kx) {
                sum += tile[ty + ky][tx + kx] * d_gaussianKernel[ky][kx];
            }
        }
        
        output[(globalY * width + globalX) * channels] = 
            (unsigned char)min(255.0f, sum);
    }
}

// Sobel edge detection
__global__ void sobelEdgeKernel(const unsigned char* input,
                                 unsigned char* output,
                                 int width, int height) {
    __shared__ unsigned char tile[TILE_WIDTH + 2][TILE_WIDTH + 2];
    
    int tx = threadIdx.x;
    int ty = threadIdx.y;
    int globalX = blockIdx.x * TILE_WIDTH + tx;
    int globalY = blockIdx.y * TILE_WIDTH + ty;
    
    // Load tile with halo
    if (globalX < width && globalY < height) {
        tile[ty + 1][tx + 1] = input[globalY * width + globalX];
    }
    
    // Load halos
    if (tx == 0 && globalX > 0 && globalY < height) {
        tile[ty + 1][0] = input[globalY * width + globalX - 1];
    }
    if (tx == TILE_WIDTH - 1 && globalX < width - 1 && globalY < height) {
        tile[ty + 1][TILE_WIDTH + 1] = input[globalY * width + globalX + 1];
    }
    if (ty == 0 && globalY > 0 && globalX < width) {
        tile[0][tx + 1] = input[(globalY - 1) * width + globalX];
    }
    if (ty == TILE_WIDTH - 1 && globalY < height - 1 && globalX < width) {
        tile[TILE_WIDTH + 1][tx + 1] = input[(globalY + 1) * width + globalX];
    }
    
    __syncthreads();
    
    // Sobel operators
    const int sobelX[3][3] = {{-1, 0, 1}, {-2, 0, 2}, {-1, 0, 1}};
    const int sobelY[3][3] = {{-1, -2, -1}, {0, 0, 0}, {1, 2, 1}};
    
    if (globalX > 0 && globalX < width - 1 &&
        globalY > 0 && globalY < height - 1) {
        
        float gx = 0.0f, gy = 0.0f;
        for (int ky = -1; ky <= 1; ++ky) {
            for (int kx = -1; kx <= 1; ++kx) {
                float pixel = tile[ty + 1 + ky][tx + 1 + kx];
                gx += pixel * sobelX[ky + 1][kx + 1];
                gy += pixel * sobelY[ky + 1][kx + 1];
            }
        }
        
        float magnitude = sqrtf(gx * gx + gy * gy);
        output[globalY * width + globalX] = (unsigned char)min(255.0f, magnitude);
    }
}

#endif