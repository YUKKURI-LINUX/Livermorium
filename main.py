#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os, sys, json, shlex, shutil, signal, re
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gio", "2.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Pango", "1.0")
from gi.repository import Gtk, Gio, GLib, Gdk, Pango

APP_ID = "dev.livermorium.gui"
HERE = Path(__file__).resolve().parent

# ---- builder/categories.py を使う ----
BUILDER_DIR = HERE / "builder"
sys.path.insert(0, str(BUILDER_DIR))
from categories import Categories  # ./builder/categories.py

# ---- パス定義 ----
UI_FILE  = HERE / "gui" / "ui" / "main.ui"
CSS_FILE = HERE / "gui" / "ui" / "style.css"
CL_MAIN  = HERE / "cl_main.py"
PROFILES_DIR = HERE / "profiles"

# ---- chroot 範囲（execution.json が無い/読めない時のフォールバック）----
DEFAULT_CHROOT_MIN = 50
DEFAULT_CHROOT_MAX = 79

# ---- ログ設定（TextView版）----
LOG_MAX_LINES = 20000  # TextView の最大行数（超えたら先頭から削除）

# ---------- utils ----------
def load_json(path: Path) -> Any:
    try:
        if path.exists():
            return json.loads(path.read_text(encoding="utf-8"))
    except Exception as e:
        return {"_error": f"{e}"}
    return None

def list_profiles() -> List[str]:
    if not PROFILES_DIR.exists():
        return []
    return sorted([p.name for p in PROFILES_DIR.iterdir() if p.is_dir()])

def profile_paths(profile: str) -> Dict[str, Path]:
    base = PROFILES_DIR / profile
    return {
        "base": base,
        "packages": base / "packages.json",
        "flatpak": base / "flatpak.json",
        "execution": base / "execution.json",
        "categories": base / "categories.json",
        "scripts": base / "scripts",
        "config": base / "config.json",
    }

def which(cmd: str) -> Optional[str]:
    return shutil.which(cmd)

