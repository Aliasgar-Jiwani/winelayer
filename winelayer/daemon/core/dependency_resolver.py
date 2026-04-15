"""
WineLayer — Dependency Resolver

Wraps Winetricks with dependency ordering (topological sort),
skip-if-installed detection, and download caching.

On Windows (development mode), winetricks calls are simulated.
"""

import asyncio
import logging
import os
from collections import defaultdict, deque
from pathlib import Path
from typing import Optional, Callable, Awaitable

from daemon.config import config
from daemon.core.wine_manager import wine_manager

logger = logging.getLogger(__name__)

ProgressReporter = Callable[[str, str], Awaitable[None]]


# ─── Dependency Graph ─────────────────────────────────────────────────
# Maps each package to its prerequisites (must be installed first).

DEPENDENCY_GRAPH: dict[str, list[str]] = {
    # Visual C++ Runtimes
    "vcrun6": [],
    "vcrun2005": [],
    "vcrun2008": [],
    "vcrun2010": [],
    "vcrun2012": [],
    "vcrun2013": [],
    "vcrun2015": [],
    "vcrun2017": ["vcrun2015"],
    "vcrun2019": ["vcrun2015"],
    "vcrun2022": ["vcrun2015"],

    # .NET Framework
    "dotnet35": [],
    "dotnet40": [],
    "dotnet45": ["dotnet40"],
    "dotnet46": ["dotnet45"],
    "dotnet48": ["dotnet46"],

    # DirectX
    "d3dx9": [],
    "d3dx10": [],
    "d3dx11_43": [],
    "d3dcompiler_47": [],
    "directplay": [],
    "directshow": [],
    "dxvk": [],
    "vkd3d": [],

    # Fonts
    "corefonts": [],
    "tahoma": [],
    "arial": [],

    # Common Libraries
    "gdiplus": [],
    "msxml3": [],
    "msxml6": [],
    "riched20": [],
    "riched30": [],
    "mfc42": [],
    "ole32": [],

    # Windows Components
    "wmp9": [],
    "wmp11": ["wmp9"],
    "ie8": [],
    "mdac28": [],
}


def topological_sort(deps: list[str]) -> list[str]:
    """
    Sort dependencies in topological order based on DEPENDENCY_GRAPH.
    Unknown packages are appended at the end in original order.
    """
    # Build subgraph for requested deps
    all_deps = set()
    queue = deque(deps)
    while queue:
        dep = queue.popleft()
        if dep in all_deps:
            continue
        all_deps.add(dep)
        for prereq in DEPENDENCY_GRAPH.get(dep, []):
            queue.append(prereq)

    # Kahn's algorithm for topological sort
    in_degree: dict[str, int] = defaultdict(int)
    adjacency: dict[str, list[str]] = defaultdict(list)

    for dep in all_deps:
        for prereq in DEPENDENCY_GRAPH.get(dep, []):
            if prereq in all_deps:
                adjacency[prereq].append(dep)
                in_degree[dep] += 1
        if dep not in in_degree:
            in_degree[dep] = 0

    result = []
    queue = deque(dep for dep in all_deps if in_degree[dep] == 0)

    while queue:
        node = queue.popleft()
        result.append(node)
        for neighbor in adjacency[node]:
            in_degree[neighbor] -= 1
            if in_degree[neighbor] == 0:
                queue.append(neighbor)

    # Append any unknown deps not in graph
    for dep in deps:
        if dep not in result:
            result.append(dep)

    return result


