#!/usr/bin/env bash

set -euo pipefail

# ==========================================
# CONFIGURATION
# ==========================================

cd /home/beemineta/image_parallelization

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# MAIN OUTPUT DIRECTORY - Everything goes here for easy download
MAIN_OUTPUT="outputs_${TIMESTAMP}"

# Subdirectories
RESULTS_DIR="${MAIN_OUTPUT}/results"
PLOTS_DIR="${MAIN_OUTPUT}/plots"
IMAGES_DIR="${MAIN_OUTPUT}/images"
CSV_DIR="${MAIN_OUTPUT}/csv"

# Original directories with existing images
ORIGINAL_OUTPUT="datasets/output"
ORIGINAL_INPUT="datasets/input"

mkdir -p \
    "${RESULTS_DIR}" \
    "${PLOTS_DIR}" \
    "${IMAGES_DIR}" \
    "${CSV_DIR}" \
    "${ORIGINAL_OUTPUT}"

CSV_FILE="${CSV_DIR}/benchmark_results_${TIMESTAMP}.csv"
SUMMARY_FILE="${RESULTS_DIR}/summary_${TIMESTAMP}.txt"

echo "========================================="
echo "IMAGE PARALLELIZATION BENCHMARK"
echo "Run: ${TIMESTAMP}"
echo "Output: ${MAIN_OUTPUT}/"
echo "========================================="

# ==========================================
# CHECK INPUT IMAGES
# ==========================================

echo
echo "[1/5] Checking input images..."

# Check 4K image
if [[ -f "${ORIGINAL_INPUT}/4k.ppm" ]]; then
    echo "  ✅ Found 4K image: ${ORIGINAL_INPUT}/4k.ppm"
    INPUT_4K="${ORIGINAL_INPUT}/4k.ppm"
elif [[ -f "${ORIGINAL_INPUT}/test_4k.ppm" ]]; then
    echo "  ✅ Found 4K image: ${ORIGINAL_INPUT}/test_4k.ppm"
    INPUT_4K="${ORIGINAL_INPUT}/test_4k.ppm"
else
    echo "  ⚠️ 4K image not found, generating..."
    ./build/sequential --size 3840x2160 --generate "${ORIGINAL_INPUT}/test_4k.ppm" > /dev/null 2>&1
    INPUT_4K="${ORIGINAL_INPUT}/test_4k.ppm"
fi

# Check 8K image
if [[ -f "${ORIGINAL_INPUT}/8k.ppm" ]]; then
    echo "  ✅ Found 8K image: ${ORIGINAL_INPUT}/8k.ppm"
    INPUT_8K="${ORIGINAL_INPUT}/8k.ppm"
elif [[ -f "${ORIGINAL_INPUT}/test_8k.ppm" ]]; then
    echo "  ✅ Found 8K image: ${ORIGINAL_INPUT}/test_8k.ppm"
    INPUT_8K="${ORIGINAL_INPUT}/test_8k.ppm"
else
    echo "  ⚠️ 8K image not found, generating..."
    ./build/sequential --size 7680x4320 --generate "${ORIGINAL_INPUT}/test_8k.ppm" > /dev/null 2>&1
    INPUT_8K="${ORIGINAL_INPUT}/test_8k.ppm"
fi

echo "  ✅ Images ready"

# ==========================================
# BENCHMARK FUNCTION
# ==========================================

run_benchmark() {
    local name="$1"
    local cmd="$2"
    
    echo -n "    ${name} ... " >&2
    
    local temp=$(mktemp)
    local start=$(date +%s%N)
    
    eval "$cmd" > "$temp" 2>&1
    
    local end=$(date +%s%N)
    local elapsed=$(( (end-start)/1000000 ))
    
    if [[ "$elapsed" -le 0 ]]; then
        elapsed=1
    fi
    
    rm -f "$temp"
    
    echo "${elapsed} ms" >&2
    echo "$elapsed"
}

# ==========================================
# RUN 4K BENCHMARKS
# ==========================================

echo
echo "[2/5] Running 4K benchmarks..."

# Sequential 4K
SEQ_4K=$(run_benchmark "Sequential 4K" \
    "./build/sequential -i ${INPUT_4K} -o ${ORIGINAL_OUTPUT}/out_seq_4k.ppm")

