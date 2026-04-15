"""
WineLayer Daemon — Global Configuration

Handles platform detection, XDG-compliant paths on Linux,
and fallback paths on Windows for development.
"""

import os
import sys
import platform
from pathlib import Path
from dataclasses import dataclass, field


def _is_linux() -> bool:
    return platform.system() == "Linux"


def _get_data_dir() -> Path:
    """
    Returns the data directory following XDG Base Directory Specification on Linux.
    On Windows, uses %LOCALAPPDATA%/winelayer for development.
    """
    if _is_linux():
        xdg_data = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
        return Path(xdg_data) / "winelayer"
    else:
        local_app = os.environ.get("LOCALAPPDATA", os.path.expanduser("~/AppData/Local"))
        return Path(local_app) / "winelayer"


def _get_cache_dir() -> Path:
    """
    Returns the cache directory following XDG spec on Linux.
    On Windows, uses %LOCALAPPDATA%/winelayer/cache.
    """
    if _is_linux():
        xdg_cache = os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
        return Path(xdg_cache) / "winelayer"
    else:
        local_app = os.environ.get("LOCALAPPDATA", os.path.expanduser("~/AppData/Local"))
        return Path(local_app) / "winelayer" / "cache"


def _get_config_dir() -> Path:
    """
    Returns the config directory following XDG spec on Linux.
    On Windows, uses %LOCALAPPDATA%/winelayer/config.
    """
    if _is_linux():
        xdg_config = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
        return Path(xdg_config) / "winelayer"
    else:
        local_app = os.environ.get("LOCALAPPDATA", os.path.expanduser("~/AppData/Local"))
        return Path(local_app) / "winelayer" / "config"


@dataclass
class WineLayerConfig:
    """Global daemon configuration."""

    # Platform
    is_linux: bool = field(default_factory=_is_linux)
    platform_name: str = field(default_factory=platform.system)

    # Paths
    data_dir: Path = field(default_factory=_get_data_dir)
    cache_dir: Path = field(default_factory=_get_cache_dir)
    config_dir: Path = field(default_factory=_get_config_dir)

    # IPC
    ipc_host: str = "127.0.0.1"
    ipc_port: int = 9274

    # Wine defaults
    default_architecture: str = "win64"
    default_wine_version: str = "stable"

    # Database
    db_name: str = "winelayer.db"

    # Logging
    log_level: str = "INFO"

    @property
    def prefixes_dir(self) -> Path:
        return self.data_dir / "prefixes"

    @property
    def wine_builds_dir(self) -> Path:
        return self.data_dir / "wine"

    @property
    def db_path(self) -> Path:
        return self.data_dir / self.db_name

    @property
    def db_url(self) -> str:
        return f"sqlite+aiosqlite:///{self.db_path}"

    @property
    def winetricks_cache_dir(self) -> Path:
        return self.cache_dir / "winetricks"

    def ensure_directories(self) -> None:
        """Create all required directories if they don't exist."""
        dirs = [
            self.data_dir,
            self.cache_dir,
            self.config_dir,
            self.prefixes_dir,
            self.wine_builds_dir,
            self.winetricks_cache_dir,
        ]
        for d in dirs:
            d.mkdir(parents=True, exist_ok=True)


# Global config instance
config = WineLayerConfig()
