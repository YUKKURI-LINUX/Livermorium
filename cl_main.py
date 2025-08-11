#!/usr/bin/env python3
import os
import sys
from datetime import datetime
from builder import executor, logger
from builder.config_loader import load_config, load_package_list, load_flatpak_list

def main():
    if len(sys.argv) < 2:
        print("使い方: sudo python3 cl_main.py <プロファイル名>")
        sys.exit(1)

    profile_name = sys.argv[1]
    profile_path = os.path.join("profiles", profile_name)
    if not os.path.isdir(profile_path):
        print(f"[ERROR] プロファイルが見つかりません: {profile_name}")
        sys.exit(1)

    # 各種設定を読み込み
    config = load_config(profile_path)
    packages_list = load_package_list(profile_path)
    flatpak_list = load_flatpak_list(profile_path)

    # user セクション取得
    user_config = config.get("user", {})

    # 環境変数にセット
    env = {
        "USERNAME": user_config.get("name", ""),
        "PASSWORD": user_config.get("password", ""),
        "LOCALE": config.get("locale", "ja_JP.UTF-8"),
        "TIMEZONE": config.get("timezone", "Asia/Tokyo"),
        "KEYBOARD": config.get("keyboard", "jp"),
        "USER_GROUPS": " ".join(user_config.get("groups", [])),
        "AUTOLOGIN": str(user_config.get("autologin", True)).lower(),
        "DISABLE_ROOT": str(user_config.get("disable_root", True)).lower(),
        "PACKAGE_LIST": " ".join(packages_list),
        "FLATPAK_LIST": " ".join(flatpak_list),
        "BASENAME": config.get("basename", profile_name),
        "PROFILENAME": profile_name
    }

    # logs ディレクトリ作成 & ログファイル名生成
    logs = os.path.join("..","work_build","logs")
    os.makedirs(logs, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    log_file = os.path.join(logs, f"{profile_name}_{env['BASENAME']}_{timestamp}.log")

    logger.log(f"[INFO] プロファイル '{profile_name}' のビルドを開始", log_file)

    # 実行
    executor.run_scripts(profile_path, log_file, env)

if __name__ == "__main__":
    main()
