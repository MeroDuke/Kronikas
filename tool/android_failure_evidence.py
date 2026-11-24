"""Collect diagnostics from the synthetic Android probes before app shutdown."""

import re
import subprocess


def collect_failure(adb, package, evidence, ui_path, error):
    def collect(name, command):
        try:
            evidence.mkdir(parents=True, exist_ok=True)
            (evidence / name).write_bytes(command())
        except (OSError, subprocess.SubprocessError, ValueError) as failure:
            print(f"Could not collect {name}: {failure}", flush=True)

    def ui_tree():
        adb("shell", "uiautomator", "dump", ui_path)
        return adb("exec-out", "cat", ui_path, text=False)

    def app_log():
        packages = adb("shell", "cmd", "package", "list", "packages", "-U", package)
        match = re.search(rf"^package:{re.escape(package)}\s+uid:(\d+)\s*$", packages, re.M)
        if not match:
            raise ValueError("Synthetic app UID unavailable.")
        return adb("logcat", "-d", "-t", "300", "--uid=" + match[1], text=False)

    collect("failure.txt", lambda: f"{type(error).__name__}: {error}\n".encode("utf-8"))
    collect("unexpected.png", lambda: adb("exec-out", "screencap", "-p", text=False))
    collect("failure-ui.xml", ui_tree)
    collect("failure-logcat.txt", app_log)
