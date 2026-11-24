"""Drive the installed probe through its public Android UI."""

import argparse
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

from android_failure_evidence import collect_failure

PACKAGE = "hu.akihabarai.kronikas_platform_probe"
ACTIVITY = f"{PACKAGE}/.MainActivity"


def adb(*args, text=True):
    return subprocess.check_output(["adb", *args], text=text, timeout=30)


def observe(label):
    for _ in range(8):
        adb("shell", "uiautomator", "dump", "/sdcard/kronikas-probe.xml")
        root = ET.fromstring(adb("shell", "cat", "/sdcard/kronikas-probe.xml"))
        for node in root.iter("node"):
            if label in (node.get("text"), node.get("content-desc")):
                print(f"Observed: {label}", flush=True)
                return node
        time.sleep(1)
    raise RuntimeError(f"UI state not observed: {label}")


def tap(label):
    button = observe(label)
    left, top, right, bottom = map(int, re.findall(r"\d+", button.get("bounds")))
    adb("shell", "input", "tap", str((left + right) // 2), str((top + bottom) // 2))


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--evidence", type=Path)
args = parser.parse_args()

try:
    adb("shell", "am", "start", "-W", "-n", ACTIVITY)
    observe("Ready for synthetic probe.")
    tap("Save test data")
    observe("Synthetic chronicle and protected value saved.")
    adb("shell", "am", "force-stop", PACKAGE)
    adb("shell", "am", "start", "-W", "-n", ACTIVITY)
    observe("Ready for synthetic probe.")
    tap("Verify saved data")
    observe("Chronicle and protected value verified.")
except Exception as error:
    if args.evidence:
        collect_failure(adb, PACKAGE, args.evidence, "/sdcard/kronikas-probe.xml", error)
    raise
finally:
    adb("shell", "am", "force-stop", PACKAGE)
    print("Closed the platform probe app.", flush=True)
