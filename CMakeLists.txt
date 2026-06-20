cmake_minimum_required(VERSION 3.12)
project(ImageProcessingPipeline LANGUAGES CXX CUDA)

# ============================================
# COMPILER AND LANGUAGE STANDARDS
# ============================================

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 14)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

# ============================================
# FIND DEPENDENCIES
# ============================================

# OpenMP (Required for CPU parallelization)
find_package(OpenMP REQUIRED)

# CUDA (Optional - only needed for GPU version)
find_package(CUDA QUIET)

# OpenCV (Optional - for additional image I/O)
find_package(OpenCV QUIET COMPONENTS core imgproc)
if(OpenCV_FOUND)
    message(STATUS "OpenCV found: ${OpenCV_VERSION}")
else()
    message(STATUS "OpenCV not found - continuing without it")
endif()

# Threads (Required)
find_package(Threads REQUIRED)

# ============================================
# COMPILER FLAGS
# ============================================

# C++ flags
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -march=native -mtune=native")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -Wpedantic")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-unused-parameter")

# CUDA flags
if(CUDA_FOUND)
    set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -O3 --use_fast_math")
    set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -Wno-deprecated-gpu-targets")
    
    # Set CUDA architecture (adjust for your GPU)
    # Common values:
    #   61 - Pascal (GTX 10xx)
    #   70 - Volta (V100)
    #   75 - Turing (RTX 20xx, GTX 16xx)
    #   80 - Ampere (RTX 30xx)
    #   89 - Ada Lovelace (RTX 40xx)
    set(CMAKE_CUDA_ARCHITECTURES 75)
    
    # Additional CUDA include directories
    if(CUDA_INCLUDE_DIRS)
        include_directories(${CUDA_INCLUDE_DIRS})
    endif()
endif()

# ============================================
# SOURCE FILES
# ============================================

# Common sources (shared across all targets)
set(COMMON_SOURCES
    src/common/image_io.cpp
)

# Sequential implementation
set(SEQUENTIAL_SOURCES
    src/sequential/pipeline_seq.cpp
    ${COMMON_SOURCES}
)

# OpenMP implementation
set(OMP_SOURCES
    src/openmp/pipeline_omp.cpp
    ${COMMON_SOURCES}
)

# CUDA implementation (only if CUDA found)
if(CUDA_FOUND)
    set(CUDA_SOURCES
        src/cuda/pipeline_cuda.cu
        ${COMMON_SOURCES}
    )
endif()

# Benchmark implementation (without CUDA dependency to avoid conflicts)
set(BENCHMARK_SOURCES
    src/profiling/benchmark.cpp
    ${COMMON_SOURCES}
    src/openmp/pipeline_omp.cpp
)

# ============================================
# EXECUTABLES
# ============================================

# 1. Sequential (Baseline)
add_executable(sequential ${SEQUENTIAL_SOURCES})
target_include_directories(sequential PRIVATE include)
target_link_libraries(sequential 
    OpenMP::OpenMP_CXX
    Threads::Threads
)

# 2. OpenMP (CPU Parallel)
add_executable(omp_pipeline ${OMP_SOURCES})
target_include_directories(omp_pipeline PRIVATE include)
target_link_libraries(omp_pipeline 
    OpenMP::OpenMP_CXX
    Threads::Threads
)

# 3. CUDA (GPU Accelerated) - only if CUDA found
if(CUDA_FOUND)
    add_executable(cuda_pipeline ${CUDA_SOURCES})
    target_include_directories(cuda_pipeline PRIVATE include src/cuda)
    target_link_libraries(cuda_pipeline 
        ${CUDA_LIBRARIES}
        Threads::Threads
    )
    
    # CUDA specific settings
    set_target_properties(cuda_pipeline PROPERTIES
        CUDA_SEPARABLE_COMPILATION ON
        CUDA_RESOLVE_DEVICE_SYMBOLS ON
        CUDA_ARCHITECTURES 75
    )
endif()

# 4. Benchmark (CPU only - no CUDA to avoid conflicts)
add_executable(benchmark ${BENCHMARK_SOURCES})
target_include_directories(benchmark PRIVATE include)
target_link_libraries(benchmark 
    OpenMP::OpenMP_CXX
    Threads::Threads
)

# ============================================
# OPTIONAL: Add OpenCV if found
# ============================================

