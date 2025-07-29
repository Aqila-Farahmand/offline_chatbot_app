cmake_minimum_required(VERSION 3.22.1 FATAL_ERROR) # Or higher, depending on NDK
project(llama_native_lib CXX)

# Path to llama.cpp (adjust if you cloned it elsewhere)
set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../llama.cpp")

# Include llama.cpp source
add_subdirectory(${LLAMA_CPP_DIR} EXCLUDE_FROM_ALL)

# Create your own native library that links llama.cpp
add_library(llama_native SHARED
        # Add your own C++ source files here if you have JNI wrappers or custom logic
        src/main/cpp/llama_bridge.cpp # Add your source file here
        # For a simple FFI integration, you might not need many custom .cpp files
        # You'll mostly link against the llama library compiled from llama.cpp
)
# Link against the llama library compiled by llama.cpp
target_link_libraries(llama_native
        llama
        # Add other Android NDK libraries if needed, e.g., for logging
        log
        android
)

# Set compiler flags (adjust as needed for performance/optimization)
target_compile_options(llama_native PRIVATE -Wall -std=c++17)

# Set include directories if you have custom C++ files or need specific headers
# target_include_directories(llama_native PRIVATE
#     ${CMAKE_CURRENT_SOURCE_DIR}/include # If you have a custom include folder
# )

# Define common ABIs for Android
set(ANDROID_ABIS arm64-v8a armeabi-v7a x86_64 x86)
# If you only want 64-bit, you can reduce this to:
# set(ANDROID_ABIS arm64-v8a)
