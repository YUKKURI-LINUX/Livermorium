import os
import subprocess
import shutil
from builder.logger import log

def write_env_file(env, path):
    """環境変数を.envファイルに書き出す"""
    with open(path, "w") as f:
        for key, value in env.items():
            f.write(f'{key}="{value}"\n')
    
    print(path)

def run_scripts(profile_path, log_file, env):
    original_scripts_dir = os.path.join(profile_path, "scripts")
    if not os.path.isdir(original_scripts_dir):
        log("[ERROR] scripts ディレクトリが見つかりません", log_file)
        return

    basename = env["BASENAME"]
    chroot_dir = os.path.join("../work_build/", basename)
    tmp_dir = os.path.join(chroot_dir, "tmp")
    os.makedirs(tmp_dir, exist_ok=True)

    scripts_dir = os.path.join("../work_build/", "scripts")
    if os.path.isdir(scripts_dir):
        shutil.rmtree(scripts_dir)

    os.makedirs(scripts_dir, exist_ok=True)
    shutil.copytree(original_scripts_dir, scripts_dir, symlinks=False, dirs_exist_ok=True)
    shutil.copytree(os.path.join("./shared_scripts/"), scripts_dir, symlinks=False, dirs_exist_ok=True)

    log(f"[DEBUG] tmp_dir: {tmp_dir}", log_file)
    log(f"[DEBUG] env: {env}", log_file)

    # .env を chroot 用に書き出す
    env_path = os.path.join(tmp_dir, "env.sh")
    write_env_file(env, env_path)
    log(f"[DEBUG] env_path: {env_path}", log_file)

    for filename in sorted(os.listdir(scripts_dir)):
        if filename.startswith(".") or not (filename.endswith(".sh") or filename.endswith(".py")):
            continue

        script_path = os.path.join(scripts_dir, filename)
        script_number = int(filename.split("-")[0])
        log(f"[INFO] 実行中: {filename}", log_file)

        try:
            if 50 <= script_number <= 79:
                # chrootスクリプト
                target_path = os.path.join(tmp_dir, filename)
                shutil.copy(script_path, target_path)
                os.chmod(target_path, 0o755)

                write_env_file(env, env_path)

                if filename.endswith(".sh"):
                    cmd = [
                        "/usr/sbin/chroot", chroot_dir, "/bin/bash",
                        "-c", f"cd /tmp && source env.sh && /tmp/{filename}"
                    ]
                elif filename.endswith(".py"):
                    cmd = [
                        "/usr/sbin/chroot", chroot_dir, "/usr/bin/python3",
                        "-c", f"import os; exec(open('/tmp/{filename}').read())"
                    ]
            else:
                # ホスト側スクリプト
                if filename.endswith(".sh"):
                    cmd = ["/bin/bash", script_path]
                elif filename.endswith(".py"):
                    cmd = ["python3", script_path]
                else:
                    continue

            # リアルタイム出力用に Popen 使用
            process = subprocess.Popen(
                cmd,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )

            for line in process.stdout:
                log(line.rstrip(), log_file)

            process.wait()

            if process.returncode != 0:
                log(f"[ERROR] スクリプト {filename} の実行に失敗", log_file)
                break

        except Exception as e:
            log(f"[ERROR] 実行中に例外発生: {e}", log_file)
            break
