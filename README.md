# Image Processing Pipeline: Architectural Profiling & Parallelization

## Overview
This project implements and benchmarks three parallelization strategies for a computationally intensive image processing pipeline (Gaussian blur + Sobel edge detection):

1. **Sequential Baseline** - Single-threaded reference implementation
2. **CPU Multi-threading** - OpenMP with block, tiled, and SIMD decompositions
3. **GPU Acceleration** - CUDA with shared memory optimization

## Repository Structure
- `src/` - source code for sequential, OpenMP, and CUDA pipelines
- `include/` - shared headers and pipeline declarations
- `datasets/input/` - input image data for experiments
- `datasets/output/` - generated output images and intermediate data
- `build/` - local build artifacts created by CMake
- `results/` - benchmark CSV and summary files
- `plots_*/` - generated performance plots
- `report_*/` - generated analysis reports and visualizations
- `scripts/` - helper scripts for plotting and profiling

## Input and Output Data
- Input datasets are stored in `datasets/input/`.
- Processed images and benchmark outputs are written to `datasets/output/` or the generated report directories.
- This repository tracks the source code, while generated artifacts such as build files, temporary `.ppm` files, benchmark plots, and report outputs are ignored by `.gitignore`.

## Report Contents
The full report output is saved under directories named `report_<timestamp>/`.
Each report directory typically contains:

- `report.html` - human-readable benchmark summary and analysis
- `summary.txt` - plain-text performance summary
- `performance_data.txt` - raw performance measurements
- `images/` - sample output images from the pipeline
- `plots/` - generated benchmarking plots and charts

## How to Run
1. Build the project with CMake or `make`.
2. Run the sequential, OpenMP, or CUDA pipeline targets.
3. Use `generate_report.sh` to produce the report and plots.
4. Inspect generated results in `report_<timestamp>/` and `results/`.

## Demo Run and Results
A sample demo was run using the repository inputs and generated output images plus a full report.

- Input images used:
  - `datasets/input/4k.jpg`
  - `datasets/input/8k.jpg`
  - `datasets/input/test_4k.ppm`
  - `datasets/input/test_8k.ppm`
- Generated output images:
  - `datasets/output/4k_seq.jpg`
  - `datasets/output/4k_cuda.jpg`
  - `datasets/output/4k_omp_16.jpg`
  - `datasets/output/8k_seq.jpg`
  - `datasets/output/8k_cuda.jpg`
  - `datasets/output/8k_omp_16.jpg`
- Result image examples from the report:
  - `report_20260620_153314/images/4k_cuda.jpg`
  - `report_20260620_153314/images/8k_cuda.jpg`

## Report Output
The demo produced a full report in `report_20260620_153314/`, including:
- `report_20260620_153314/report.html`
- `report_20260620_153314/summary.txt`
- `report_20260620_153314/performance_data.txt`
- `report_20260620_153314/images/`
- `report_20260620_153314/plots/`

## Output Folder Contents
A selection of generated images and plots was copied into `output/` for easier review:
- `output/4k_cuda.jpg`
- `output/8k_cuda.jpg`
- `output/4k_omp_16.jpg`
- `output/8k_omp_16.jpg`
- `output/test.jpg`
- `output/cpu_vs_gpu.png`
- `output/efficiency_heatmap.png`
- `output/execution_time.png`
- `output/speedup_comparison.png`
- `output/strong_scaling.png`

## Demo Result Summary
The sample run showed strong acceleration from the parallel versions:
- CUDA speedup: 4.17x for 8K input, 1.24x for 4K input
- Best OpenMP speedup: 4.98x with 32 threads (8K), 4.79x with 32 threads (4K)
- OpenMP (16 threads) speedup: 4.35x (8K) and 3.84x (4K)

