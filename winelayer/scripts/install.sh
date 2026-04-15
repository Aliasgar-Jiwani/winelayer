#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  WineLayer — One-Command Linux Installer
#  Run this with:
#    curl -fsSL https://raw.githubusercontent.com/Aliasgar-Jiwani/winelayer/main/scripts/install.sh | bash
# ─────────────────────────────────────────────────────────────

set -e

REPO_URL="https://github.com/Aliasgar-Jiwani/winelayer"
APPIMAGE_URL="https://github.com/Aliasgar-Jiwani/winelayer/releases/latest/download/WineLayer-x86_64.AppImage"
INSTALL_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

echo ""
echo -e "${CYAN}╔══════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║        WineLayer Installer           ║${RESET}"
echo -e "${CYAN}║  Run Windows apps natively on Linux  ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════╝${RESET}"
echo ""

# --- Detect distro ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    DISTRO="unknown"
fi

echo -e "${GREEN}► Detected distro:${RESET} $DISTRO"

# --- Check / Install Wine ---
if command -v wine &>/dev/null; then
    WINE_VER=$(wine --version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}► Wine already installed:${RESET} $WINE_VER"
else
    echo -e "${YELLOW}► Wine not found. Installing Wine...${RESET}"
    case "$DISTRO" in
        ubuntu|linuxmint|pop|elementary)
            sudo dpkg --add-architecture i386
            sudo apt-get update -qq
            sudo apt-get install -y wine wine32 wine64 winetricks
            ;;
        fedora)
            sudo dnf install -y wine winetricks
            ;;
        arch|manjaro|endeavouros)
            sudo pacman -Sy --noconfirm wine winetricks
            ;;
        opensuse*|sles)
            sudo zypper install -y wine winetricks
            ;;
        *)
            echo -e "${YELLOW}► Unknown distro. Please install Wine manually:${RESET}"
            echo "  Visit https://www.winehq.org/download"
            echo ""
            ;;
    esac
    echo -e "${GREEN}✓ Wine installed!${RESET}"
fi

# --- Install WineLayer AppImage ---
echo ""
echo -e "${GREEN}► Downloading WineLayer...${RESET}"
mkdir -p "$INSTALL_DIR"
curl -L --progress-bar "$APPIMAGE_URL" -o "$INSTALL_DIR/WineLayer.AppImage"
chmod +x "$INSTALL_DIR/WineLayer.AppImage"

# --- Desktop Shortcut ---
echo -e "${GREEN}► Creating desktop entry...${RESET}"
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_DIR/winelayer.desktop" << EOF
[Desktop Entry]
Name=WineLayer
Comment=Run Windows apps on Linux — plug and play
Exec=$INSTALL_DIR/WineLayer.AppImage
Icon=winelayer
Type=Application
Categories=System;Emulator;
StartupWMClass=winelayer
EOF

# Update desktop database
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true

echo ""
echo -e "${GREEN}╔══════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║      WineLayer installed! 🎉          ║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════╝${RESET}"
echo ""
echo -e "  Run it:    ${CYAN}WineLayer.AppImage${RESET}"
echo -e "  Or find it in your Application Menu as ${CYAN}WineLayer${RESET}"
echo ""
echo -e "  GitHub:    ${CYAN}$REPO_URL${RESET}"
echo ""
