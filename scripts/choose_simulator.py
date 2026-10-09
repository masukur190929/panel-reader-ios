#!/usr/bin/env python3
"""Choose an available iPhone simulator, without hard-coding a model name."""
import json
import re
import subprocess

data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"]))
runtimes = sorted(
    (key for key in data["devices"] if "iOS" in key),
    key=lambda key: tuple(int(number) for number in re.findall(r"\d+", key)), reverse=True,
)
for runtime in runtimes:
    phones = [device for device in data["devices"][runtime]
              if device.get("isAvailable") and device["name"].startswith("iPhone")]
    if phones:
        print(phones[0]["udid"])
        break
else:
    raise SystemExit("No available iPhone simulator found on this runner.")
