"""
WineLayer — Auto-Fix Suggester/Engine (Phase 3)

Responsible for taking a FixSuggestion and actually applying it
to an app's Wine prefix.
"""

import logging
from typing import Optional, Callable, Awaitable

from daemon.core.dependency_resolver import dependency_resolver
from daemon.core.registry_manager import registry_manager
from daemon.core.prefix_manager import prefix_manager

logger = logging.getLogger(__name__)

ProgressReporter = Callable[[str, str], Awaitable[None]]

class FixEngine:
    """Applies fixes (winetricks, registry) to a specific App Prefix."""

    async def apply_fix(
        self,
        app_id: str,
        fix_action: dict,
        reporter: Optional[ProgressReporter] = None
    ) -> bool:
        """
        Applies a fix action dict to the given app's environment.
        Args:
            app_id: The ID of the app to apply the fix to.
            fix_action: Dictionary containing 'action' and 'args'.
                        e.g., {'action': 'winetricks', 'args': ['vcrun2019']}
        """
        prefix_path = await prefix_manager.get_prefix_path(app_id)
        if not prefix_path:
            raise RuntimeError(f"No prefix found for {app_id}")

        action = fix_action.get("action")
        args = fix_action.get("args")

        if not action or not args:
            raise ValueError("Invalid fix_action format")

        try:
            if action == "winetricks":
                if not isinstance(args, list):
                    args = [args]
                
                if reporter:
                    await reporter("applying_fix", f"Installing dependencies: {', '.join(args)}")
                
                res = await dependency_resolver.resolve_and_install(
                    prefix_path, args, reporter
                )
                if res["failed"]:
                    raise RuntimeError(f"Failed to install: {res['failed']}")
                return True

            elif action == "registry":
                # args is a dict of registry changes e.g. {"windows_version": "win10"}
                if isinstance(args, dict) and "windows_version" in args:
                    win_ver = args["windows_version"]
                    if reporter:
                        await reporter("applying_fix", f"Setting Windows version to {win_ver}")
                    await registry_manager.set_windows_version(prefix_path, win_ver, reporter)
                    return True
                
                # Handling custom registry keys from fixes could be added here
                raise NotImplementedError(f"Registry format not completely supported: {args}")

            else:
                raise ValueError(f"Unknown fix action: {action}")

        except Exception as e:
            logger.error(f"Failed to apply fix '{fix_action}' to '{app_id}': {e}")
            raise

# Singleton instance
fix_engine = FixEngine()
