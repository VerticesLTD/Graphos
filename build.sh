#!/bin/bash
set -ex

# --- 1. CONFIGURATION ---
GODOT_VERSION="4.6-stable"
BASE_VERSION=$(echo "$GODOT_VERSION" | cut -d'-' -f1)
V_DIR="${BASE_VERSION}.stable"
BINARYEN_VERSION="version_116"

# This is the path to your custom engine you just built in the cloud
# MAKE SURE THE TAG (v1.0-custom-engine) MATCHES YOUR .YML FILE
CUSTOM_ENGINE_URL="https://github.com/VerticesLTD/Graphos/releases/download/v1.0-custom-engine/custom_engine_4.6.zip"

mkdir -p ~/.local/share/godot/export_templates/${V_DIR}
mkdir -p public

# --- 2. SETUP GODOT & CUSTOM TEMPLATES ---
echo "Setting up Godot ${GODOT_VERSION}..."
FILE_VERSION="Godot_v${GODOT_VERSION}_linux.x86_64"

# Download the Headless Editor
if [ ! -f godot.zip ]; then
    curl -L -s "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${FILE_VERSION}.zip" -o godot.zip
    unzip -q godot.zip
fi

# DOWNLOAD THE CUSTOM LIGHTWEIGHT ENGINE (The 5MB Surgery Build)
echo "Fetching custom stripped engine from GitHub..."
curl -L -s "$CUSTOM_ENGINE_URL" -o custom_templates.zip
unzip -o custom_templates.zip -d ~/.local/share/godot/export_templates/${V_DIR}/

# --- 3. EXPORT PROJECT ---
echo "Building Graphos with Custom Engine..."
./${FILE_VERSION} --headless --export-release "web" public/index.html

# --- 4. WASM OPTIMIZATION (THE SURGERY) ---
echo "Downloading WASM Optimizer..."
if [ ! -d binaryen-${BINARYEN_VERSION} ]; then
    curl -L -s "https://github.com/WebAssembly/binaryen/releases/download/${BINARYEN_VERSION}/binaryen-${BINARYEN_VERSION}-x86_64-linux.tar.gz" | tar xz
fi

echo "Optimizing index.wasm for MAXIMUM execution speed (-O4)..."
./binaryen-${BINARYEN_VERSION}/bin/wasm-opt -O4 \
    --strip-debug \
    --enable-threads \
    --enable-bulk-memory \
    --enable-simd \
    --enable-sign-ext \
    --enable-nontrapping-float-to-int \
    --enable-exception-handling \
    --enable-reference-types \
    public/index.wasm -o public/index.wasm

# --- 5. CLEANUP ---
echo "Cleaning up build artifacts..."
rm -rf godot.zip custom_templates.zip binaryen-${BINARYEN_VERSION} ${FILE_VERSION}

echo "Build complete. Engine surgery successful."
