#!/bin/bash
set -ex

# --- 1. CONFIGURATION ---
GODOT_VERSION="4.6-stable"
BASE_VERSION=$(echo "$GODOT_VERSION" | cut -d'-' -f1)
V_DIR="${BASE_VERSION}.stable"
BINARYEN_VERSION="version_116"

# Export templates (web):
# - Default (unset): download official Godot .tpz from GitHub — stable for main / Vercel, no custom release required.
# - Optional: set CUSTOM_ENGINE_URL (e.g. in Vercel env) to a Release asset: slim custom web_release.zip or legacy wasm+js zip.
#   Build locally or on a branch workflow to avoid burning Actions minutes on long engine compiles.
: "${CUSTOM_ENGINE_URL:=}"

OFFICIAL_EXPORT_TEMPLATES_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"

mkdir -p public

# --- 2. SETUP GODOT & CUSTOM TEMPLATES ---
echo "Setting up Godot ${GODOT_VERSION}..."
FILE_VERSION="Godot_v${GODOT_VERSION}_linux.x86_64"

if [ ! -f godot.zip ]; then
    curl -L -s "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${FILE_VERSION}.zip" -o godot.zip
    unzip -q godot.zip
fi

# EXPORT TEMPLATES (official by default; custom only if CUSTOM_ENGINE_URL is set)
TPL_ROOT="${HOME}/.local/share/godot/export_templates/${V_DIR}"
mkdir -p "${HOME}/.local/share/godot/export_templates"

if [ -n "${CUSTOM_ENGINE_URL}" ]; then
	echo "Using custom web template from CUSTOM_ENGINE_URL…"
	curl -fL -s "${CUSTOM_ENGINE_URL}" -o custom_templates.zip
	mkdir -p "${TPL_ROOT}"
	if unzip -l custom_templates.zip | grep -qE '[[:space:]]web_release\.wasm[[:space:]]*$' \
		&& unzip -l custom_templates.zip | grep -qE '[[:space:]]web_release\.js[[:space:]]*$'; then
		echo "Installing legacy loose web template (wasm + js)…"
		unzip -o -q custom_templates.zip -d "${TPL_ROOT}"
	else
		echo "Installing custom web_release.zip bundle…"
		cp -f custom_templates.zip "${TPL_ROOT}/web_release.zip"
	fi
else
	echo "Using official Godot export templates (${GODOT_VERSION})…"
	curl -fL -s "${OFFICIAL_EXPORT_TEMPLATES_URL}" -o export_templates.tpz
	# .tpz is a zip; contents are NOT always rooted at ${V_DIR}/ — use a temp dir and copy
	# the web zips into the path Godot expects (it checks both release and debug exist).
	_tpz_unpack=$(mktemp -d)
	unzip -o -q export_templates.tpz -d "${_tpz_unpack}"
	_rel=$(find "${_tpz_unpack}" -name 'web_release.zip' -type f | head -n1)
	_dbg=$(find "${_tpz_unpack}" -name 'web_debug.zip' -type f | head -n1)
	if [ -z "${_rel}" ] || [ -z "${_dbg}" ]; then
		echo "Could not find web_release.zip / web_debug.zip inside export_templates.tpz"
		find "${_tpz_unpack}" -type f | head -80
		exit 1
	fi
	mkdir -p "${TPL_ROOT}"
	cp -f "${_rel}" "${TPL_ROOT}/web_release.zip"
	cp -f "${_dbg}" "${TPL_ROOT}/web_debug.zip"
	rm -rf "${_tpz_unpack}"
	rm -f export_templates.tpz
fi

# --- 3. EXPORT PROJECT ---
echo "Building Graphos for web…"
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
rm -rf godot.zip custom_templates.zip export_templates.tpz binaryen-${BINARYEN_VERSION} ${FILE_VERSION}
echo "Build complete."
