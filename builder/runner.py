#!/usr/bin/env python3

from builder.executor import run_scripts

def run(profile_path, log_file, env):
    run_scripts(profile_path, log_file, env)
