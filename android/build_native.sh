#!/bin/bash

# Build script for Android native llama library
set -e

echo "Building Android native llama library..."

# Check if we're in the right directory
if [ ! -f "app/build.gradle.kts" ]; then
    echo "Error: This script must be run from the android directory"
    exit 1
fi

# Check if llama.cpp exists
if [ ! -d "../llama.cpp" ]; then
    echo "Error: llama.cpp directory not found. Please ensure llama.cpp is cloned in the project root."
    exit 1
fi

echo "Cleaning previous builds..."
./gradlew clean

echo "Building native library..."
./gradlew assembleDebug

echo "Build completed successfully!"
echo "The native library should be available in: app/src/main/cpp/build/intermediates/cmake/debug/obj/" 