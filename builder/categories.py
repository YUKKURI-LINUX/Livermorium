# -*- coding: utf-8 -*-
"""
Utility for loading categories.json and providing the following:

- nodes:
    Recursively resolves 'includes' / 'deps' and collects 'real file names'
    by glob-expanding 'patterns' on the scripts_dir.
- prelude:
    Provides 'always_first' as is (with normalization only).
- finalizers:
    Provides 'always' / 'on_failure' / 'on_success' as is (with normalization only).

* Note: Execution orchestration (sequential execution, branching on success/failure,
   chroot detection, etc.) is handled by cl_main.py / executor.py.
"""

from __future__ import annotations
import json
import re
from pathlib import Path
from typing import Dict, List, Set


class Categories:
    def __init__(self, data: Dict):
        # ---------- nodes ----------
        self.nodes: Dict = data.get("nodes", {}) or {}

        # ---------- prelude ----------
        pr = data.get("prelude", {}) or {}
        af = pr.get("always_first", []) or []
        self._prelude_always_first: List[str] = [
            str(x) for x in af if isinstance(x, str) and x.strip()
        ]

        # ---------- finalizers ----------
        fi = data.get("finalizers", {}) or {}
        self._finalizers = {
            "always": [
                str(x) for x in (fi.get("always", []) or []) if isinstance(x, str) and x.strip()
            ],
            "on_failure": [
                str(x) for x in (fi.get("on_failure", []) or []) if isinstance(x, str) and x.strip()
            ],
            "on_success": [
                str(x) for x in (fi.get("on_success", []) or []) if isinstance(x, str) and x.strip()
            ],
        }

    # ===== relaxed JSON loader =====
    @classmethod
    def load(cls, path: Path) -> "Categories":
        """
        Loads categories.json.
        - Removes // line comments and /* block */ comments.
        - Allows trailing commas (lightweight JSON5 style).
        """
        raw = path.read_text(encoding="utf-8")
        # block comments
        raw = re.sub(r"/\*.*?\*/", "", raw, flags=re.S)
        # line comments
        raw = re.sub(r"(^|\s)//.*", "", raw)
        # trailing commas
        raw = re.sub(r",(\s*[}\]])", r"\1", raw)
        data = json.loads(raw)
        return cls(data)

    # ===== public API =====
    def resolve_nodes(
        self,
        tokens: List[str],
        scripts_dir: Path,
        *,
        allow_deprecated: bool = False,
        allow_deprecated_nodes: Set[str] | None = None,
    ) -> List[str]:
        """
        Expands tokens (node names or file patterns) and returns a sorted list of real file names.
        - Node name: Recursively resolves includes/deps and collects real file names by glob-expanding
          patterns on the scripts_dir.
        - Pattern: Directly matches files using scripts_dir.glob().
        """
        if allow_deprecated_nodes is None:
            allow_deprecated_nodes = set()

        results: Set[str] = set()
        for raw in tokens:
            token = (raw or "").strip()
            if not token:
                continue

            if token in self.nodes:
                self._expand_node(
                    token,
                    scripts_dir,
                    results,
                    seen=set(),
                    allow_deprecated=allow_deprecated,
                    allow_deprecated_nodes=allow_deprecated_nodes,
                )
            else:
                # Treat as a file pattern
                for f in scripts_dir.glob(token):
                    if f.is_file():
                        results.add(f.name)

        return sorted(results)

    def get_prelude_always_first(self) -> List[str]:
        """Returns prelude.always_first (normalized raw data)."""
        return list(self._prelude_always_first)

    def get_finalizers(self) -> Dict[str, List[str]]:
        """Returns finalizers (normalized raw data)."""
        return {
            "always": list(self._finalizers.get("always", [])),
            "on_failure": list(self._finalizers.get("on_failure", [])),
            "on_success": list(self._finalizers.get("on_success", [])),
        }

    # ===== internal =====
    def _expand_node(
        self,
        name: str,
        scripts_dir: Path,
        results: Set[str],
        seen: Set[str],
        *,
        allow_deprecated: bool,
        allow_deprecated_nodes: Set[str],
    ) -> None:
        """Expands node 'name' and adds real file names to 'results'."""
        if name in seen:
            # Silently ignore circular dependencies (can be changed to raise an exception if needed)
            return
        seen.add(name)

        node = self.nodes.get(name)
        if not node:
            return

        # Deprecated check
        if node.get("deprecated", False):
            if not (allow_deprecated or name in allow_deprecated_nodes):
                raise RuntimeError(f"Deprecated node '{name}' was included but not allowed")

        # Glob-expand and collect 'patterns' of the current node on scripts_dir
        for pat in node.get("patterns", []) or []:
            if isinstance(pat, str) and pat.strip():
                for f in scripts_dir.glob(pat.strip()):
                    if f.is_file():
                        results.add(f.name)

        # Recurse on 'includes'
        for child in node.get("includes", []) or []:
            if isinstance(child, str) and child.strip():
                self._expand_node(
                    child.strip(),
                    scripts_dir,
                    results,
                    seen,
                    allow_deprecated=allow_deprecated,
                    allow_deprecated_nodes=allow_deprecated_nodes,
                )

        # Recurse on 'deps'
        for dep in node.get("deps", []) or []:
            if isinstance(dep, str) and dep.strip():
                self._expand_node(
                    dep.strip(),
                    scripts_dir,
                    results,
                    seen,
                    allow_deprecated=allow_deprecated,
                    allow_deprecated_nodes=allow_deprecated_nodes,
                )