"""Check the dedicated CI emulator before starting any app assertions."""

import argparse
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

UI_PATH = "/sdcard/kronikas-preflight.xml"


def adb(*args, text=True):
    return subprocess.check_output(["adb", *args], text=text, timeout=30)


def inspect():
    adb("shell", "rm", "-f", UI_PATH)
    adb("shell", "uiautomator", "dump", UI_PATH)
    return adb("exec-out", "cat", UI_PATH, text=False)


def launcher_dialog(xml):
    nodes = list(ET.fromstring(xml).iter("node"))
    if not any(node.get("package") == "android"
               and node.get("resource-id") == "android:id/alertTitle"
               and node.get("text") == "Pixel Launcher isn't responding"
               for node in nodes):
        return None
    for node in nodes:
        if node.get("package") == "android" and node.get("resource-id") == "android:id/aerr_close":
            return node
    raise RuntimeError("Pixel Launcher ANR is visible without its close action.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"emulator-\d+", adb("get-serialno").strip()):
        raise RuntimeError("Android preflight requires a CI emulator.")

    adb("shell", "input", "keyevent", "KEYCODE_WAKEUP")
    adb("shell", "wm", "dismiss-keyguard")
    xml = inspect()
    close = launcher_dialog(xml)
    if close is None:
        print("Android preflight passed.", flush=True)
        return

    args.evidence.mkdir(parents=True, exist_ok=True)
    (args.evidence / "launcher-anr.xml").write_bytes(xml)
    (args.evidence / "launcher-anr.png").write_bytes(
        adb("exec-out", "screencap", "-p", text=False))
    print("Android preflight: closing a confirmed Pixel Launcher ANR before app tests.", flush=True)
    left, top, right, bottom = map(int, re.findall(r"\d+", close.get("bounds", "")))
    adb("shell", "input", "tap", str((left + right) // 2), str((top + bottom) // 2))
    time.sleep(1)
    if launcher_dialog(inspect()) is not None:
        raise RuntimeError("Pixel Launcher ANR persisted after one recovery attempt.")


if __name__ == "__main__":
    main()
