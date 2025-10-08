# -*- coding: utf-8 -*-
from __future__ import annotations
import os, fnmatch, subprocess, shutil
from typing import Dict, Iterable, List, Optional
from builder.logger import log
from pathlib import Path

def _num_key(name: str):
    """
    Key function for numeric sorting based on the first two digits.
    Uses (first 2 chars, full name) for sorting.
    """
    return (name[:2], name)

def _sorted_numeric(files: Iterable[str]) -> List[str]:
    """Sorts files numerically based on their leading two digits."""
    files = [f for f in files if len(f) >= 2 and f[:2].isdigit()]
    files.sort(key=_num_key)
    return files

def _write_env_file(env: Dict[str, str], path: str) -> None:
    """Writes environment variables to a file in 'KEY="VALUE"' format."""
    with open(path, "w") as f:
        for k, v in env.items():
            f.write(f'{k}="{v}"\n')

def _resolve_patterns(scripts_dir: str, patterns_csv: str) -> List[str]:
    """
    Resolves CSV patterns/filenames to real files, collects them, and sorts them numerically.
    """
    names = [x.strip() for x in (patterns_csv or "").split(",") if x.strip()]
    if not names:
        return []
    # Collect all valid script files (must end with .sh or .py, have length >= 2, and start with digits)
    all_files = [f for f in os.listdir(scripts_dir) if f.endswith((".sh",".py")) and len(f)>=2 and f[:2].isdigit()]
    matched = set()
    for n in names:
        if any(ch in n for ch in "*?[]"):
            # If the name contains wildcards, use fnmatch
            matched.update(fnmatch.filter(all_files, n))
        else:
            # Otherwise, check for an exact match
            if n in all_files:
                matched.add(n)
    return _sorted_numeric(matched)