# OpenMP 4K (various thread counts)
declare -A OMP_4K
for t in 1 2 4 8 16 32; do
    if [[ $t -le $(nproc) ]]; then
        OMP_4K[$t]=$(run_benchmark "OpenMP ${t}T 4K" \
            "./build/omp_pipeline -i ${INPUT_4K} -o ${ORIGINAL_OUTPUT}/out_omp_4k_${t}.ppm -t ${t} -d tiled")
    fi
done

# CUDA 4K
CUDA_4K=$(run_benchmark "CUDA 4K" \
    "./build/cuda_pipeline -i ${INPUT_4K} -o ${ORIGINAL_OUTPUT}/out_cuda_4k.ppm")

# ==========================================
# RUN 8K BENCHMARKS
# ==========================================

echo
echo "[3/5] Running 8K benchmarks..."

# Sequential 8K
SEQ_8K=$(run_benchmark "Sequential 8K" \
    "./build/sequential -i ${INPUT_8K} -o ${ORIGINAL_OUTPUT}/out_seq_8k.ppm")

# OpenMP 8K
declare -A OMP_8K
for t in 1 2 4 8 16 32; do
    if [[ $t -le $(nproc) ]]; then
        OMP_8K[$t]=$(run_benchmark "OpenMP ${t}T 8K" \
            "./build/omp_pipeline -i ${INPUT_8K} -o ${ORIGINAL_OUTPUT}/out_omp_8k_${t}.ppm -t ${t} -d tiled")
    fi
done

# CUDA 8K
CUDA_8K=$(run_benchmark "CUDA 8K" \
    "./build/cuda_pipeline -i ${INPUT_8K} -o ${ORIGINAL_OUTPUT}/out_cuda_8k.ppm")

# ==========================================
# GENERATE CSV
# ==========================================

echo
echo "[4/5] Generating CSV..."

cat > "$CSV_FILE" << 'EOF'
Implementation,Image,Resolution,Threads,Time_ms,Speedup,Efficiency_%
EOF

add_row() {
    local impl="$1"
    local image="$2"
    local resolution="$3"
    local threads="$4"
    local time_ms="$5"
    local seq_time="$6"
    
    local speedup
    local efficiency
    
    if [[ "$impl" == "Sequential" ]]; then
        speedup="1.00"
        efficiency="-"
    else
        speedup=$(awk -v seq="$seq_time" -v t="$time_ms" 'BEGIN{printf "%.2f", seq/t}')
        
        if [[ "$impl" == "OpenMP" ]]; then
            efficiency=$(awk -v s="$speedup" -v th="$threads" 'BEGIN{printf "%.2f", (s/th)*100}')
        else
            efficiency="-"
        fi
    fi
    
    echo "${impl},${image},${resolution},${threads},${time_ms},${speedup},${efficiency}" >> "$CSV_FILE"
}

# 4K Data
add_row "Sequential" "4K" "3840x2160" "1" "$SEQ_4K" "$SEQ_4K"
for t in 1 2 4 8 16 32; do
    if [[ -n "${OMP_4K[$t]:-}" ]]; then
        add_row "OpenMP" "4K" "3840x2160" "$t" "${OMP_4K[$t]}" "$SEQ_4K"
    fi
done
add_row "CUDA" "4K" "3840x2160" "1" "$CUDA_4K" "$SEQ_4K"

# 8K Data
add_row "Sequential" "8K" "7680x4320" "1" "$SEQ_8K" "$SEQ_8K"
for t in 1 2 4 8 16 32; do
    if [[ -n "${OMP_8K[$t]:-}" ]]; then
        add_row "OpenMP" "8K" "7680x4320" "$t" "${OMP_8K[$t]}" "$SEQ_8K"
    fi
done
add_row "CUDA" "8K" "7680x4320" "1" "$CUDA_8K" "$SEQ_8K"

echo "  ✅ CSV saved: ${CSV_FILE}"

# ==========================================
# GENERATE PLOTS
# ==========================================

echo
echo "[5/5] Generating plots..."

python3 << PYTHON_SCRIPT
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import os

# Read CSV
csv_file = "${CSV_FILE}"
plots_dir = "${PLOTS_DIR}"

if not os.path.exists(csv_file):
    print(f"❌ CSV not found: {csv_file}")
    exit(1)

