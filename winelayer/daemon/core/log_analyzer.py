"""
WineLayer — Log Analyzer Engine (Phase 3)

Parses Wine stderr logs and matches them against a JSON rule database
to suggest automatic fixes.
"""

import json
import logging
import re
from pathlib import Path
from pydantic import BaseModel

from daemon.config import config

logger = logging.getLogger(__name__)

class FixAction(BaseModel):
    action: str
    args: list[str] | dict[str, str]

class FixSuggestion(BaseModel):
    id: str
    description: str
    action: FixAction
    confidence: float

class LogAnalyzer:
    """Matches Wine logs against known error patterns to suggest fixes."""

    def __init__(self):
        # We assume compat-db is a sibling to daemon (managed by project structure)
        self._rules_file = Path(__file__).parent.parent.parent / "compat-db" / "error_rules.json"
        self._rules = []
        self.load_rules()

    def load_rules(self) -> int:
        """Loads the JSON rule database."""
        try:
            if self._rules_file.exists():
                with open(self._rules_file, "r", encoding="utf-8") as f:
                    self._rules = json.load(f)
                return len(self._rules)
        except Exception as e:
            logger.error(f"Failed to load error rules: {e}")
        return 0

    def get_log_path(self, app_id: str) -> Path:
        """Get the path to the app's log file."""
        log_dir = config.data_dir / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        return log_dir / f"{app_id}.log"

    def analyze_log(self, app_id: str) -> list[dict]:
        """
        Reads the log file for an app and returns a list of suggested fixes (dict).
        Sorted by confidence (highest first).
        """
        log_path = self.get_log_path(app_id)
        if not log_path.exists():
            return []

        try:
            # Read the last N bytes to avoid massive files
            with open(log_path, "r", encoding="utf-8", errors="replace") as f:
                f.seek(0, 2) # Go to end
                file_size = f.tell()
                read_size = min(file_size, 512 * 1024) # read last 512KB max
                f.seek(file_size - read_size)
                log_text = f.read()

            matches = []
            for rule in self._rules:
                if re.search(rule["pattern"], log_text, re.IGNORECASE):
                    suggestion = FixSuggestion(
                        id=rule["id"],
                        description=rule["description"],
                        action=FixAction(**rule["fix"]),
                        confidence=rule.get("confidence", 0.8)
                    )
                    matches.append(suggestion)

            # Sort by confidence descending
            matches = sorted(matches, key=lambda x: -x.confidence)
            return [m.model_dump() for m in matches]

        except Exception as e:
            logger.error(f"Error analyzing log for '{app_id}': {e}")
            return []

# Singleton instance
log_analyzer = LogAnalyzer()
