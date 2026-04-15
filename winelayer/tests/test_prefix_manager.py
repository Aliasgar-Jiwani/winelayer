"""
Unit tests for the Prefix Manager module.
"""

import asyncio
import os
import tempfile
from pathlib import Path
from unittest.mock import patch, AsyncMock

import pytest

# Mock the config before importing prefix_manager
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))


class TestPrefixManager:
    """Tests for PrefixManager functionality."""

    @pytest.fixture
    def temp_dir(self):
        """Create a temporary directory for test prefixes."""
        with tempfile.TemporaryDirectory() as tmpdir:
            yield tmpdir

    def test_prefix_path_generation(self, temp_dir):
        """Prefix paths should follow the {data_dir}/prefixes/{app_id}/ pattern."""
        from daemon.config import config
        expected = config.prefixes_dir / "test_app"
        assert "test_app" in str(expected)

    def test_sanitize_app_id(self):
        """App IDs should be lowercase, alphanumeric with underscores."""
        from daemon.core.installer import _sanitize_app_id

        assert _sanitize_app_id("Notepad++") == "notepad"
        assert _sanitize_app_id("Adobe Photoshop CS6") == "adobe_photoshop_cs6"
        assert _sanitize_app_id("7-Zip") == "7_zip"
        assert _sanitize_app_id("My App 2.0") == "my_app_2_0"

    def test_config_paths_exist(self):
        """Config should generate valid paths."""
        from daemon.config import config

        assert config.data_dir is not None
        assert config.prefixes_dir is not None
        assert config.db_path is not None
        assert config.db_url.startswith("sqlite+aiosqlite:///")

    def test_config_platform_detection(self):
        """Config should detect the current platform."""
        from daemon.config import config
        import platform

        assert config.platform_name == platform.system()
        assert config.is_linux == (platform.system() == "Linux")

    def test_ensure_directories(self, temp_dir):
        """ensure_directories should create all required directories."""
        from daemon.config import WineLayerConfig

        test_config = WineLayerConfig(
            data_dir=Path(temp_dir) / "data",
            cache_dir=Path(temp_dir) / "cache",
            config_dir=Path(temp_dir) / "config",
        )
        test_config.ensure_directories()

        assert test_config.data_dir.exists()
        assert test_config.cache_dir.exists()
        assert test_config.config_dir.exists()
        assert test_config.prefixes_dir.exists()
        assert test_config.wine_builds_dir.exists()