df = pd.read_csv(csv_file)
print(f"✅ Read {len(df)} rows")

os.makedirs(plots_dir, exist_ok=True)

# Clean data
df['Time_ms'] = pd.to_numeric(df['Time_ms'], errors='coerce')
df['Speedup'] = pd.to_numeric(df['Speedup'], errors='coerce')
df = df.dropna(subset=['Time_ms', 'Speedup'])

# Extract data
df_4k = df[df['Image'] == '4K']
df_8k = df[df['Image'] == '8K']

# Get sequential times
seq_4k = df_4k[df_4k['Implementation'] == 'Sequential']['Time_ms'].values[0]
seq_8k = df_8k[df_8k['Implementation'] == 'Sequential']['Time_ms'].values[0]

# Prepare data
impls_4k = df_4k['Implementation'].values
times_4k = df_4k['Time_ms'].values
speedups_4k = df_4k['Speedup'].values
threads_4k = df_4k['Threads'].values

impls_8k = df_8k['Implementation'].values
times_8k = df_8k['Time_ms'].values
speedups_8k = df_8k['Speedup'].values
threads_8k = df_8k['Threads'].values

# Create labels
labels_4k = []
for impl, t in zip(impls_4k, threads_4k):
    if impl == 'Sequential':
        labels_4k.append('Seq')
    elif impl == 'CUDA':
        labels_4k.append('CUDA')
    else:
        labels_4k.append(f'{impl}\n{t}T')

labels_8k = []
for impl, t in zip(impls_8k, threads_8k):
    if impl == 'Sequential':
        labels_8k.append('Seq')
    elif impl == 'CUDA':
        labels_8k.append('CUDA')
    else:
        labels_8k.append(f'{impl}\n{t}T')

print("Generating plots...")

# ==========================================
# PLOT 1: Speedup Comparison
# ==========================================
print("  [1/5] Speedup comparison...")

fig, ax = plt.subplots(figsize=(12, 6))
x = np.arange(len(labels_4k))
width = 0.35

bars1 = ax.bar(x - width/2, speedups_4k, width, label='4K', color='#3498db', alpha=0.8)
bars2 = ax.bar(x + width/2, speedups_8k, width, label='8K', color='#e74c3c', alpha=0.8)

ax.set_ylabel('Speedup (Sequential / Parallel Time)', fontsize=12)
ax.set_title('Speedup Comparison: 4K vs 8K', fontsize=14, fontweight='bold')
ax.set_xticks(x)
ax.set_xticklabels(labels_4k, rotation=45, ha='right')
ax.legend(fontsize=11)
ax.grid(True, alpha=0.3, axis='y')
ax.axhline(y=1, color='gray', linestyle='--', alpha=0.5)

for bars in [bars1, bars2]:
    for bar in bars:
        height = bar.get_height()
        if height > 0:
            ax.text(bar.get_x() + bar.get_width()/2, height + 0.05,
                    f'{height:.2f}x', ha='center', va='bottom', fontsize=8)

plt.tight_layout()
plt.savefig(f'{plots_dir}/speedup_comparison.png', dpi=150, bbox_inches='tight')
plt.savefig(f'{plots_dir}/speedup_comparison.pdf', bbox_inches='tight')
plt.close()
print("    ✅ speedup_comparison.png")

# ==========================================
# PLOT 2: Execution Time
# ==========================================
print("  [2/5] Execution time...")

fig, ax = plt.subplots(figsize=(12, 6))

ax.plot(labels_4k, times_4k, 'o-', linewidth=2, markersize=10, 
        label='4K', color='#3498db')
ax.plot(labels_8k, times_8k, 's-', linewidth=2, markersize=10, 
        label='8K', color='#e74c3c')

ax.set_xlabel('Implementation', fontsize=12)
ax.set_ylabel('Execution Time (ms)', fontsize=12)
ax.set_title('Execution Time Comparison', fontsize=14, fontweight='bold')
ax.legend(fontsize=11)
ax.grid(True, alpha=0.3)

for i, (t4, t8) in enumerate(zip(times_4k, times_8k)):
    if t4 > 0:
        ax.text(i, t4 * 1.05, f'{t4:.0f}ms', ha='center', va='bottom', fontsize=8)
    if t8 > 0:
        ax.text(i, t8 * 0.95, f'{t8:.0f}ms', ha='center', va='top', fontsize=8)