if(OpenCV_FOUND)
    target_link_libraries(sequential ${OpenCV_LIBS})
    target_link_libraries(omp_pipeline ${OpenCV_LIBS})
    target_link_libraries(benchmark ${OpenCV_LIBS})
    if(CUDA_FOUND)
        target_link_libraries(cuda_pipeline ${OpenCV_LIBS})
    endif()
endif()

# ============================================
# INSTALLATION
# ============================================

install(TARGETS 
    sequential 
    omp_pipeline 
    benchmark
    ${CUDA_FOUND_INSTALL_TARGETS}
    DESTINATION bin
)

if(CUDA_FOUND)
    install(TARGETS cuda_pipeline DESTINATION bin)
endif()

# ============================================
# CUSTOM TARGETS (Profiling)
# ============================================

add_custom_target(profile_cpu
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/scripts/profile.sh cpu
    COMMENT "Profiling CPU implementation with perf"
)

add_custom_target(profile_gpu
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/scripts/profile.sh gpu
    COMMENT "Profiling GPU implementation with NVIDIA tools"
)

add_custom_target(profile_memory
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/scripts/profile.sh memory
    COMMENT "Analyzing memory bandwidth"
)

add_custom_target(profile_cache
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/scripts/profile.sh cache
    COMMENT "Analyzing cache hierarchy"
)

add_custom_target(profile_scaling
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/scripts/profile.sh scaling
    COMMENT "Analyzing thread scaling"
)

# ============================================
# HELPER TARGETS
# ============================================

add_custom_target(run-seq
    COMMAND ./sequential --size 1920x1080 --generate test.ppm
    COMMAND ./sequential -i test.ppm -o out_seq.ppm
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running sequential pipeline on synthetic image"
)

add_custom_target(run-omp
    COMMAND ./omp_pipeline -i test.ppm -o out_omp.ppm -t 16 -d tiled
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running OpenMP pipeline on synthetic image"
)

if(CUDA_FOUND)
    add_custom_target(run-cuda
        COMMAND ./cuda_pipeline -i test.ppm -o out_cuda.ppm
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Running CUDA pipeline on synthetic image"
    )
endif()

add_custom_target(run-all
    DEPENDS run-seq run-omp
    COMMENT "Running all pipeline implementations"
)

if(CUDA_FOUND)
    add_dependencies(run-all run-cuda)
endif()

# ============================================
# PRINT BUILD CONFIGURATION
# ============================================

message(STATUS "")
message(STATUS "========================================")
message(STATUS "  Image Processing Pipeline - Build Info")
message(STATUS "========================================")
message(STATUS "")
message(STATUS "Compiler:")
message(STATUS "  C++    : ${CMAKE_CXX_COMPILER}")
message(STATUS "  C++ Ver: ${CMAKE_CXX_STANDARD}")
if(CUDA_FOUND)
    message(STATUS "  CUDA   : ${CMAKE_CUDA_COMPILER}")
    message(STATUS "  CUDA   : Version ${CMAKE_CUDA_COMPILER_VERSION}")
endif()
message(STATUS "")
message(STATUS "Libraries:")
message(STATUS "  OpenMP : ${OpenMP_FOUND}")
message(STATUS "  CUDA   : ${CUDA_FOUND}")
message(STATUS "  OpenCV : ${OpenCV_FOUND}")
if(OpenCV_FOUND)
    message(STATUS "  OpenCV : ${OpenCV_VERSION}")
endif()
message(STATUS "")
message(STATUS "Targets:")
message(STATUS "  sequential   - Single-threaded baseline")
message(STATUS "  omp_pipeline - OpenMP CPU parallel")
if(CUDA_FOUND)
    message(STATUS "  cuda_pipeline- CUDA GPU accelerated")
else()
    message(STATUS "  cuda_pipeline- DISABLED (CUDA not found)")
endif()
message(STATUS "  benchmark    - Performance benchmarking")
message(STATUS "")
message(STATUS "========================================")
message(STATUS "")

# ============================================
# WARNINGS AND NOTES
# ============================================

if(NOT CUDA_FOUND)
    message(WARNING "CUDA not found. GPU acceleration will be disabled.")
    message(WARNING "To enable CUDA, install nvidia-cuda-toolkit:")
    message(WARNING "  sudo apt-get install nvidia-cuda-toolkit")
    message(STATUS "")
endif()

if(NOT OpenCV_FOUND)
    message(STATUS "OpenCV not found. Using built-in PPM image I/O.")
    message(STATUS "To enable OpenCV, install libopencv-dev:")
    message(STATUS "  sudo apt-get install libopencv-dev")
    message(STATUS "")
endif()
