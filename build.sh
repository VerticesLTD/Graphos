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
echo "Setting up Godot ${GODOT_VERSION}..."
FILE_VERSION="Godot_v${GODOT_VERSION}_linux.x86_64"

# Only download if missing (saves time/bandwidth)
if [ ! -f godot.zip ]; then
  curl -L -s "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${FILE_VERSION}.zip" -o godot.zip
  curl -L -s "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz" -o templates.tpz
  unzip -q godot.zip
  unzip -q templates.tpz
  mv templates/* ~/.local/share/godot/export_templates/${V_DIR}/
fi

# --- 3. EXPORT PROJECT ---
echo "Building Graphos for Web..."
# MUST BE "web" (match your export_presets.cfg)
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
echo "Cleaning up..."
rm -rf godot.zip templates.tpz templates binaryen-${BINARYEN_VERSION} ${FILE_VERSION}

echo "Build complete."
