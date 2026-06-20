#!/bin/bash
# ============================================
# SIMPLIFIED BENCHMARK SCRIPT
# No Python dependencies required
# ============================================

PROJECT_DIR="/home/beemineta/image_parallelization"
OUTPUT_DIR="${PROJECT_DIR}/results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_FILE="${OUTPUT_DIR}/benchmark_results_${TIMESTAMP}.csv"

mkdir -p "${OUTPUT_DIR}" "${PROJECT_DIR}/datasets/output"

echo "=========================================="
echo "  IMAGE PROCESSING PIPELINE BENCHMARK"
echo "  Run ID: ${TIMESTAMP}"
echo "=========================================="

# ============================================
# CHECK INPUT IMAGES
# ============================================

echo -e "\n[1/4] Checking input images..."

if [ ! -f "${PROJECT_DIR}/datasets/input/4k.ppm" ]; then
    echo "  Generating synthetic 4K image..."
    ${PROJECT_DIR}/build/sequential --size 3840x2160 --generate ${PROJECT_DIR}/datasets/input/4k.ppm
fi

if [ ! -f "${PROJECT_DIR}/datasets/input/8k.ppm" ]; then
    echo "  Generating synthetic 8K image..."
    ${PROJECT_DIR}/build/sequential --size 7680x4320 --generate ${PROJECT_DIR}/datasets/input/8k.ppm
fi

echo "  ✅ Input images ready"

# ============================================
# RUN BENCHMARKS
# ============================================

echo -e "\n[2/4] Running benchmarks..."

# Function to run and capture time
run_test() {
    local name="$1"
    local cmd="$2"
    local output_file="$3"
    
    echo -n "  $name... "
    
    # Run command
    eval $cmd > /dev/null 2>&1
    
    # Check if output file exists and has content
    if [ -f "$output_file" ] && [ -s "$output_file" ]; then
        # Get time from command output (stored in temp file)
        local time_ms=$(grep -o "[0-9.]* ms" /tmp/benchmark_output 2>/dev/null | head -1 | cut -d' ' -f1)
        if [ -z "$time_ms" ]; then
            time_ms="N/A"
        fi
        echo "${time_ms} ms"
    else
        echo "FAILED"
    fi
}

# Run Sequential 4K
echo "  Running Sequential 4K..."
./build/sequential -i datasets/input/4k.ppm -o datasets/output/4k_seq.ppm 2>&1 | tee /tmp/benchmark_output
SEQ_4K=$(grep "Time:" /tmp/benchmark_output | awk '{print $2}' | cut -d'(' -f1)

# Run OpenMP 4K (16 threads)
echo "  Running OpenMP 4K (16 threads)..."
./build/omp_pipeline -i datasets/input/4k.ppm -o datasets/output/4k_omp.ppm -t 16 -d tiled 2>&1 | tee /tmp/benchmark_output
OMP_4K=$(grep "Time:" /tmp/benchmark_output | awk '{print $2}')

# Run CUDA 4K
echo "  Running CUDA 4K..."
./build/cuda_pipeline -i datasets/input/4k.ppm -o datasets/output/4k_cuda.ppm 2>&1 | tee /tmp/benchmark_output
CUDA_4K=$(grep "Time:" /tmp/benchmark_output | awk '{print $2}')

# Run Sequential 8K
echo "  Running Sequential 8K..."
./build/sequential -i datasets/input/8k.ppm -o datasets/output/8k_seq.ppm 2>&1 | tee /tmp/benchmark_output
SEQ_8K=$(grep "Time:" /tmp/benchmark_output | awk '{print $2}' | cut -d'(' -f1)

# Run OpenMP 8K (16 threads)
echo "  Running OpenMP 8K (16 threads)..."
./build/omp_pipeline -i datasets/input/8k.ppm -o datasets/output/8k_omp.ppm -t 16 -d tiled 2>&1 | tee /tmp/benchmark_output
OMP_8K=$(grep "Time:" /tmp/benchmark_output | awk '{print $2}')

# Run CUDA 8K
echo "  Running CUDA 8K..."
./build/cuda_pipeline -i datasets/input/8k.ppm -o datasets/output/8k_cuda.ppm 2>&1 | tee /tmp/benchmark_output
CUDA_8K=$(grep "Time:" /tmp/benchmark_output | awk '{print $2}')

# ============================================
# GENERATE CSV
# ============================================

echo -e "\n[3/4] Generating CSV results..."

cat > "${RESULTS_FILE}" << EOF
Implementation,Image,Resolution,Time_ms,Speedup
Sequential,4K,3840x2160,${SEQ_4K},1.00
OpenMP_16T,4K,3840x2160,${OMP_4K},$(echo "scale=2; ${SEQ_4K}/${OMP_4K}" | bc -l 2>/dev/null || echo "N/A")
CUDA,4K,3840x2160,${CUDA_4K},$(echo "scale=2; ${SEQ_4K}/${CUDA_4K}" | bc -l 2>/dev/null || echo "N/A")
Sequential,8K,7680x4320,${SEQ_8K},1.00
OpenMP_16T,8K,7680x4320,${OMP_8K},$(echo "scale=2; ${SEQ_8K}/${OMP_8K}" | bc -l 2>/dev/null || echo "N/A")
CUDA,8K,7680x4320,${CUDA_8K},$(echo "scale=2; ${SEQ_8K}/${CUDA_8K}" | bc -l 2>/dev/null || echo "N/A")
EOF

echo "  ✅ CSV saved: ${RESULTS_FILE}"

# ============================================
# DISPLAY RESULTS
# ============================================

echo -e "\n[4/4] Results Summary"
echo "=========================================="
echo ""
echo "Performance Results:"
echo "----------------------------------------"
printf "%-20s %-15s %-15s\n" "Implementation" "4K (ms)" "8K (ms)"
echo "----------------------------------------"
printf "%-20s %-15s %-15s\n" "Sequential" "${SEQ_4K:-N/A}" "${SEQ_8K:-N/A}"
printf "%-20s %-15s %-15s\n" "OpenMP (16T)" "${OMP_4K:-N/A}" "${OMP_8K:-N/A}"
printf "%-20s %-15s %-15s\n" "CUDA" "${CUDA_4K:-N/A}" "${CUDA_8K:-N/A}"
echo "----------------------------------------"
echo ""
echo "Output Images:"
ls -lh datasets/output/*.ppm 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
echo ""
echo "=========================================="
echo "Results saved in: ${RESULTS_FILE}"
echo "=========================================="

# ============================================
# VIEW RESULTS (if display available)
# ============================================

if command -v display &> /dev/null; then
    echo -e "\nViewing results..."
    display datasets/output/4k_seq.ppm &
    display datasets/output/4k_omp.ppm &
    display datasets/output/4k_cuda.ppm &
elif command -v eog &> /dev/null; then
    eog datasets/output/4k_cuda.ppm &
elif command -v feh &> /dev/null; then
    feh datasets/output/4k_cuda.ppm &
else
    echo -e "\nTo view images:"
    echo "  python3 -c \"from PIL import Image; Image.open('datasets/output/4k_cuda.ppm').show()\""
fi
