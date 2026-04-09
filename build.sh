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

# --- MICROSOFT CLARITY INJECTION 
echo "Injecting Microsoft Clarity..."
CLARITY_ID="w8x9s1vxi5"
CLARITY_JS='<script type="text/javascript">(function(c,l,a,r,i,t,y){c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};t=l.createElement(r);t.async=1;t.src="https://www.clarity.ms/tag/"+i;t.setAttribute("crossorigin", "anonymous");y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y);c[a]("start", i);})(window, document, "clarity", "script", "w8x9s1vxi5");</script>'

# Inject to the header
sed -i "s@</head>@${CLARITY_JS}</head>@" public/index.html

echo "Build complete."
