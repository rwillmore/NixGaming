import os
import sys
import shlex
import time
import signal
import hashlib
import subprocess
from pathlib import Path

from PyQt6.QtCore import QTimer, Qt, QUrl
from PyQt6.QtGui import QAction, QIcon, QPixmap, QPainter, QFont, QDesktopServices
from PyQt6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

APP_NAME = "NixOS Update Tray"

DEFAULT_REPO = Path(os.environ.get("NIXTRAY_REPO", "/home/rwillmore/NixGaming"))
DEFAULT_HOST = os.environ.get("NIXTRAY_HOST", "gaming")
DEFAULT_LOG = Path(os.environ.get("NIXTRAY_LOG", str(Path.home() / ".cache" / "nixtray.log")))
DEFAULT_CACHE_DIR = Path(os.environ.get("NIXTRAY_CACHE_DIR", str(DEFAULT_REPO / ".cache" / "nixtray")))
DEFAULT_KEEP = os.environ.get("NIXTRAY_KEEP_LOCK", "1") == "1"
DEFAULT_DEBUG = os.environ.get("NIXTRAY_DEBUG", "0") == "1"

# Boring reliability: use absolute binaries from the running system
NIX = os.environ.get("NIXTRAY_NIX", "/run/current-system/sw/bin/nix")
BASH = os.environ.get("NIXTRAY_BASH", "/run/current-system/sw/bin/bash")
PKEXEC = os.environ.get("NIXTRAY_PKEXEC", "/run/wrappers/bin/pkexec")
NIXOS_REBUILD = os.environ.get("NIXTRAY_NIXOS_REBUILD", "/run/current-system/sw/bin/nixos-rebuild")

# Track a currently running child process group so SIGTERM can kill it
_ACTIVE_PGID: int | None = None


def now_ts() -> str:
    return time.strftime("%Y-%m-%d %H:%M:%S")


def ensure_parent(p: Path) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)


def append_log(log_path: Path, text: str) -> None:
    ensure_parent(log_path)
    with log_path.open("a", encoding="utf-8") as f:
        f.write(text)
        if not text.endswith("\n"):
            f.write("\n")


def log_block(log_path: Path, title: str, lines: list[str]) -> None:
    append_log(log_path, "")
    append_log(log_path, f"=== {title} ({now_ts()}) ===")
    for ln in lines:
        append_log(log_path, ln)


def _kill_active_process_group(log_path: Path) -> None:
    global _ACTIVE_PGID
    if _ACTIVE_PGID is None:
        return
    pgid = _ACTIVE_PGID
    _ACTIVE_PGID = None
    try:
        log_block(log_path, "Shutdown", [f"Killing active process group pgid={pgid}"])
        os.killpg(pgid, signal.SIGTERM)
        time.sleep(0.5)
        try:
            os.killpg(pgid, signal.SIGKILL)
        except Exception:
            pass
    except Exception as e:
        log_block(log_path, "Shutdown", [f"Failed to kill pgid={pgid}", repr(e)])


def run_cmd(
    log_path: Path,
    cmd: list[str],
    cwd: Path | None = None,
    env: dict | None = None,
    timeout: int | None = None,
) -> tuple[int, str, str]:
    """
    Runs a command without freezing shutdown forever:
    - uses Popen
    - creates a new process group so SIGTERM can kill the whole tree
    - optional timeout
    """
    global _ACTIVE_PGID

    cmd_str = " ".join(shlex.quote(c) for c in cmd)
    log_block(
        log_path,
        "Command",
        [
            f"cwd: {str(cwd) if cwd else os.getcwd()}",
            f"cmd: {cmd_str}",
            f"timeout: {timeout if timeout is not None else 'none'}",
        ],
    )

    try:
        p = subprocess.Popen(
            cmd,
            cwd=str(cwd) if cwd else None,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            start_new_session=True,
        )
        _ACTIVE_PGID = p.pid

        try:
            out, err = p.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            log_block(log_path, "Timeout", [f"Command exceeded timeout, killing pgid={_ACTIVE_PGID}"])
            _kill_active_process_group(log_path)
            return 124, "", "timeout"
        finally:
            _ACTIVE_PGID = None

        rc = p.returncode
        out = out or ""
        err = err or ""
        log_block(
            log_path,
            "Result",
            [
                f"returncode: {rc}",
                f"stdout:\n{out.rstrip()}",
                f"stderr:\n{err.rstrip()}",
            ],
        )
        return rc, out, err

    except Exception as e:
        _ACTIVE_PGID = None
        log_block(log_path, "Exception", [repr(e)])
        return 999, "", repr(e)


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def notify(title: str, body: str, urgency: str = "normal") -> None:
    notify_send = "/run/current-system/sw/bin/notify-send"
    if not Path(notify_send).exists():
        return
    try:
        subprocess.run([notify_send, "--urgency", urgency, title, body], check=False)
    except Exception:
        pass


