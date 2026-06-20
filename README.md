# Image Processing Pipeline: Architectural Profiling & Parallelization

## Overview
This project implements and benchmarks three parallelization strategies for a computationally intensive image processing pipeline (Gaussian blur + Sobel edge detection):

1. **Sequential Baseline** - Single-threaded reference implementation
2. **CPU Multi-threading** - OpenMP with block, tiled, and SIMD decompositions
3. **GPU Acceleration** - CUDA with shared memory optimization
