#!/bin/bash
set -ex

GODOT_VERSION="4.6-stable"
BASE_VERSION=$(echo "$GODOT_VERSION" | cut -d'-' -f1)
V_DIR="${BASE_VERSION}.stable"

mkdir -p ~/.local/share/godot/export_templates/${V_DIR}
mkdir -p public

echo "Downloading Godot ${GODOT_VERSION}..."
FILE_VERSION="Godot_v${GODOT_VERSION}_linux.x86_64"
curl -L -s "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${FILE_VERSION}.zip" -o godot.zip
curl -L -s "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz" -o templates.tpz

echo "Extracting..."
unzip -q godot.zip
unzip -q templates.tpz

echo "Installing templates..."
mv templates/* ~/.local/share/godot/export_templates/${V_DIR}/

echo "Building project for Web..."
./${FILE_VERSION} --headless --export-release "Web" public/index.html

echo "Build complete."
