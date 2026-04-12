#!/bin/bash
set -ex

# --- 1. CONFIGURATION ---
GODOT_VERSION="4.6-stable"
BASE_VERSION=$(echo "$GODOT_VERSION" | cut -d'-' -f1)
V_DIR="${BASE_VERSION}.stable"
BINARYEN_VERSION="version_116"

# Custom web template from a GitHub Release (manual workflow: .github/workflows/build_custom_engine.yml).
# Supports both: (1) legacy zip with loose web_release.wasm + web_release.js at root, (2) official Godot template zip as web_release.zip.
CUSTOM_ENGINE_URL="https://github.com/VerticesLTD/Graphos/releases/download/v4.6-custom/web_release.zip"

mkdir -p public

# --- 2. SETUP GODOT & CUSTOM TEMPLATES ---
echo "Setting up Godot ${GODOT_VERSION}..."
FILE_VERSION="Godot_v${GODOT_VERSION}_linux.x86_64"

if [ ! -f godot.zip ]; then
    curl -L -s "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${FILE_VERSION}.zip" -o godot.zip
    unzip -q godot.zip
fi

# DOWNLOAD THE CUSTOM WEB TEMPLATE
echo "Fetching custom stripped 4.6 engine..."
curl -fL -s "$CUSTOM_ENGINE_URL" -o custom_templates.zip

TPL_ROOT="${HOME}/.local/share/godot/export_templates/${V_DIR}"
mkdir -p "${TPL_ROOT}"

# Old CI produced a tiny zip with only web_release.wasm + web_release.js (export expected them loose in TPL_ROOT).
# New workflow uploads the real Godot bundle; that must stay named web_release.zip in TPL_ROOT.
if unzip -l custom_templates.zip | grep -qE '[[:space:]]web_release\.wasm[[:space:]]*$' \
	&& unzip -l custom_templates.zip | grep -qE '[[:space:]]web_release\.js[[:space:]]*$'; then
	echo "Installing legacy loose web template (wasm + js)…"
	unzip -o -q custom_templates.zip -d "${TPL_ROOT}"
else
	echo "Installing official web_release.zip bundle…"
	cp -f custom_templates.zip "${TPL_ROOT}/web_release.zip"
fi

# --- 3. EXPORT PROJECT ---
echo "Building Graphos with Custom Engine..."
./${FILE_VERSION} --headless --export-release "web" public/index.html

# --- 4. WASM OPTIMIZATION ---
echo "Downloading WASM Optimizer..."
if [ ! -d binaryen-${BINARYEN_VERSION} ]; then
    curl -L -s "https://github.com/WebAssembly/binaryen/releases/download/${BINARYEN_VERSION}/binaryen-${BINARYEN_VERSION}-x86_64-linux.tar.gz" | tar xz
fi

echo "Optimizing index.wasm for MAXIMUM speed..."
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
rm -rf godot.zip custom_templates.zip binaryen-${BINARYEN_VERSION} ${FILE_VERSION}
echo "Build complete. Engine surgery successful."