class DependencyResolver:
    """
    Resolves and installs Winetricks dependencies for a Wine prefix.
    """

    async def is_installed(self, prefix_path: str, dep: str) -> bool:
        """
        Check if a dependency is already installed in a prefix.
        Heuristic: checks for marker files or DLLs in the prefix.
        """
        prefix = Path(prefix_path)
        system32 = prefix / "drive_c" / "windows" / "system32"

        # Known marker files for common dependencies
        markers = {
            "vcrun2015": ["msvcp140.dll", "vcruntime140.dll"],
            "vcrun2017": ["msvcp140.dll", "vcruntime140.dll"],
            "vcrun2019": ["msvcp140.dll", "vcruntime140.dll"],
            "vcrun2022": ["msvcp140.dll", "vcruntime140.dll"],
            "dotnet40": ["mscoree.dll"],
            "dotnet45": ["mscoree.dll"],
            "dotnet48": ["mscoree.dll"],
            "corefonts": [],  # Check fonts dir
            "dxvk": ["d3d11.dll"],
            "d3dx9": ["d3dx9_43.dll"],
            "gdiplus": ["gdiplus.dll"],
        }

        if dep in markers and markers[dep]:
            return all(
                (system32 / dll).exists()
                for dll in markers[dep]
            )

        # Fallback: assume not installed
        return False

    async def install_dependency(
        self,
        prefix_path: str,
        dep: str,
        reporter: Optional[ProgressReporter] = None,
    ) -> bool:
        """
        Install a single dependency using winetricks.
        Returns True on success.
        """
        if reporter:
            await reporter("installing_dep", f"Installing {dep}...")

        if not config.is_linux:
            # Dev stub
            logger.info(f"Dev mode: Simulating winetricks install of '{dep}'")
            await asyncio.sleep(0.3)  # Simulate install time

            # Create stub marker files
            system32 = Path(prefix_path) / "drive_c" / "windows" / "system32"
            system32.mkdir(parents=True, exist_ok=True)

            markers = {
                "vcrun2015": ["msvcp140.dll", "vcruntime140.dll"],
                "vcrun2019": ["msvcp140.dll", "vcruntime140.dll"],
                "vcrun2022": ["msvcp140.dll", "vcruntime140.dll"],
                "corefonts": [],
                "dxvk": ["d3d11.dll"],
                "d3dx9": ["d3dx9_43.dll"],
            }
            for dll in markers.get(dep, []):
                (system32 / dll).touch()

            if reporter:
                await reporter("dep_installed", f"{dep} installed (dev mode)")
            return True

        # Real Winetricks install on Linux
        env = {
            **os.environ,
            "WINEPREFIX": prefix_path,
            "WINEDEBUG": "-all",
            "WINETRICKS_CACHE": str(config.winetricks_cache_dir),
        }

        wine_binary = wine_manager.get_wine_binary()
        if wine_binary != "wine":
            env["WINE"] = wine_binary

        try:
            proc = await asyncio.create_subprocess_exec(
                "winetricks", "-q", dep,
                env=env,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, stderr = await proc.communicate()

            if proc.returncode != 0:
                error_text = stderr.decode()[:500]
                logger.error(f"Winetricks install '{dep}' failed: {error_text}")
                if reporter:
                    await reporter("dep_failed", f"Failed to install {dep}")
                return False

            if reporter:
                await reporter("dep_installed", f"{dep} installed successfully")
            logger.info(f"Winetricks installed '{dep}' in {prefix_path}")
            return True

        except FileNotFoundError:
            logger.error("Winetricks not found. Install it: sudo apt install winetricks")
            if reporter:
                await reporter("dep_failed", "Winetricks not found on system")
            return False

    async def resolve_and_install(
        self,
        prefix_path: str,
        deps: list[str],
        reporter: Optional[ProgressReporter] = None,
    ) -> dict:
        """
        Resolve dependency order, skip installed, and install remaining.

        Returns:
            Dict with 'installed', 'skipped', 'failed' lists.
        """
        if not deps:
            return {"installed": [], "skipped": [], "failed": []}

        # Step 1: Topological sort
        ordered = topological_sort(deps)
        total = len(ordered)
        logger.info(f"Resolved {total} dependencies (ordered): {ordered}")

        if reporter:
            await reporter("resolving_deps", f"Resolved {total} dependencies")

        installed = []
        skipped = []
        failed = []

        # Step 2: Install each dependency
        for i, dep in enumerate(ordered, 1):
            if reporter:
                await reporter(
                    "dep_progress",
                    f"[{i}/{total}] Processing {dep}..."
                )

            # Check if already installed
            if await self.is_installed(prefix_path, dep):
                logger.info(f"Dependency '{dep}' already installed — skipping")
                skipped.append(dep)
                if reporter:
                    await reporter("dep_skipped", f"{dep} already installed")
                continue

            # Install
            success = await self.install_dependency(prefix_path, dep, reporter)
            if success:
                installed.append(dep)
            else:
                failed.append(dep)

        result = {
            "installed": installed,
            "skipped": skipped,
            "failed": failed,
        }
        logger.info(f"Dependency resolution complete: {result}")
        return result


# Singleton instance
dependency_resolver = DependencyResolver()
