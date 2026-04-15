"""
WineLayer — Registry Manager

Applies Windows registry modifications to Wine prefixes using `wine reg add`.
Also handles Windows version configuration.

On Windows (development mode), registry operations are simulated.
"""

import asyncio
import logging
import os
from typing import Optional, Callable, Awaitable

from daemon.config import config
from daemon.core.wine_manager import wine_manager

logger = logging.getLogger(__name__)

ProgressReporter = Callable[[str, str], Awaitable[None]]

# Windows version registry values for winecfg
WINDOWS_VERSIONS = {
    "win11": {"ProductName": "Microsoft Windows 11", "CSDVersion": "", "CurrentBuildNumber": "22000", "CurrentVersion": "10.0"},
    "win10": {"ProductName": "Microsoft Windows 10", "CSDVersion": "", "CurrentBuildNumber": "19041", "CurrentVersion": "10.0"},
    "win81": {"ProductName": "Microsoft Windows 8.1", "CSDVersion": "", "CurrentBuildNumber": "9600", "CurrentVersion": "6.3"},
    "win8":  {"ProductName": "Microsoft Windows 8", "CSDVersion": "", "CurrentBuildNumber": "9200", "CurrentVersion": "6.2"},
    "win7":  {"ProductName": "Microsoft Windows 7", "CSDVersion": "Service Pack 1", "CurrentBuildNumber": "7601", "CurrentVersion": "6.1"},
    "winxp": {"ProductName": "Microsoft Windows XP", "CSDVersion": "Service Pack 3", "CurrentBuildNumber": "2600", "CurrentVersion": "5.1"},
    "win2k": {"ProductName": "Microsoft Windows 2000", "CSDVersion": "Service Pack 4", "CurrentBuildNumber": "2195", "CurrentVersion": "5.0"},
}


class RegistryManager:
    """
    Manages Windows registry modifications in Wine prefixes.
    """

    async def apply_registry_entry(
        self,
        prefix_path: str,
        key: str,
        value: str,
        data: str,
        reg_type: str = "REG_SZ",
        reporter: Optional[ProgressReporter] = None,
    ) -> bool:
        """
        Apply a single registry entry using `wine reg add`.

        Args:
            prefix_path: Path to the Wine prefix
            key: Registry key (e.g., HKEY_CURRENT_USER\\Software\\App)
            value: Value name
            data: Value data
            reg_type: REG_SZ, REG_DWORD, REG_BINARY, etc.
        """
        if reporter:
            await reporter("registry", f"Setting {key}\\{value}")

        if not config.is_linux:
            logger.info(f"Dev mode: Simulating registry set {key}\\{value} = {data}")
            return True

        wine_binary = wine_manager.get_wine_binary()
        env = {
            **os.environ,
            "WINEPREFIX": prefix_path,
            "WINEDEBUG": "-all",
        }

        try:
            proc = await asyncio.create_subprocess_exec(
                wine_binary, "reg", "add", key,
                "/v", value, "/t", reg_type, "/d", data, "/f",
                env=env,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, stderr = await proc.communicate()

            if proc.returncode != 0:
                error = stderr.decode()[:300]
                logger.error(f"Registry set failed: {error}")
                return False

            logger.info(f"Registry set: {key}\\{value} = {data}")
            return True

        except Exception as e:
            logger.error(f"Registry operation failed: {e}")
            return False

    async def apply_registry_entries(
        self,
        prefix_path: str,
        entries: list[dict],
        reporter: Optional[ProgressReporter] = None,
    ) -> dict:
        """
        Apply a list of registry entries.

        Args:
            entries: List of dicts with 'key', 'value', 'data', 'type'

        Returns:
            Dict with 'applied' and 'failed' counts.
        """
        applied = 0
        failed = 0

        for entry in entries:
            success = await self.apply_registry_entry(
                prefix_path=prefix_path,
                key=entry["key"],
                value=entry["value"],
                data=entry["data"],
                reg_type=entry.get("type", "REG_SZ"),
                reporter=reporter,
            )
            if success:
                applied += 1
            else:
                failed += 1

        result = {"applied": applied, "failed": failed}
        logger.info(f"Registry entries result: {result}")
        return result

    async def set_windows_version(
        self,
        prefix_path: str,
        version: str,
        reporter: Optional[ProgressReporter] = None,
    ) -> bool:
        """
        Set the Windows version for a prefix.
        Uses registry entries under HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion.
        """
        if version not in WINDOWS_VERSIONS:
            logger.error(f"Unknown Windows version: {version}")
            return False

        if reporter:
            await reporter("windows_version", f"Setting Windows version to {version}")

        version_info = WINDOWS_VERSIONS[version]
        base_key = "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion"

        entries = [
            {"key": base_key, "value": k, "data": v, "type": "REG_SZ"}
            for k, v in version_info.items()
        ]

        result = await self.apply_registry_entries(prefix_path, entries, reporter)

        success = result["failed"] == 0
        if success:
            logger.info(f"Windows version set to {version} for {prefix_path}")
        return success


# Singleton instance
registry_manager = RegistryManager()