plt.xticks(rotation=45, ha='right')
plt.tight_layout()
plt.savefig(f'{plots_dir}/execution_time.png', dpi=150, bbox_inches='tight')
plt.savefig(f'{plots_dir}/execution_time.pdf', bbox_inches='tight')
plt.close()
print("    ✅ execution_time.png")

# ==========================================
# PLOT 3: Strong Scaling (OpenMP)
# ==========================================
print("  [3/5] Strong scaling...")

omp_4k = df_4k[df_4k['Implementation'] == 'OpenMP']
omp_8k = df_8k[df_8k['Implementation'] == 'OpenMP']

if not omp_4k.empty:
    fig, ax = plt.subplots(figsize=(10, 6))
    
    threads_omp_4k = omp_4k['Threads'].values
    times_omp_4k = omp_4k['Time_ms'].values
    
    ax.plot(threads_omp_4k, times_omp_4k, 'o-', linewidth=2, markersize=10,
            label='4K', color='#2ecc71')
    
    if not omp_8k.empty:
        threads_omp_8k = omp_8k['Threads'].values
        times_omp_8k = omp_8k['Time_ms'].values
        ax.plot(threads_omp_8k, times_omp_8k, 's-', linewidth=2, markersize=10,
                label='8K', color='#f39c12')
    
    # Ideal scaling
    ideal = [times_omp_4k[0] / (t / threads_omp_4k[0]) for t in threads_omp_4k]
    ax.plot(threads_omp_4k, ideal, '--', linewidth=1.5, alpha=0.5,
            label='Ideal Scaling', color='gray')
    
    ax.set_xlabel('Number of Threads', fontsize=12)
    ax.set_ylabel('Execution Time (ms)', fontsize=12)
    ax.set_title('OpenMP Strong Scaling', fontsize=14, fontweight='bold')
    ax.set_xscale('log', base=2)
    ax.legend(fontsize=11)
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(f'{plots_dir}/strong_scaling.png', dpi=150, bbox_inches='tight')
    plt.savefig(f'{plots_dir}/strong_scaling.pdf', bbox_inches='tight')
    plt.close()
    print("    ✅ strong_scaling.png")

# ==========================================
# PLOT 4: Efficiency Heatmap
# ==========================================
print("  [4/5] Efficiency heatmap...")

if not omp_4k.empty and not omp_8k.empty:
    # Calculate efficiencies
    eff_4k = []
    for t, time in zip(omp_4k['Threads'].values, omp_4k['Time_ms'].values):
        eff = (seq_4k / time) / t * 100
        eff_4k.append(eff)
    
    eff_8k = []
    for t, time in zip(omp_8k['Threads'].values, omp_8k['Time_ms'].values):
        eff = (seq_8k / time) / t * 100
        eff_8k.append(eff)
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    heatmap_data = np.array([eff_4k, eff_8k])
    resolutions = ['4K', '8K']
    thread_labels = [str(t) for t in omp_4k['Threads'].values]
    
    im = ax.imshow(heatmap_data, cmap='RdYlGn', aspect='auto', vmin=0, vmax=100)
    
    ax.set_xticks(np.arange(len(thread_labels)))
    ax.set_yticks(np.arange(len(resolutions)))
    ax.set_xticklabels(thread_labels)
    ax.set_yticklabels(resolutions)
    
    for i in range(len(resolutions)):
        for j in range(len(thread_labels)):
            val = heatmap_data[i,j]
            if not np.isnan(val) and val > 0:
                ax.text(j, i, f'{val:.1f}%',
                       ha="center", va="center", 
                       color="black" if val > 50 else "white")
    
    ax.set_xlabel('Thread Count', fontsize=12)
    ax.set_ylabel('Resolution', fontsize=12)
    ax.set_title('OpenMP Efficiency Heatmap (%)', fontsize=14, fontweight='bold')
    
    plt.colorbar(im, ax=ax, label='Efficiency (%)')
    plt.tight_layout()
    plt.savefig(f'{plots_dir}/efficiency_heatmap.png', dpi=150, bbox_inches='tight')
    plt.savefig(f'{plots_dir}/efficiency_heatmap.pdf', bbox_inches='tight')
    plt.close()
    print("    ✅ efficiency_heatmap.png")

