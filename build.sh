#!/bin/bash
set -ex

# --- 1. CONFIGURATION ---
GODOT_VERSION="4.6-stable"
BASE_VERSION=$(echo "$GODOT_VERSION" | cut -d'-' -f1)
V_DIR="${BASE_VERSION}.stable"
BINARYEN_VERSION="version_116"

# Fast path: small custom web template from your Release (not the huge official .tpz).
# Override in Vercel if needed: CUSTOM_ENGINE_URL=https://...
CUSTOM_ENGINE_URL="${CUSTOM_ENGINE_URL:-https://github.com/VerticesLTD/Graphos/releases/download/v4.6-custom/web_release.zip}"

mkdir -p public

# --- 2. SETUP GODOT & TEMPLATES ---
echo "Setting up Godot ${GODOT_VERSION}…"
FILE_VERSION="Godot_v${GODOT_VERSION}_linux.x86_64"

if [ ! -f godot.zip ]; then
	curl -L -s "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${FILE_VERSION}.zip" -o godot.zip
	unzip -q godot.zip
fi

echo "Fetching web template (fast download)…"
curl -fL -s "${CUSTOM_ENGINE_URL}" -o custom_templates.zip

TPL_ROOT="${HOME}/.local/share/godot/export_templates/${V_DIR}"
mkdir -p "${TPL_ROOT}"

# Legacy zip: loose web_release.wasm + .js (unzip into version dir).
# Bundle: Godot-shaped web_release.zip → copy; duplicate as web_debug.zip so export validation passes.
if unzip -l custom_templates.zip | grep -qE '[[:space:]]web_release\.wasm[[:space:]]*$' \
	&& unzip -l custom_templates.zip | grep -qE '[[:space:]]web_release\.js[[:space:]]*$'; then
	echo "Installing legacy loose wasm + js…"
	unzip -o -q custom_templates.zip -d "${TPL_ROOT}"
else
	echo "Installing web_release.zip bundle…"
	cp -f custom_templates.zip "${TPL_ROOT}/web_release.zip"
	cp -f "${TPL_ROOT}/web_release.zip" "${TPL_ROOT}/web_debug.zip"
fi

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
