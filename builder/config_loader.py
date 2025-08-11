#!/usr/bin/env python3

import json
import os

def load_config(profile_path):
    path = os.path.join(profile_path, "config.json")
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def load_package_list(profile_path):
    path = os.path.join(profile_path, "packages.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
            return [item["name"] for item in data if item.get("default", False)]
    except Exception as e:
        print(f"[ERROR] パッケージリスト読み込み失敗: {e}")
        return []

def load_flatpak_list(profile_path):
    path = os.path.join(profile_path, "flatpak.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
            return [item["name"] for item in data if item.get("default", False)]
    except Exception as e:
        print(f"[ERROR] Flatpakリスト読み込み失敗: {e}")
        return []
