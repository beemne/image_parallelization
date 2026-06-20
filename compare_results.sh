#!/bin/bash
echo "=== Image Comparison ==="

# Check if images exist
if [ -f "datasets/output/4k_seq.ppm" ]; then
    echo "4K Sequential: $(du -h datasets/output/4k_seq.ppm | cut -f1)"
fi
if [ -f "datasets/output/4k_omp.ppm" ]; then
    echo "4K OpenMP: $(du -h datasets/output/4k_omp.ppm | cut -f1)"
fi
if [ -f "datasets/output/4k_cuda.ppm" ]; then
    echo "4K CUDA: $(du -h datasets/output/4k_cuda.ppm | cut -f1)"
fi

echo ""
if [ -f "datasets/output/8k_seq.ppm" ]; then
    echo "8K Sequential: $(du -h datasets/output/8k_seq.ppm | cut -f1)"
fi
if [ -f "datasets/output/8k_omp.ppm" ]; then
    echo "8K OpenMP: $(du -h datasets/output/8k_omp.ppm | cut -f1)"
fi
if [ -f "datasets/output/8k_cuda.ppm" ]; then
    echo "8K CUDA: $(du -h datasets/output/8k_cuda.ppm | cut -f1)"
fi

echo -e "\nAll outputs are in datasets/output/"
