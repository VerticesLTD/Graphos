#!/bin/bash
set -ex

# --- 1. CONFIGURATION ---
GODOT_VERSION="4.6-stable"
BASE_VERSION=$(echo "$GODOT_VERSION" | cut -d'-' -f1)
V_DIR="${BASE_VERSION}.stable"
BINARYEN_VERSION="version_116"

mkdir -p ~/.local/share/godot/export_templates/${V_DIR}
mkdir -p public

# --- 2. SETUP GODOT & TEMPLATES ---
echo "Downloading Godot ${GODOT_VERSION}..."
FILE_VERSION="Godot_v${GODOT_VERSION}_linux.x86_64"

curl -L -s "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${FILE_VERSION}.zip" -o godot.zip
curl -L -s "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz" -o templates.tpz

unzip -q godot.zip
unzip -q templates.tpz
mv templates/* ~/.local/share/godot/export_templates/${V_DIR}/

# --- 3. EXPORT PROJECT ---
echo "Building Graphos for Web..."
./${FILE_VERSION} --headless --export-release "web" public/index.html

# --- 4. WASM OPTIMIZATION (THE SURGERY) ---
# This tool strips unused C++ functions from the Godot engine binary.
echo "Downloading WASM Optimizer..."
curl -L -s "https://github.com/WebAssembly/binaryen/releases/download/${BINARYEN_VERSION}/binaryen-${BINARYEN_VERSION}-x86_64-linux.tar.gz" | tar xz

echo "Optimizing index.wasm for speed and size..."
# Added --enable-bulk-memory to fix the validator errors
./binaryen-${BINARYEN_VERSION}/bin/wasm-opt -Oz \
  --strip-debug \
  --enable-threads \
  --enable-bulk-memory \
  public/index.wasm -o public/index.wasm

echo "Optimizing index.wasm for speed and size..."
# -Oz: Aggressive size optimization
# --strip-debug: Remove symbols (saves massive space)
# --enable-threads: REQUIRED because we enabled multi-threading in the UI
./binaryen-${BINARYEN_VERSION}/bin/wasm-opt -Oz --strip-debug --enable-threads public/index.wasm -o public/index.wasm

# --- 5. CLEANUP ---
echo "Cleaning up build environment..."
rm -rf godot.zip templates.tpz templates binaryen-${BINARYEN_VERSION} ${FILE_VERSION}

echo "Build complete."
