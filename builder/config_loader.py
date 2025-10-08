#!/usr/bin/env python3

import json
import os

def load_config(profile_path):
    """
    Loads the configuration from config.json within the specified profile path.
    """
    path = os.path.join(profile_path, "config.json")
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def load_package_list(profile_path):
    """
    Loads the package list from packages.json and returns a list of names
    for items where "default" is True. Prints an error on failure.
    """
    path = os.path.join(profile_path, "packages.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
            # Returns the 'name' of items where 'default' is True
            return [item["name"] for item in data if item.get("default", False)]
    except Exception as e:
        # Prints the English error message to standard output, as in the original code.
        print(f"[ERROR] Failed to load package list: {e}") 
        return []

def load_flatpak_list(profile_path):
    """
    Loads the Flatpak list from flatpak.json and returns a list of names
    for items where "default" is True. Prints an error on failure.
    """
    path = os.path.join(profile_path, "flatpak.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
            # Returns the 'name' of items where 'default' is True
            return [item["name"] for item in data if item.get("default", False)]
    except Exception as e:
        # Prints the English error message to standard output, as in the original code.
        print(f"[ERROR] Failed to load Flatpak list: {e}")
        return []