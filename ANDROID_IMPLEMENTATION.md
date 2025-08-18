# Android Implementation Guide

This document explains the Android implementation of llama.cpp integration in the Flutter app.

## Overview

The Android implementation uses a native library approach instead of the executable approach used on macOS. This is because:

1. Android doesn't allow executing binaries from the app bundle
2. Native libraries are the standard approach for Android
3. Better performance and integration with the Android system

## Architecture

### Platform Detection

- **macOS**: Uses `llama-cli` executable with `Process.run()`
- **Android**: Uses native library with Dart FFI

### Key Components

1. **BundleUtils** (`lib/utils/bundle_utils.dart`)

   - Detects platform and returns appropriate paths
   - For Android: returns `'native_library'` placeholder
   - For macOS: returns path to `llama-cli` executable

2. **LLMService** (`lib/services/llm_service.dart`)

   - Platform-agnostic service that delegates to platform-specific implementations
   - Uses conditional imports for Android-specific code

3. **AndroidLLMService** (`lib/services/android_llm_service.dart`)

   - Android-specific implementation using Dart FFI
   - Loads `libllama_native.so` and calls native functions

4. **Native Library** (`android/app/src/main/cpp/`)
   - `CMakeLists.txt`: Builds llama.cpp and creates `libllama_native.so`
   - `llama_bridge.cpp`: C++ wrapper exposing functions for Dart FFI

## Building the Native Library

### Prerequisites

- Android NDK (version 27.0.12077973 or compatible)
- CMake (version 3.22.1 or higher)
- llama.cpp cloned in the project root

### Build Steps

1. **Ensure llama.cpp is present:**

   ```bash
   # From project root
   ls llama.cpp/
   ```

2. **Build the native library:**

   ```bash
   # From project root
   cd android
   ./build_native.sh
   ```

3. **Verify the build:**
   ```bash
   # Check that the .so files were created
   find . -name "*.so" -type f
   ```

### Troubleshooting Build Issues

1. **CMake version too old:**

   ```bash
   # Update CMake (macOS)
   brew install cmake
   ```

2. **NDK not found:**

   - Install Android NDK through Android Studio
   - Set `ndkVersion` in `android/app/build.gradle.kts`

3. **llama.cpp not found:**
   ```bash
   # Clone llama.cpp if missing
   git clone https://github.com/ggerganov/llama.cpp.git
   ```

## Native Library Functions

The native library exposes three main functions:

1. **`initLlama(const char* model_path)`**

   - Loads the GGUF model file
   - Initializes llama.cpp context
   - Returns `true` on success, `false` on failure

2. **`generateText(const char* prompt)`**

   - Generates text based on the prompt
   - Returns a C string (must be freed by caller)
   - Returns `nullptr` on error

3. **`freeLlama()`**
   - Frees all llama.cpp resources
   - Should be called before app termination

## FFI Integration

The Dart FFI layer handles:

- Loading the native library
- Converting Dart strings to C strings
- Managing memory allocation/deallocation
- Error handling and exception propagation

## Memory Management

- C strings returned by `generateText()` are allocated with `strdup()`
- Dart FFI layer must free these strings using `calloc.free()`
- Global llama context is managed by the native library

## Performance Considerations

1. **Model Loading:**

   - Models are loaded once at initialization
   - Large models may take significant time to load
   - Consider showing a loading indicator

2. **Text Generation:**

   - Generation happens on the main thread (blocking)
   - Consider moving to a background isolate for better UX
   - Context size affects memory usage

3. **Memory Usage:**
   - llama.cpp uses significant RAM
   - Monitor memory usage on lower-end devices
   - Consider model quantization for smaller devices

## Debugging

### Common Issues

1. **Library not found:**

   ```
   Error: Failed to load native library
   ```

   - Ensure the .so file was built correctly
   - Check that the library is included in the APK

2. **Model loading failed:**

   ```
   Error: Failed to initialize llama native library
   ```

   - Verify the model file exists and is valid
   - Check file permissions
   - Ensure the model is a valid GGUF file

3. **Text generation errors:**
   ```
   Error: Failed to generate text
   ```
   - Check that llama was initialized successfully
   - Verify the prompt is not empty
   - Monitor memory usage

### Debug Logs

Enable debug logging by checking the console output:

```bash
flutter run --debug
```

### how to pull chat logs?

```bash
adb shell run-as it.aqila.farahmand.medicoai ls -lh app_flutter/chat_logs
adb exec-out run-as it.aqila.farahmand.medicoai cat "app_flutter/chat_logs/chat_history_$(date +%F).csv" > chat_history_$(date +%F).csv
# or copy to public Downloads, then pull:
adb shell run-as it.aqila.farahmand.medicoai cp "app_flutter/chat_logs/chat_history_$(date +%F).csv" /sdcard/Download/
adb pull /sdcard/Download/chat_history_$(date +%F).csv .
```

Look for these log messages:

- "Android platform detected - using native library approach"
- "Loading Android native library..."
- "Android LLM service initialized successfully"
- "Llama initialized successfully"

## Testing

1. **Unit Tests:**

   ```bash
   flutter test
   ```

2. **Integration Tests:**

   ```bash
   flutter drive --target=test_driver/app.dart
   ```

3. **Manual Testing:**
   - Test on different Android devices
   - Test with different model sizes
   - Test memory usage under load

## Deployment

### Release Build

```bash
flutter build apk --release
```

### ProGuard/R8

Add to `android/app/proguard-rules.pro`:

```proguard
-keep class it.aqila.farahmand.medicoai.** { *; }
-keep class * implements androidx.versionedparcelable.VersionedParcelable { *; }
```

### Native Library Optimization

- The native library is automatically optimized during release builds
- Consider using different optimization levels for debug vs release

## Future Improvements

1. **Background Processing:**

   - Move text generation to background isolates
   - Implement streaming responses

2. **Model Management:**

   - Add model download functionality
   - Implement model switching
   - Add model validation

3. **Performance:**

   - Implement GPU acceleration where available
   - Add model quantization options
   - Optimize memory usage

4. **Error Handling:**
   - Add more detailed error messages
   - Implement retry mechanisms
   - Add fallback options

## Support

For issues with the Android implementation:

1. Check the build logs for CMake/NDK errors
2. Verify llama.cpp is properly cloned and up-to-date
3. Test with a known working model file
4. Check device compatibility and memory constraints
