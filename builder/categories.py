# -*- coding: utf-8 -*-
"""
categories.json を読み込み、以下を提供するユーティリティ:

- nodes:
    includes / deps を再帰解決し、patterns を scripts_dir 上で
    「実在ファイル名」へ glob 展開して収集する。
- prelude:
    always_first をそのまま提供（正規化のみ）。
- finalizers:
    always / on_failure / on_success をそのまま提供（正規化のみ）。

※ 実行オーケストレーション（番号順の実行、成功/失敗での分岐、
   chroot 判定など）は cl_main.py / executor.py 側で行います。
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
        categories.json を読み込む。
        - // line コメント、/* block */ コメントを除去
        - 末尾カンマも許容（軽量 JSON5 風）
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
        トークン（ノード名 or ファイルパターン）を展開し、実在ファイル名の昇順リストを返す。
        - ノード名: includes/deps を再帰解決し、patterns を scripts_dir 上で glob 展開して収集
        - パターン: scripts_dir.glob() で直接マッチ
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
                # ファイルパターンとして扱う
                for f in scripts_dir.glob(token):
                    if f.is_file():
                        results.add(f.name)

        return sorted(results)

    def get_prelude_always_first(self) -> List[str]:
        """prelude.always_first（正規化済みの生データ）を返す。"""
        return list(self._prelude_always_first)

    def get_finalizers(self) -> Dict[str, List[str]]:
        """finalizers（正規化済みの生データ）を返す。"""
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
        """ノード name を展開して results に実在ファイル名を追加する。"""
        if name in seen:
            # 循環参照は静かに無視（必要なら例外に変更可）
            return
        seen.add(name)

        node = self.nodes.get(name)
        if not node:
            return

        # deprecated 判定
        if node.get("deprecated", False):
            if not (allow_deprecated or name in allow_deprecated_nodes):
                raise RuntimeError(f"Deprecated node '{name}' was included but not allowed")

        # 自ノードの patterns を scripts_dir 上で glob 展開して収集
        for pat in node.get("patterns", []) or []:
            if isinstance(pat, str) and pat.strip():
                for f in scripts_dir.glob(pat.strip()):
                    if f.is_file():
                        results.add(f.name)

        # includes を再帰
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

        # deps を再帰
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
