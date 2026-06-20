#!/usr/bin/env python3
"""
Complete benchmark runner script
"""

import subprocess
import json
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from pathlib import Path
import sys
import os

class BenchmarkRunner:
    def __init__(self, executable_path="./build/benchmark"):
        self.executable = executable_path
        self.results = {}
        
    def run_all_benchmarks(self):
        """Run all benchmark configurations"""
        configs = [
            ("sequential", ["--seq", "--size", "3840x2160"]),
            ("openmp_block", ["--omp", "--threads", "1,2,4,8,16,32"]),
            ("openmp_tiled", ["--omp", "--threads", "1,2,4,8,16,32"]),
            ("cuda", ["--cuda", "--size", "3840x2160"]),
        ]
        
        for name, args in configs:
            print(f"Running {name} benchmarks...")
            try:
                result = subprocess.run([self.executable] + args, 
                                      capture_output=True, text=True, timeout=300)
                self.results[name] = self.parse_output(result.stdout)
                print(f"  Completed: {len(self.results[name])} measurements")
            except subprocess.TimeoutExpired:
                print(f"  Timeout for {name}")
                self.results[name] = []
            except Exception as e:
                print(f"  Error: {e}")
                self.results[name] = []
        
        return self.results
    
    def parse_output(self, output):
        """Parse benchmark output into structured data"""
        data = []
        lines = output.split('\n')
        for line in lines:
            if 'Threads:' in line or 'threads:' in line.lower():
                parts = line.split()
                try:
                    threads = int(parts[1])
                except:
                    continue
                for i, part in enumerate(parts):
                    if 'ms' in part and 'Time' in parts[max(0, i-1)]:
                        time_ms = float(part.replace('ms', ''))
                        data.append({'threads': threads, 'time_ms': time_ms})
                        break
            elif 'Time:' in line and 'ms' in line:
                parts = line.split()
                for i, part in enumerate(parts):
                    if 'ms' in part:
                        try:
                            time_ms = float(part.replace('ms', ''))
                            data.append({'threads': 1, 'time_ms': time_ms})
                        except:
                            pass
                        break
        return data
    
    def plot_speedup_curves(self, save_path="speedup_curves.png"):
        """Generate speedup comparison plot"""
        plt.figure(figsize=(12, 8))
        
        for name, data in self.results.items():
            if data and len(data) > 1:
                # Sort by threads
                data_sorted = sorted(data, key=lambda x: x['threads'])
                baseline = data_sorted[0]['time_ms']
                threads = [d['threads'] for d in data_sorted if d['threads'] > 0]
                speedups = [baseline / d['time_ms'] for d in data_sorted if d['threads'] > 0]
                
                label = name.replace('_', ' ').title()
                plt.plot(threads, speedups, 'o-', label=label, linewidth=2, markersize=8)
        
        # Ideal scaling line
        max_threads = 32
        plt.plot([1, max_threads], [1, max_threads], 'k--', label='Ideal Scaling', alpha=0.5)
        
        plt.xscale('log', base=2)
        plt.xlabel('Number of Threads', fontsize=12)
        plt.ylabel('Speedup', fontsize=12)
        plt.title('Strong Scaling Comparison: OpenMP Decomposition Strategies', fontsize=14)
        plt.grid(True, alpha=0.3)
        plt.legend()
        plt.tight_layout()
        plt.savefig(save_path, dpi=150)
        plt.show()
        print(f"Speedup plot saved to: {save_path}")
    
    def plot_efficiency_heatmap(self, save_path="efficiency_heatmap.png"):
        """Create efficiency heatmap"""
        efficiency_data = []
        for name, data in self.results.items():
            if data and len(data) > 1:
                data_sorted = sorted(data, key=lambda x: x['threads'])
                baseline = data_sorted[0]['time_ms']
                for d in data_sorted[1:]:
                    efficiency = (baseline / d['time_ms']) / d['threads'] * 100
                    efficiency_data.append({
                        'Implementation': name.replace('_', ' ').title(),
                        'Threads': d['threads'],
                        'Efficiency (%)': efficiency
                    })
        
        if not efficiency_data:
            print("No efficiency data available")
            return
        
        df = pd.DataFrame(efficiency_data)
        pivot = df.pivot(index='Implementation', columns='Threads', values='Efficiency (%)')
        
        plt.figure(figsize=(10, 6))
        sns.heatmap(pivot, annot=True, fmt='.1f', cmap='RdYlGn', center=50, 
                   cbar_kws={'label': 'Efficiency (%)'})
        plt.title('Parallel Efficiency Across Implementations (%)', fontsize=14)
        plt.tight_layout()
        plt.savefig(save_path, dpi=150)
        plt.show()
        print(f"Efficiency heatmap saved to: {save_path}")
    
    def plot_comparison_bar(self, save_path="comparison_bar.png"):
        """Bar chart comparing best performance"""
        best_times = {}
        for name, data in self.results.items():
            if data:
                best_times[name] = min(d['time_ms'] for d in data)
        
        plt.figure(figsize=(10, 6))
        names = list(best_times.keys())
        times = list(best_times.values())
        
        bars = plt.bar(names, times, color=['#2ecc71', '#3498db', '#e74c3c', '#f39c12'])
        plt.ylabel('Execution Time (ms)', fontsize=12)
        plt.title('Best Performance Comparison', fontsize=14)
        
        # Add value labels on bars
        for bar, time in zip(bars, times):
            plt.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 5, 
                    f'{time:.1f}ms', ha='center', va='bottom', fontsize=10)
        
        plt.xticks(rotation=45, ha='right')
        plt.tight_layout()
        plt.savefig(save_path, dpi=150)
        plt.show()
        print(f"Comparison bar chart saved to: {save_path}")

def main():
    runner = BenchmarkRunner()
    
    # Check if executable exists
    if not os.path.exists(runner.executable):
        print(f"Executable not found: {runner.executable}")
        print("Building project...")
        os.system("cd build && make -j$(nproc)")
    
    # Run benchmarks
    runner.run_all_benchmarks()
    
    # Generate plots
    runner.plot_speedup_curves()
    runner.plot_efficiency_heatmap()
    runner.plot_comparison_bar()
    
    print("\nBenchmark complete!")
    print("Generated files:")
    print("  - speedup_curves.png")
    print("  - efficiency_heatmap.png")
    print("  - comparison_bar.png")

if __name__ == "__main__":
    main()