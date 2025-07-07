#!/bin/bash

# Create the Resources/llama directory if it doesn't exist
mkdir -p "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/llama"

# Create the Resources/lib directory for dynamic library
mkdir -p "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/lib"

# Copy llama-cli from Homebrew to the app bundle
cp "/opt/homebrew/bin/llama-cli" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/llama/"

# Array of required dylibs
REQUIRED_LIBS=(
  "libllama.dylib"
  "libggml.dylib"
  "libggml-cpu.dylib"
  "libggml-blas.dylib"
  "libggml-metal.dylib"
  "libggml-base.dylib"
)

# Copy each required dylib from Homebrew lib directory to the app bundle
for LIB in "${REQUIRED_LIBS[@]}"; do
  if [ -f "/opt/homebrew/lib/${LIB}" ]; then
    echo "Copying ${LIB} into app bundle..."
    cp "/opt/homebrew/lib/${LIB}" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/lib/"
  else
    echo "Warning: /opt/homebrew/lib/${LIB} not found. Skipping copy."
  fi
done

# Make the copied llama-cli executable
chmod +x "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/llama/llama-cli"

# Codesign the executable and each dylib with the app's signing identity so
# that they satisfy the Hardened Runtime when loaded from the sandbox.

if [ -n "${EXPANDED_CODE_SIGN_IDENTITY}" ]; then
  IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY}"
  echo "Signing llama-cli and dylibs with identity ${IDENTITY}..."

  codesign --force --options runtime --sign "${IDENTITY}" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/llama/llama-cli"

  for LIB in "${REQUIRED_LIBS[@]}"; do
    codesign --force --options runtime --sign "${IDENTITY}" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/lib/${LIB}"
  done
else
  echo "Warning: EXPANDED_CODE_SIGN_IDENTITY is not set; dylibs will remain with existing signature."
fi 