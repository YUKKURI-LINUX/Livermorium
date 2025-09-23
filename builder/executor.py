# -*- coding: utf-8 -*-
from __future__ import annotations
import os, fnmatch, subprocess, shutil
from typing import Dict, Iterable, List, Optional
from builder.logger import log
from pathlib import Path

def _num_key(name: str):
    return (name[:2], name)

def _sorted_numeric(files: Iterable[str]) -> List[str]:
    files = [f for f in files if len(f) >= 2 and f[:2].isdigit()]
    files.sort(key=_num_key)
    return files

def _write_env_file(env: Dict[str, str], path: str) -> None:
    with open(path, "w") as f:
        for k, v in env.items():
            f.write(f'{k}="{v}"\n')

def _resolve_patterns(scripts_dir: str, patterns_csv: str) -> List[str]:
    """CSVのパターン/ファイル名 → 実在ファイルを収集して番号順に整列"""
    names = [x.strip() for x in (patterns_csv or "").split(",") if x.strip()]
    if not names:
        return []
    all_files = [f for f in os.listdir(scripts_dir) if f.endswith((".sh",".py")) and len(f)>=2 and f[:2].isdigit()]
    matched = set()
    for n in names:
        if any(ch in n for ch in "*?[]"):
            matched.update(fnmatch.filter(all_files, n))
        else:
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

    # chroot 範囲（環境から）
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

    # 作業用 scripts をコピー（元を汚さない）
    #work_scripts_dir = os.path.join("..","work_build","scripts")
    work_scripts_dir = os.path.join(Path(env["WORK_DIR"]),"scripts")
    if os.path.isdir(work_scripts_dir): shutil.rmtree(work_scripts_dir)
    os.makedirs(work_scripts_dir, exist_ok=True)
    shutil.copytree(original_scripts_dir, work_scripts_dir, symlinks=False, dirs_exist_ok=True)

    log(f"[DEBUG] : chroot_dir:{chroot_dir}", log_file)
    log(f"[DEBUG] : tmp_dir:{tmp_dir}", log_file)
    log(f"[DEBUG] : work_scripts_dir:{work_scripts_dir}", log_file)

    # 本編ターゲット（RUN_LIST or 全部）→番号順
    run_list_csv = env.get("RUN_LIST","")
    allow_names = [x.strip() for x in run_list_csv.split(",") if x.strip()]
    if allow_names:
        main_targets = _sorted_numeric([n for n in allow_names if os.path.isfile(os.path.join(work_scripts_dir, n))])
    else:
        all_files = [f for f in os.listdir(work_scripts_dir) if f.endswith((".sh",".py")) and len(f)>=2 and f[:2].isdigit()]
        main_targets = _sorted_numeric(all_files)

    # PRELUDE（先頭必須）→ 番号順
    prelude_first = _resolve_patterns(work_scripts_dir, env.get("PRELUDE_FIRST",""))

    # ターゲット結合（重複除外）。順序は prelude→本編、各群は番号昇順。
    seen = set()
    targets: List[str] = []
    for n in prelude_first + main_targets:
        if n not in seen:
            seen.add(n)
            targets.append(n)

    # finalizers（番号順）
    fin_always  = _resolve_patterns(work_scripts_dir, env.get("FINAL_ALWAYS",""))
    fin_on_fail = _resolve_patterns(work_scripts_dir, env.get("FINAL_ON_FAIL",""))
    fin_on_succ = _resolve_patterns(work_scripts_dir, env.get("FINAL_ON_SUCC",""))
    log(f"[DEBUG] prelude: {prelude_first}", log_file)
    log(f"[DEBUG] finalizers: always={fin_always} fail={fin_on_fail} succ={fin_on_succ}", log_file)

    # env.sh を chroot 側にも配置
    env_path = os.path.join(tmp_dir, "env.sh"); _write_env_file(env, env_path)

    def _run_one(filename: str) -> int:
        """★ ここが実際の実行本体（bash/python3 or chroot 経由で Popen）"""
        script_path = os.path.join(work_scripts_dir, filename)
        if not os.path.isfile(script_path):
            log(f"[WARN] missing: {filename}", log_file); return 0
        try:
            number = int(filename.split("-")[0])
        except Exception:
            log(f"[WARN] invalid leading number: {filename}", log_file); return 0

        # chroot / host 判定
        if ch_min <= number <= ch_max:
            shutil.copy(script_path, os.path.join(tmp_dir, filename))
            _write_env_file(env, env_path)
            if filename.endswith(".sh"):
                cmd = ["/usr/sbin/chroot", chroot_dir, "/bin/bash", "-c",
                       f"set -euo pipefail; cd /tmp && source env.sh && /tmp/{filename}"]
            else:
                cmd = ["/usr/sbin/chroot", chroot_dir, "/usr/bin/python3", "-c",
                       f"import os; exec(open('/tmp/{filename}').read())"]
            where = "CHROOT"
        else:
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
            for line in proc.stdout:
                log(line.rstrip("\n"), log_file)
            proc.wait()
            return proc.returncode or 0
        except Exception as e:
            log(f"[ERROR] exception: {filename}: {e}", log_file)
            return 1

    # ===== prelude → 本編 =====
    overall_rc = 0
    executed = []  # 実行済み（finalizersの二重実行防止）
    for filename in targets:
        rc = _run_one(filename)
        executed.append(filename)
        if rc != 0:
            overall_rc = rc
            if not continue_on_error:
                log("[INFO] stop on first error", log_file)
                break

    # ===== finalizers（番号順、未実行のみ）=====
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
        rc1 = _run_finalizers(fin_on_fail)
        rc2 = _run_finalizers(fin_always)
        overall_rc = overall_rc or rc1 or rc2
    else:
        rc1 = _run_finalizers(fin_on_succ)
        rc2 = _run_finalizers(fin_always)
        overall_rc = rc1 or rc2  # 本編成功時はファイナライザの失敗を返す

    if overall_rc == 0:
        log("[INFO] all done", log_file)
    else:
        log(f"[INFO] done with errors (rc={overall_rc})", log_file)
    return overall_rc
