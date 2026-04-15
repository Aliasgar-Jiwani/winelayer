"""
WineLayer — Catalog Manager

Loads, searches, and filters the compat-db/apps.json app catalog.
Provides fuzzy search and category filtering for the GUI's browse screen.
"""

import json
import logging
from pathlib import Path
from typing import Optional

from daemon.config import config

logger = logging.getLogger(__name__)


class CatalogEntry:
    """A single entry in the app compatibility catalog."""

    def __init__(self, app_id: str, data: dict):
        self.app_id = app_id
        self.display_name = data.get("display_name", app_id)
        self.status = data.get("status", "unknown")
        self.report_count = data.get("report_count", 0)
        self.last_updated = data.get("last_updated", "")
        self.config_file = data.get("config_file", "")
        self.category = data.get("category", "other")
        self.description = data.get("description", "")
        self.website = data.get("website", "")
        self.icon_url = data.get("icon_url", "")
        self.size_estimate = data.get("size_estimate", "")
        self.has_script = bool(self.config_file)

    def to_dict(self) -> dict:
        return {
            "app_id": self.app_id,
            "display_name": self.display_name,
            "status": self.status,
            "report_count": self.report_count,
            "last_updated": self.last_updated,
            "config_file": self.config_file,
            "category": self.category,
            "description": self.description,
            "website": self.website,
            "icon_url": self.icon_url,
            "size_estimate": self.size_estimate,
            "has_script": self.has_script,
        }

    def matches_query(self, query: str) -> bool:
        """Fuzzy search: checks if query appears in name, category, or app_id."""
        q = query.lower()
        return (
            q in self.display_name.lower()
            or q in self.app_id.lower()
            or q in self.category.lower()
            or q in self.description.lower()
        )


class CatalogManager:
    """
    Manages the app compatibility catalog from compat-db/apps.json.
    """

    def __init__(self):
        self._catalog: dict[str, CatalogEntry] = {}
        self._loaded = False

    def _find_catalog_file(self) -> Optional[Path]:
        """Find the apps.json catalog file."""
        candidates = [
            Path(__file__).parent.parent.parent / "compat-db" / "apps.json",
            config.data_dir / "compat-db" / "apps.json",
        ]
        for path in candidates:
            if path.exists():
                return path
        return None

    def load_catalog(self) -> int:
        """
        Load the catalog from apps.json.
        Returns the number of entries loaded.
        """
        catalog_path = self._find_catalog_file()
        if not catalog_path:
            logger.warning("Catalog file not found")
            return 0

        try:
            with open(catalog_path, "r", encoding="utf-8") as f:
                raw = json.load(f)

            self._catalog = {
                app_id: CatalogEntry(app_id, data)
                for app_id, data in raw.items()
            }
            self._loaded = True
            logger.info(f"Loaded catalog: {len(self._catalog)} apps")
            return len(self._catalog)

        except Exception as e:
            logger.error(f"Failed to load catalog: {e}")
            return 0

    def search(self, query: str) -> list[dict]:
        """
        Fuzzy search the catalog by query string.
        Returns matching entries sorted by relevance (name match first, then report count).
        """
        if not self._loaded:
            self.load_catalog()

        if not query.strip():
            return self.get_all()

        results = []
        q = query.lower()

        for entry in self._catalog.values():
            if entry.matches_query(query):
                # Score: exact name match > starts with > contains
                score = 0
                if entry.display_name.lower() == q:
                    score = 100
                elif entry.display_name.lower().startswith(q):
                    score = 50
                else:
                    score = 10
                score += entry.report_count / 10  # Boost popular apps
                results.append((score, entry))

        results.sort(key=lambda x: -x[0])
        return [entry.to_dict() for _, entry in results]

    def get_entry(self, app_id: str) -> Optional[dict]:
        """Get a single catalog entry by app_id."""
        if not self._loaded:
            self.load_catalog()

        entry = self._catalog.get(app_id)
        return entry.to_dict() if entry else None

    def get_all(self) -> list[dict]:
        """Get all catalog entries."""
        if not self._loaded:
            self.load_catalog()

        entries = sorted(
            self._catalog.values(),
            key=lambda e: -e.report_count,
        )
        return [e.to_dict() for e in entries]

    def list_categories(self) -> list[str]:
        """Get unique category list sorted alphabetically."""
        if not self._loaded:
            self.load_catalog()

        categories = set(e.category for e in self._catalog.values())
        return sorted(categories)

    def filter_by_category(self, category: str) -> list[dict]:
        """Filter catalog entries by category."""
        if not self._loaded:
            self.load_catalog()

        entries = [
            e for e in self._catalog.values()
            if e.category == category
        ]
        entries.sort(key=lambda e: -e.report_count)
        return [e.to_dict() for e in entries]

    def filter_by_status(self, status: str) -> list[dict]:
        """Filter catalog entries by compatibility status."""
        if not self._loaded:
            self.load_catalog()

        entries = [
            e for e in self._catalog.values()
            if e.status == status
        ]
        entries.sort(key=lambda e: -e.report_count)
        return [e.to_dict() for e in entries]

    @property
    def count(self) -> int:
        return len(self._catalog)

    async def sync_compat_db(self) -> bool:
        """
        Mock synchronizing the compatibility database from GitHub.
        Simulates network latency and then reloads from the local store.
        """
        import asyncio
        logger.info("Syncing compatibility database from community repository...")
        # Simulating API request to GitHub raw content
        await asyncio.sleep(1.5)
        self.load_catalog()
        logger.info("Database sync complete.")
        return True

    async def submit_report(self, app_id: str, status: str, description: str) -> bool:
        """
        Mock submitting a user report to GitHub Issues.
        """
        import asyncio
        logger.info(f"Submitting user report for '{app_id}' (status: {status})...")
        # Simulating API POST request to GitHub issues
        await asyncio.sleep(1.0)
        logger.info(f"Mock report submitted successfully. Description len: {len(description)}")
        return True


# Singleton instance
catalog_manager = CatalogManager()
