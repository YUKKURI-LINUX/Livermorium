#!/usr/bin/env python3
import time

def log(message, file):
    timestamp = time.strftime("[%Y-%m-%d %H:%M:%S]")
    line = f"{timestamp} {message}\n"
    print(line, end="")
    with open(file, "a", encoding="utf-8") as f:
        f.write(line)
