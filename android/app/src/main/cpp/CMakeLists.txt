cmake_minimum_required(VERSION 3.22.1 FATAL_ERROR)
project(llama_native_lib CXX)

# Path to llama.cpp (adjust if you cloned it elsewhere)
set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../llama.cpp")

# Check if llama.cpp directory exists
if(NOT EXISTS ${LLAMA_CPP_DIR})
    message(FATAL_ERROR "llama.cpp directory not found at ${LLAMA_CPP_DIR}")
endif()

# Set llama.cpp build options for Android cross-compilation
set(LLAMA_BLAS OFF CACHE BOOL "" FORCE)
set(LLAMA_NATIVE OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)

# Disable problematic features for cross-compilation
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
set(GGML_USE_ACCELERATE OFF CACHE BOOL "" FORCE)
set(GGML_USE_METAL OFF CACHE BOOL "" FORCE)
set(GGML_USE_CUBLAS OFF CACHE BOOL "" FORCE)
set(GGML_USE_OPENBLAS OFF CACHE BOOL "" FORCE)
set(GGML_USE_CLBLAST OFF CACHE BOOL "" FORCE)
set(GGML_USE_VULKAN OFF CACHE BOOL "" FORCE)

# Set cross-compilation cache variables to avoid TRY_RUN issues
set(GGML_MACHINE_SUPPORTS_dotprod_EXITCODE 0 CACHE STRING "" FORCE)
set(GGML_MACHINE_SUPPORTS_i8mm_EXITCODE 0 CACHE STRING "" FORCE)
set(GGML_MACHINE_SUPPORTS_sve_EXITCODE 0 CACHE STRING "" FORCE)
set(GGML_MACHINE_SUPPORTS_sme_EXITCODE 0 CACHE STRING "" FORCE)

# Include llama.cpp source with binary directory
add_subdirectory(${LLAMA_CPP_DIR} ${CMAKE_CURRENT_BINARY_DIR}/llama_cpp EXCLUDE_FROM_ALL)

# Create your own native library that links llama.cpp
add_library(llama_native SHARED
    llama_bridge.cpp
)

# Link against the llama library compiled by llama.cpp
target_link_libraries(llama_native
    llama
    # Add other Android NDK libraries if needed, e.g., for logging
    log
    android
)

# Set compiler flags (adjust as needed for performance/optimization)
target_compile_options(llama_native PRIVATE 
    -Wall 
    -std=c++17
    -O3
    -DNDEBUG
)

# Set include directories - include both llama.cpp root and include directory
target_include_directories(llama_native PRIVATE
    ${LLAMA_CPP_DIR}
    ${LLAMA_CPP_DIR}/include
    ${LLAMA_CPP_DIR}/src
    ${LLAMA_CPP_DIR}/ggml/include
    ${LLAMA_CPP_DIR}/ggml/src
)

# Define only arm64-v8a for better compatibility
set(ANDROID_ABIS arm64-v8a)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
