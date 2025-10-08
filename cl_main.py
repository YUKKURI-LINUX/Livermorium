#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from __future__ import annotations
import os, sys, argparse, json
from datetime import datetime
from pathlib import Path
from typing import List, Set
from builder import executor, logger
from builder.config_loader import load_config, load_package_list, load_flatpak_list
from builder.categories import Categories

# Default range of script numbers that should run inside chroot
DEFAULT_CHROOT_MIN = 50
DEFAULT_CHROOT_MAX = 79

# Normalizes a comma-separated string, handling spaces and semi-colons
def _comma_norm(s: str) -> str:
    if not s: return ""
    import re
    s = re.sub(r"[;\s]+", ",", s.strip())
    return re.sub(r",+", ",", s).strip(",")

def parse_args(argv=None):
    p = argparse.ArgumentParser(description="Livermorium build runner")
    p.add_argument("profile", help="Profile name (e.g., ubuntu)")
    p.add_argument("-r","--run", default="", help="Nodes/patterns to run (e.g., full-desktop,85-*.sh)")
    p.add_argument("--allow-deprecated", action="store_true", help="Allow deprecated scripts to run")
    p.add_argument("--allow-deprecated-nodes", default="", help="Comma-separated list of deprecated nodes to allow")
    p.add_argument("--chroot-min", type=int, default=None, help="Minimum script number for chroot execution")
    p.add_argument("--chroot-max", type=int, default=None, help="Maximum script number for chroot execution")
    p.add_argument("--print-plan", action="store_true", help="Print the execution plan and exit")
    p.add_argument("--validate", action="store_true", help="Validate settings and exit")
    p.add_argument("--list-only", action="store_true", help="Print the script list and exit")
    p.add_argument("--dry-run", action="store_true", help="Perform a dry run (do not execute scripts)")
    p.add_argument("--continue-on-error", action="store_true", help="Continue running scripts even if one fails")
    p.add_argument("--package-list", default="", help="Comma-separated extra package list")
    p.add_argument("--flatpak-list", default="", help="Comma-separated extra Flatpak list")
    return p.parse_args(argv)

# Loads chroot range settings from execution.json if available
def _load_execution_cfg(profile_dir: Path) -> tuple[int, int]:
    path = profile_dir / "execution.json"
    mn, mx = DEFAULT_CHROOT_MIN, DEFAULT_CHROOT_MAX
    if path.exists():
        try:
            j = json.loads(path.read_text(encoding="utf-8"))
            ch = j.get("chroot", {})
            if isinstance(ch, dict):
                mn = int(ch.get("min", mn))
                mx = int(ch.get("max", mx))
        except Exception:
            pass
    if not (0 <= mn <= 99 and 0 <= mx <= 99 and mn <= mx):
        mn, mx = DEFAULT_CHROOT_MIN, DEFAULT_CHROOT_MAX
    return mn, mx

# Builds the list of scripts to run based on categories.json or directory contents
def _build_run_list(profile_dir: Path, args) -> List[str]:
    scripts_dir = profile_dir / "scripts"
    categories_json = profile_dir / "categories.json"
    if not scripts_dir.is_dir():
        raise FileNotFoundError(f"Scripts directory not found: {scripts_dir}")
    
    run_tokens = _comma_norm(args.run).split(",") if args.run else []

    allow_nodes: Set[str] = {s for s in _comma_norm(args.allow_deprecated_nodes).split(",") if s}
    if categories_json.exists():
        cats = Categories.load(categories_json)
        # Resolve nodes into a list of script filenames
        plan = cats.resolve_nodes(tokens=run_tokens, scripts_dir=scripts_dir,
                                  allow_deprecated=args.allow_deprecated,
                                  allow_deprecated_nodes=allow_nodes)
    else:
        # Fallback: list all numeric scripts if categories.json is missing
        plan = sorted(f.name for f in scripts_dir.iterdir()
                      if f.is_file() and f.suffix in (".sh",".py") and f.name[:2].isdigit())
        
    # Sort scripts by number then name
    def key(n:str): return (n[:2], n)
    exist, seen = [], set()
    for name in sorted(plan, key=key):
        p = scripts_dir / name
        if name in seen: continue
        if not p.is_file(): continue
        if p.suffix not in (".sh",".py"): continue
        if not (len(name)>=2 and name[:2].isdigit()): continue
        seen.add(name); exist.append(name)
    return exist

