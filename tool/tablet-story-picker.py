"""Install a commit-pinned ARM64 picker and verify its UI over Wi-Fi ADB."""

import argparse
import hashlib
import re
import subprocess
import time
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

PACKAGE = "hu.akihabarai.kronikas_story_picker_probe"
ACTIVITY = f"{PACKAGE}/hu.akihabarai.kronikas_platform_probe.MainActivity"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path, help="extracted CI artifact")
    parser.add_argument("--commit", required=True)
    parser.add_argument("--device", required=True, help="ADB Wi-Fi endpoint")
    parser.add_argument("--adb", default="adb")
    parser.add_argument("--evidence", required=True, type=Path)
    parser.add_argument("--replace-test-app", action="store_true",
                        help="allow uninstall of this synthetic app if its signature differs")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.commit) or ":" not in args.device:
        parser.error("expected the full commit SHA and an explicit Wi-Fi endpoint")
    apk = args.artifact / "story-picker.apk"
    if (args.artifact / "source-commit.txt").read_text().strip() != args.commit:
        raise RuntimeError("APK source commit does not match the requested commit.")
    expected = (args.artifact / "sha256.txt").read_text().split()[0]
    if file_sha(apk) != expected:
        raise RuntimeError("APK checksum mismatch.")
    with zipfile.ZipFile(apk) as archive:
        abi = {name.split("/")[1] for name in archive.namelist()
               if name.startswith("lib/") and name.endswith(".so")}
        if abi != {"arm64-v8a"}:
            raise RuntimeError(f"Unexpected APK architecture: {abi}")

    def adb(*command, text=True):
        return subprocess.check_output(
            [args.adb, "-s", args.device, *command],
            text=text, encoding="utf-8" if text else None,
            stderr=subprocess.PIPE, timeout=90,
        )

    if adb("get-state").strip() != "device":
        raise RuntimeError("Selected Wi-Fi device is unavailable.")
    if "arm64-v8a" not in adb("shell", "getprop", "ro.product.cpu.abilist").strip().split(","):
        raise RuntimeError("Selected device does not support ARM64.")
    args.evidence.mkdir(parents=True, exist_ok=False)
    try:
        adb("install", "-r", str(apk.resolve()))
    except subprocess.CalledProcessError as failure:
        if not args.replace_test_app or "INSTALL_FAILED_UPDATE_INCOMPATIBLE" not in failure.stderr:
            raise RuntimeError(f"APK installation failed: {failure.stderr.strip()}") from failure
        adb("uninstall", PACKAGE)
        adb("install", str(apk.resolve()))

    package_paths = adb("shell", "pm", "path", PACKAGE).strip().splitlines()
    if len(package_paths) != 1 or not package_paths[0].startswith("package:"):
        raise RuntimeError("Expected one installed base APK for the story picker.")
    installed = args.evidence / "installed.apk"
    try:
        adb("pull", package_paths[0].removeprefix("package:"), str(installed.resolve()))
        if file_sha(installed) != expected:
            raise RuntimeError("Installed APK does not match the CI artifact.")
    finally:
        installed.unlink(missing_ok=True)

    journal = args.evidence / "steps.txt"

    def record(message):
        print(message, flush=True)
        with journal.open("a", encoding="utf-8") as stream:
            stream.write(message + "\n")

    def capture(name):
        png = adb("exec-out", "screencap", "-p", text=False)
        if not png.startswith(b"\x89PNG\r\n\x1a\n"):
            raise RuntimeError("ADB did not return a PNG screenshot.")
        (args.evidence / f"{name}.png").write_bytes(png)

    def observe(label):
        for _ in range(8):
            adb("shell", "uiautomator", "dump", "/sdcard/kronikas-story-picker.xml")
            root = ET.fromstring(adb("shell", "cat", "/sdcard/kronikas-story-picker.xml"))
            for node in root.iter("node"):
                labels = (node.get("text", "") + "\n" + node.get("content-desc", "")).splitlines()
                if label in labels and node.get("package") == PACKAGE:
                    record(f"Observed: {label}")
                    return node
            time.sleep(1)
        capture("unexpected")
        raise RuntimeError(f"UI state not observed: {label}")

    def tap(label):
        node = observe(label)
        left, top, right, bottom = map(int, re.findall(r"\d+", node.get("bounds", "")))
        record(f"Tap: {label}")
        adb("shell", "input", "tap", str((left + right) // 2), str((top + bottom) // 2))

    record(f"Installed commit {args.commit}, APK SHA-256 {expected}")
    adb("shell", "am", "force-stop", PACKAGE)
    try:
        adb("shell", "am", "start", "-W", "-n", ACTIVITY)
        observe("Repó csatlakoztatása")
        capture("01-connect")
        tap("Repó csatlakoztatása")
        observe("Teszt mese")
        capture("02-story-list")
        tap("Teszt mese")
        observe("Szintetikus próbatörténet.")
        capture("03-story-open")
        tap("Vissza a mesékhez")
        observe("Mesék · main")
        capture("04-story-list-return")
    finally:
        adb("shell", "am", "force-stop", PACKAGE)
        record("Closed the story picker app.")


def file_sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


if __name__ == "__main__":
    main()
