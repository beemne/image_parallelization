# Simple Makefile - easier to debug
CXX = g++
NVCC = nvcc

# Compiler flags
CXXFLAGS = -O3 -march=native -mtune=native -std=c++17 -fopenmp
CXXFLAGS += -Wall -Wextra -Wpedantic

# CUDA flags (adjust architecture for your GPU)
# Common: sm_75 (RTX 20xx), sm_80 (RTX 30xx), sm_89 (RTX 40xx)
CUDAFLAGS = -O3 --use_fast_math -std=c++14 -arch=sm_75

LDFLAGS = -fopenmp -lpthread -lcudart

# Source files
COMMON_SRC = src/common/image_io.cpp
SEQ_SRC = src/sequential/pipeline_seq.cpp $(COMMON_SRC)
OMP_SRC = src/openmp/pipeline_omp.cpp $(COMMON_SRC)
CUDA_SRC = src/cuda/pipeline_cuda.cu $(COMMON_SRC)
BENCH_SRC = src/profiling/benchmark.cpp $(COMMON_SRC) src/openmp/pipeline_omp.cpp

# Include directories
INCLUDES = -Iinclude -Isrc/cuda

# Targets
TARGETS = sequential omp_pipeline cuda_pipeline benchmark

all: $(TARGETS)

sequential: $(SEQ_SRC)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -o $@ $^ $(LDFLAGS)

omp_pipeline: $(OMP_SRC)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -o $@ $^ $(LDFLAGS)

cuda_pipeline: $(CUDA_SRC)
	$(NVCC) $(CUDAFLAGS) $(INCLUDES) -o $@ $^

benchmark: $(BENCH_SRC)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -o $@ $^ $(LDFLAGS)

clean:
	rm -f $(TARGETS) datasets/output/*.ppm

# Run targets
run-seq: sequential
	./sequential --size 1920x1080 --generate test.ppm
	./sequential -i test.ppm -o out_seq.ppm

run-omp: omp_pipeline
	./omp_pipeline -i test.ppm -o out_omp.ppm -t 16 -d tiled

run-cuda: cuda_pipeline
	./cuda_pipeline -i test.ppm -o out_cuda.ppm

run-all: run-seq run-omp run-cuda
	@echo "All runs complete!"

.PHONY: all clean run-seq run-omp run-cuda run-all
