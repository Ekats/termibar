#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/plugin"
PACKAGE_DIR="$SCRIPT_DIR/package"
QML_DEST="$(qtpaths6 --query QT_INSTALL_QML)/org/termibar"
PLASMOID_ID="com.github.ekats.termibar"

echo "==> Building plugin..."
cd "$PLUGIN_DIR"
cmake -B build -DCMAKE_BUILD_TYPE=Release -Wno-dev
cmake --build build --parallel

echo "==> Installing QML plugin (needs sudo)..."
sudo mkdir -p "$QML_DEST"
sudo cp build/org/termibar/libtermibarplugin.so "$QML_DEST/"
sudo cp build/org/termibar/qmldir "$QML_DEST/"
sudo cp build/org/termibar/termibarplugin.qmltypes "$QML_DEST/"

echo "==> Installing plasmoid..."
rm -rf "$HOME/.local/share/plasma/plasmoids/$PLASMOID_ID"
kpackagetool6 -t Plasma/Applet -i "$PACKAGE_DIR"

echo "==> Restarting plasmashell..."
PSPID=$(pgrep -x plasmashell)
kquitapp6 plasmashell 2>/dev/null || true
sleep 3
if [ -n "$PSPID" ]; then
    pkill -KILL -P "$PSPID" 2>/dev/null
    kill -9 "$PSPID" 2>/dev/null
fi
sleep 0.5
systemctl --user start plasma-plasmashell.service

echo "==> Done. Add 'Termibar' from the widget picker."
