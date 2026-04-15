"""
WineLayer — YAML Script Engine

Parses and validates per-app YAML configuration scripts using Pydantic models.
Scripts define the full installation recipe for a Windows app: dependencies,
registry tweaks, Wine version, post-install actions, and known issues.
"""

import json
import logging
from pathlib import Path
from typing import Optional

import yaml
from pydantic import BaseModel, Field, field_validator

from daemon.config import config

logger = logging.getLogger(__name__)


# ─── Pydantic Models ──────────────────────────────────────────────────

class RegistryEntry(BaseModel):
    """A Windows registry modification."""
    key: str
    value: str
    data: str
    type: str = "REG_SZ"


class PostInstallAction(BaseModel):
    """An action to run after the main install completes."""
    action: str  # copy_file, delete_file, run_exe, set_env
    src: Optional[str] = None
    dest: Optional[str] = None
    command: Optional[str] = None


class KnownIssue(BaseModel):
    """A documented known issue with a workaround."""
    description: str
    fix: Optional[str] = None
    severity: str = "minor"  # minor, moderate, major, critical


class AppScript(BaseModel):
    """
    Complete installation recipe for a Windows application.
    Validated from a YAML config file in compat-db/scripts/.
    """
    app_id: str
    display_name: str
    version_tested: str = ""
    wine_version: str = "stable"
    windows_version: str = "win10"
    architecture: str = "win64"

    dependencies: list[str] = Field(default_factory=list)
    registry: list[RegistryEntry] = Field(default_factory=list)

    dxvk: bool = False
    esync: bool = False
    fsync: bool = False

    post_install: list[PostInstallAction] = Field(default_factory=list)
    known_issues: list[KnownIssue] = Field(default_factory=list)

    status: str = "unknown"
    last_verified: str = ""
    contributor: str = ""

    @field_validator("architecture")
    @classmethod
    def validate_architecture(cls, v: str) -> str:
        if v not in ("win32", "win64"):
            raise ValueError(f"Architecture must be 'win32' or 'win64', got '{v}'")
        return v

    @field_validator("windows_version")
    @classmethod
    def validate_windows_version(cls, v: str) -> str:
        valid = {"win7", "win8", "win81", "win10", "win11", "winxp", "win2k"}
        if v not in valid:
            raise ValueError(f"Invalid Windows version '{v}'. Valid: {valid}")
        return v

    def to_dict(self) -> dict:
        return self.model_dump()

    def get_install_plan(self) -> dict:
        """Return a human-readable install plan for the GUI."""
        return {
            "app_id": self.app_id,
            "display_name": self.display_name,
            "wine_version": self.wine_version,
            "windows_version": self.windows_version,
            "architecture": self.architecture,
            "dependencies": self.dependencies,
            "registry_count": len(self.registry),
            "post_install_count": len(self.post_install),
            "dxvk": self.dxvk,
            "esync": self.esync,
            "known_issues": [
                {"description": i.description, "severity": i.severity}
                for i in self.known_issues
            ],
        }


# ─── Script Engine ────────────────────────────────────────────────────

class ScriptEngine:
    """
    Loads and validates per-app YAML configs from the compat-db.
    """

    def __init__(self):
        # Resolve scripts directory relative to the project root
        self._scripts_dir = self._find_scripts_dir()
        self._cache: dict[str, AppScript] = {}

    def _find_scripts_dir(self) -> Path:
        """Find the compat-db/scripts/ directory."""
        # Try relative to the daemon package
        candidates = [
            Path(__file__).parent.parent.parent / "compat-db" / "scripts",
            config.data_dir / "scripts",
        ]
        for path in candidates:
            if path.exists():
                return path

        # Fallback: create in data dir
        default = config.data_dir / "scripts"
        default.mkdir(parents=True, exist_ok=True)
        return default

    def load_script(self, app_id: str) -> Optional[AppScript]:
        """
        Load and validate a YAML script for the given app_id.
        Returns None if the script doesn't exist.
        """
        # Check cache first
        if app_id in self._cache:
            return self._cache[app_id]

        script_path = self._scripts_dir / f"{app_id}.yaml"
        if not script_path.exists():
            # Also try .yml extension
            script_path = self._scripts_dir / f"{app_id}.yml"
            if not script_path.exists():
                logger.debug(f"No script found for '{app_id}'")
                return None

        try:
            with open(script_path, "r", encoding="utf-8") as f:
                raw = yaml.safe_load(f)

            if not isinstance(raw, dict):
                logger.error(f"Script '{app_id}' is not a valid YAML dict")
                return None

            script = AppScript(**raw)
            self._cache[app_id] = script
            logger.info(f"Loaded script for '{app_id}': {len(script.dependencies)} deps, "
                        f"{len(script.registry)} registry entries")
            return script

        except Exception as e:
            logger.error(f"Failed to load script '{app_id}': {e}")
            return None

    def list_scripts(self) -> list[str]:
        """List all available script app_ids."""
        if not self._scripts_dir.exists():
            return []

        scripts = []
        for f in self._scripts_dir.iterdir():
            if f.suffix in (".yaml", ".yml"):
                scripts.append(f.stem)
        return sorted(scripts)

    def get_all_scripts(self) -> list[AppScript]:
        """Load and return all available scripts."""
        result = []
        for app_id in self.list_scripts():
            script = self.load_script(app_id)
            if script:
                result.append(script)
        return result

    def has_script(self, app_id: str) -> bool:
        """Check if a script exists for the given app_id."""
        return (
            (self._scripts_dir / f"{app_id}.yaml").exists()
            or (self._scripts_dir / f"{app_id}.yml").exists()
        )

    def clear_cache(self) -> None:
        """Clear the script cache."""
        self._cache.clear()


# Singleton instance
script_engine = ScriptEngine()
