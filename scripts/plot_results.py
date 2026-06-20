#!/usr/bin/env python3
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns
from pathlib import Path

def plot_comprehensive_results(csv_file="benchmark_results.csv"):
    """Generate comprehensive comparison plots"""
    
    # Read data
    df = pd.read_csv(csv_file)
    
    # Set style
    plt.style.use('seaborn-v0_8-darkgrid')
    sns.set_palette("husl")
    
    # Figure 1: Speedup comparison
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    
    # 1. Strong scaling
    ax = axes[0, 0]
    for impl in df['Implementation'].unique():
        data = df[df['Implementation'] == impl]
        baseline = data[data['Threads'] == 1]['Time_ms'].values[0]
        speedup = baseline / data['Time_ms']
        ax.plot(data['Threads'], speedup, 'o-', linewidth=2, markersize=8, label=impl)
    ax.plot([1, 32], [1, 32], 'k--', alpha=0.5, label='Ideal')
    ax.set_xscale('log', base=2)
    ax.set_xlabel('Number of Threads', fontsize=11)
    ax.set_ylabel('Speedup', fontsize=11)
    ax.set_title('Strong Scaling Performance', fontsize=12)
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # 2. Efficiency
    ax = axes[0, 1]
    for impl in df['Implementation'].unique():
        data = df[df['Implementation'] == impl]
        baseline = data[data['Threads'] == 1]['Time_ms'].values[0]
        efficiency = (baseline / data['Time_ms']) / data['Threads'] * 100
        ax.plot(data['Threads'], efficiency, 'o-', linewidth=2, markersize=8, label=impl)
    ax.set_xscale('log', base=2)
    ax.set_xlabel('Number of Threads', fontsize=11)
    ax.set_ylabel('Efficiency (%)', fontsize=11)
    ax.set_title('Parallel Efficiency', fontsize=12)
    ax.legend()
    ax.grid(True, alpha=0.3)
    ax.axhline(y=50, color='r', linestyle='--', alpha=0.5)
    
    # 3. Memory bandwidth
    ax = axes[1, 0]
    for impl in df['Implementation'].unique():
        data = df[df['Implementation'] == impl]
        ax.plot(data['Threads'], data['MemoryBandwidth_MBps'] / 1000, 
                'o-', linewidth=2, markersize=8, label=impl)
    ax.set_xscale('log', base=2)
    ax.set_xlabel('Number of Threads', fontsize=11)
    ax.set_ylabel('Memory Bandwidth (GB/s)', fontsize=11)
    ax.set_title('Effective Memory Bandwidth', fontsize=12)
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # 4. Execution time heatmap
    ax = axes[1, 1]
    pivot = df.pivot('Implementation', 'Threads', 'Time_ms')
    sns.heatmap(pivot, annot=True, fmt='.0f', cmap='RdYlGn_r', ax=ax)
    ax.set_title('Execution Time Heatmap (ms)', fontsize=12)
    
    plt.tight_layout()
    plt.savefig('comprehensive_analysis.png', dpi=150, bbox_inches='tight')
    plt.show()
    
    # Figure 2: Resolution scaling
    fig2, ax2 = plt.subplots(figsize=(10, 6))
    
    resolutions = ['1920x1080', '3840x2160', '7680x4320']
    seq_times = [245.3, 982.1, 3928.4]  # Example values
    omp_times = [18.2, 68.4, 261.3]
    cuda_times = [5.6, 18.9, 72.4]
    
    x = np.arange(len(resolutions))
    width = 0.25
    
    ax2.bar(x - width, seq_times, width, label='Sequential', alpha=0.8)
    ax2.bar(x, omp_times, width, label='OpenMP (32 threads)', alpha=0.8)
    ax2.bar(x + width, cuda_times, width, label='CUDA', alpha=0.8)
    
    ax2.set_xlabel('Resolution', fontsize=12)
    ax2.set_ylabel('Execution Time (ms)', fontsize=12)
    ax2.set_title('Performance Scaling with Image Resolution', fontsize=14)
    ax2.set_xticks(x)
    ax2.set_xticklabels(resolutions)
    ax2.legend()
    ax2.set_yscale('log')
    ax2.grid(True, alpha=0.3, axis='y')
    
    plt.tight_layout()
    plt.savefig('resolution_scaling.png', dpi=150)
    plt.show()
    
    # Generate summary statistics
    print("\n=== Performance Summary ===")
    print(f"Best CPU Speedup: {df['Speedup'].max():.2f}x")
    print(f"Best CPU Efficiency: {df['Efficiency'].max():.1f}%")
    print(f"Peak Memory Bandwidth: {df['MemoryBandwidth_MBps'].max() / 1000:.1f} GB/s")
    
    # Export data for paper
    df.to_csv('paper_data.csv', index=False)
    print("\nData exported for paper: paper_data.csv")

def generate_roofline_plot():
    """Generate roofline model visualization"""
    fig, ax = plt.subplots(figsize=(10, 6))
    
    # Theoretical peaks
    peak_flops = 20000  # 20 TFLOPS for RTX 4090
    peak_bandwidth = 1000  # 1 TB/s
    
    # Roofline
    intensities = np.logspace(-2, 2, 100)
    compute_bound = peak_flops * np.ones_like(intensities)
    memory_bound = peak_bandwidth * intensities
    
    roofline = np.minimum(compute_bound, memory_bound)
    
    ax.loglog(intensities, roofline, 'k-', linewidth=2, label='Roofline')
    ax.loglog(intensities, memory_bound, 'b--', alpha=0.5, label='Memory Bound')
    ax.loglog(intensities, compute_bound, 'r--', alpha=0.5, label='Compute Bound')
    
    # Example operational points
    ops_points = [
        ('Sequential', 0.1, 5),
        ('OpenMP', 0.5, 150),
        ('CUDA', 0.8, 1800),
    ]
    
    for label, intensity, perf in ops_points:
        ax.plot(intensity, perf, 'o', markersize=10, label=label)
        ax.annotate(label, (intensity, perf), xytext=(5, 5), 
                   textcoords='offset points', fontsize=10)
    
    ax.set_xlabel('Arithmetic Intensity (FLOP/byte)', fontsize=12)
    ax.set_ylabel('Performance (GFLOPS)', fontsize=12)
    ax.set_title('Roofline Model Analysis', fontsize=14)
    ax.legend()
    ax.grid(True, alpha=0.3, which='both')
    
    plt.tight_layout()
    plt.savefig('roofline_model.png', dpi=150)
    plt.show()

if __name__ == "__main__":
    plot_comprehensive_results()
    generate_roofline_plot()