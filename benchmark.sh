#!/bin/bash

echo "========================================="
echo "  PERFORMANCE BENCHMARK - 4K & 8K IMAGES"
echo "========================================="

mkdir -p datasets/output

# Function to run and time
run_test() {
    local name=$1
    local cmd=$2
    echo -n "$name: "
    time $cmd 2>&1 | grep -E "Time|GPU Time|saved" || true
    echo ""
}

echo -e "\n=== 4K IMAGE (3840x2160) ==="
run_test "Sequential" "./build/sequential -i datasets/input/4k.ppm -o datasets/output/4k_seq.ppm"
run_test "OpenMP 4T"  "./build/omp_pipeline -i datasets/input/4k.ppm -o datasets/output/4k_omp_4.ppm -t 4 -d tiled"
run_test "OpenMP 8T"  "./build/omp_pipeline -i datasets/input/4k.ppm -o datasets/output/4k_omp_8.ppm -t 8 -d tiled"
run_test "OpenMP 16T" "./build/omp_pipeline -i datasets/input/4k.ppm -o datasets/output/4k_omp_16.ppm -t 16 -d tiled"
run_test "OpenMP 32T" "./build/omp_pipeline -i datasets/input/4k.ppm -o datasets/output/4k_omp_32.ppm -t 32 -d tiled"
run_test "CUDA"       "./build/cuda_pipeline -i datasets/input/4k.ppm -o datasets/output/4k_cuda.ppm"

echo -e "\n=== 8K IMAGE (7680x4320) ==="
run_test "Sequential" "./build/sequential -i datasets/input/8k.ppm -o datasets/output/8k_seq.ppm"
run_test "OpenMP 16T" "./build/omp_pipeline -i datasets/input/8k.ppm -o datasets/output/8k_omp_16.ppm -t 16 -d tiled"
run_test "OpenMP 32T" "./build/omp_pipeline -i datasets/input/8k.ppm -o datasets/output/8k_omp_32.ppm -t 32 -d tiled"
run_test "CUDA"       "./build/cuda_pipeline -i datasets/input/8k.ppm -o datasets/output/8k_cuda.ppm"

echo -e "\n========================================="
echo "Benchmark complete! Check datasets/output/"
ls -lh datasets/output/*.ppm
