"""
Unit tests for the Catalog Manager module.
"""

from pathlib import Path
import pytest
import sys

sys.path.insert(0, str(Path(__file__).parent.parent))


class TestCatalogManager:
    """Tests for the CatalogManager."""

    def test_load_catalog(self):
        from daemon.core.catalog_manager import catalog_manager

        count = catalog_manager.load_catalog()
        assert count == 15  # We have 15 entries in apps.json

    def test_get_all(self):
        from daemon.core.catalog_manager import catalog_manager

        entries = catalog_manager.get_all()
        assert len(entries) == 15
        assert all(isinstance(e, dict) for e in entries)

    def test_search_by_name(self):
        from daemon.core.catalog_manager import catalog_manager

        results = catalog_manager.search("Notepad")
        assert len(results) >= 1
        assert results[0]["app_id"] == "notepadplusplus"

    def test_search_by_category(self):
        from daemon.core.catalog_manager import catalog_manager

        results = catalog_manager.search("media")
        assert len(results) >= 1

    def test_search_empty_returns_all(self):
        from daemon.core.catalog_manager import catalog_manager

        results = catalog_manager.search("")
        assert len(results) == 15

    def test_get_entry(self):
        from daemon.core.catalog_manager import catalog_manager

        entry = catalog_manager.get_entry("vlc")
        assert entry is not None
        assert entry["display_name"] == "VLC Media Player"

    def test_get_nonexistent_returns_none(self):
        from daemon.core.catalog_manager import catalog_manager

        entry = catalog_manager.get_entry("nonexistent_xyz")
        assert entry is None

    def test_list_categories(self):
        from daemon.core.catalog_manager import catalog_manager

        cats = catalog_manager.list_categories()
        assert "media" in cats
        assert "utility" in cats
        assert "graphics" in cats

    def test_filter_by_category(self):
        from daemon.core.catalog_manager import catalog_manager

        media = catalog_manager.filter_by_category("media")
        assert len(media) >= 3  # VLC, foobar2000, MPC-HC, Winamp, Audacity
        assert all(e["category"] == "media" for e in media)

    def test_filter_by_status(self):
        from daemon.core.catalog_manager import catalog_manager

        working = catalog_manager.filter_by_status("working")
        assert len(working) >= 8
        assert all(e["status"] == "working" for e in working)

    def test_count_property(self):
        from daemon.core.catalog_manager import catalog_manager

        assert catalog_manager.count == 15


class TestCatalogEntry:
    def test_matches_query(self):
        from daemon.core.catalog_manager import CatalogEntry

        entry = CatalogEntry("test", {
            "display_name": "Test App",
            "category": "utility",
            "description": "A test application",
        })
        assert entry.matches_query("test")
        assert entry.matches_query("util")
        assert not entry.matches_query("zzzzz")

    def test_to_dict(self):
        from daemon.core.catalog_manager import CatalogEntry

        entry = CatalogEntry("test", {"display_name": "Test"})
        d = entry.to_dict()
        assert d["app_id"] == "test"
        assert d["display_name"] == "Test"
