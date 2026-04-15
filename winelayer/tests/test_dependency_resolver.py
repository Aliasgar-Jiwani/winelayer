"""
Unit tests for the Dependency Resolver module.
"""

from pathlib import Path
import pytest
import sys

sys.path.insert(0, str(Path(__file__).parent.parent))


class TestTopologicalSort:
    """Tests for the topological sort algorithm."""

    def test_simple_deps(self):
        from daemon.core.dependency_resolver import topological_sort

        result = topological_sort(["corefonts"])
        assert "corefonts" in result

    def test_chain_deps(self):
        from daemon.core.dependency_resolver import topological_sort

        # dotnet48 → dotnet46 → dotnet45 → dotnet40
        result = topological_sort(["dotnet48"])
        idx_48 = result.index("dotnet48")
        idx_46 = result.index("dotnet46")
        idx_45 = result.index("dotnet45")
        idx_40 = result.index("dotnet40")

        # Must be installed in order: 40 → 45 → 46 → 48
        assert idx_40 < idx_45 < idx_46 < idx_48

    def test_multiple_independent_deps(self):
        from daemon.core.dependency_resolver import topological_sort

        result = topological_sort(["corefonts", "dxvk", "d3dx9"])
        assert len(result) == 3

    def test_shared_prerequisite(self):
        from daemon.core.dependency_resolver import topological_sort

        # vcrun2019 and vcrun2017 both depend on vcrun2015
        result = topological_sort(["vcrun2019", "vcrun2017"])
        idx_2015 = result.index("vcrun2015")
        idx_2019 = result.index("vcrun2019")
        idx_2017 = result.index("vcrun2017")

        assert idx_2015 < idx_2019
        assert idx_2015 < idx_2017

    def test_unknown_deps_appended(self):
        from daemon.core.dependency_resolver import topological_sort

        result = topological_sort(["corefonts", "custom_unknown_pkg"])
        assert "custom_unknown_pkg" in result

    def test_empty_deps(self):
        from daemon.core.dependency_resolver import topological_sort

        result = topological_sort([])
        assert result == []


class TestDependencyResolver:
    def test_singleton_exists(self):
        from daemon.core.dependency_resolver import dependency_resolver
        assert dependency_resolver is not None

    def test_dependency_graph_has_common_packages(self):
        from daemon.core.dependency_resolver import DEPENDENCY_GRAPH

        expected = ["vcrun2019", "dotnet48", "corefonts", "dxvk", "d3dx9"]
        for pkg in expected:
            assert pkg in DEPENDENCY_GRAPH, f"Missing package: {pkg}"
