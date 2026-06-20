CXX = g++
NVCC = nvcc
CXXFLAGS = -O3 -march=native -mtune=native -Wall -Wextra -std=c++17 -fopenmp
CUDAFLAGS = -O3 --use_fast_math -arch=sm_75
LDFLAGS = -fopenmp -lpthread

SOURCES_SEQ = src/sequential/pipeline_seq.cpp src/common/image_io.cpp
SOURCES_OMP = src/openmp/pipeline_omp.cpp src/common/image_io.cpp
SOURCES_CUDA = src/cuda/pipeline_cuda.cu src/common/image_io.cpp

TARGETS = sequential omp_pipeline cuda_pipeline benchmark

all: $(TARGETS)

sequential: $(SOURCES_SEQ)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

omp_pipeline: $(SOURCES_OMP)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

cuda_pipeline: $(SOURCES_CUDA)
	$(NVCC) $(CUDAFLAGS) -o $@ $^

benchmark: $(SOURCES_OMP) src/profiling/benchmark.cpp
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f $(TARGETS) datasets/output/*.ppm

run-sequential: sequential
	./sequential datasets/input/test_4k.ppm datasets/output/out_seq.ppm

run-omp: omp_pipeline
	./omp_pipeline datasets/input/test_4k.ppm datasets/output/out_omp.ppm 8 tiled

run-cuda: cuda_pipeline
	./cuda_pipeline datasets/input/test_4k.ppm datasets/output/out_cuda.ppm

bench: benchmark
	./benchmark --all --output results.json

profile-cpu:
	perf stat -e cycles,instructions,cache-misses,cache-references ./omp_pipeline datasets/input/test_8k.ppm /dev/null 16 tiled

profile-gpu:
	nsys profile --stats=true ./cuda_pipeline datasets/input/test_8k.ppm /dev/null

.PHONY: all clean run-sequential run-omp run-cuda bench profile-cpu profile-gpu