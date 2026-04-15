#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  WineLayer — Build Script for Linux Release
#  Compiles the Python daemon with PyInstaller and the Flutter
#  UI for Linux, then bundles everything into a dist/ folder.
#
#  Requirements:
#    pip install pyinstaller
#    flutter SDK in PATH
# ─────────────────────────────────────────────────────────────

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo -e "${CYAN}[WineLayer Build] Starting build...${RESET}"
echo -e "${CYAN}[WineLayer Build] Root: $ROOT_DIR${RESET}"

mkdir -p "$DIST_DIR"

# --- Step 1: Compile Python Daemon ---
echo ""
echo -e "${GREEN}► Step 1: Compiling Python daemon with PyInstaller...${RESET}"
cd "$ROOT_DIR"

pip install pyinstaller --quiet

pyinstaller \
    --onefile \
    --name winelayer-daemon \
    --add-data "compat-db:compat-db" \
    --hidden-import "sqlalchemy.dialects.sqlite" \
    --hidden-import "asyncio" \
    daemon/main.py

cp "$ROOT_DIR/dist/winelayer-daemon" "$DIST_DIR/winelayer-daemon"
echo -e "${GREEN}✓ Daemon compiled → $DIST_DIR/winelayer-daemon${RESET}"

# --- Step 2: Compile Flutter UI ---
echo ""
echo -e "${GREEN}► Step 2: Compiling Flutter UI for Linux...${RESET}"
cd "$ROOT_DIR/app"

flutter build linux --release

cp -r build/linux/x64/release/bundle "$DIST_DIR/ui"
echo -e "${GREEN}✓ Flutter UI compiled → $DIST_DIR/ui${RESET}"

# --- Step 3: Bundle everything ---
echo ""
echo -e "${GREEN}► Step 3: Creating release bundle...${RESET}"

RELEASE_DIR="$DIST_DIR/WineLayer"
mkdir -p "$RELEASE_DIR/daemon" "$RELEASE_DIR/ui"

cp "$DIST_DIR/winelayer-daemon" "$RELEASE_DIR/daemon/winelayer-daemon"
cp -r "$DIST_DIR/ui/"* "$RELEASE_DIR/ui/"
cp "$ROOT_DIR/scripts/start.sh" "$RELEASE_DIR/WineLayer.sh"
chmod +x "$RELEASE_DIR/WineLayer.sh"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║       Build complete! 🎉              ║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════╝${RESET}"
echo ""
echo -e "  Output: ${CYAN}$RELEASE_DIR${RESET}"
echo ""
echo -e "  To test: ${CYAN}$RELEASE_DIR/WineLayer.sh${RESET}"
echo ""
echo -e "  To package as AppImage, run:"
echo -e "    ${CYAN}appimagetool $RELEASE_DIR WineLayer-x86_64.AppImage${RESET}"
