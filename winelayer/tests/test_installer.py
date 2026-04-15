"""
Unit tests for the Installer module.
"""

import tempfile
from pathlib import Path

import pytest

import sys
sys.path.insert(0, str(Path(__file__).parent.parent))


class TestInstaller:
    """Tests for the Installer and its utilities."""

    def test_sanitize_simple_name(self):
        """Simple app names should sanitize correctly."""
        from daemon.core.installer import _sanitize_app_id

        assert _sanitize_app_id("VLC") == "vlc"
        assert _sanitize_app_id("notepad") == "notepad"

    def test_sanitize_with_special_chars(self):
        """Special characters should be replaced with underscores."""
        from daemon.core.installer import _sanitize_app_id

        assert _sanitize_app_id("Paint.NET") == "paint_net"
        assert _sanitize_app_id("WinRAR 6.0") == "winrar_6_0"

    def test_sanitize_strips_leading_trailing(self):
        """Leading and trailing underscores should be stripped."""
        from daemon.core.installer import _sanitize_app_id

        result = _sanitize_app_id("  My App  ")
        assert not result.startswith("_")
        assert not result.endswith("_")

    def test_sanitize_collapses_underscores(self):
        """Multiple consecutive underscores should collapse to one."""
        from daemon.core.installer import _sanitize_app_id

        result = _sanitize_app_id("My---App___Here")
        assert "__" not in result

    def test_app_status_constants(self):
        """AppStatus should define all expected lifecycle states."""
        from daemon.db.models import AppStatus

        assert AppStatus.PENDING == "pending"
        assert AppStatus.INSTALLING == "installing"
        assert AppStatus.INSTALLED == "installed"
        assert AppStatus.RUNNING == "running"
        assert AppStatus.ERROR == "error"
        assert AppStatus.UNINSTALLED == "uninstalled"

    def test_app_model_to_dict(self):
        """App.to_dict() should produce a complete dictionary."""
        from daemon.db.models import App

        app = App(
            id=1,
            app_id="test_app",
            display_name="Test App",
            exe_path="/path/to/test.exe",
            architecture="win64",
            wine_version="stable",
            status="installed",
        )

        d = app.to_dict()
        assert d["app_id"] == "test_app"
        assert d["display_name"] == "Test App"
        assert d["exe_path"] == "/path/to/test.exe"
        assert d["architecture"] == "win64"
        assert d["status"] == "installed"