def open_log(log_path: Path) -> None:
    # Prefer Qt desktop integration (best behavior from systemd user services)
    try:
        ok = QDesktopServices.openUrl(QUrl.fromLocalFile(str(log_path)))
        if ok:
            return
    except Exception:
        pass

    # Fallbacks
    for exe in ("/run/current-system/sw/bin/kde-open5", "/run/current-system/sw/bin/xdg-open"):
        try:
            if Path(exe).exists():
                subprocess.run([exe, str(log_path)], check=False)
                return
        except Exception:
            continue


def _fallback_icon(letter: str = "N") -> QIcon:
    pm = QPixmap(64, 64)
    pm.fill(Qt.GlobalColor.transparent)
    painter = QPainter(pm)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    painter.fillRect(0, 0, 64, 64, Qt.GlobalColor.black)
    painter.setPen(Qt.GlobalColor.white)
    font = QFont()
    font.setBold(True)
    font.setPointSize(28)
    painter.setFont(font)
    painter.drawText(pm.rect(), Qt.AlignmentFlag.AlignCenter, letter)
    painter.end()
    return QIcon(pm)


def _theme_icon(names: list[str], fallback_letter: str) -> QIcon:
    for n in names:
        ico = QIcon.fromTheme(n)
        if not ico.isNull():
            return ico
    return _fallback_icon(fallback_letter)