# ---------- UI ----------
class MainWindow(Gtk.ApplicationWindow):
    def __init__(self, app: Gtk.Application):
        super().__init__(application=app)
        self.set_title("Livermorium GUI")
        self.set_default_size(840, 620)

        # UIロード
        self.builder = Gtk.Builder.new_from_file(str(UI_FILE))
        root = self.builder.get_object("root")
        self.set_child(root)

        # CSS
        try:
            if CSS_FILE.exists():
                css = Gtk.CssProvider()
                css.load_from_path(str(CSS_FILE))
                Gtk.StyleContext.add_provider_for_display(
                    Gdk.Display.get_default(),
                    css,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                )
        except Exception as e:
            print(f"[WARN] CSS load failed: {e}", file=sys.stderr)

        # ヘッダ
        self.profile_combo: Gtk.ComboBoxText = self.builder.get_object("profile_combo")
        self.btn_reload: Gtk.Button = self.builder.get_object("refresh_profiles_btn")
        self.btn_run: Gtk.Button = self.builder.get_object("run_button")
        self.progress: Gtk.ProgressBar = self.builder.get_object("progress")
        self.stack: Gtk.Stack = self.builder.get_object("stack")

        # Packages / Flatpak
        self.pkg_list: Gtk.ListBox = self.builder.get_object("packages_list")
        self.pkg_empty: Gtk.Label = self.builder.get_object("packages_empty_label")
        self.fp_list: Gtk.ListBox = self.builder.get_object("flatpak_list")
        self.fp_empty: Gtk.Label = self.builder.get_object("flatpak_empty_label")

        # 実行制御（categories + files）
        self.exec_cat_search: Gtk.SearchEntry = self.builder.get_object("exec_cat_search")
        self.exec_files_search: Gtk.SearchEntry = self.builder.get_object("exec_files_search")
        self.exec_cat_list: Gtk.ListBox = self.builder.get_object("exec_categories_list")
        self.exec_files_list: Gtk.ListBox = self.builder.get_object("exec_files_list")
        self.exec_empty: Gtk.Label = self.builder.get_object("exec_empty_label")
        self.btn_exec_clear: Gtk.Button = self.builder.get_object("exec_clear_all_btn")
        self.btn_files_select_all: Gtk.Button = self.builder.get_object("exec_files_select_all_btn")
        self.btn_files_clear_all: Gtk.Button = self.builder.get_object("exec_files_clear_all_btn")
        self.btn_files_toggle: Gtk.Button = self.builder.get_object("exec_files_toggle_btn")

        # 実行設定（chroot-min/max）
        self.spin_min: Gtk.SpinButton = self.builder.get_object("exec_spin_min")
        self.spin_max: Gtk.SpinButton = self.builder.get_object("exec_spin_max")

        # Options
        self.rb_dry_on: Gtk.CheckButton = self.builder.get_object("opt_dry_on")
        self.rb_dry_off: Gtk.CheckButton = self.builder.get_object("opt_dry_off")
        self.rb_keep_on: Gtk.CheckButton = self.builder.get_object("opt_keep_on")
        self.rb_keep_off: Gtk.CheckButton = self.builder.get_object("opt_keep_off")
        self.rb_depr_all_on: Gtk.CheckButton = self.builder.get_object("opt_depr_all_on")
        self.rb_depr_all_off: Gtk.CheckButton = self.builder.get_object("opt_depr_all_off")
        self.rb_depr_nodes_on: Gtk.CheckButton = self.builder.get_object("opt_depr_nodes_on")
        self.rb_depr_nodes_off: Gtk.CheckButton = self.builder.get_object("opt_depr_nodes_off")
        self.entry_depr_nodes: Gtk.Entry = self.builder.get_object("opt_depr_nodes_entry")

        # Categories（read-only）
        self.cat_list: Gtk.ListBox = self.builder.get_object("categories_list")
        self.cat_empty: Gtk.Label = self.builder.get_object("categories_empty_label")

        # Config（read-only）
        self.cfg_text: Gtk.TextView = self.builder.get_object("config_textview")
        self.cfg_buf: Gtk.TextBuffer = self.cfg_text.get_buffer()

        # 初期/最終実行
        self.prelude_list: Gtk.ListBox = self.builder.get_object("prelude_list")
        self.finalizers_list: Gtk.ListBox = self.builder.get_object("finalizers_list")

        # Logs -> GtkTextView
        self.log_scroller: Gtk.ScrolledWindow = self.builder.get_object("log_scroller")
        self.log_text: Gtk.TextView = self.builder.get_object("log_textview")
        self.log_buf: Gtk.TextBuffer = self.log_text.get_buffer()


        self.log_buf.create_tag("log-info",   foreground="#222222")
        self.log_buf.create_tag("log-warn",   foreground="#d98c00")
        self.log_buf.create_tag("log-error",  foreground="#cc0000", weight=Pango.Weight.BOLD)
        self.log_buf.create_tag("log-debug",  foreground="#1a5fb4")
        self.log_buf.create_tag("log-stderr", foreground="#7a1fa2")


        # 選択コピーのために編集禁止＆カーソル非表示（見た目すっきり）
        self.log_text.set_editable(False)
        self.log_text.set_cursor_visible(False)
        self.log_text.set_monospace(True)
        self.log_text.set_wrap_mode(Pango.WrapMode.CHAR)

        # state
        self.current_profile: str = ""
        self.packages: List[Dict[str, Any]] = []
        self.flatpaks: List[Dict[str, Any]] = []
        self.categories_nodes: Dict[str, Dict[str, Any]] = {}
        self.selected_categories: Set[str] = set()
        self.files: List[Dict[str, Any]] = []  # {"name":basename, "rel":relpath, "checked":bool}
        self._suspend_cat_toggled: bool = False

        # process
        self.proc: Optional[Gio.Subprocess] = None
        self._pulse_id: Optional[int] = None
        self._running: bool = False

        # signals
        self.btn_reload.connect("clicked", self.on_reload)
        self.profile_combo.connect("changed", self.on_profile_changed)
        self.btn_run.connect("clicked", self.on_run_clicked)
        self.exec_cat_search.connect("search-changed", self.on_filter_changed)
        self.exec_files_search.connect("search-changed", self.on_filter_changed)
        self.btn_exec_clear.connect("clicked", self.on_exec_clear_categories)
        self.btn_files_select_all.connect("clicked", self.on_files_select_all)
        self.btn_files_clear_all.connect("clicked", self.on_files_clear_all)
        self.btn_files_toggle.connect("clicked", self.on_files_toggle)
        self.rb_depr_nodes_on.connect("toggled", self._on_depr_nodes_mode_changed)
        self._on_depr_nodes_mode_changed(None)

        # init
        self.populate_profiles(default_empty=True)
        self.update_tabs(None)
        self._set_running(False)
        self._log("GUI initialized", "[READY]")

    # ---- log helpers（TextView） ----
    def _scroll_log_to_bottom(self):
        end_it = self.log_buf.get_end_iter()
        self.log_text.scroll_to_iter(end_it, 0.0, True, 0.0, 1.0)

    def _level_from(self, prefix: str, msg: str) -> str:
        p = (prefix or "").upper()
        if "STDERR" in p: return "STDERR"
        if "ERROR"  in p: return "ERROR"
        if "WARN"   in p: return "WARN"
        if "DEBUG"  in p: return "DEBUG"
        u = (msg or "").upper()
        if re.match(r"\s*\[(ERROR|ERR|FAIL|FAILED)\]\s*", u) or re.search(r"\b(ERROR|ERR|FAIL|FAILED)\b", u):
            return "ERROR"
        if re.match(r"\s*\[(WARN|WARNING)\]\s*", u) or re.search(r"\b(WARN(ING)?|CAUTION)\b", u):
            return "WARN"
        if re.match(r"\s*\[(DEBUG|TRACE)\]\s*", u) or re.search(r"\b(DEBUG|TRACE)\b", u):
            return "DEBUG"
        return "INFO"

    def _log(self, msg: str, prefix: str = "[INFO]"):
        level = self._level_from(prefix, msg)
        try:
            it = self.log_buf.get_end_iter()
            text = f"{prefix} {msg}\n"
            tagname = {
                "INFO": "log-info",
                "WARN": "log-warn",
                "ERROR": "log-error",
                "DEBUG": "log-debug",
                "STDERR": "log-stderr",
            }.get(level, "log-info")
            self.log_buf.insert_with_tags_by_name(it, text, tagname)

            # 行数制限：超過分をまとめて削除
            lines = self.log_buf.get_line_count()
            if lines > LOG_MAX_LINES:
                start = self.log_buf.get_start_iter()
                cut   = self.log_buf.get_iter_at_line(lines - LOG_MAX_LINES)
                self.log_buf.delete(start, cut)

            # 常に末尾へ（次フレームで）
            GLib.idle_add(self._scroll_log_to_bottom)
        except Exception as e:
            print(text, end="", file=sys.stderr)
            print(f"[WARN] log insert failed: {e}", file=sys.stderr)

    # ---- profiles ----
    def populate_profiles(self, default_empty: bool = True):
        self.profile_combo.remove_all()
        if default_empty:
            self.profile_combo.append_text("")  # default empty
        for name in list_profiles():
            self.profile_combo.append_text(name)
        #self.profile_combo.set_active(0)

    def on_reload(self, *_):
        self.populate_profiles(default_empty=True)

    def on_profile_changed(self, combo: Gtk.ComboBoxText):
        self.current_profile = (combo.get_active_text() or "").strip()
        self.update_tabs(self.current_profile if self.current_profile else None)

    # ---- options ----
    def _on_depr_nodes_mode_changed(self, *_):
        enabled = self.rb_depr_nodes_on.get_active()
        self.entry_depr_nodes.set_sensitive(enabled)

    def _get_deprecated_policy(self) -> Tuple[bool, Set[str]]:
        allow_all = self.rb_depr_all_on.get_active()
        if allow_all:
            return True, set()
        if self.rb_depr_nodes_on.get_active():
            raw = self.entry_depr_nodes.get_text() or ""
            items = [s.strip() for s in raw.split(",") if s.strip()]
            uniq = list(dict.fromkeys(items))
            return False, set(uniq)
        return False, set()

    # ---- categories utils ----
    def _load_categories_and_nodes(self, profile: str):
        cpath = profile_paths(profile)["categories"]
        try:
            cat = Categories.load(cpath)
            nodes = cat.nodes or {}
            return cat, nodes
        except FileNotFoundError:
            self._log(f"categories.json が見つかりません: {cpath}", "[ERROR]")
            return None, {}
        except Exception as e:
            self._log(f"categories.json 読み込み失敗: {e}", "[ERROR]")
            return None, {}

    def _resolve_deps_base(self, base_on: Set[str]) -> Set[str]:
        resolved, seen = set(), set()
        def dfs(name: str):
            if name in seen: return
            seen.add(name)
            node = self.categories_nodes.get(name) or {}
            for k in ("includes", "deps"):
                for child in node.get(k, []) or []:
                    if isinstance(child, str) and child.strip():
                        dfs(child.strip())
            resolved.add(name)
        for n in base_on: dfs(n)
        return resolved

    # ---- tabs ----
    def update_tabs(self, profile: Optional[str]):
        # packages
        self._clear_list(self.pkg_list)
        self.packages = []
        if profile:
            raw = load_json(profile_paths(profile)["packages"])
            items = []
            if isinstance(raw, list):
                items = [{"name": s, "description": "", "default": False} for s in raw] if (raw and isinstance(raw[0], str)) else raw
            elif isinstance(raw, dict):
                if isinstance(raw.get("packages"), list):
                    arr = raw["packages"]
                    items = [{"name": s, "description": "", "default": False} for s in arr] if (arr and isinstance(arr[0], str)) else arr
                elif isinstance(raw.get("items"), list):
                    items = raw["items"]
                elif raw.get("_error"):
                    self._log(f"packages.json 読み込み失敗: {raw['_error']}", "[ERROR]")
            else:
                self._log("packages.json が見つからないか形式不正です", "[WARN]")

            if isinstance(items, list) and items:
                self.pkg_empty.set_visible(False)
                self.packages = [{
                    "name": d.get("name", d if isinstance(d, str) else ""),
                    "description": d.get("description", "") if isinstance(d, dict) else "",
                    "enabled": bool((d.get("default", False) if isinstance(d, dict) else False))
                } for d in items]
                for item in self.packages:
                    self.pkg_list.append(self._make_check_row(item, "enabled"))
            else:
                self.pkg_empty.set_visible(True)
        else:
            self.pkg_empty.set_visible(True)

        # flatpak
        self._clear_list(self.fp_list)
        self.flatpaks = []
        if profile:
            raw = load_json(profile_paths(profile)["flatpak"])
            items = []
            if isinstance(raw, list):
                items = [{"name": s, "description": "", "default": False} for s in raw] if (raw and isinstance(raw[0], str)) else raw
            elif isinstance(raw, dict):
                if isinstance(raw.get("flatpaks"), list):
                    arr = raw["flatpaks"]
                    items = [{"name": s, "description": "", "default": False} for s in arr] if (arr and isinstance(arr[0], str)) else arr
                elif isinstance(raw.get("items"), list):
                    items = raw["items"]
                elif raw.get("_error"):
                    self._log(f"flatpak.json 読み込み失敗: {raw['_error']}", "[ERROR]")
            else:
                self._log("flatpak.json が見つからないか形式不正です", "[WARN]")

            if isinstance(items, list) and items:
                self.fp_empty.set_visible(False)
                self.flatpaks = [{
                    "name": d.get("name", d if isinstance(d, str) else ""),
                    "description": d.get("description", "") if isinstance(d, dict) else "",
                    "enabled": bool((d.get("default", False) if isinstance(d, dict) else False))
                } for d in items]
                for item in self.flatpaks:
                    self.fp_list.append(self._make_check_row(item, "enabled"))
            else:
                self.fp_empty.set_visible(True)
        else:
            self.fp_empty.set_visible(True)

        # execution (categories + files)
        self._clear_list(self.exec_cat_list)
        self._clear_list(self.exec_files_list)
        self.selected_categories.clear()
        self.files = []
        self.categories_nodes = {}
        we_have_nodes = False

        if profile:
            cat, nodes = self._load_categories_and_nodes(profile)
            if nodes:
                we_have_nodes = True
                self.exec_empty.set_visible(False)
                self.categories_nodes = nodes

                # 左：カテゴリ
                for key, meta in nodes.items():
                    item = {"name": key, "description": meta.get("desc",""), "enabled": False}
                    row = self._make_check_row(
                        item, "enabled",
                        toggled_cb=lambda btn, k=key: self._on_category_toggled(k, btn.get_active())
                    )
                    self.exec_cat_list.append(row)

                # 右：scripts/ 実ファイル
                scripts_dir = profile_paths(profile)["scripts"]
                if scripts_dir.exists():
                    base = scripts_dir
                    for f in sorted(scripts_dir.rglob("*")):
                        if not f.is_file(): continue
                        if f.suffix not in (".sh", ".py"): continue
                        rel = f.relative_to(base).as_posix()
                        self.files.append({"name": f.name, "rel": rel, "checked": False})
                    for fitem in self.files:
                        row = self._make_check_row({"name": fitem["name"], "description": fitem["rel"]}, "checked")
                        self.exec_files_list.append(row)
                else:
                    self._log(f"scripts ディレクトリが見つかりません: {scripts_dir}", "[WARN]")

        self.exec_empty.set_visible(not we_have_nodes)

        # categories (read-only)
        self._clear_list(self.cat_list)
        if profile and self.categories_nodes:
            self.cat_empty.set_visible(False)
            for key, meta in self.categories_nodes.items():
                item = {"name": key, "description": meta.get("desc","")}
                self.cat_list.append(self._make_info_row(item, meta))
        else:
            self.cat_empty.set_visible(True)

        # Config（read-only）
        self._refresh_config_view(profile)

        # 初期/最終実行
        for r in list(self.prelude_list): self.prelude_list.remove(r)
        for r in list(self.finalizers_list): self.finalizers_list.remove(r)
        if profile:
            cat, _ = self._load_categories_and_nodes(profile)
            if cat:
                for name in cat.get_prelude_always_first():
                    self.prelude_list.append(self._make_info_text_row(name))
                fins = cat.get_finalizers()
                def _section(title, items):
                    self.finalizers_list.append(self._make_section_row(title))
                    for n in items:
                        self.finalizers_list.append(self._make_info_text_row(n))
                _section("always", fins.get("always", []))
                _section("on_success", fins.get("on_success", []))
                _section("on_failure", fins.get("on_failure", []))

        # 実行設定（min/max）
        self._refresh_exec_spin(profile)

        # フィルタ
        self.on_filter_changed()

    # ---- Config 読み込み（read-only）----
    def _refresh_config_view(self, profile: Optional[str]):
        if not profile:
            self.cfg_buf.set_text("プロファイル未選択\n")
            return
        cfg_path = profile_paths(profile)["config"]
        cfg_raw = load_json(cfg_path)
        if cfg_raw is None:
            self.cfg_buf.set_text(f"config.json が見つかりません: {cfg_path}\n")
        elif isinstance(cfg_raw, dict) and "_error" in cfg_raw:
            self.cfg_buf.set_text(f"config.json の読み込みに失敗しました: {cfg_raw['_error']}\n")
        else:
            try:
                pretty = json.dumps(cfg_raw, ensure_ascii=False, indent=2)
                self.cfg_buf.set_text(pretty)
            except Exception as e:
                self.cfg_buf.set_text(f"config.json の整形に失敗: {e}\n")

    # ---- 実行設定（min/max） ----
    def _refresh_exec_spin(self, profile: Optional[str]):
        if not profile:
            self.spin_min.set_value(DEFAULT_CHROOT_MIN)
            self.spin_max.set_value(DEFAULT_CHROOT_MAX)
            return
        ep = profile_paths(profile)["execution"]
        ch_min, ch_max = self._read_chroot_min_max(ep)
        self.spin_min.set_value(float(ch_min))
        self.spin_max.set_value(float(ch_max))

    def _read_chroot_min_max(self, exec_path: Path) -> tuple[int, int]:
        def _as_int(x):
            try:
                if isinstance(x, (int, float)): return int(x)
                if isinstance(x, str) and x.strip().isdigit(): return int(x.strip())
            except Exception:
                pass
            return None
        data = load_json(exec_path)
        if not isinstance(data, dict):
            self._log(f"execution.json を読めませんでした: {exec_path}（既定 {DEFAULT_CHROOT_MIN}-{DEFAULT_CHROOT_MAX}）", "[WARN]")
            return DEFAULT_CHROOT_MIN, DEFAULT_CHROOT_MAX
        if isinstance(data.get("chroot"), dict):
            mn = _as_int(data["chroot"].get("min"))
            mx = _as_int(data["chroot"].get("max"))
            if mn is not None and mx is not None:
                return mn, mx
        mn = _as_int(data.get("min"))
        mx = _as_int(data.get("max"))
        if mn is not None and mx is not None:
            return mn, mx
        self._log(f"execution.json に min/max が見つかりません（既定 {DEFAULT_CHROOT_MIN}-{DEFAULT_CHROOT_MAX}）", "[WARN]")
        return DEFAULT_CHROOT_MIN, DEFAULT_CHROOT_MAX

    # ---- filtering ----
    def on_filter_changed(self, *_args):
        q_cat = (self.exec_cat_search.get_text() or "").strip().lower() if self.exec_cat_search else ""
        q_file = (self.exec_files_search.get_text() or "").strip().lower() if self.exec_files_search else ""
        for row in self.exec_cat_list:
            box = row.get_child()
            try:
                vb = box.get_first_child()
                chk: Gtk.CheckButton = vb.get_first_child()
                label = chk.get_label() or ""
            except Exception:
                label = ""
            row.set_visible(q_cat in label.lower())
        for row in self.exec_files_list:
            box = row.get_child()
            try:
                vb = box.get_first_child()
                chk: Gtk.CheckButton = vb.get_first_child()
                label = chk.get_label() or ""
                desc = vb.get_next_sibling()
                reltxt = desc.get_text() if isinstance(desc, Gtk.Label) else ""
            except Exception:
                label, reltxt = "", ""
            key = (label + " " + reltxt).lower()
            row.set_visible(q_file in key)

    # ---- 実行制御：カテゴリ全解除 ----
    def on_exec_clear_categories(self, *_):
        self._suspend_cat_toggled = True
        try:
            for row in list(self.exec_cat_list):
                try:
                    vb = row.get_child().get_first_child()
                    chk: Gtk.CheckButton = vb.get_first_child()
                    if chk.get_active():
                        chk.set_active(False)
                except Exception:
                    pass
        finally:
            self._suspend_cat_toggled = False
        self._recompute_from_current_categories()
        self._log("カテゴリを全解除しました", "[INFO]")

    # ---- 実行制御：ファイル全選択/全解除/反転 ----
    def on_files_select_all(self, *_):
        for idx, f in enumerate(self.files):
            f["checked"] = True
            try:
                row = list(self.exec_files_list)[idx]
                vb = row.get_child().get_first_child()
                chk: Gtk.CheckButton = vb.get_first_child()
                chk.set_active(True)
            except Exception:
                pass
        self._log("ファイル: 全選択しました", "[INFO]")

    def on_files_clear_all(self, *_):
        for idx, f in enumerate(self.files):
            f["checked"] = False
            try:
                row = list(self.exec_files_list)[idx]
                vb = row.get_child().get_first_child()
                chk: Gtk.CheckButton = vb.get_first_child()
                chk.set_active(False)
            except Exception:
                pass
        self._log("ファイル: 全解除しました", "[INFO]")

    def on_files_toggle(self, *_):
        for idx, f in enumerate(self.files):
            new_state = not bool(f.get("checked"))
            f["checked"] = new_state
            try:
                row = list(self.exec_files_list)[idx]
                vb = row.get_child().get_first_child()
                chk: Gtk.CheckButton = vb.get_first_child()
                chk.set_active(new_state)
            except Exception:
                pass
        self._log("ファイル: 反転しました", "[INFO]")

    # ---- カテゴリ個別トグル ----
    def _on_category_toggled(self, key: str, state: bool):
        if getattr(self, "_suspend_cat_toggled", False):
            return
        self._recompute_from_current_categories()

    # ---- 依存解決 + ファイル反映 ----
    def _recompute_from_current_categories(self):
        base_on: Set[str] = set()
        for row in self.exec_cat_list:
            box = row.get_child()
            try:
                vb = box.get_first_child()
                chk: Gtk.CheckButton = vb.get_first_child()
                if chk.get_active():
                    name = chk.get_label()
                    if name: base_on.add(name)
            except Exception:
                pass
        self.selected_categories = self._resolve_deps_base(base_on)

        # 左UIにも反映（依存でONにした分）
        for row in self.exec_cat_list:
            try:
                vb = row.get_child().get_first_child()
                chk: Gtk.CheckButton = vb.get_first_child()
                name = chk.get_label()
                if name:
                    chk.set_active(name in self.selected_categories)
            except Exception:
                pass

        allow_all, allow_nodes = self._get_deprecated_policy()

        matched_basenames: Set[str] = set()
        if self.current_profile:
            cat, _nodes = self._load_categories_and_nodes(self.current_profile)
            scripts_dir = profile_paths(self.current_profile)["scripts"]
            if cat and scripts_dir.exists():
                try:
                    try:
                        matched_basenames = set(cat.resolve_nodes(
                            tokens=sorted(self.selected_categories),
                            scripts_dir=scripts_dir,
                            allow_deprecated=allow_all or bool(allow_nodes),
                            allow_deprecated_nodes=sorted(allow_nodes) if allow_nodes else None
                        ))
                    except TypeError:
                        matched_basenames = set(cat.resolve_nodes(
                            tokens=sorted(self.selected_categories),
                            scripts_dir=scripts_dir,
                            allow_deprecated=allow_all or bool(allow_nodes)
                        ))
                        if allow_nodes and not allow_all:
                            self._log("categories.py が個別指定に未対応のため全体許可にフォールバック", "[WARN]")
                except Exception as e:
                    self._log(f"categories.resolve_nodes 失敗: {e}", "[ERROR]")

        if allow_nodes and not allow_all and self.categories_nodes:
            for n in sorted(allow_nodes):
                if n not in self.categories_nodes:
                    self._log(f"unknown deprecated node: {n}", "[WARN]")

        selected_rel = []
        for idx, f in enumerate(self.files):
            basename = f.get("name", "")
            should = basename in matched_basenames
            f["checked"] = should
            try:
                row = list(self.exec_files_list)[idx]
                vb = row.get_child().get_first_child()
                chk: Gtk.CheckButton = vb.get_first_child()
                chk.set_active(should)
            except Exception:
                pass
            if should:
                selected_rel.append(f.get("rel", basename))

        self._log("selected categories: " + ", ".join(sorted(self.selected_categories)), "[DEBUG]")
        pol = "ALL" if allow_all else ("NODES=" + ",".join(sorted(allow_nodes)) if allow_nodes else "OFF")
        self._log("deprecated policy: " + pol, "[DEBUG]")
        if selected_rel:
            self._log("matched (relpath): " + ", ".join(selected_rel), "[DEBUG]")

    # ---- run / cancel ----
    def _set_running(self, running: bool):
        self._running = running
        if running:
            self.btn_run.set_label("キャンセル")
            self.progress.set_show_text(True)
            self.progress.set_text("実行中…")
            self.progress.pulse()
            if self._pulse_id is None:
                self._pulse_id = GLib.timeout_add(100, self._on_pulse)
        else:
            self.btn_run.set_label("実行")
            if self._pulse_id is not None:
                GLib.source_remove(self._pulse_id)
                self._pulse_id = None
            self.progress.set_fraction(0.0)
            self.progress.set_text("")
            self.progress.set_show_text(False)

    def _on_pulse(self):
        if not self._running:
            return False
        self.progress.pulse()
        return True

    def on_run_clicked(self, *_):
        # 実行中ならキャンセル
        if self._running and self.proc is not None:
            try:
                self._log("キャンセル要求: SIGINT を送信します", "[INFO]")
                self.proc.send_signal(signal.SIGINT)
            except Exception as e:
                self._log(f"SIGINT送信失敗: {e}", "[WARN]")
            GLib.timeout_add(2000, self._force_kill_if_alive)
            return

        if not self.current_profile:
            self._log("プロファイルが未選択です。", "[WARN]")
            return

        # チェック状態を同期
        self._sync_checks(self.pkg_list, self.packages, "enabled")
        self._sync_checks(self.fp_list, self.flatpaks, "enabled")
        self._sync_checks(self.exec_files_list, self.files, "checked")

        pkgs = [x["name"] for x in self.packages if x.get("enabled")]
        fps  = [x["name"] for x in self.flatpaks if x.get("enabled")]
        run_files = [x["name"] for x in self.files if x.get("checked")]  # -r は basename で渡す

        # Logs タブへ
        self.stack.set_visible_child_name("page_logs")

        # 実行設定（min/max）
        ch_min = int(self.spin_min.get_value())
        ch_max = int(self.spin_max.get_value())

        # オプション
        allow_all, allow_nodes = self._get_deprecated_policy()
        dry = self.rb_dry_on.get_active()
        keep = self.rb_keep_on.get_active()

        self._log(f"実行開始 profile={self.current_profile}", "[INFO]")
        self._log(f"packages: {len(pkgs)} / flatpaks: {len(fps)} / run(files): {len(run_files)}", "[INFO]")
        self._log(f"chroot-range: min={ch_min} max={ch_max}", "[INFO]")

        cl_main = str(CL_MAIN)
        if not Path(cl_main).exists():
            self._log(f"cl_main.py が見つかりません: {cl_main}", "[ERROR]")
            return

        # 引数構築（cl_main.py は -r を「カンマ区切りの1引数」想定）
        argv = ["python3", "-u", cl_main, self.current_profile]  # -u: 非バッファ
        if run_files:
            argv += ["-r", ",".join(run_files)]
        if pkgs:
            argv += ["--package-list", ",".join(pkgs)]
        if fps:
            argv += ["--flatpak-list", ",".join(fps)]
        argv += ["--chroot-min", str(ch_min), "--chroot-max", str(ch_max)]
        if dry:
            argv.append("--dry-run")
        if keep:
            argv.append("--keep-going")
        if allow_all:
            argv.append("--allow-deprecated")
        elif allow_nodes:
            argv += ["--allow-deprecated-nodes", ",".join(sorted(allow_nodes))]

        # root 実行: pkexec 優先、無ければ sudo -E
        if which("pkexec"):
            argv = ["pkexec"] + argv
        else:
            argv = ["sudo", "-E"] + argv

        self._log("起動コマンド(root): " + " ".join(shlex.quote(a) for a in argv), "[INFO]")

        # 起動（CWD をリポジトリルートに固定、Python側も非バッファリング環境変数）
        try:
            launcher = Gio.SubprocessLauncher(
                flags=Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE
            )
            launcher.set_cwd(str(HERE))
            launcher.setenv("PYTHONUNBUFFERED", "1", True)
            self.proc = launcher.spawnv(argv)
        except Exception as e:
            self._log(f"プロセス起動失敗: {e}", "[ERROR]")
            return

        # 非同期読み取り＆進捗
        self._set_running(True)
        self._pipe_read(self.proc.get_stdout_pipe(), False)
        self._pipe_read(self.proc.get_stderr_pipe(), True)
        self.proc.wait_check_async(None, self._on_wait_done, None)

    def _force_kill_if_alive(self):
        if self.proc is None:
            return False
        try:
            if not self.proc.get_if_exited() and not self.proc.get_if_signaled():
                self._log("強制終了を試みます", "[INFO]")
                self.proc.force_exit()
        except Exception as e:
            self._log(f"強制終了失敗: {e}", "[WARN]")
        return False

    def _on_wait_done(self, proc: Gio.Subprocess, res, _data=None):
        try:
            ok = proc.wait_check_finish(res)
        except Exception as e:
            self._log(f"プロセス待機で例外: {e}", "[ERROR]")
            self._set_running(False)
            return
        code = proc.get_exit_status()
        if ok:
            self._log(f"実行完了 (exit={code})", "[INFO]")
        else:
            self._log(f"実行失敗 (exit={code})", "[ERROR]")
        self._set_running(False)
        self.proc = None

    # ---- stream reading（行単位・最終行欠落なし） ----
    def _pipe_read(self, stream: Gio.InputStream, is_stderr: bool):
        din = Gio.DataInputStream.new(stream)
        din.set_newline_type(Gio.DataStreamNewlineType.LF)

        def _on_read_line(din: Gio.DataInputStream, res, _u=None):
            try:
                line, _len = din.read_line_finish_utf8(res)
            except Exception as e:
                self._log(f"読取例外: {e}", "[ERROR]")
                return
            if line is None:
                return  # EOF
            self._log(line, prefix="[STDERR]" if is_stderr else "[INFO]")
            din.read_line_async(GLib.PRIORITY_DEFAULT, None, _on_read_line, None)

        din.read_line_async(GLib.PRIORITY_DEFAULT, None, _on_read_line, None)

    # ---- UI helpers ----
    def _make_check_row(self, item: Dict[str, Any], key: str, toggled_cb=None) -> Gtk.ListBoxRow:
        row = Gtk.ListBoxRow()
        row.set_selectable(False)
        hb = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12,
                     margin_start=6, margin_end=6, margin_top=6, margin_bottom=6)
        vb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        chk = Gtk.CheckButton(label=item["name"])
        chk.set_active(bool(item.get(key)))
        if toggled_cb is not None:
            chk.connect("toggled", toggled_cb)
        else:
            chk.connect("toggled", lambda btn: item.__setitem__(key, btn.get_active()))
        sub = Gtk.Label()
        sub.set_wrap(True)
        sub.set_wrap_mode(Pango.WrapMode.WORD_CHAR)
        sub.set_markup(f"<small>{GLib.markup_escape_text(item.get('description',''))}</small>")
        sub.set_xalign(0)
        vb.append(chk); vb.append(sub)
        hb.append(vb)
        row.set_child(hb)
        return row

    def _make_info_row(self, item: Dict[str, Any], meta: Dict[str, Any]) -> Gtk.ListBoxRow:
        row = Gtk.ListBoxRow(); row.set_selectable(False)
        hb = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12,
                     margin_start=6, margin_end=6, margin_top=6, margin_bottom=6)
        vb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        title = Gtk.Label(xalign=0)
        title.set_markup(f"<b>{GLib.markup_escape_text(item['name'])}</b>")
        desc = Gtk.Label(xalign=0)
        desc.set_wrap(True); desc.set_wrap_mode(Pango.WrapMode.WORD_CHAR)
        desc.set_markup(f"<small>{GLib.markup_escape_text(item.get('description',''))}</small>")
        deps = meta.get("deps", []); incs = meta.get("includes", []); pats = meta.get("patterns", [])
        extra = Gtk.Label(xalign=0); extra.set_wrap(True); extra.set_wrap_mode(Pango.WrapMode.WORD_CHAR)
        extra.set_markup("<small>includes: " + GLib.markup_escape_text(", ".join(incs) if incs else "-") +
                         " / deps: " + GLib.markup_escape_text(", ".join(deps) if deps else "-") +
                         " / patterns: " + GLib.markup_escape_text(", ".join(pats) if pats else "-") + "</small>")
        vb.append(title); vb.append(desc); vb.append(extra)
        hb.append(vb)
        row.set_child(hb)
        return row

    def _make_info_text_row(self, text: str) -> Gtk.ListBoxRow:
        row = Gtk.ListBoxRow(); row.set_selectable(False)
        lb = Gtk.Label(xalign=0); lb.set_wrap(True); lb.set_text(text)
        row.set_child(lb); return row

    def _make_section_row(self, title: str) -> Gtk.ListBoxRow:
        row = Gtk.ListBoxRow(); row.set_selectable(False)
        lb = Gtk.Label(xalign=0); lb.set_markup(f"<b>{GLib.markup_escape_text(title)}</b>")
        row.set_child(lb); return row

    def _clear_list(self, lb: Gtk.ListBox):
        for r in list(lb):
            lb.remove(r)

    def _sync_checks(self, lb: Gtk.ListBox, arr: List[Dict[str, Any]], key: str):
        labels = []
        for row in lb:
            box = row.get_child()
            try:
                vb = box.get_first_child()
                chk: Gtk.CheckButton = vb.get_first_child()
                labels.append((chk.get_label(), chk.get_active()))
            except Exception:
                pass
        by_name = {name: active for name, active in labels}
        for it in arr:
            n = it.get("name")
            if n in by_name:
                it[key] = by_name[n]


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID)

    def do_activate(self):

        win = MainWindow(self)
        win.present()


def main():
    app = App()
    sys.exit(app.run(sys.argv))


if __name__ == "__main__":
    main()
