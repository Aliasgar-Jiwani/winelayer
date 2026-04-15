"""
System Requirements Checker
Runs at daemon startup to verify the host environment is ready.
"""
import asyncio
import shutil
import subprocess
import logging
import platform
from typing import Optional

logger = logging.getLogger(__name__)


class SystemRequirements:
    def __init__(self):
        self.is_linux = platform.system() == "Linux"
        self.wine_path: Optional[str] = None
        self.winetricks_path: Optional[str] = None

    def check_wine(self) -> dict:
        """Check if Wine is installed and return its version."""
        path = shutil.which("wine")
        if not path:
            return {"installed": False, "version": None, "path": None}

        try:
            result = subprocess.run(
                [path, "--version"],
                capture_output=True, text=True, timeout=5
            )
            version = result.stdout.strip()
            self.wine_path = path
            return {"installed": True, "version": version, "path": path}
        except Exception as e:
            logger.warning(f"Wine check failed: {e}")
            return {"installed": False, "version": None, "path": None}

    def check_winetricks(self) -> dict:
        """Check if winetricks is installed."""
        path = shutil.which("winetricks")
        if path:
            self.winetricks_path = path
            return {"installed": True, "path": path}
        return {"installed": False, "path": None}

    def get_distro(self) -> str:
        """Detect Linux distribution."""
        try:
            with open("/etc/os-release") as f:
                for line in f:
                    if line.startswith("ID="):
                        return line.strip().split("=")[1].strip('"').lower()
        except Exception:
            pass
        return "unknown"

    def get_install_command(self) -> Optional[list]:
        """Return the correct system command to install Wine for this distro."""
        distro = self.get_distro()
        commands = {
            "ubuntu": ["pkexec", "apt-get", "install", "-y", "wine", "wine32", "wine64", "winetricks"],
            "linuxmint": ["pkexec", "apt-get", "install", "-y", "wine", "wine32", "wine64", "winetricks"],
            "pop": ["pkexec", "apt-get", "install", "-y", "wine", "wine32", "wine64", "winetricks"],
            "debian": ["pkexec", "apt-get", "install", "-y", "wine", "wine32", "wine64", "winetricks"],
            "fedora": ["pkexec", "dnf", "install", "-y", "wine", "winetricks"],
            "arch": ["pkexec", "pacman", "-Sy", "--noconfirm", "wine", "winetricks"],
            "manjaro": ["pkexec", "pacman", "-Sy", "--noconfirm", "wine", "winetricks"],
            "opensuse-leap": ["pkexec", "zypper", "install", "-y", "wine", "winetricks"],
            "opensuse-tumbleweed": ["pkexec", "zypper", "install", "-y", "wine", "winetricks"],
        }
        return commands.get(distro)

    async def install_wine(self, reporter=None) -> bool:
        """
        Attempt to install Wine using the correct package manager.
        Uses pkexec for GUI privilege escalation — no terminal needed!
        """
        if not self.is_linux:
            logger.info("Not Linux — skipping Wine install")
            return True

        cmd = self.get_install_command()
        if not cmd:
            logger.warning(f"Unknown distro — cannot auto-install Wine")
            return False

        try:
            if reporter:
                await reporter("installing_wine", "Installing Wine (you may see a password prompt)...")

            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, stderr = await proc.communicate()

            if proc.returncode == 0:
                if reporter:
                    await reporter("wine_installed", "Wine installed successfully!")
                logger.info("Wine installed successfully via package manager")
                return True
            else:
                logger.error(f"Wine installation failed: {stderr.decode()}")
                return False
        except Exception as e:
            logger.error(f"Wine auto-install error: {e}")
            return False

    def get_status(self) -> dict:
        """Full system status snapshot."""
        wine = self.check_wine()
        tricks = self.check_winetricks()
        distro = self.get_distro() if self.is_linux else "windows"
        return {
            "platform": "linux" if self.is_linux else "windows",
            "distro": distro,
            "wine": wine,
            "winetricks": tricks,
            "can_auto_install": self.get_install_command() is not None,
        }


system_requirements = SystemRequirements()
