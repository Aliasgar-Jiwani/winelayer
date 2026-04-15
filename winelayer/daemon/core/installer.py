"""
WineLayer — App Installer (Phase 2)

Orchestrates the installation of Windows .exe applications.
Supports two modes:
  - Generic: Register app, create prefix, run .exe (Phase 1)
  - Script-based: Load YAML config, auto-install deps & registry (Phase 2)

On Windows (development mode), Wine execution is simulated.
"""

import asyncio
import logging
import os
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable, Optional, Awaitable

from sqlalchemy import select

from daemon.config import config
from daemon.db.database import get_session
from daemon.db.models import App, AppStatus, InstallLog
from daemon.core.prefix_manager import prefix_manager
from daemon.core.wine_manager import wine_manager
from daemon.core.script_engine import script_engine
from daemon.core.dependency_resolver import dependency_resolver
from daemon.core.registry_manager import registry_manager
from daemon.core.vm_manager import vm_manager

logger = logging.getLogger(__name__)

# Type alias for progress reporter
ProgressReporter = Callable[[str, str], Awaitable[None]]


def _sanitize_app_id(name: str) -> str:
    """
    Generate a safe app_id from a display name.
    Lowercase, alphanumeric + underscores only.
    """
    sanitized = re.sub(r"[^a-zA-Z0-9]", "_", name.lower())
    sanitized = re.sub(r"_+", "_", sanitized).strip("_")
    return sanitized