class NixTray(QSystemTrayIcon):
    def __init__(self, repo: Path, host: str, log_path: Path, cache_dir: Path, keep_lock: bool, debug: bool):
        super().__init__()
        self.repo = repo
        self.host = host
        self.log_path = log_path
        self.cache_dir = cache_dir
        self.keep_lock = keep_lock
        self.debug = debug

        self._busy = False
        self._last_check_ts: str | None = None
        self._last_result: str = "Ready"

        # Better icon reliability on minimal icon themes
        self.icon_ok = _theme_icon(["emblem-default", "dialog-information", "help-about"], "N")
        self.icon_updates = _theme_icon(["software-update-available", "system-software-update", "view-refresh"], "U")
        self.icon_busy = _theme_icon(["view-refresh", "process-working", "system-run"], "R")
        self.icon_fail = _theme_icon(["dialog-error", "emblem-important", "process-stop"], "X")

        self.setIcon(self.icon_ok)

        self.menu = QMenu()

        self.act_status = QAction("Status: Ready")
        self.act_status.setEnabled(False)

        self.act_check = QAction("Check for updates")
        self.act_check.triggered.connect(self.check_updates)

        self.act_sync_apply = QAction("Sync + Apply")
        self.act_sync_apply.triggered.connect(self.sync_apply)

        self.act_check_sync_apply = QAction("Check then Sync + Apply")
        self.act_check_sync_apply.triggered.connect(self.check_then_sync_apply)

        self.act_open_repo = QAction("Open repo folder")
        self.act_open_repo.triggered.connect(self.open_repo)

        self.act_open_log = QAction("Open log")
        self.act_open_log.triggered.connect(lambda: open_log(self.log_path))

        self.act_about = QAction("About")
        self.act_about.triggered.connect(self.about)

        self.act_quit = QAction("Quit")
        self.act_quit.triggered.connect(QApplication.instance().quit)

        self.menu.addAction(self.act_status)
        self.menu.addSeparator()
        self.menu.addAction(self.act_check)
        self.menu.addSeparator()
        self.menu.addAction(self.act_sync_apply)
        self.menu.addAction(self.act_check_sync_apply)
        self.menu.addSeparator()
        self.menu.addAction(self.act_open_repo)
        self.menu.addAction(self.act_open_log)
        self.menu.addAction(self.act_about)
        self.menu.addSeparator()
        self.menu.addAction(self.act_quit)

        self.setContextMenu(self.menu)

        log_block(
            self.log_path,
            "Startup",
            [
                f"repo: {self.repo}",
                f"host: {self.host}",
                f"log: {self.log_path}",
                f"cache_dir: {self.cache_dir}",
                f"keep_lock: {self.keep_lock}",
                f"debug: {self.debug}",
                f"NIX: {NIX}",
                f"BASH: {BASH}",
                f"PKEXEC: {PKEXEC}",
                f"NIXOS_REBUILD: {NIXOS_REBUILD}",
                f"TMPDIR: {os.environ.get('TMPDIR','')}",
            ],
        )

        self._set_status(self.icon_ok, "Ready")
        self.show()

        # Initial check (don’t do it immediately at startup)
        QTimer.singleShot(1200, self.check_updates)

    def _set_busy(self, busy: bool) -> None:
        self._busy = busy
        self.act_check.setEnabled(not busy)
        self.act_sync_apply.setEnabled(not busy)
        self.act_check_sync_apply.setEnabled(not busy)
        self.act_open_repo.setEnabled(not busy)
        self.act_open_log.setEnabled(True)
        self.act_about.setEnabled(True)
        self.act_quit.setEnabled(True)

    def _update_status_line(self, text: str) -> None:
        self._last_result = text
        if self._last_check_ts:
            self.act_status.setText(f"Status: {text} (last check {self._last_check_ts})")
        else:
            self.act_status.setText(f"Status: {text}")

        tip = text
        if self._last_check_ts:
            tip = f"{text}\nLast check: {self._last_check_ts}\nRepo: {self.repo}"
        else:
            tip = f"{text}\nRepo: {self.repo}"
        self.setToolTip(tip)

    def _set_status(self, icon: QIcon, tooltip: str) -> None:
        self.setIcon(icon)
        self._update_status_line(tooltip)

    def _lock_paths(self) -> tuple[Path, Path]:
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        new_lock = self.cache_dir / "flake.lock.nixtray.new"
        stamp_lock = self.cache_dir / f"flake.lock.nixtray.{int(time.time())}.new"
        return new_lock, stamp_lock

    def _nix_env(self) -> dict:
        env = dict(os.environ)
        extra = "nix-command flakes"
        existing = env.get("NIX_CONFIG", "")
        if existing:
            env["NIX_CONFIG"] = existing + "\n" + f"experimental-features = {extra}"
        else:
            env["NIX_CONFIG"] = f"experimental-features = {extra}"
        return env

    def open_repo(self) -> None:
        try:
            QDesktopServices.openUrl(QUrl.fromLocalFile(str(self.repo)))
        except Exception:
            pass

    def about(self) -> None:
        msg = (
            f"{APP_NAME}\n\n"
            f"Repo: {self.repo}\n"
            f"Host: {self.host}\n"
            f"Log: {self.log_path}\n"
            f"Cache: {self.cache_dir}\n"
            f"Keep lock: {self.keep_lock}\n"
            f"Debug: {self.debug}"
        )
        notify(APP_NAME, msg)

    def check_updates(self) -> bool:
        if self._busy:
            notify(APP_NAME, "Already running, try again in a bit.")
            return False

        self._set_busy(True)
        self._set_status(self.icon_busy, "Checking updates...")
        notify(APP_NAME, "Checking for updates...")

        flake_lock = self.repo / "flake.lock"
        if not flake_lock.exists():
            self._set_status(self.icon_fail, "Missing flake.lock")
            log_block(self.log_path, "Error", [f"Missing {flake_lock}"])
            notify(APP_NAME, "Missing flake.lock", "critical")
            self._set_busy(False)
            return False

        new_lock, stamp_lock = self._lock_paths()

        if new_lock.exists():
            try:
                new_lock.unlink()
            except Exception as e:
                log_block(self.log_path, "Warning", [f"Could not remove old lock file: {new_lock}", repr(e)])

        cmd = [
            NIX,
            "--extra-experimental-features", "nix-command",
            "--extra-experimental-features", "flakes",
            "flake", "lock",
            "--refresh",
            "--output-lock-file", str(new_lock),
            str(self.repo),
        ]

        log_block(self.log_path, "Check Updates Paths", [
            f"flake_lock: {flake_lock}",
            f"new_lock: {new_lock}",
            f"stamp_lock: {stamp_lock}",
            f"exists_before: {new_lock.exists()}",
        ])

        rc, _, _ = run_cmd(self.log_path, cmd, cwd=self.repo, env=self._nix_env(), timeout=600)
        self._last_check_ts = now_ts()

        if rc != 0:
            self._set_status(self.icon_fail, "Update check failed")
            notify(APP_NAME, "Update check failed. Opening log.", "critical")
            open_log(self.log_path)
            self._set_busy(False)
            return False

        if not new_lock.exists():
            self._set_status(self.icon_fail, "Update check bug: lock file missing")
            log_block(self.log_path, "BUG", [
                "nix flake lock returned 0 but lock file does not exist.",
                f"expected: {new_lock}",
                f"cwd: {self.repo}",
                f"TMPDIR: {os.environ.get('TMPDIR','')}",
            ])
            notify(APP_NAME, "BUG: nix returned ok but lock file missing. Opening log.", "critical")
            open_log(self.log_path)
            self._set_busy(False)
            return False

        if self.debug:
            try:
                stamp_lock.write_bytes(new_lock.read_bytes())
                log_block(self.log_path, "Debug", [f"Archived lock to {stamp_lock}"])
            except Exception as e:
                log_block(self.log_path, "Debug", [f"Failed to archive lock: {repr(e)}"])

        old_hash = sha256_file(flake_lock)
        new_hash = sha256_file(new_lock)

        log_block(self.log_path, "Comparison", [
            f"old_sha256: {old_hash}",
            f"new_sha256: {new_hash}",
            f"same: {old_hash == new_hash}",
        ])

        if old_hash == new_hash:
            self._set_status(self.icon_ok, "No updates available")
            notify(APP_NAME, "No updates available")
            if not self.keep_lock and not self.debug:
                try:
                    new_lock.unlink()
                except Exception:
                    pass
            self._set_busy(False)
            return True

        self._set_status(self.icon_updates, "Updates available")
        notify(APP_NAME, "Updates available")
        self._set_busy(False)
        return True

    def sync_apply(self) -> bool:
        if self._busy:
            notify(APP_NAME, "Already running, try again in a bit.")
            return False

        self._set_busy(True)
        self._set_status(self.icon_busy, "Syncing + applying...")
        notify(APP_NAME, "Running Sync + Apply...")

        git_sync = self.repo / "scripts" / "git-sync.sh"
        if not git_sync.exists():
            self._set_status(self.icon_fail, "Missing scripts/git-sync.sh")
            log_block(self.log_path, "Error", [f"Missing {git_sync}"])
            notify(APP_NAME, "Missing scripts/git-sync.sh", "critical")
            open_log(self.log_path)
            self._set_busy(False)
            return False

        rc1, _, _ = run_cmd(self.log_path, [BASH, str(git_sync)], cwd=self.repo, env=os.environ.copy(), timeout=600)
        if rc1 != 0:
            self._set_status(self.icon_fail, "Git sync failed")
            notify(APP_NAME, "Git sync failed. Opening log.", "critical")
            open_log(self.log_path)
            self._set_busy(False)
            return False

        apply_cmd = (
            f"cd {shlex.quote(str(self.repo))} && "
            f"{shlex.quote(NIXOS_REBUILD)} switch --flake {shlex.quote(f'.#{self.host}')}"
        )
        cmd2 = [PKEXEC, BASH, "-lc", apply_cmd]
        rc2, _, _ = run_cmd(self.log_path, cmd2, cwd=self.repo, env=os.environ.copy(), timeout=3600)

        if rc2 != 0:
            self._set_status(self.icon_fail, "Apply failed")
            notify(APP_NAME, "Apply failed. Opening log.", "critical")
            open_log(self.log_path)
            self._set_busy(False)
            return False

        self._set_status(self.icon_ok, "Sync + Apply: success")
        notify(APP_NAME, "Sync + Apply: success")
        self._set_busy(False)
        return True

    def check_then_sync_apply(self) -> None:
        ok = self.check_updates()
        if not ok:
            return
        tip = self._last_result or ""
        if "Updates available" in tip:
            self.sync_apply()
        else:
            notify(APP_NAME, "No updates, not applying.")


def main():
    repo = DEFAULT_REPO
    host = DEFAULT_HOST
    log_path = DEFAULT_LOG
    cache_dir = DEFAULT_CACHE_DIR
    keep_lock = DEFAULT_KEEP
    debug = DEFAULT_DEBUG

    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)

    _tray = NixTray(repo, host, log_path, cache_dir, keep_lock, debug)

    def _handle_term(*_args):
        # Exit cleanly, but still kill active child trees first.
        try:
            log_block(log_path, "Signal", ["Received termination signal, quitting"])
            _kill_active_process_group(log_path)
        finally:
            app.quit()

    signal.signal(signal.SIGTERM, _handle_term)
    signal.signal(signal.SIGINT, _handle_term)

    sys.exit(app.exec())