def main(argv=None):
    args = parse_args(argv)
    root = Path(__file__).resolve().parent
    profile_dir = root / "profiles" / args.profile
    if not profile_dir.is_dir():
        print(f"[ERROR] Profile not found: {profile_dir}", file=sys.stderr); return 2

    # chroot range determination
    cfg_min, cfg_max = _load_execution_cfg(profile_dir)
    ch_min = args.chroot_min if args.chroot_min is not None else cfg_min
    ch_max = args.chroot_max if args.chroot_max is not None else cfg_max
    if not (0 <= ch_min <= 99 and 0 <= ch_max <= 99 and ch_min <= ch_max):
        print(f"[ERROR] Invalid chroot range: {ch_min}..{ch_max}", file=sys.stderr); return 3

    # Get prelude / finalizers from categories.json
    prelude_first: List[str] = []
    finalizers = {"always": [], "on_failure": [], "on_success": []}
    cats_path = profile_dir / "categories.json"
    if cats_path.exists():
        cats = Categories.load(cats_path)
        prelude_first = cats.get_prelude_always_first()
        finalizers = cats.get_finalizers()
    else:
        # Default finalizer if categories.json is missing
        finalizers["on_failure"] = ["99-*.sh"]

    # Load configurations and package lists
    config = load_config(str(profile_dir))
    user = config.get("user", {})
    pkgs = load_package_list(str(profile_dir))
    flats = load_flatpak_list(str(profile_dir))
    
    # Add extra packages/flatpaks from command line arguments
    pkgs += [s for s in _comma_norm(args.package_list).split(",") if s]
    flats += [s for s in _comma_norm(args.flatpak_list).split(",") if s]
    package_csv = ",".join(sorted(set(pkgs)))
    flatpak_csv = ",".join(sorted(set(flats)))

    try:
        run_list = _build_run_list(profile_dir, args)
    except Exception as e:
        print(f"[ERROR] Plan build failed: {e}", file=sys.stderr); return 3
    
    # Error exit if -r is specified but no scripts were resolved (to prevent fallback to full run)
    if args.run and not run_list:
        print(
            f"[ERROR] No scripts matched for -r '{args.run}'. "
            "Use an exact node name or a valid glob pattern.",
            file=sys.stderr
        )
        return 1


    if args.print_plan or args.list_only or args.validate:
        print("[PLAN] Targets (main, numeric order):")
        for n in run_list: print("  -", n)
        print(f"[PLAN] Chroot range: {ch_min}..{ch_max}")
        print("[PLAN] prelude.always_first:", prelude_first)
        print("[PLAN] finalizers:",
              "always=", finalizers.get("always", []),
              "on_failure=", finalizers.get("on_failure", []),
              "on_success=", finalizers.get("on_success", []))
        if args.validate or args.list_only: return 0

    repo_root = Path(__file__).resolve().parent
    parent_of_repo = repo_root.parent

    # Default: <repo>/../work_build ← sibling directory
    default_work_dir = (parent_of_repo / "work_build").resolve()
    work_dir = str(default_work_dir)
    os.makedirs(work_dir, exist_ok=True)

    # Set up environment variables
    env = {
        "WORK_DIR": work_dir,
        "PROFILE_DIR": profile_dir,
        "USERNAME": user.get("name",""),
        "PASSWORD": user.get("password",""),
        "LOCALE":   config.get("locale","ja_JP.UTF-8"),
        "TIMEZONE": config.get("timezone","Asia/Tokyo"),
        "KEYBOARD": config.get("keyboard","jp"),
        "USER_GROUPS": ",".join(user.get("groups", [])),
        "AUTOLOGIN": str(user.get("autologin", True)).lower(),
        "DISABLE_ROOT": str(user.get("disable_root", True)).lower(),
        "PACKAGE_LIST": package_csv,
        "FLATPAK_LIST": flatpak_csv,
        "BASENAME": config.get("basename", args.profile),
        "PROFILENAME": args.profile,
        "CHROOT_MIN": str(ch_min),
        "CHROOT_MAX": str(ch_max),
        "PRELUDE_FIRST": ",".join(prelude_first),
        "FINAL_ALWAYS":  ",".join(finalizers.get("always", [])),
        "FINAL_ON_FAIL": ",".join(finalizers.get("on_failure", []) if finalizers.get("on_failure") else ["99-*.sh"]),
        "FINAL_ON_SUCC": ",".join(finalizers.get("on_success", [])),
    }
    if run_list: env["RUN_LIST"] = ",".join(run_list)

    # Setup logging
    logs_dir =  Path(env['WORK_DIR']) /  "logs"; logs_dir.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    log_file = str(logs_dir / f"{args.profile}_{env['BASENAME']}_{ts}.log")
    logger.log(f"[INFO] RUN_LIST={env.get('RUN_LIST','')}", log_file)
    logger.log(f"[INFO] CHROOT_RANGE={ch_min}..{ch_max}", log_file)
    logger.log(f"[INFO] PRELUDE_FIRST={env['PRELUDE_FIRST']}", log_file)
    logger.log(f"[INFO] FINALIZERS: always={env['FINAL_ALWAYS']} fail={env['FINAL_ON_FAIL']} succ={env['FINAL_ON_SUCC']}", log_file)

    # Execute scripts
    try:
        rc = executor.run_scripts(str(profile_dir), log_file=log_file, env=env,
                                  dry_run=args.dry_run, continue_on_error=args.continue_on_error)
    except Exception as e:
        print(f"[ERROR] Execution failed: {e}", file=sys.stderr); return 4
    return rc

if __name__ == "__main__":
    raise SystemExit(main())