class Installer:
    """
    Handles the full installation lifecycle for Windows apps.
    Supports generic install and script-driven install from compat-db.
    """

    # ─── Script-Based Install (Phase 2) ──────────────────────────────

    async def install_from_script(
        self,
        app_id: str,
        exe_path: str,
        reporter: Optional[ProgressReporter] = None,
    ) -> dict:
        """
        Install an app using its YAML script from the compat-db.
        Pipeline: load script → create prefix → set Win version →
                  install deps → apply registry → run exe → post-install.

        Args:
            app_id: The app_id matching a YAML script in compat-db
            exe_path: Path to the .exe installer/executable
            reporter: Async callback for progress updates

        Returns:
            Dict with app info on success
        """
        # Step 1: Load the script
        script = script_engine.load_script(app_id)
        if not script:
            raise RuntimeError(f"No install script found for '{app_id}'")

        if not Path(exe_path).exists():
            raise FileNotFoundError(f"Executable not found: {exe_path}")

        if reporter:
            await reporter("loading_script", f"Loaded script for {script.display_name}")

        # Step 2: Register app in database
        async with get_session() as session:
            existing = await session.execute(
                select(App).where(App.app_id == app_id)
            )
            if existing.scalar_one_or_none():
                raise RuntimeError(f"App '{app_id}' is already installed")

            app = App(
                app_id=app_id,
                display_name=script.display_name,
                exe_path=exe_path,
                architecture=script.architecture,
                wine_version=script.wine_version,
                status=AppStatus.INSTALLING,
            )
            session.add(app)

            log_entry = InstallLog(
                app_id=app_id,
                action="install_start",
                result="in_progress",
                log_text=f"Script-based install with {len(script.dependencies)} deps",
            )
            session.add(log_entry)
            await session.commit()

        if reporter:
            await reporter("registered", "App registered in database")

        # Step 3: Ensure Wine version
        try:
            wine_binary = await wine_manager.ensure_version(
                script.wine_version, reporter
            )
        except Exception as e:
            await self._mark_failed(app_id, f"Wine version setup failed: {e}")
            raise

        # Step 4: Create Wine prefix
        try:
            prefix_path = await prefix_manager.create_prefix(
                app_id=app_id,
                architecture=script.architecture,
                wine_version=script.wine_version,
                reporter=reporter,
            )
        except Exception as e:
            await self._mark_failed(app_id, f"Prefix creation failed: {e}")
            raise

        # Step 5: Set Windows version
        if reporter:
            await reporter("windows_version", f"Setting Windows version to {script.windows_version}")

        try:
            await registry_manager.set_windows_version(
                prefix_path, script.windows_version, reporter
            )
        except Exception as e:
            logger.warning(f"Failed to set Windows version: {e}")

        # Step 6: Install dependencies
        if script.dependencies:
            if reporter:
                await reporter("dependencies", f"Installing {len(script.dependencies)} dependencies...")

            try:
                dep_result = await dependency_resolver.resolve_and_install(
                    prefix_path, script.dependencies, reporter
                )
                if dep_result["failed"]:
                    logger.warning(f"Some deps failed: {dep_result['failed']}")
            except Exception as e:
                await self._mark_failed(app_id, f"Dependency installation failed: {e}")
                raise

        # Step 7: Apply registry tweaks
        if script.registry:
            if reporter:
                await reporter("registry", f"Applying {len(script.registry)} registry entries...")

            try:
                entries = [r.model_dump() for r in script.registry]
                await registry_manager.apply_registry_entries(
                    prefix_path, entries, reporter
                )
            except Exception as e:
                logger.warning(f"Some registry entries failed: {e}")

        # Step 8: Run the .exe
        if reporter:
            await reporter("running_exe", f"Running {Path(exe_path).name}...")

        try:
            if config.is_linux:
                await self._run_wine_exe(app_id, prefix_path, exe_path, script.wine_version)
            else:
                # Windows: run .exe natively (no Wine needed)
                await self._run_native_exe(app_id, exe_path)
        except Exception as e:
            await self._mark_failed(app_id, f"Execution failed: {e}")
            raise

        # Step 9: Post-install actions
        if script.post_install:
            if reporter:
                await reporter("post_install", f"Running {len(script.post_install)} post-install actions...")
            # Post-install actions would be executed here (file copy, env set, etc.)
            for action in script.post_install:
                logger.info(f"Post-install: {action.action} ({action.src} → {action.dest})")

        # Step 10: Mark as installed
        async with get_session() as session:
            result = await session.execute(
                select(App).where(App.app_id == app_id)
            )
            app = result.scalar_one()
            app.status = AppStatus.INSTALLED

            log_entry = InstallLog(
                app_id=app_id,
                action="install_complete",
                result="success",
                log_text=f"Script install done. Deps: {len(script.dependencies)}, Registry: {len(script.registry)}",
            )
            session.add(log_entry)
            await session.commit()
            app_dict = app.to_dict()

        if reporter:
            await reporter("install_complete", f"{script.display_name} installed successfully!")

        logger.info(f"Script-based install complete: '{script.display_name}' ({app_id})")
        return app_dict

    async def get_install_plan(self, app_id: str) -> Optional[dict]:
        """
        Get a preview of what will be installed for a catalog app.
        Returns None if no script exists.
        """
        script = script_engine.load_script(app_id)
        if not script:
            return None
        return script.get_install_plan()

    # ─── Generic Install (Phase 1 — preserved) ──────────────────────

    async def install_app(
        self,
        display_name: str,
        exe_path: str,
        architecture: str = "win64",
        wine_version: str = "stable",
        reporter: Optional[ProgressReporter] = None,
        execution_engine: str = "wine",
    ) -> dict:
        """
        Install a Windows application (generic mode — no script).

        Args:
            display_name: Human-readable app name
            exe_path: Path to the .exe installer/executable
            architecture: 'win32' or 'win64'
            wine_version: Wine version to use
            reporter: Async callback for progress updates (stage, message)

        Returns:
            Dict with app info on success
        """
        # Validate exe exists
        if not Path(exe_path).exists():
            raise FileNotFoundError(f"Executable not found: {exe_path}")

        app_id = _sanitize_app_id(display_name)

        # Check if a script exists — auto-redirect to script-based install
        if script_engine.has_script(app_id):
            logger.info(f"Script found for '{app_id}' — using script-based install")
            return await self.install_from_script(app_id, exe_path, reporter)

        if reporter:
            await reporter("starting", f"Installing {display_name}...")

        # Step 1: Register app in database
        async with get_session() as session:
            existing = await session.execute(
                select(App).where(App.app_id == app_id)
            )
            if existing.scalar_one_or_none():
                raise RuntimeError(f"App '{app_id}' is already installed")

            app = App(
                app_id=app_id,
                display_name=display_name,
                exe_path=exe_path,
                architecture=architecture,
                wine_version=wine_version,
                status=AppStatus.INSTALLING,
                execution_engine=execution_engine,
            )
            session.add(app)
            await session.commit()

            log_entry = InstallLog(
                app_id=app_id,
                action="install_start",
                result="in_progress",
            )
            session.add(log_entry)
            await session.commit()

        if reporter:
            await reporter("registered", "App registered in database")
        # Step 2: Create Wine prefix
        try:
            prefix_path = await prefix_manager.create_prefix(
                app_id=app_id,
                architecture=architecture,
                wine_version=wine_version,
                reporter=reporter,
            )
        except Exception as e:
            await self._mark_failed(app_id, f"Prefix creation failed: {e}")
            raise

        # Step 3: Run the .exe via Wine
        if reporter:
            await reporter("running_exe", f"Running {Path(exe_path).name}...")

        try:
            if config.is_linux:
                await self._run_wine_exe(app_id, prefix_path, exe_path, wine_version)
            else:
                # Windows: run .exe natively (no Wine needed)
                await self._run_native_exe(app_id, exe_path)
        except Exception as e:
            await self._mark_failed(app_id, f"Execution failed: {e}")
            raise

        # Attempt to auto-discover installed executable shortcut (Linux only)
        if config.is_linux:
            discovered_path = self._auto_discover_executable(Path(prefix_path))
            if discovered_path:
                logger.info(f"Auto-discovered executable: {discovered_path}")
                exe_path = discovered_path

        # Step 4: Mark as installed
        async with get_session() as session:
            result = await session.execute(
                select(App).where(App.app_id == app_id)
            )
            app = result.scalar_one()
            app.status = AppStatus.INSTALLED
            if app.exe_path != exe_path:
                app.exe_path = exe_path

            log_entry = InstallLog(
                app_id=app_id,
                action="install_complete",
                result="success",
            )
            session.add(log_entry)
            await session.commit()

            app_dict = app.to_dict()

        if reporter:
            await reporter("install_complete", f"{display_name} installed successfully!")

        logger.info(f"Generic install complete: '{display_name}' ({app_id})")
        return app_dict

    async def update_app(self, app_id: str, updates: dict) -> dict:
        """
        Update an existing application's properties (like exe_path).
        """
        async with get_session() as session:
            result = await session.execute(
                select(App).where(App.app_id == app_id)
            )
            app = result.scalar_one_or_none()
            if not app:
                raise ValueError(f"App '{app_id}' not found")

            # Allow updating specific safe fields
            if "exe_path" in updates:
                app.exe_path = updates["exe_path"]
            if "display_name" in updates:
                app.display_name = updates["display_name"]
            if "execution_engine" in updates:
                app.execution_engine = updates["execution_engine"]

            await session.commit()
            return app.to_dict()

    def _auto_discover_executable(self, prefix_path: Path) -> Optional[str]:
        """
        Scan the Wine prefix for newly created .lnk files (Desktop & Start Menu)
        to automatically swap the Generic Installer path to the real application.
        """
        import re
        
        # We check public desktop and start menu
        search_dirs = [
            prefix_path / "drive_c" / "users" / "Public" / "Desktop",
            prefix_path / "drive_c" / "ProgramData" / "Microsoft" / "Windows" / "Start Menu" / "Programs",
        ]
        
        for s_dir in search_dirs:
            if not s_dir.exists():
                continue
                
            for lnk_file in s_dir.rglob("*.lnk"):
                try:
                    with open(lnk_file, "rb") as f:
                        data = f.read()
                        
                        # Very primitive extraction of ascii paths from a binary .lnk 
                        # Looking for C:\...
                        matches = re.findall(b'([C|c]:\\\\[^\\0]+?\\.exe)', data)
                        if matches:
                            win_path = matches[0].decode('utf-8', errors='ignore')
                            # Convert C:\ to drive_c/ and normalize slashes
                            rel_path = win_path[3:].replace('\\', '/')
                            full_path = prefix_path / "drive_c" / rel_path
                            if full_path.exists():
                                return str(full_path)
                except Exception as e:
                    logger.warning(f"Failed to parse shortcut {lnk_file}: {e}")
                    
        return None

    # ─── Shared Methods ──────────────────────────────────────────────

    def _get_log_file(self, app_id: str):
        """Open a log file for appending stderr output."""
        log_dir = config.data_dir / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        return open(log_dir / f"{app_id}.log", "a", encoding="utf-8")

    async def _run_wine_exe(
        self, app_id: str, prefix_path: str, exe_path: str, wine_version: str
    ) -> None:
        """Run a Windows executable using Wine. Linux only."""
        wine_binary = wine_manager.get_wine_binary(wine_version)
        env = {
            **os.environ,
            "WINEPREFIX": prefix_path,
            "WINEDEBUG": "-all",
        }

        log_file = self._get_log_file(app_id)

        proc = await asyncio.create_subprocess_exec(
            wine_binary, exe_path,
            env=env,
            stdout=asyncio.subprocess.PIPE,
            stderr=log_file,
        )
        stdout, _ = await proc.communicate()
        log_file.close()

        if proc.returncode != 0:
            logger.error(f"Wine execution failed for {app_id}")
            raise RuntimeError(f"Wine process exited with code {proc.returncode}")

    async def _run_native_exe(self, app_id: str, exe_path: str) -> None:
        """
        Run a Windows executable natively on Windows.
        Used during development/testing — no Wine needed.
        """
        logger.info(f"Running .exe natively on Windows: {exe_path}")
        
        log_file = self._get_log_file(app_id)
        
        proc = await asyncio.create_subprocess_exec(
            exe_path,
            stdout=asyncio.subprocess.PIPE,
            stderr=log_file,
        )
        stdout, _ = await proc.communicate()
        log_file.close()

        if proc.returncode != 0:
            logger.error(f"Native execution failed for {app_id}")
            raise RuntimeError(f"Process exited with code {proc.returncode}")
        logger.info(f"Native exe completed successfully: {exe_path}")

    async def launch_app(self, app_id: str, reporter: Optional[ProgressReporter] = None) -> dict:
        """Launch an already-installed app."""
        async with get_session() as session:
            result = await session.execute(
                select(App).where(App.app_id == app_id)
            )
            app = result.scalar_one_or_none()
            if not app:
                raise RuntimeError(f"App '{app_id}' not found")

            if app.status not in (AppStatus.INSTALLED, AppStatus.RUNNING):
                raise RuntimeError(f"App '{app_id}' is not in a launchable state (status: {app.status})")

            exe_path = app.exe_path
            wine_version = app.wine_version or "stable"
            prefix_path = await prefix_manager.get_prefix_path(app_id)

            if not prefix_path:
                raise RuntimeError(f"No prefix found for app '{app_id}'")

        if reporter:
            await reporter("launching", f"Launching {app_id}...")

        if app.execution_engine == "microvm":
            # Hand off entirely to VM Engine Sandbox (Phase 4)
            await vm_manager.run_app_in_vm(app_id, exe_path, reporter)
        else:
            # Launch Wine process natively (non-blocking)
            if config.is_linux:
                env = {
                    **os.environ,
                    "WINEPREFIX": prefix_path,
                    "WINEDEBUG": "-all",
                }
                wine_binary = wine_manager.get_wine_binary(wine_version)
                log_file = self._get_log_file(app_id)
                
                proc = await asyncio.create_subprocess_exec(
                    wine_binary, exe_path,
                    env=env,
                    stdout=asyncio.subprocess.DEVNULL,
                    stderr=log_file,
                )
                # Cannot close log_file here since proc runs in background. 
                # We must leave it open until process exits naturally.
                logger.info(f"Launched '{app_id}' with PID {proc.pid}")
            else:
                # Windows: launch .exe natively (non-blocking, detached)
                import subprocess as sp
                log_file = self._get_log_file(app_id)
                try:
                    proc = sp.Popen(
                        [exe_path],
                        stdout=sp.DEVNULL,
                        stderr=log_file,
                        creationflags=sp.DETACHED_PROCESS | sp.CREATE_NEW_PROCESS_GROUP,
                    )
                    logger.info(f"Launched '{app_id}' natively with PID {proc.pid}")
                except OSError as e:
                    logger.error(f"Failed to launch '{app_id}': {e}")
                    raise RuntimeError(f"Failed to launch {exe_path}: {e}")

        # Update last_launched
        async with get_session() as session:
            result = await session.execute(
                select(App).where(App.app_id == app_id)
            )
            app = result.scalar_one()
            app.last_launched = datetime.now(timezone.utc)
            app.status = AppStatus.RUNNING
            await session.commit()
            return app.to_dict()

    async def uninstall_app(self, app_id: str, reporter: Optional[ProgressReporter] = None) -> bool:
        """Uninstall an app: delete its prefix and remove from database."""
        if reporter:
            await reporter("uninstalling", f"Removing {app_id}...")

        await prefix_manager.delete_prefix(app_id)

        async with get_session() as session:
            result = await session.execute(
                select(App).where(App.app_id == app_id)
            )
            app = result.scalar_one_or_none()
            if app:
                await session.delete(app)
                await session.commit()
                logger.info(f"Uninstalled app '{app_id}'")
                return True

        return False

    async def list_apps(self) -> list[dict]:
        """List all installed apps."""
        async with get_session() as session:
            result = await session.execute(select(App))
            apps = result.scalars().all()
            return [a.to_dict() for a in apps]

    async def get_app(self, app_id: str) -> Optional[dict]:
        """Get details of a specific app."""
        async with get_session() as session:
            result = await session.execute(
                select(App).where(App.app_id == app_id)
            )
            app = result.scalar_one_or_none()
            return app.to_dict() if app else None

    async def _mark_failed(self, app_id: str, error_message: str) -> None:
        """Mark an app installation as failed."""
        async with get_session() as session:
            result = await session.execute(
                select(App).where(App.app_id == app_id)
            )
            app = result.scalar_one_or_none()
            if app:
                app.status = AppStatus.ERROR

            log_entry = InstallLog(
                app_id=app_id,
                action="install_failed",
                result="error",
                log_text=error_message,
            )
            session.add(log_entry)
            await session.commit()

        logger.error(f"Installation failed for '{app_id}': {error_message}")


# Singleton instance
installer = Installer()
