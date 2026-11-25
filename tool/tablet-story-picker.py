"""Install a commit-pinned picker and verify its UI on an explicit ADB device."""

import argparse
import hashlib
import re
import subprocess
import time
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

from android_failure_evidence import collect_failure

PACKAGE = "hu.akihabarai.kronikas_story_picker_probe"
ACTIVITY = f"{PACKAGE}/hu.akihabarai.kronikas_platform_probe.MainActivity"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path, help="extracted CI artifact")
    parser.add_argument("--commit", required=True)
    parser.add_argument("--device", required=True, help="ADB Wi-Fi endpoint or emulator serial")
    parser.add_argument("--abi", choices=("arm64-v8a", "x86_64"), default="arm64-v8a")
    parser.add_argument("--adb", default="adb")
    parser.add_argument("--evidence", required=True, type=Path)
    conflict_mode = parser.add_mutually_exclusive_group()
    conflict_mode.add_argument("--conflict", action="store_true", help="exercise full synthetic conflict resolution")
    conflict_mode.add_argument("--conflict-smoke", action="store_true", help="resolve one synthetic conflict")
    parser.add_argument("--replace-test-app", action="store_true",
                        help="allow uninstall of this synthetic app if its signature differs")
    args = parser.parse_args()
    if (not re.fullmatch(r"[0-9a-f]{40}", args.commit) or
            (":" not in args.device and not re.fullmatch(r"emulator-\d+", args.device))):
        parser.error("expected the full commit SHA and an explicit Wi-Fi or emulator endpoint")
    apk = args.artifact / "story-picker.apk"
    if (args.artifact / "source-commit.txt").read_text().strip() != args.commit:
        raise RuntimeError("APK source commit does not match the requested commit.")
    expected = (args.artifact / "sha256.txt").read_text().split()[0]
    if file_sha(apk) != expected:
        raise RuntimeError("APK checksum mismatch.")
    with zipfile.ZipFile(apk) as archive:
        abi = {name.split("/")[1] for name in archive.namelist()
               if name.startswith("lib/") and name.endswith(".so")}
        if abi != {args.abi}:
            raise RuntimeError(f"Unexpected APK architecture: {abi}")

    def adb(*command, text=True):
        return subprocess.check_output(
            [args.adb, "-s", args.device, *command],
            text=text, encoding="utf-8" if text else None,
            stderr=subprocess.PIPE, timeout=90,
        )

    if adb("get-state").strip() != "device":
        raise RuntimeError("Selected ADB device is unavailable.")
    if args.abi not in adb("shell", "getprop", "ro.product.cpu.abilist").strip().split(","):
        raise RuntimeError(f"Selected device does not support {args.abi}.")
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
    package = adb("shell", "dumpsys", "package", PACKAGE)
    if not re.search(rf"(?m)^\s*primaryCpuAbi={re.escape(args.abi)}\s*$", package):
        raise RuntimeError(f"Android did not select the expected ABI: {args.abi}.")
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

    def observe(label, *, scroll=False, resource_id=None):
        for attempt in range(12 if scroll else 8):
            adb("shell", "uiautomator", "dump", "/sdcard/kronikas-story-picker.xml")
            root = ET.fromstring(adb("shell", "cat", "/sdcard/kronikas-story-picker.xml"))
            for node in root.iter("node"):
                labels = (node.get("text", "") + "\n" + node.get("content-desc", "")).splitlines()
                matched = (node.get("resource-id") == resource_id
                           if resource_id is not None else label in labels)
                if matched and node.get("package") == PACKAGE:
                    record(f"Observed: {label}")
                    return node
            if scroll:
                size = re.findall(r"(\d+)x(\d+)", adb("shell", "wm", "size"))
                width, height = map(int, size[-1])
                top, bottom = height * 4 // 10, height * 7 // 10
                start, end = (bottom, top) if attempt < 5 else (top, bottom)
                adb("shell", "input", "swipe", str(width // 2), str(start),
                    str(width // 2), str(end), "320")
            time.sleep(1)
        raise RuntimeError(f"UI state not observed: {label}")

    def tap(label, *, scroll=False, resource_id=None):
        node = observe(label, scroll=scroll, resource_id=resource_id)
        left, top, right, bottom = map(int, re.findall(r"\d+", node.get("bounds", "")))
        record(f"Tap: {label}")
        adb("shell", "input", "tap", str((left + right) // 2), str((top + bottom) // 2))

    record(f"Installed commit {args.commit}, ABI {args.abi}, APK SHA-256 {expected}")
    adb("shell", "am", "force-stop", PACKAGE)
    try:
        adb("shell", "am", "start", "-W", "-n", ACTIVITY)
        observe("Teszt mese")
        capture("02-story-list")
        tap("Teszt mese")
        observe("Szintetikus próbatörténet.")
        capture("03-story-open")
        tap("Lezárt játékalkalom")
        observe("A csapat átkelt a folyón.")
        observe("Csak a mesélőnek")
        capture("04-session-history")
        if args.conflict or args.conflict_smoke:
            tap("Lezárt játékalkalom")
            tap("Mese szinkronizálása", scroll=True)
            observe("Helyi: Helyi átkelés", scroll=True)
            observe("Távoli: Távoli átkelés", scroll=True)
            if args.conflict:
                tap("Helyi érték", scroll=True)
                observe("Kiválasztva: Helyi átkelés", scroll=True)
                capture("06-conflict-values")
                tap("Szimulált távoli módosítás", scroll=True)
                tap("Feloldás mentése", scroll=True)
                observe("A változatok frissültek. Erősítsd meg újra.", scroll=True)
                observe("Távoli: Friss távoli átkelés", scroll=True)
            tap("Új érték", scroll=True, resource_id="conflict-value-adventures/synthetic/title")
            adb("shell", "input", "text", "Merged%stitle")
            adb("shell", "input", "keyevent", "4")
            observe("Kiválasztva: Merged title", scroll=True)
            tap("Feloldás mentése", scroll=True)
            observe("A feloldás mentve.", scroll=True)
            observe("Merged title", scroll=True)
            capture("06-resolution-saved")
            if args.conflict:
                tap("Eredeti helyi változat megnyitása", scroll=True)
                observe("Visszaállított példány: Helyi átkelés", scroll=True)
                capture("07-original-local")
                tap("Eredeti távoli változat megnyitása", scroll=True)
                observe("Visszaállított példány: Friss távoli átkelés", scroll=True)
                capture("08-original-remote")
        tap("Vissza a mesékhez", scroll=args.conflict or args.conflict_smoke)
        observe("Mesék")
        capture("05-story-list-return")
    except Exception as error:
        collect_failure(adb, PACKAGE, args.evidence, "/sdcard/kronikas-story-picker.xml", error)
        raise
    finally:
        adb("shell", "am", "force-stop", PACKAGE)
        record("Closed the story picker app.")


def file_sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


if __name__ == "__main__":
    main()
