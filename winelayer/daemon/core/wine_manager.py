"""
WineLayer — Wine Version Manager

Detects system Wine installation, provides version info, manages
the Wine binary path, and supports downloading/managing multiple
Wine builds (stable, staging, wine-ge).

On Windows (development mode), all Wine calls return stubs.
"""

import asyncio
import logging
import platform
import shutil
from pathlib import Path
from dataclasses import dataclass
from typing import Optional, Callable, Awaitable

from daemon.config import config

logger = logging.getLogger(__name__)

ProgressReporter = Callable[[str, str], Awaitable[None]]


@dataclass
class WineInfo:
    """Information about a Wine installation."""
    version: str
    path: str
    arch: str
    is_staging: bool = False
    is_ge: bool = False

    def to_dict(self) -> dict:
        return {
            "version": self.version,
            "path": self.path,
            "arch": self.arch,
            "is_staging": self.is_staging,
            "is_ge": self.is_ge,
        }


# Known Wine download sources (for Linux)
WINE_SOURCES = {
    "stable": {
        "name": "Wine Stable",
        "detect_cmd": "wine",
        "description": "Official Wine release",
    },
    "staging": {
        "name": "Wine Staging",
        "detect_cmd": "wine",
        "description": "Patched Wine with experimental features",
    },
    "wine-ge": {
        "name": "Wine-GE (GloriousEggroll)",
        "detect_cmd": None,
        "description": "Community build optimized for gaming",
    },
}


class WineManager:
    """
    Manages Wine runtime detection, version selection, and multiple builds.
    """

    def __init__(self):
        self._wine_path: Optional[str] = None
        self._wine_info: Optional[WineInfo] = None
        self._versions: dict[str, WineInfo] = {}

    async def detect_wine(self) -> Optional[WineInfo]:
        """
        Detect the system-installed Wine binary and version.
        Returns WineInfo if found, None otherwise.
        """
        if not config.is_linux:
            logger.info("Not on Linux — returning stub Wine info for development")
            self._wine_info = WineInfo(
                version="development-stub-9.0",
                path="wine",
                arch="win64",
            )
            self._versions["stable"] = self._wine_info
            return self._wine_info

        # Try to find wine binary
        wine_path = shutil.which("wine")
        if not wine_path:
            logger.warning("Wine not found in PATH")
            return None

        self._wine_path = wine_path

        # Get Wine version
        try:
            proc = await asyncio.create_subprocess_exec(
                wine_path, "--version",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, stderr = await proc.communicate()
            version_str = stdout.decode().strip()

            # Parse version — e.g., "wine-9.0 (Staging)" or "wine-9.4"
            is_staging = "staging" in version_str.lower()
            is_ge = "ge" in version_str.lower()

            self._wine_info = WineInfo(
                version=version_str,
                path=wine_path,
                arch="win64",
                is_staging=is_staging,
                is_ge=is_ge,
            )

            # Categorize the detected version
            if is_ge:
                self._versions["wine-ge"] = self._wine_info
            elif is_staging:
                self._versions["staging"] = self._wine_info
            else:
                self._versions["stable"] = self._wine_info

            logger.info(f"Detected Wine: {version_str} at {wine_path}")
            return self._wine_info

        except Exception as e:
            logger.error(f"Failed to detect Wine version: {e}")
            return None

    def get_wine_binary(self, version: str = "stable") -> str:
        """
        Return the path to the wine binary for the given version.
        Falls back to 'wine' if not found.
        """
        # Check if we have a specific build for this version
        info = self._versions.get(version)
        if info:
            return info.path

        # Check local builds directory
        build_dir = config.wine_builds_dir / version
        wine_bin = build_dir / "bin" / "wine"
        if wine_bin.exists():
            return str(wine_bin)

        # Fallback
        if self._wine_path:
            return self._wine_path
        return "wine"

    def get_wine_info(self) -> Optional[WineInfo]:
        """Return cached Wine info, or None if not yet detected."""
        return self._wine_info

    def list_versions(self) -> list[dict]:
        """
        List all locally available Wine versions.
        Includes both detected system Wine and downloaded builds.
        """
        versions = []

        # System-detected versions
        for key, info in self._versions.items():
            versions.append({
                "version_id": key,
                "version": info.version,
                "path": info.path,
                "source": "system",
                "is_staging": info.is_staging,
                "is_ge": info.is_ge,
            })

        # Local builds directory
        builds_dir = config.wine_builds_dir
        if builds_dir.exists():
            for d in builds_dir.iterdir():
                if d.is_dir() and (d / "bin" / "wine").exists():
                    vid = d.name
                    if vid not in self._versions:
                        versions.append({
                            "version_id": vid,
                            "version": vid,
                            "path": str(d / "bin" / "wine"),
                            "source": "local",
                            "is_staging": "staging" in vid.lower(),
                            "is_ge": "ge" in vid.lower(),
                        })

        return versions

    async def ensure_version(
        self,
        version: str,
        reporter: Optional[ProgressReporter] = None,
    ) -> str:
        """
        Ensure a Wine version is available locally.
        Downloads it if necessary.
        Returns the path to the wine binary.
        """
        # Check if already available
        binary = self.get_wine_binary(version)
        if binary != "wine" or version == "stable":
            return binary

        # On dev (Windows), just return stub
        if not config.is_linux:
            logger.info(f"Dev mode: Simulating Wine {version} availability")
            return "wine"

        if reporter:
            await reporter("wine_version", f"Wine {version} required — using system Wine as fallback")

        # For Phase 2, we return the system wine as fallback.
        # Full download logic will be implemented in Phase 3.
        return self.get_wine_binary()

    async def get_wine_server_binary(self) -> Optional[str]:
        """Find the wineserver binary, typically alongside wine."""
        if not config.is_linux:
            return "wineserver"

        wineserver = shutil.which("wineserver")
        return wineserver

    def get_available_sources(self) -> list[dict]:
        """List all known Wine sources with metadata."""
        return [
            {
                "id": key,
                "name": source["name"],
                "description": source["description"],
                "installed": key in self._versions,
            }
            for key, source in WINE_SOURCES.items()
        ]


# Singleton instance
wine_manager = WineManager()
