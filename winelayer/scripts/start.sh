#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  WineLayer — Startup Script
#  Boots the Python daemon in the background, then launches
#  the Flutter UI. Cleans up the daemon when the UI closes.
# ─────────────────────────────────────────────────────────────

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON_BIN="$SCRIPT_DIR/../daemon/winelayer-daemon"
UI_BIN="$SCRIPT_DIR/../ui/winelayer"

# --- Check for compiled binaries (release mode) ---
if [ -f "$DAEMON_BIN" ] && [ -f "$UI_BIN" ]; then
    echo "[WineLayer] Starting compiled release..."
    "$DAEMON_BIN" &
    DAEMON_PID=$!
    sleep 1
    "$UI_BIN"
    kill "$DAEMON_PID" 2>/dev/null || true
    exit 0
fi

# --- Development mode (source) ---
echo "[WineLayer] Development mode detected — running from source..."

WINELAYER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check Python
if ! command -v python3 &>/dev/null; then
    echo "[ERROR] Python 3 is not installed. Please install it first."
    exit 1
fi

# Check Flutter
if ! command -v flutter &>/dev/null; then
    echo "[ERROR] Flutter SDK not found. Please add it to PATH."
    exit 1
fi

# Check Wine
if ! command -v wine &>/dev/null; then
    echo "[WARNING] Wine is not installed! WineLayer will prompt you to install it on first launch."
fi

# Boot daemon
echo "[WineLayer] Starting daemon..."
cd "$WINELAYER_ROOT"
python3 -m daemon.main &
DAEMON_PID=$!

# Give it a moment to open the socket
sleep 1.5

# Launch Flutter UI
echo "[WineLayer] Launching UI..."
cd "$WINELAYER_ROOT/app"
flutter run -d linux

# Cleanup when UI closes
echo "[WineLayer] UI closed. Shutting down daemon (PID $DAEMON_PID)..."
kill "$DAEMON_PID" 2>/dev/null || true

echo "[WineLayer] Goodbye!"
