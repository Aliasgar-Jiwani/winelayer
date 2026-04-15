# Contributing to WineLayer

Thank you for helping make Windows apps run better on Linux! 🎉

There are two main ways to contribute — you don't need to be a programmer for either one.

---

## 📝 Adding an App to the Catalog

The most impactful contribution you can make is adding a new Windows app to the **Catalog**. This means Linux users can install that app with zero configuration.

### Step 1: Test the App Yourself
Install the app using WineLayer's "Add Application" feature first. Document:
- Which Wine version worked (stable, staging, or wine-ge)?
- Did it need any Winetricks components (e.g., `vcrun2019`, `dotnet48`)?
- What Architecture does it need (win32 or win64)?

### Step 2: Create a YAML Script
Create a new file in `compat-db/scripts/your-app-name.yaml`:

```yaml
app_id: your-app-name
display_name: "Your App Name"
version: "1.0"
description: "What this app does"
wine_version: stable
architecture: win64
homepage: https://your-app-website.com

dependencies:
  - vcrun2019
  - dotnet48

registry: []

post_install: []
```

### Step 3: Add an Error Rule (Optional)
If you know a common crash pattern and its fix, add it to `compat-db/error_rules.json`:

```json
{
  "id": "your_unique_rule_id",
  "pattern": "err:module:import_dll.*YourDLL.dll",
  "fix_action": "winetricks",
  "fix_args": ["vcrun2019"],
  "description": "Missing Your DLL runtime",
  "confidence": 0.9
}
```

### Step 4: Open a Pull Request
- Fork the repository
- Add your YAML file and any rule changes
- Open a Pull Request with a title like: `catalog: add Notepad++ 8.6`
- Include a screenshot of the app running if possible!

---

## 🐛 Reporting Bugs

Found something broken? Please open a GitHub Issue with:
- Your Linux distro and version (`lsb_release -a`)
- Your Wine version (`wine --version`)
- The app you were trying to run
- The full error message from Settings → (App) → Diagnostics

---

## 💻 Code Contributions

WineLayer is split into two parts:

| Component | Language | Location |
|---|---|---|
| Backend Daemon | Python 3.11+ | `winelayer/daemon/` |
| Desktop UI | Flutter / Dart | `winelayer/app/` |

### Setting Up for Development

```bash
# Clone the repo
git clone https://github.com/Aliasgar-Jiwani/winelayer.git
cd winelayer/winelayer

# Install Python dependencies
pip install -e ".[dev]"

# Run the daemon
python -m daemon.main

# In a new terminal, run the UI
cd app
flutter run -d linux
```

---

## Code of Conduct

Be kind. Be constructive. We're all here to make Linux better. 💙
