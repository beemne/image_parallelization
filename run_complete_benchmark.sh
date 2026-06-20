#!/bin/bash
# ============================================
# COMPLETE BENCHMARK SCRIPT
# ============================================

cd /home/beemineta/image_parallelization

echo "=========================================="
echo "  IMAGE PROCESSING PIPELINE BENCHMARK"
echo "  $(date)"
echo "=========================================="

# Create directories
mkdir -p datasets/input datasets/output results

# ============================================
# GENERATE INPUT IMAGES (if needed)
# ============================================

if [ ! -f "datasets/input/4k.ppm" ] || [ ! -s "datasets/input/4k.ppm" ]; then
    echo -e "\n[1/5] Generating 4K input image..."
    ./build/sequential --size 3840x2160 --generate datasets/input/4k.ppm
fi

if [ ! -f "datasets/input/8k.ppm" ] || [ ! -s "datasets/input/8k.ppm" ]; then
    echo -e "\n[1/5] Generating 8K input image..."
    ./build/sequential --size 7680x4320 --generate datasets/input/8k.ppm
fi

# ============================================
# RUN BENCHMARKS
# ============================================

echo -e "\n[2/5] Running 4K benchmarks..."

echo "  Sequential 4K..."
time ./build/sequential -i datasets/input/4k.ppm -o datasets/output/4k_seq.ppm 2>&1 | grep -E "Time|Throughput"

echo "  OpenMP 4K (16 threads)..."
time ./build/omp_pipeline -i datasets/input/4k.ppm -o datasets/output/4k_omp.ppm -t 16 -d tiled 2>&1 | grep -E "Time|Throughput"

echo "  CUDA 4K..."
time ./build/cuda_pipeline -i datasets/input/4k.ppm -o datasets/output/4k_cuda.ppm 2>&1 | grep -E "GPU Time|Saved"

echo -e "\n[3/5] Running 8K benchmarks..."

echo "  Sequential 8K..."
time ./build/sequential -i datasets/input/8k.ppm -o datasets/output/8k_seq.ppm 2>&1 | grep -E "Time|Throughput"

echo "  OpenMP 8K (16 threads)..."
time ./build/omp_pipeline -i datasets/input/8k.ppm -o datasets/output/8k_omp.ppm -t 16 -d tiled 2>&1 | grep -E "Time|Throughput"

echo "  CUDA 8K..."
time ./build/cuda_pipeline -i datasets/input/8k.ppm -o datasets/output/8k_cuda.ppm 2>&1 | grep -E "GPU Time|Saved"

# ============================================
# CHECK RESULTS
# ============================================

echo -e "\n[4/5] Checking results..."
echo "  Output files:"
ls -lh datasets/output/*.ppm | awk '{print "    " $9 " (" $5 ")"}'

SUCCESS=$(find datasets/output -name "*.ppm" -size +0 | wc -l)
echo "  ✅ $SUCCESS successful files"

# ============================================
# CONVERT TO JPEG
# ============================================

echo -e "\n[5/5] Converting to JPEG..."

python3 << 'PYTHON'
import os
from PIL import Image

output_dir = 'datasets/output'
converted = 0

for filename in os.listdir(output_dir):
    if filename.endswith('.ppm'):
        ppm_path = os.path.join(output_dir, filename)
        jpg_path = ppm_path.replace('.ppm', '.jpg')
        
        if os.path.getsize(ppm_path) == 0:
            print(f"  ⚠️ Skipping empty: {filename}")
            continue
        
        try:
            img = Image.open(ppm_path)
            if img.mode != 'RGB':
                img = img.convert('RGB')
            img.save(jpg_path, 'JPEG', quality=95)
            print(f"  ✅ Converted: {filename}")
            converted += 1
        except Exception as e:
            print(f"  ❌ Error: {filename} - {e}")

print(f"\n  ✅ Converted {converted} images to JPEG")
PYTHON

# ============================================
# SUMMARY
# ============================================

echo -e "\n=========================================="
echo "  ✅ BENCHMARK COMPLETE!"
echo "=========================================="
echo ""
echo "Results saved in:"
echo "  📁 PPM: datasets/output/*.ppm"
echo "  📁 JPEG: datasets/output/*.jpg"
echo ""
echo "View with:"
echo "  display datasets/output/4k_cuda.jpg"
echo "  or download to local machine"
echo "=========================================="
