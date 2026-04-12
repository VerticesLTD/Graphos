#!/bin/bash
set -ex

# --- 1. CONFIGURATION ---
GODOT_VERSION="4.6-stable"
BASE_VERSION=$(echo "$GODOT_VERSION" | cut -d'-' -f1)
V_DIR="${BASE_VERSION}.stable"
BINARYEN_VERSION="version_116"

# Web export template — matches .github/workflows/build_custom_engine.yml:
#   Release asset = Godot's bin/godot.web.template_release.wasm32.zip renamed to web_release.zip (do not unzip that file).
# Install: ~/.local/share/godot/export_templates/4.6.stable/web_release.zip
# We also copy web_debug.zip from the same archive so Godot's export check passes (release export still uses release).
# Optional override: CUSTOM_ENGINE_URL=… (e.g. another Release or branch build).
CUSTOM_ENGINE_URL="${CUSTOM_ENGINE_URL:-https://github.com/VerticesLTD/Graphos/releases/download/v4.6-custom/web_release.zip}"

mkdir -p public

# --- 2. SETUP GODOT & TEMPLATES ---
echo "Setting up Godot ${GODOT_VERSION}…"
FILE_VERSION="Godot_v${GODOT_VERSION}_linux.x86_64"

if [ ! -f godot.zip ]; then
	curl -L -s "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${FILE_VERSION}.zip" -o godot.zip
	unzip -q godot.zip
fi

echo "Fetching web template…"
curl -fL -s "${CUSTOM_ENGINE_URL}" -o custom_templates.zip
unzip -t -q custom_templates.zip

TPL_ROOT="${HOME}/.local/share/godot/export_templates/${V_DIR}"
mkdir -p "${TPL_ROOT}"

# A) Legacy helper zip: only loose web_release.wasm + web_release.js at top level → unzip into version dir.
# B) Custom workflow (default): single Godot template zip → place as web_release.zip + web_debug.zip (same bytes; satisfies editor).
if unzip -l custom_templates.zip | grep -qE '[[:space:]]web_release\.wasm[[:space:]]*$' \
	&& unzip -l custom_templates.zip | grep -qE '[[:space:]]web_release\.js[[:space:]]*$'; then
	echo "Installing legacy loose wasm + js…"
	unzip -o -q custom_templates.zip -d "${TPL_ROOT}"
else
	echo "Installing custom template bundle (workflow web_release.zip)…"
	cp -f custom_templates.zip "${TPL_ROOT}/web_release.zip"
	cp -f "${TPL_ROOT}/web_release.zip" "${TPL_ROOT}/web_debug.zip"
fi

ls -la "${TPL_ROOT}"

# --- 3. EXPORT ---
echo "Building Graphos for web…"
./${FILE_VERSION} --headless --export-release "web" public/index.html

# --- 4. WASM OPTIMIZATION ---
echo "Downloading WASM Optimizer…"
if [ ! -d "binaryen-${BINARYEN_VERSION}" ]; then
	curl -L -s "https://github.com/WebAssembly/binaryen/releases/download/${BINARYEN_VERSION}/binaryen-${BINARYEN_VERSION}-x86_64-linux.tar.gz" | tar xz
fi

echo "Optimizing index.wasm…"
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
rm -rf godot.zip custom_templates.zip "binaryen-${BINARYEN_VERSION}" "${FILE_VERSION}"
echo "Build complete."
