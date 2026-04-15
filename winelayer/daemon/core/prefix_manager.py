"""
WineLayer — Prefix Manager

Creates, deletes, lists, and manages per-app Wine prefixes.
Each app gets an isolated prefix at {data_dir}/prefixes/{app_id}/.

On Windows (development mode), prefix creation skips wineboot
and only creates the directory structure.
"""

import asyncio
import logging
import shutil
from pathlib import Path
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import selectinload

from daemon.config import config
from daemon.db.database import get_session
from daemon.db.models import App, Prefix, AppStatus
from daemon.core.wine_manager import wine_manager

logger = logging.getLogger(__name__)


class PrefixManager:
    """
    Manages Wine prefixes — isolated Windows environments for each app.
    """

    def __init__(self):
        self._prefixes_dir = config.prefixes_dir

    async def create_prefix(
        self,
        app_id: str,
        architecture: str = "win64",
        wine_version: str = "stable",
        reporter=None,
    ) -> str:
        """
        Create a new Wine prefix for an app.
        
        Args:
            app_id: Unique identifier for the app
            architecture: 'win32' or 'win64'
            wine_version: Wine version to use
            reporter: Optional callback for progress reporting
            
        Returns:
            Path to the created prefix
        """
        prefix_path = self._prefixes_dir / app_id
        prefix_path.mkdir(parents=True, exist_ok=True)

        if reporter:
            await reporter("creating_prefix", f"Creating prefix for {app_id}")

        if config.is_linux:
            await self._init_wine_prefix(str(prefix_path), architecture)
        else:
            # Development stub: create basic directory structure
            logger.info(f"Dev mode: Creating stub prefix at {prefix_path}")
            (prefix_path / "drive_c").mkdir(exist_ok=True)
            (prefix_path / "drive_c" / "windows").mkdir(exist_ok=True)
            (prefix_path / "drive_c" / "users").mkdir(exist_ok=True)
            (prefix_path / "drive_c" / "Program Files").mkdir(exist_ok=True)

        # Store prefix in database
        async with get_session() as session:
            prefix = Prefix(
                app_id=app_id,
                path=str(prefix_path),
                architecture=architecture,
                wine_version=wine_version,
            )
            session.add(prefix)
            await session.commit()

        if reporter:
            await reporter("prefix_ready", f"Prefix ready at {prefix_path}")

        logger.info(f"Created prefix for '{app_id}' at {prefix_path}")
        return str(prefix_path)

    async def _init_wine_prefix(self, prefix_path: str, architecture: str) -> None:
        """
        Initialize a real Wine prefix using wineboot.
        Only called on Linux.
        """
        import os

        wine_binary = wine_manager.get_wine_binary()
        env = {
            **os.environ,
            "WINEPREFIX": prefix_path,
            "WINEARCH": architecture,
            "WINEDEBUG": "-all",
        }

        try:
            proc = await asyncio.create_subprocess_exec(
                "wineboot", "--init",
                env=env,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, stderr = await proc.communicate()

            if proc.returncode != 0:
                error_msg = stderr.decode().strip()
                logger.error(f"wineboot failed: {error_msg}")
                raise RuntimeError(f"Failed to initialize Wine prefix: {error_msg}")

            logger.info(f"Wine prefix initialized at {prefix_path}")

        except FileNotFoundError:
            raise RuntimeError("wineboot not found. Is Wine installed?")

    async def delete_prefix(self, app_id: str) -> bool:
        """
        Delete a Wine prefix and its database record.
        Returns True if successfully deleted.
        """
        prefix_path = self._prefixes_dir / app_id

        # Remove from filesystem
        if prefix_path.exists():
            shutil.rmtree(prefix_path)
            logger.info(f"Deleted prefix directory: {prefix_path}")

        # Remove from database
        async with get_session() as session:
            result = await session.execute(
                select(Prefix).where(Prefix.app_id == app_id)
            )
            prefix = result.scalar_one_or_none()
            if prefix:
                await session.delete(prefix)
                await session.commit()
                logger.info(f"Deleted prefix record for '{app_id}'")
                return True

        return False

    async def get_prefix_path(self, app_id: str) -> Optional[str]:
        """Get the filesystem path of an app's prefix."""
        async with get_session() as session:
            result = await session.execute(
                select(Prefix).where(Prefix.app_id == app_id)
            )
            prefix = result.scalar_one_or_none()
            return prefix.path if prefix else None

    async def list_prefixes(self) -> list[dict]:
        """List all managed prefixes."""
        async with get_session() as session:
            result = await session.execute(select(Prefix))
            prefixes = result.scalars().all()
            return [p.to_dict() for p in prefixes]

    async def prefix_exists(self, app_id: str) -> bool:
        """Check if a prefix exists for the given app."""
        prefix_path = self._prefixes_dir / app_id
        return prefix_path.exists()


# Singleton instance
prefix_manager = PrefixManager()
