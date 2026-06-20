#!/bin/bash
# Complete profiling script for CPU and GPU performance analysis

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Image Processing Pipeline Profiler   ${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if executables exist
check_executable() {
    if [ ! -f "$1" ]; then
        echo -e "${RED}Error: $1 not found. Build the project first.${NC}"
        exit 1
    fi
}

# CPU Profiling with perf
profile_cpu() {
    echo -e "\n${GREEN}=== CPU Profiling with perf ===${NC}"
    
    # Check if perf is available
    if ! command -v perf &> /dev/null; then
        echo -e "${YELLOW}perf not found. Installing...${NC}"
        sudo apt-get update && sudo apt-get install -y linux-tools-common linux-tools-$(uname -r)
    fi
    
    # Check for test image
    if [ ! -f "datasets/input/test_4k.ppm" ]; then
        echo -e "${YELLOW}Generating test image...${NC}"
        ./build/sequential --size 3840x2160 --generate datasets/input/test_4k.ppm
    fi
    
    echo -e "\n${BLUE}1. Basic Performance Counters${NC}"
    perf stat -e cycles,instructions,cache-references,cache-misses,\
L1-dcache-load-misses,LLC-load-misses,branch-misses,branch-load-misses \
-r 3 \
./build/omp_pipeline datasets/input/test_4k.ppm /dev/null 16 tiled
    
    echo -e "\n${BLUE}2. Detailed Cache Analysis${NC}"
    perf stat -e L1-dcache-loads,L1-dcache-load-misses,\
L1-dcache-stores,L1-dcache-store-misses,\
L2_cache_misses_from_dc_misses,\
LLC-loads,LLC-load-misses,LLC-stores,LLC-store-misses \
-r 3 \
./build/omp_pipeline datasets/input/test_4k.ppm /dev/null 16 tiled
    
    echo -e "\n${BLUE}3. CPU Cycles Analysis${NC}"
    perf stat -e cpu-cycles,cpu-clock,task-clock,\
page-faults,context-switches,cpu-migrations \
-r 3 \
./build/omp_pipeline datasets/input/test_4k.ppm /dev/null 16 tiled
    
    echo -e "\n${BLUE}4. Generate Flame Graph${NC}"
    # Record with call graph
    echo "Recording performance data (this may take a minute)..."
    sudo perf record -F 99 -g -- ./build/omp_pipeline datasets/input/test_4k.ppm /dev/null 16 tiled
    
    # Generate flame graph if tools are available
    if command -v perf script &> /dev/null; then
        echo "Generating flame graph data..."
        sudo perf script > perf.data.out
        
        # Check for flame graph tools
        if [ -f "/usr/local/bin/stackcollapse-perf.pl" ] && [ -f "/usr/local/bin/flamegraph.pl" ]; then
            /usr/local/bin/stackcollapse-perf.pl perf.data.out > perf.folded
            /usr/local/bin/flamegraph.pl perf.folded > cpu_flamegraph.svg
            echo -e "${GREEN}Flame graph generated: cpu_flamegraph.svg${NC}"
        else
            echo -e "${YELLOW}Flame graph tools not installed.${NC}"
            echo "Install with:"
            echo "  git clone https://github.com/brendangregg/FlameGraph.git"
            echo "  cd FlameGraph && sudo make install"
        fi
    fi
    
    # Intel VTune (if available)
    if command -v vtune &> /dev/null; then
        echo -e "\n${BLUE}5. Intel VTune Analysis${NC}"
        vtune -collect hotspots -result-dir vtune_results -- \
            ./build/omp_pipeline datasets/input/test_4k.ppm /dev/null 16 tiled
        vtune -report summary -result-dir vtune_results
        echo -e "${GREEN}VTune results saved to: vtune_results/${NC}"
    else
        echo -e "${YELLOW}Intel VTune not found. Skipping.${NC}"
    fi
}

# GPU Profiling with NVIDIA tools
profile_gpu() {
    echo -e "\n${GREEN}=== GPU Profiling with NVIDIA Tools ===${NC}"
    
    # Check if CUDA is available
    if ! command -v nvcc &> /dev/null; then
        echo -e "${RED}CUDA not found. Skipping GPU profiling.${NC}"
        return
    fi
    
    # Check for test image
    if [ ! -f "datasets/input/test_4k.ppm" ]; then
        echo -e "${YELLOW}Generating test image...${NC}"
        ./build/sequential --size 3840x2160 --generate datasets/input/test_4k.ppm
    fi
    
    # Basic GPU info
    echo -e "\n${BLUE}1. GPU Information${NC}"
    nvidia-smi --query-gpu=name,driver_version,memory.total,compute_cap \
               --format=csv,noheader
    
    echo -e "\n${BLUE}2. Basic CUDA Profiling (nvprof)${NC}"
    if command -v nvprof &> /dev/null; then
        nvprof --metrics all ./build/cuda_pipeline datasets/input/test_4k.ppm /dev/null
    else
        echo -e "${YELLOW}nvprof not found (deprecated in newer CUDA). Using nsys.${NC}"
    fi
    
    echo -e "\n${BLUE}3. NVIDIA Nsight Systems (system-level)${NC}"
    if command -v nsys &> /dev/null; then
        nsys profile --stats=true -o gpu_profile \
            ./build/cuda_pipeline datasets/input/test_4k.ppm /dev/null
        echo -e "${GREEN}Nsight Systems report: gpu_profile.nsys-rep${NC}"
    else
        echo -e "${YELLOW}Nsight Systems not found. Skipping.${NC}"
    fi
    
    echo -e "\n${BLUE}4. NVIDIA Nsight Compute (kernel-level)${NC}"
    if command -v ncu &> /dev/null; then
        ncu --metrics sm__throughput.avg.pct,\
smsp__inst_executed.avg.per_cycle_active,\
l1tex__t_sectors_pipe_lsu_mem_global_op_ld.sum.per_second,\
l1tex__t_sectors_pipe_lsu_mem_shared_op_ld.sum.per_second \
./build/cuda_pipeline datasets/input/test_4k.ppm /dev/null
        
        echo -e "\n${BLUE}5. Occupancy Analysis${NC}"
        ncu --kernel-id ::gaussianBlurShared:1 \
            --metrics sm__warps_active.avg.pct \
            ./build/cuda_pipeline datasets/input/test_4k.ppm /dev/null
    else
        echo -e "${YELLOW}Nsight Compute not found. Skipping.${NC}"
    fi
}

# Memory bandwidth test
test_memory_bandwidth() {
    echo -e "\n${GREEN}=== Memory Bandwidth Analysis ===${NC}"
    
    # Check for STREAM benchmark
    if [ ! -f "stream" ]; then
        echo -e "${YELLOW}Downloading STREAM benchmark...${NC}"
        wget http://www.cs.virginia.edu/stream/FTP/Code/stream.c
        gcc -O3 -fopenmp stream.c -o stream
    fi
    
    echo -e "\n${BLUE}1. STREAM Benchmark (Memory Bandwidth)${NC}"
    ./stream
    
    echo -e "\n${BLUE}2. Application Memory Bandwidth${NC}"
    for size in 1920x1080 3840x2160 7680x4320; do
        echo -e "\n${YELLOW}Testing $size...${NC}"
        # Generate image if needed
        ./build/sequential --size $size --generate datasets/input/test_${size}.ppm 2>/dev/null || true
        
        # Measure memory bandwidth
        perf stat -e ref-cycles,mem_load_uops_retired.l3_miss \
            ./build/omp_pipeline datasets/input/test_${size}.ppm /dev/null 16 tiled 2>&1 | \
            grep -E "seconds time elapsed|mem_load_uops" || true
    done
}

# Cache analysis
analyze_cache() {
    echo -e "\n${GREEN}=== Cache Hierarchy Analysis ===${NC}"
    
    # Check for test image
    if [ ! -f "datasets/input/test_8k.ppm" ]; then
        echo -e "${YELLOW}Generating 8K test image...${NC}"
        ./build/sequential --size 7680x4320 --generate datasets/input/test_8k.ppm
    fi
    
    echo -e "\n${BLUE}1. L1 Cache Analysis${NC}"
    perf stat -e L1-dcache-load-misses,L1-dcache-loads,\
L1-dcache-store-misses,L1-dcache-stores \
-r 3 \
./build/omp_pipeline datasets/input/test_8k.ppm /dev/null 32 tiled
    
    echo -e "\n${BLUE}2. L2 Cache Analysis${NC}"
    perf stat -e L2_cache_misses_from_dc_misses,\
L2_cache_misses_from_dc_stores \
-r 3 \
./build/omp_pipeline datasets/input/test_8k.ppm /dev/null 32 tiled
    
    echo -e "\n${BLUE}3. L3/LLC Cache Analysis${NC}"
    perf stat -e LLC-loads,LLC-load-misses,LLC-stores,LLC-store-misses \
-r 3 \
./build/omp_pipeline datasets/input/test_8k.ppm /dev/null 32 tiled
    
    echo -e "\n${BLUE}4. Cache Miss Rate Summary${NC}"
    perf stat -e cache-references,cache-misses \
-r 3 \
./build/omp_pipeline datasets/input/test_8k.ppm /dev/null 32 tiled
}

# Thread scaling analysis
analyze_scaling() {
    echo -e "\n${GREEN}=== Thread Scaling Analysis ===${NC}"
    
    echo -e "\n${BLUE}1. Strong Scaling (Fixed Problem Size)${NC}"
    echo "Threads,Time_ms,Speedup,Efficiency" > strong_scaling.csv
    
    for t in 1 2 4 8 16 24 32 48 64; do
        if [ $t -le $(nproc) ]; then
            echo -n "Testing $t threads... "
            TIME=$(./build/omp_pipeline datasets/input/test_4k.ppm /dev/null $t tiled 2>&1 | \
                   grep "Time:" | awk '{print $2}')
            if [ ! -z "$TIME" ]; then
                echo "$t,$TIME" >> strong_scaling.csv
                echo "Done: ${TIME}ms"
            else
                echo "Failed"
            fi
        fi
    done
    
    echo -e "\n${BLUE}2. Weak Scaling (Growing Problem Size)${NC}"
    echo "Threads,Width,Height,Time_ms" > weak_scaling.csv
    
    base_w=1920
    base_h=1080
    
    for t in 1 2 4 8 16 24 32; do
        if [ $t -le $(nproc) ]; then
            w=$((base_w * t))
            h=$((base_h * t))
            echo -n "Testing $t threads with ${w}x${h}... "
            ./build/sequential --size ${w}x${h} --generate datasets/input/test_temp.ppm 2>/dev/null || true
            TIME=$(./build/omp_pipeline datasets/input/test_temp.ppm /dev/null $t tiled 2>&1 | \
                   grep "Time:" | awk '{print $2}')
            if [ ! -z "$TIME" ]; then
                echo "$t,$w,$h,$TIME" >> weak_scaling.csv
                echo "Done: ${TIME}ms"
            else
                echo "Failed"
            fi
        fi
    done
    
    echo -e "\n${GREEN}Scaling data saved to: strong_scaling.csv, weak_scaling.csv${NC}"
}

# Main execution
main() {
    case "$1" in
        cpu)
            profile_cpu
            ;;
        gpu)
            profile_gpu
            ;;
        memory)
            test_memory_bandwidth
            ;;
        cache)
            analyze_cache
            ;;
        scaling)
            analyze_scaling
            ;;
        all)
            profile_cpu
            profile_gpu
            test_memory_bandwidth
            analyze_cache
            analyze_scaling
            ;;
        *)
            echo "Usage: $0 {cpu|gpu|memory|cache|scaling|all}"
            echo ""
            echo "Options:"
            echo "  cpu      - Profile CPU performance"
            echo "  gpu      - Profile GPU performance"
            echo "  memory   - Test memory bandwidth"
            echo "  cache    - Analyze cache hierarchy"
            echo "  scaling  - Analyze thread scaling"
            echo "  all      - Run all profiling"
            echo ""
            echo "Example: $0 all"
            exit 1
            ;;
    esac
    
    echo -e "\n${GREEN}=== Profiling Complete ===${NC}"
}

# Run main
main "$@"