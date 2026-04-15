"""
Unit tests for the Script Engine module.
"""

from pathlib import Path
import pytest
import sys

sys.path.insert(0, str(Path(__file__).parent.parent))


class TestAppScriptModel:
    """Tests for the AppScript Pydantic model."""

    def test_valid_script_creation(self):
        from daemon.core.script_engine import AppScript

        script = AppScript(
            app_id="test_app",
            display_name="Test App",
            architecture="win64",
            windows_version="win10",
            dependencies=["corefonts", "vcrun2019"],
        )
        assert script.app_id == "test_app"
        assert script.architecture == "win64"
        assert len(script.dependencies) == 2

    def test_invalid_architecture_raises(self):
        from daemon.core.script_engine import AppScript

        with pytest.raises(ValueError, match="Architecture"):
            AppScript(
                app_id="bad",
                display_name="Bad",
                architecture="arm64",
            )

    def test_invalid_windows_version_raises(self):
        from daemon.core.script_engine import AppScript

        with pytest.raises(ValueError, match="Invalid Windows version"):
            AppScript(
                app_id="bad",
                display_name="Bad",
                windows_version="vista",
            )

    def test_get_install_plan(self):
        from daemon.core.script_engine import AppScript, KnownIssue

        script = AppScript(
            app_id="test_app",
            display_name="Test App",
            dependencies=["vcrun2019", "dotnet48"],
            dxvk=True,
            known_issues=[
                KnownIssue(description="Test issue", severity="minor"),
            ],
        )
        plan = script.get_install_plan()

        assert plan["app_id"] == "test_app"
        assert plan["dxvk"] is True
        assert len(plan["dependencies"]) == 2
        assert len(plan["known_issues"]) == 1

    def test_to_dict(self):
        from daemon.core.script_engine import AppScript

        script = AppScript(
            app_id="test",
            display_name="Test",
        )
        d = script.to_dict()
        assert isinstance(d, dict)
        assert d["app_id"] == "test"
        assert "dependencies" in d


class TestRegistryEntry:
    def test_registry_entry_creation(self):
        from daemon.core.script_engine import RegistryEntry

        entry = RegistryEntry(
            key="HKEY_CURRENT_USER\\Software\\Test",
            value="Setting",
            data="1",
            type="REG_DWORD",
        )
        assert entry.key == "HKEY_CURRENT_USER\\Software\\Test"
        assert entry.type == "REG_DWORD"


class TestScriptEngine:
    def test_engine_initializes(self):
        from daemon.core.script_engine import script_engine

        assert script_engine is not None

    def test_list_scripts(self):
        from daemon.core.script_engine import script_engine

        scripts = script_engine.list_scripts()
        assert isinstance(scripts, list)
        assert "notepadplusplus" in scripts

    def test_load_notepadplusplus_script(self):
        from daemon.core.script_engine import script_engine

        script = script_engine.load_script("notepadplusplus")
        assert script is not None
        assert script.app_id == "notepadplusplus"
        assert script.display_name == "Notepad++"
        assert "corefonts" in script.dependencies

    def test_load_nonexistent_returns_none(self):
        from daemon.core.script_engine import script_engine

        result = script_engine.load_script("nonexistent_app_xyz")
        assert result is None

    def test_has_script(self):
        from daemon.core.script_engine import script_engine

        assert script_engine.has_script("notepadplusplus")
        assert not script_engine.has_script("nonexistent_xyz")

    def test_get_all_scripts(self):
        from daemon.core.script_engine import script_engine

        all_scripts = script_engine.get_all_scripts()
        assert len(all_scripts) >= 5  # We created 6 YAML files