def run_scripts(
    profile_path: str,
    *,
    log_file: Optional[str],
    env: Dict[str, str],
    dry_run: bool = False,
    continue_on_error: bool = False,
) -> int:
    original_scripts_dir = os.path.join(profile_path, "scripts")
    if not os.path.isdir(original_scripts_dir):
        log("[ERROR] scripts not found", log_file); return 2

    # chroot scope (from environment)
    try:
        ch_min = int(env.get("CHROOT_MIN","50"))
        ch_max = int(env.get("CHROOT_MAX","79"))
    except Exception:
        ch_min, ch_max = 50, 79
    if not (0 <= ch_min <= 99 and 0 <= ch_max <= 99 and ch_min <= ch_max):
        ch_min, ch_max = 50, 79

    basename = env.get("BASENAME","livermorium")
    #chroot_dir = os.path.join("..","work_build", basename)
    chroot_dir = os.path.join(Path(env["WORK_DIR"]), basename)
    tmp_dir = os.path.join(chroot_dir, "tmp"); os.makedirs(tmp_dir, exist_ok=True)

    # Copy working scripts (to avoid modifying the original)
    #work_scripts_dir = os.path.join("..","work_build","scripts")
    work_scripts_dir = os.path.join(Path(env["WORK_DIR"]),"scripts")
    if os.path.isdir(work_scripts_dir): shutil.rmtree(work_scripts_dir)
    os.makedirs(work_scripts_dir, exist_ok=True)
    shutil.copytree(original_scripts_dir, work_scripts_dir, symlinks=False, dirs_exist_ok=True)

    log(f"[DEBUG] : chroot_dir:{chroot_dir}", log_file)
    log(f"[DEBUG] : tmp_dir:{tmp_dir}", log_file)
    log(f"[DEBUG] : work_scripts_dir:{work_scripts_dir}", log_file)

    # Main targets (RUN_LIST or all) -> sorted numerically
    run_list_csv = env.get("RUN_LIST","")
    allow_names = [x.strip() for x in run_list_csv.split(",") if x.strip()]
    if allow_names:
        # Filter files specified in RUN_LIST that actually exist
        main_targets = _sorted_numeric([n for n in allow_names if os.path.isfile(os.path.join(work_scripts_dir, n))])
    else:
        # Get all valid scripts
        all_files = [f for f in os.listdir(work_scripts_dir) if f.endswith((".sh",".py")) and len(f)>=2 and f[:2].isdigit()]
        main_targets = _sorted_numeric(all_files)

    # PRELUDE (must be run first) -> sorted numerically
    prelude_first = _resolve_patterns(work_scripts_dir, env.get("PRELUDE_FIRST",""))

    # Combine targets (deduplication). Order is prelude -> main, each group sorted numerically.
    seen = set()
    targets: List[str] = []
    for n in prelude_first + main_targets:
        if n not in seen:
            seen.add(n)
            targets.append(n)

    # Finalizers (sorted numerically)
    fin_always  = _resolve_patterns(work_scripts_dir, env.get("FINAL_ALWAYS",""))
    fin_on_fail = _resolve_patterns(work_scripts_dir, env.get("FINAL_ON_FAIL",""))
    fin_on_succ = _resolve_patterns(work_scripts_dir, env.get("FINAL_ON_SUCC",""))
    log(f"[DEBUG] prelude: {prelude_first}", log_file)
    log(f"[DEBUG] finalizers: always={fin_always} fail={fin_on_fail} succ={fin_on_succ}", log_file)

    # Place env.sh inside the chroot environment as well
    env_path = os.path.join(tmp_dir, "env.sh"); _write_env_file(env, env_path)

    def _run_one(filename: str) -> int:
        """★ This is the actual execution body (Popen via bash/python3 or chroot)"""
        script_path = os.path.join(work_scripts_dir, filename)
        if not os.path.isfile(script_path):
            log(f"[WARN] missing: {filename}", log_file); return 0
        try:
            # Extracts the leading number for chroot check
            number = int(filename.split("-")[0])
        except Exception:
            log(f"[WARN] invalid leading number: {filename}", log_file); return 0

        # chroot / host determination
        if ch_min <= number <= ch_max:
            # Copy script to temporary chroot location
            shutil.copy(script_path, os.path.join(tmp_dir, filename))
            # Ensure env.sh is up-to-date in tmp_dir
            _write_env_file(env, env_path)
            if filename.endswith(".sh"):
                # Command to run shell script inside chroot
                cmd = ["/usr/sbin/chroot", chroot_dir, "/bin/bash", "-c",
                       f"set -euo pipefail; cd /tmp && source env.sh && /tmp/{filename}"]
            else:
                # Command to run Python script inside chroot
                cmd = ["/usr/sbin/chroot", chroot_dir, "/usr/bin/python3", "-c",
                       f"import os; exec(open('/tmp/{filename}').read())"]
            where = "CHROOT"
        else:
            # Command to run on the host system
            cmd = ["/bin/bash", script_path] if filename.endswith(".sh") else ["python3", script_path]
            where = "HOST"

        log(f"[RUN:{where}] {' '.join(cmd)}", log_file)
        if dry_run:
            return 0

        try:
            proc = subprocess.Popen(
                cmd,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )
            assert proc.stdout is not None
            # Stream output to log file
            for line in proc.stdout:
                log(line.rstrip("\n"), log_file)
            proc.wait()
            return proc.returncode or 0
        except Exception as e:
            log(f"[ERROR] exception: {filename}: {e}", log_file)
            return 1

    # ===== prelude → main scripts =====
    overall_rc = 0
    executed = []  # List of executed scripts (to prevent double execution by finalizers)
    for filename in targets:
        rc = _run_one(filename)
        executed.append(filename)
        if rc != 0:
            overall_rc = rc
            if not continue_on_error:
                log("[INFO] stop on first error", log_file)
                break

    # ===== finalizers (numeric order, only unexecuted) =====
    def _run_finalizers(cands: List[str]) -> int:
        rc_fin = 0
        for f in cands:
            if f in executed:
                continue
            r = _run_one(f)
            if r != 0 and rc_fin == 0:
                rc_fin = r
        return rc_fin

    if overall_rc != 0:
        # If main execution failed
        rc1 = _run_finalizers(fin_on_fail)
        rc2 = _run_finalizers(fin_always)
        # Final result is the first error code encountered (main or finalizer)
        overall_rc = overall_rc or rc1 or rc2
    else:
        # If main execution succeeded
        rc1 = _run_finalizers(fin_on_succ)
        rc2 = _run_finalizers(fin_always)
        # Return finalizer failure code if any, otherwise 0
        overall_rc = rc1 or rc2  

    if overall_rc == 0:
        log("[INFO] all done", log_file)
    else:
        log(f"[INFO] done with errors (rc={overall_rc})", log_file)
    return overall_rc