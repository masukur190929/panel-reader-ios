#!/usr/bin/env python3
"""Validate the supplied App Store profile and generate export settings."""
import datetime
import os
from pathlib import Path
import plistlib

profile = plistlib.loads(Path("build/profile.plist").read_bytes())
bundle = os.environ["BUNDLE_ID"]
team = os.environ["APPLE_TEAM_ID"]
entitlements = profile.get("Entitlements", {})
if team not in profile.get("TeamIdentifier", []):
    raise SystemExit("The provisioning profile belongs to a different Apple team.")
if not entitlements.get("application-identifier", "").endswith("." + bundle):
    raise SystemExit("The provisioning profile does not match BUNDLE_ID.")
if profile.get("ProvisionedDevices") or profile.get("ProvisionsAllDevices") or entitlements.get("get-task-allow"):
    raise SystemExit("Use an App Store distribution profile, not a development or Ad Hoc profile.")
expires = profile.get("ExpirationDate")
if expires is None or expires.replace(tzinfo=datetime.timezone.utc) <= datetime.datetime.now(datetime.timezone.utc):
    raise SystemExit("The provisioning profile has expired.")
options = {
    "method": "app-store-connect", "teamID": team, "signingStyle": "manual",
    "signingCertificate": "Apple Distribution", "provisioningProfiles": {bundle: profile["Name"]},
    "uploadSymbols": True,
}
Path("build/ExportOptions.plist").write_bytes(plistlib.dumps(options))
with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as output:
    if any(character in profile["Name"] for character in "\r\n"):
        raise SystemExit("Unexpected newline in provisioning profile name.")
    output.write("PANEL_PROFILE_NAME=" + profile["Name"] + "\n")
print("App Store profile validated; export settings generated.")
