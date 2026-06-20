cmake_minimum_required(VERSION 3.12)
project(ImageProcessingPipeline LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

# Find dependencies
find_package(OpenMP REQUIRED)
find_package(CUDA REQUIRED)
find_package(OpenCV OPTIONAL_COMPONENTS core imgproc)

# CUDA architecture (adjust for your GPU)
set(CMAKE_CUDA_ARCHITECTURES 75)  # RTX 2080/Turing

# Compiler flags
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -march=native -mtune=native")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -Wpedantic")
set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -O3 --use_fast_math")

# Source files
set(COMMON_SOURCES
    src/common/image_io.cpp
)

set(SEQUENTIAL_SOURCES
    src/sequential/pipeline_seq.cpp
    ${COMMON_SOURCES}
)

set(OMP_SOURCES
    src/openmp/pipeline_omp.cpp
    ${COMMON_SOURCES}
)

set(CUDA_SOURCES
    src/cuda/pipeline_cuda.cu
    ${COMMON_SOURCES}
)

set(BENCHMARK_SOURCES
    src/profiling/benchmark.cpp
    ${COMMON_SOURCES}
    ${OMP_SOURCES}
)

# Executables
add_executable(sequential ${SEQUENTIAL_SOURCES})
add_executable(omp_pipeline ${OMP_SOURCES})
add_executable(cuda_pipeline ${CUDA_SOURCES})
add_executable(benchmark ${BENCHMARK_SOURCES})

# Link libraries
target_link_libraries(sequential OpenMP::OpenMP_CXX)
target_link_libraries(omp_pipeline OpenMP::OpenMP_CXX)
target_link_libraries(cuda_pipeline ${CUDA_LIBRARIES})
target_link_libraries(benchmark OpenMP::OpenMP_CXX ${CUDA_LIBRARIES})

# Include directories
target_include_directories(sequential PRIVATE include)
target_include_directories(omp_pipeline PRIVATE include)
target_include_directories(cuda_pipeline PRIVATE include)
target_include_directories(benchmark PRIVATE include)

# CUDA specific
set_target_properties(cuda_pipeline PROPERTIES
    CUDA_SEPARABLE_COMPILATION ON
    CUDA_RESOLVE_DEVICE_SYMBOLS ON
)

# Install
install(TARGETS sequential omp_pipeline cuda_pipeline benchmark DESTINATION bin)

# Profiling targets
add_custom_target(profile_cpu
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/scripts/profile.sh cpu
    COMMENT "Profiling CPU implementation"
)

add_custom_target(profile_gpu
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/scripts/profile.sh gpu
    COMMENT "Profiling GPU implementation"
)