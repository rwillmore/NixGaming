#!/usr/bin/env python3
import json
import os
import signal
import subprocess
import sys
import tempfile
from pathlib import Path

from PyQt6.QtCore import QProcess, QTimer
from PyQt6.QtGui import QAction, QIcon
from PyQt6.QtWidgets import QApplication, QMenu, QMessageBox, QSystemTrayIcon

APP_NAME = "NixUpdate Tray"

# Your flake setup — override via env vars if needed
FLAKE_DIR = Path(os.environ.get("FLAKE_DIR", "/home/rwillmore/NixGaming"))
FLAKE_HOST = os.environ.get("FLAKE_HOST", "gaming")

# 12 hours
CHECK_INTERVAL_MS = 12 * 60 * 60 * 1000

# Delay first auto-check after login for stability
STARTUP_CHECK_DELAY_MS = 2 * 60 * 60 * 1000  # 2 hours

# Avoid hanging checks
CHECK_TIMEOUT_SECONDS = 180

# Generations to keep when garbage collecting
GC_KEEP_GENERATIONS = 5

# Notification icon names to try in order
ICON_NAMES = [
    "system-software-update",
    "software-update-available",
    "update-none",
    "view-refresh",
]

def run_cmd(cmd, cwd=None, timeout=None):
    return subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )

def load_json(path: Path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def lock_nodes(lock_json):
    # flake.lock format: lockFileVersion + nodes
    return lock_json.get("nodes", {})

def summarize_flake_lock_changes(old_lock: Path, new_lock: Path):
    """
    Return a human-readable list of changed flake inputs.
    """
    try:
        oldj = load_json(old_lock)
        newj = load_json(new_lock)
    except Exception as e:
        return False, [f"Could not parse flake lock files: {e}"]

    old_nodes = lock_nodes(oldj)
    new_nodes = lock_nodes(newj)

    changed = []
    all_keys = sorted(set(old_nodes.keys()) | set(new_nodes.keys()))

    for key in all_keys:
        o = old_nodes.get(key)
        n = new_nodes.get(key)

        if o is None:
            changed.append(f"{key}: added")
            continue
        if n is None:
            changed.append(f"{key}: removed")
            continue

        # compare locked revision/version-ish fields
        ol = o.get("locked", {})
        nl = n.get("locked", {})

        if ol != nl:
            old_desc = describe_locked(ol)
            new_desc = describe_locked(nl)
            changed.append(f"{key}: {old_desc} -> {new_desc}")

    return (len(changed) > 0), changed

def describe_locked(locked):
    if not locked:
        return "unknown"
    # Prefer rev, then narHash, then ref, then version
    parts = []
    if "owner" in locked and "repo" in locked:
        parts.append(f"{locked.get('owner')}/{locked.get('repo')}")
    if "ref" in locked:
        parts.append(str(locked["ref"]))
    if "rev" in locked:
        rev = str(locked["rev"])
        parts.append(rev[:12])
    elif "lastModified" in locked:
        parts.append(f"ts:{locked['lastModified']}")
    elif "version" in locked:
        parts.append(str(locked["version"]))
    return " ".join(parts) if parts else "changed"

class NixUpdateTray:
    def __init__(self, app: QApplication):
        self.app = app
        self.tray = QSystemTrayIcon()
        self.menu = QMenu()

        self.check_action = QAction("Check for updates now")
        self.install_action = QAction("Install updates + rebuild + garbage collect")
        self.show_last_action = QAction("Show last check result")
        self.quit_action = QAction("Quit")

        self.check_action.triggered.connect(self.check_updates_manual)
        self.install_action.triggered.connect(self.install_updates)
        self.show_last_action.triggered.connect(self.show_last_result)
        self.quit_action.triggered.connect(self.quit)

        self.menu.addAction(self.check_action)
        self.menu.addAction(self.install_action)
        self.menu.addSeparator()
        self.menu.addAction(self.show_last_action)
        self.menu.addSeparator()
        self.menu.addAction(self.quit_action)

        self.tray.setContextMenu(self.menu)
        self.tray.setIcon(self.choose_icon())
        self.tray.setToolTip(f"{APP_NAME}: idle")

        self.last_check_lines = ["No checks yet."]
        self.last_updates_available = False
        self.check_running = False

        self.timer = QTimer()
        self.timer.setInterval(CHECK_INTERVAL_MS)
        self.timer.timeout.connect(self.check_updates_timer)

    def choose_icon(self):
        for name in ICON_NAMES:
            icon = QIcon.fromTheme(name)
            if not icon.isNull():
                return icon
        return self.app.style().standardIcon(self.app.style().StandardPixmap.SP_BrowserReload)

    def start(self):
        if not FLAKE_DIR.exists() or not (FLAKE_DIR / "flake.nix").exists():
            QMessageBox.critical(
                None,
                APP_NAME,
                f"Flake directory not found or invalid:\n{FLAKE_DIR}\n\n"
                "Edit FLAKE_DIR in the script."
            )
            sys.exit(1)

        self.tray.show()
        self.timer.start()

        # Delay first automatic check after login to reduce session startup load
        QTimer.singleShot(STARTUP_CHECK_DELAY_MS, self.check_updates_timer)
        self.notify(
            "Started",
            "Will check for flake updates every 12 hours. First auto-check is delayed after login."
        )

    def set_status(self, text):
        self.tray.setToolTip(f"{APP_NAME}: {text}")

    def notify(self, title, message):
        # Native tray notification
        self.tray.showMessage(title, message, QSystemTrayIcon.MessageIcon.Information, 10000)

    def warn(self, title, message):
        self.tray.showMessage(title, message, QSystemTrayIcon.MessageIcon.Warning, 12000)

    def error(self, title, message):
        self.tray.showMessage(title, message, QSystemTrayIcon.MessageIcon.Critical, 15000)

    def check_updates_timer(self):
        self.check_updates(manual=False)

    def check_updates_manual(self):
        self.check_updates(manual=True)

    def check_updates(self, manual=False):
        if self.check_running:
            if manual:
                self.warn("Check already running", "A check is already in progress.")
            return

        self.check_running = True
        self.set_status("checking for updates...")

        try:
            updates_available, lines = self._check_flake_updates()
            self.last_updates_available = updates_available
            self.last_check_lines = lines

            if updates_available:
                self.set_status("updates available")
                summary = lines[0] if lines else "Updates found."
                self.notify("Nix updates available", summary)
            else:
                self.set_status("up to date")
                if manual:
                    self.notify("Nix updates", "No updates available.")
        except subprocess.TimeoutExpired:
            self.last_updates_available = False
            self.last_check_lines = [f"Check timed out after {CHECK_TIMEOUT_SECONDS}s."]
            self.set_status("check timed out")
            if manual:
                self.error("Nix update check failed", self.last_check_lines[0])
        except Exception as e:
            self.last_updates_available = False
            self.last_check_lines = [f"Check failed: {e}"]
            self.set_status("check failed")
            if manual:
                self.error("Nix update check failed", str(e))
        finally:
            self.check_running = False

    def _check_flake_updates(self):
        """
        Check updates without modifying the real flake.lock.
        Strategy:
          1. Generate a temporary updated lock file
          2. Compare it against current flake.lock
          3. Summarize changed inputs
        """
        current_lock = FLAKE_DIR / "flake.lock"
        if not current_lock.exists():
            return False, ["No flake.lock found in flake directory."]

        fd, tmp_path_str = tempfile.mkstemp(prefix="flake.lock.nixupdate.", suffix=".new")
        os.close(fd)
        tmp_path = Path(tmp_path_str)

        try:
            # Create a temp lock file candidate
            # We use --output-lock-file so the real lock file is untouched.
            cmd = [
                "nix", "flake", "update",
                "--output-lock-file", str(tmp_path),
            ]
            proc = run_cmd(cmd, cwd=FLAKE_DIR, timeout=CHECK_TIMEOUT_SECONDS)
            if proc.returncode != 0:
                msg = (proc.stderr or proc.stdout or "Unknown nix flake update error").strip()
                return False, [f"nix flake update check failed: {msg}"]

            updates_available, changes = summarize_flake_lock_changes(current_lock, tmp_path)

            if updates_available:
                top = f"{len(changes)} flake input update(s) available"
                # Show a short list in notifications and full list in dialog
                display = [top] + changes[:50]
                return True, display
            else:
                return False, ["No flake input updates found."]
        finally:
            try:
                tmp_path.unlink(missing_ok=True)
            except Exception:
                pass

    def show_last_result(self):
        text = "\n".join(self.last_check_lines[:200])
        QMessageBox.information(None, "Last Nix Update Check", text)

    def install_updates(self):
        if self.check_running:
            self.warn("Busy", "Wait for the current check to finish.")
            return

        reply = QMessageBox.question(
            None,
            "Install updates",
            "This will:\n"
            "1. Update flake inputs\n"
            "2. Run nixos-rebuild switch\n"
            f"3. Run nixgarbage (keep {GC_KEEP_GENERATIONS} generations)\n\n"
            "Continue?"
        )
        if reply != QMessageBox.StandardButton.Yes:
            return

        self.set_status("launching install in terminal...")

        # Heavy work runs in terminal, not inside the tray process.
        # This keeps the tray app light and reduces Plasma instability risk.
        script = f"""set -euo pipefail
cd "{FLAKE_DIR}"
echo "== Updating flake inputs =="
nix flake update
echo
echo "== Rebuilding and switching =="
sudo nixos-rebuild switch --flake "{FLAKE_DIR}#{FLAKE_HOST}"
echo
echo "== Garbage collection =="
nixgarbage {GC_KEEP_GENERATIONS}
echo
echo "Done."
read -rp "Press Enter to close..."
"""

        # Prefer Konsole on KDE. Fallback to xterm if installed.
        terminals = [
            ["konsole", "-e", "bash", "-lc", script],
            ["xterm", "-e", "bash", "-lc", script],
        ]

        launched = False
        for cmd in terminals:
            try:
                p = subprocess.Popen(cmd)
                if p.pid:
                    launched = True
                    break
            except FileNotFoundError:
                continue
            except Exception as e:
                self.error("Terminal launch failed", str(e))
                return

        if launched:
            self.notify("Nix update install", "Opened terminal for update and rebuild.")
            self.set_status("idle")
        else:
            self.error("No terminal found", "Install Konsole or xterm.")
            self.set_status("idle")

    def quit(self):
        self.timer.stop()
        self.tray.hide()
        self.app.quit()

def main():
    # Make Ctrl+C behave if run from terminal
    signal.signal(signal.SIGINT, signal.SIG_DFL)

    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)

    tray = NixUpdateTray(app)
    tray.start()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
