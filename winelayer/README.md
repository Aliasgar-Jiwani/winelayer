# WineLayer

> **Run Windows apps on Linux — no terminal required.**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/platform-Linux-orange)](https://github.com)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen)](CONTRIBUTING.md)

WineLayer is an **experience orchestration engine** built on top of [Wine](https://www.winehq.org). It handles the full lifecycle of running a Windows application on Linux — installation, environment isolation, dependency resolution, crash fixing — all through a beautiful modern GUI.

> **No terminal. No configuration files. No manual Wine setup. Just install and run.**

---

## ✨ Features

| Feature | Description |
|---|---|
| 🧠 **Smart Installer** | YAML-powered app scripts pre-configure Wine automatically |
| 🔧 **Auto-Fix Engine** | Detects crashes and suggests one-click fixes |
| 🧪 **Micro-VM Sandbox** | KVM-based isolation for complex apps (Adobe, Office) |
| 📦 **App Catalog** | Curated scripts for popular Windows software |
| 🔍 **Log Diagnostics** | In-app crash log viewer with fix suggestions |
| 🌐 **Compat DB Sync** | Community-sourced compatibility database |
| 🖥️ **Zero Terminal** | Everything happens through a polished desktop UI |

---

## 🚀 Installation

### One-Command Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/Aliasgar-Jiwani/winelayer/main/winelayer/scripts/install.sh | bash
```

This script will:
1. Detect your Linux distribution (Ubuntu, Fedora, Arch, etc.)
2. Automatically install Wine if it's missing
3. Download and install WineLayer
4. Create a desktop shortcut

### Manual Download

Go to the [Releases Page](https://github.com/Aliasgar-Jiwani/winelayer/releases) and download `WineLayer-linux-x86_64.tar.gz`.

```bash
tar -xzf WineLayer-linux-x86_64.tar.gz
./WineLayer/WineLayer.sh
```

### Build from Source

```bash
# Requirements: Python 3.11+, Flutter SDK, Wine
git clone https://github.com/Aliasgar-Jiwani/winelayer.git
cd winelayer/winelayer

# Install Python deps
pip install -e ".[dev]"

# Terminal 1: Start the daemon
python -m daemon.main

# Terminal 2: Launch the UI
cd app && flutter run -d linux
```

---

## 🧩 Supported Linux Distros

| Distro | Status |
|---|---|
| Ubuntu 22.04+ | ✅ Fully supported |
| Linux Mint 21+ | ✅ Fully supported |
| Fedora 38+ | ✅ Fully supported |
| Arch / Manjaro | ✅ Fully supported |
| openSUSE | ✅ Fully supported |
| Debian 12+ | ✅ Fully supported |
| Pop!_OS | ✅ Fully supported |

---

## 🏗️ Architecture

WineLayer is split into two components that communicate over a local socket:

```
┌─────────────────────────────────┐
│   Flutter Desktop App (GUI)     │  ← What the user sees
│   lib/ · Dart · Riverpod        │
└──────────────┬──────────────────┘
               │  JSON-RPC over TCP socket
┌──────────────▼──────────────────┐
│   Python Daemon (Backend)       │  ← Where the real work happens
│   daemon/ · asyncio · SQLite    │
└─────────────────────────────────┘
```

### Key Modules

| Module | Description |
|---|---|
| `daemon/core/installer.py` | App installation, Wine prefix management |
| `daemon/core/wine_manager.py` | Wine version detection and switching |
| `daemon/core/fix_engine.py` | Auto-fix orchestrator |
| `daemon/core/log_analyzer.py` | Wine log parser and error matcher |
| `daemon/core/vm_manager.py` | KVM Micro-VM orchestrator (Phase 4) |
| `daemon/core/ipc_server.py` | JSON-RPC socket server |
| `compat-db/scripts/` | YAML app compatibility scripts |
| `compat-db/error_rules.json` | Error signature → fix mapping database |

---

## 📦 Adding App Support

Want to add Notepad++, Steam, Photoshop or any other Windows app to the catalog?
See [CONTRIBUTING.md](CONTRIBUTING.md) — it takes about 10 minutes and helps everyone!

---

## 🛠️ Development Phases

- ✅ **Phase 1 — Foundation**: Flutter shell, Python daemon, SQLite, Wine launch
- ✅ **Phase 2 — Smart Installer**: YAML scripts, Catalog, Winetricks dependency resolver
- ✅ **Phase 3 — Auto-Fix Engine**: Log analysis, error rules, fix suggestions, Compat DB sync
- ✅ **Phase 4 — Platform Maturity**: Micro-VM sandbox engine for complex apps

---

## 📄 License

WineLayer is licensed under the **GNU General Public License v3.0**.
See [LICENSE](LICENSE) for full terms.

WineLayer is **not affiliated with** or endorsed by the Wine project.

---

## 🤝 Contributing

Pull requests are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) to get started.

The most impactful thing you can do is add new app YAML scripts to `compat-db/scripts/`.

---

*Made with ❤️ for the Linux desktop community.*