# ==========================================
# PLOT 5: CPU vs GPU
# ==========================================
print("  [5/5] CPU vs GPU...")

omp_16t_4k = df_4k[(df_4k['Implementation'] == 'OpenMP') & (df_4k['Threads'] == 16)]
omp_16t_8k = df_8k[(df_8k['Implementation'] == 'OpenMP') & (df_8k['Threads'] == 16)]
cuda_4k = df_4k[df_4k['Implementation'] == 'CUDA']
cuda_8k = df_8k[df_8k['Implementation'] == 'CUDA']

if not omp_16t_4k.empty and not cuda_4k.empty:
    fig, ax = plt.subplots(figsize=(10, 6))
    
    cpu_speedup = [
        seq_4k / omp_16t_4k['Time_ms'].values[0] if not omp_16t_4k.empty else 0,
        seq_8k / omp_16t_8k['Time_ms'].values[0] if not omp_16t_8k.empty else 0
    ]
    gpu_speedup = [
        seq_4k / cuda_4k['Time_ms'].values[0] if not cuda_4k.empty else 0,
        seq_8k / cuda_8k['Time_ms'].values[0] if not cuda_8k.empty else 0
    ]
    
    categories = ['4K', '8K']
    x = np.arange(len(categories))
    width = 0.35
    
    bars1 = ax.bar(x - width/2, cpu_speedup, width, label='CPU (OpenMP 16T)', 
                   color='#3498db', alpha=0.8)
    bars2 = ax.bar(x + width/2, gpu_speedup, width, label='GPU (CUDA)', 
                   color='#e74c3c', alpha=0.8)
    
    ax.set_xlabel('Image Resolution', fontsize=12)
    ax.set_ylabel('Speedup vs Sequential', fontsize=12)
    ax.set_title('CPU vs GPU Acceleration', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(categories)
    ax.legend(fontsize=11)
    ax.grid(True, alpha=0.3, axis='y')
    ax.axhline(y=1, color='gray', linestyle='--', alpha=0.5)
    
    for bars in [bars1, bars2]:
        for bar in bars:
            height = bar.get_height()
            if height > 0:
                ax.text(bar.get_x() + bar.get_width()/2, height + 0.05,
                        f'{height:.2f}x', ha='center', va='bottom', fontsize=10)
    
    plt.tight_layout()
    plt.savefig(f'{plots_dir}/cpu_vs_gpu.png', dpi=150, bbox_inches='tight')
    plt.savefig(f'{plots_dir}/cpu_vs_gpu.pdf', bbox_inches='tight')
    plt.close()
    print("    ✅ cpu_vs_gpu.png")

print(f"\n✅ All plots saved to: {plots_dir}/")

# List files
print("\n📁 Generated files:")
for f in sorted(os.listdir(plots_dir)):
    if f.endswith(('.png', '.pdf')):
        size = os.path.getsize(os.path.join(plots_dir, f)) / 1024
        print(f"  - {f} ({size:.1f} KB)")
PYTHON_SCRIPT

# ==========================================
# COPY IMAGES TO OUTPUT FOLDER
# ==========================================

echo
echo "Copying output images..."

# Copy PPM images
cp ${ORIGINAL_OUTPUT}/*.ppm ${IMAGES_DIR}/ 2>/dev/null || true

# Convert to JPEG if PIL available
python3 << 'EOF'
import os
from PIL import Image

images_dir = "${IMAGES_DIR}"

for filename in os.listdir('datasets/output'):
    if filename.endswith('.ppm'):
        ppm_path = os.path.join('datasets/output', filename)
        jpg_path = os.path.join(images_dir, filename.replace('.ppm', '.jpg'))
        
        try:
            img = Image.open(ppm_path)
            if img.mode != 'RGB':
                img = img.convert('RGB')
            img.save(jpg_path, 'JPEG', quality=95)
            print(f"  ✅ Converted: {filename}")
        except Exception as e:
            print(f"  ⚠️ Could not convert: {filename}")
EOF

echo "  ✅ Images saved to: ${IMAGES_DIR}/"

# ==========================================
# CREATE SUMMARY
# ==========================================

echo
echo "Creating summary..."

CUDA_SPEEDUP_4K=$(awk -v seq="$SEQ_4K" -v cuda="$CUDA_4K" 'BEGIN{printf "%.2f", seq/cuda}')
CUDA_SPEEDUP_8K=$(awk -v seq="$SEQ_8K" -v cuda="$CUDA_8K" 'BEGIN{printf "%.2f", seq/cuda}')

cat > "${SUMMARY_FILE}" << EOF
========================================
  IMAGE PARALLELIZATION BENCHMARK
  Run: ${TIMESTAMP}
  Date: $(date)
========================================

HARDWARE:
- GPU: Tesla V100-SXM2-16GB
- CPU: $(nproc) cores
- RAM: $(free -h | grep Mem | awk '{print $2}')

INPUT IMAGES:
- 4K: ${INPUT_4K}
- 8K: ${INPUT_8K}

========================================
  4K RESULTS (3840x2160)
========================================
Sequential:  ${SEQ_4K} ms
OpenMP 16T:  ${OMP_4K[16]:-N/A} ms
CUDA:        ${CUDA_4K} ms
CUDA Speedup: ${CUDA_SPEEDUP_4K}x

========================================
  8K RESULTS (7680x4320)
========================================
Sequential:  ${SEQ_8K} ms
OpenMP 16T:  ${OMP_8K[16]:-N/A} ms
CUDA:        ${CUDA_8K} ms
CUDA Speedup: ${CUDA_SPEEDUP_8K}x

========================================
  ALL IMPLEMENTATIONS
========================================

4K:
EOF

for t in 1 2 4 8 16 32; do
    if [[ -n "${OMP_4K[$t]:-}" ]]; then
        speedup=$(awk -v seq="$SEQ_4K" -v t="${OMP_4K[$t]}" 'BEGIN{printf "%.2f", seq/t}')
        echo "  OpenMP ${t}T: ${OMP_4K[$t]} ms (${speedup}x)" >> "${SUMMARY_FILE}"
    fi
done

echo "" >> "${SUMMARY_FILE}"
echo "8K:" >> "${SUMMARY_FILE}"

for t in 1 2 4 8 16 32; do
    if [[ -n "${OMP_8K[$t]:-}" ]]; then
        speedup=$(awk -v seq="$SEQ_8K" -v t="${OMP_8K[$t]}" 'BEGIN{printf "%.2f", seq/t}')
        echo "  OpenMP ${t}T: ${OMP_8K[$t]} ms (${speedup}x)" >> "${SUMMARY_FILE}"
    fi
done

cat >> "${SUMMARY_FILE}" << EOF

========================================
  FILES GENERATED
========================================

CSV Data:     ${CSV_FILE}
Plots:        ${PLOTS_DIR}/
Images:       ${IMAGES_DIR}/
Summary:      ${SUMMARY_FILE}

To download everything, copy the folder:
  ${MAIN_OUTPUT}/

========================================
EOF

echo "  ✅ Summary saved: ${SUMMARY_FILE}"

# ==========================================
# FINAL OUTPUT
# ==========================================

echo
echo "========================================="
echo "  ✅ BENCHMARK COMPLETE!"
echo "========================================="
echo ""
echo "📁 Everything saved in: ${MAIN_OUTPUT}/"
echo ""
echo "  📊 CSV:     ${CSV_FILE}"
echo "  📈 Plots:   ${PLOTS_DIR}/"
echo "  🖼️ Images:  ${IMAGES_DIR}/"
echo "  📝 Summary: ${SUMMARY_FILE}"
echo ""
echo "Performance Summary:"
echo "  4K CUDA Speedup: ${CUDA_SPEEDUP_4K}x"
echo "  8K CUDA Speedup: ${CUDA_SPEEDUP_8K}x"
echo ""
echo "To download all results:"
echo "  scp -r ${MAIN_OUTPUT}/ user@local:/path/to/download/"
echo "  or zip and download:"
echo "  zip -r ${MAIN_OUTPUT}.zip ${MAIN_OUTPUT}/"
echo ""
echo "========================================="

# Display CSV
echo ""
echo "CSV Data:"
column -t -s, "${CSV_FILE}"
echo ""
echo "========================================="
echo "DONE"
