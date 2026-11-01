#!/usr/bin/env python3
"""pty-run.py -- run a command on a pseudo-terminal and feed it keyboard input.

The managed-file review prompts only appear when stdin is a terminal (and, for
bash, /dev/tty opens), so interactive test cases run the command here.

Backends:
  POSIX    stdlib pty.fork(): the child is a session leader with the pty as its
           controlling terminal.
  Windows  pywinpty (ConPTY; tests/managed-files/requirements-windows.txt,
           commander 2026-11-01 "Adopt, spike first"). The CI probe
           (winpty-probe.py, run 41262097075) showed Git Bash sees a terminal
           and /dev/tty inside ConPTY, pwsh sees non-redirected input, and pwsh
           needs Enter as CR: a bare LF never completes [Console]::ReadLine().
           So every LF of --input is sent as CR. On timeout the whole process
           tree is killed (taskkill /T /F), not only the direct child.

Usage: pty-run.py --input TEXT [--log FILE] [--timeout SECONDS] -- CMD [ARGS...]
  --input    keystrokes; backslash escapes are decoded (\\n newline, \\x04 EOF)
  --log      write everything the command printed on the terminal to FILE
  --timeout  kill the command after this many seconds (default 30; commander,
             2026-11-01). A timeout is reported on stderr with the command
             and the elapsed time, so a hung case is not a silent stall.
Exit code: the command's exit code (124 on timeout, 127 when it cannot start).
"""
from __future__ import annotations

import argparse
import os
import select
import shutil
import subprocess
import sys
import time

QUIET_SECONDS = 0.4  # feed the next line after the child has been quiet this long


def timeout_note(started: float, timeout: float, cmd: list[str], unsent: int) -> None:
    sys.stderr.write(
        f"pty-run: timeout after {time.monotonic() - started:.1f}s "
        f"(--timeout {timeout:g}); killed: {' '.join(cmd)}; "
        f"{unsent} input line(s) not sent\n")


def run_posix(cmd: list[str], keys: bytes, timeout: float) -> tuple[int, bytes]:
    import pty
    import signal

    pid, fd = pty.fork()
    if pid == 0:
        try:
            os.execvp(cmd[0], cmd)
        except OSError as e:
            sys.stderr.write(f"pty-run: cannot exec {cmd[0]}: {e}\n")
        os._exit(127)

    out = bytearray()
    started = time.monotonic()
    deadline = started + timeout
    # Feed one line per prompt: wait until the child has printed something new
    # and gone quiet, then send the next line. Keeps input from being consumed
    # by an earlier read or discarded when a program resets the terminal.
    lines = keys.splitlines(keepends=True)
    status = None
    last_out = time.monotonic()
    sent_at_len = -1
    while True:
        if time.monotonic() > deadline:
            os.kill(pid, signal.SIGKILL)
            os.waitpid(pid, 0)
            timeout_note(started, timeout, cmd, len(lines))
            return 124, bytes(out)
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                data = os.read(fd, 65536)
            except OSError:
                data = b""
            if data:
                out += data
                last_out = time.monotonic()
        done, st = os.waitpid(pid, os.WNOHANG)
        if done:
            status = st
            break
        quiet = time.monotonic() - last_out > QUIET_SECONDS
        if lines and quiet and len(out) != sent_at_len:
            os.write(fd, lines.pop(0))
            sent_at_len = len(out)
    # Drain what is left
    while True:
        try:
            r, _, _ = select.select([fd], [], [], 0.05)
            if not r:
                break
            data = os.read(fd, 65536)
            if not data:
                break
            out += data
        except OSError:
            break
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status), bytes(out)
    return (128 + os.WTERMSIG(status) if os.WIFSIGNALED(status) else 1), bytes(out)


def run_windows(cmd: list[str], keys: bytes, timeout: float) -> tuple[int, bytes]:
    try:
        from winpty import PtyProcess
    except ImportError as e:
        sys.stderr.write(
            f"pty-run: pywinpty is not installed ({e}); install it with "
            "python -m pip install --require-hashes -r tests/managed-files/requirements-windows.txt\n")
        return 127, b""
    exe = shutil.which(cmd[0]) or cmd[0]
    try:
        # Wide terminal: ConPTY re-renders the screen and wraps at the width.
        proc = PtyProcess.spawn([exe, *cmd[1:]], dimensions=(50, 250))
    except Exception as e:  # noqa: BLE001 -- report why the command could not start
        sys.stderr.write(f"pty-run: cannot start {cmd[0]} ({exe}): {type(e).__name__}: {e}\n")
        return 127, b""

    # Enter is CR in a Windows console (pwsh's ReadLine ignores a bare LF).
    text = keys.decode("latin-1").replace("\r\n", "\n").replace("\n", "\r")
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    started = time.monotonic()
    deadline = started + timeout
    last_out = time.monotonic()
    sent_at_len = -1
    total = 0
    while proc.isalive():
        if time.monotonic() > deadline:
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True)
            timeout_note(started, timeout, cmd, len(lines))
            return 124, "".join(out).encode("utf-8", "replace")
        r, _, _ = select.select([proc.fileobj], [], [], 0.05)
        if r:
            try:
                data = proc.read(65536)
            except EOFError:
                break
            if data:
                out.append(data)
                total += len(data)
                last_out = time.monotonic()
        quiet = time.monotonic() - last_out > QUIET_SECONDS
        if lines and quiet and total != sent_at_len:
            proc.write(lines.pop(0))
            sent_at_len = total
    # Drain what is left, then wait briefly for the exit status to appear.
    drain_until = time.monotonic() + 1.0
    while time.monotonic() < drain_until:
        r, _, _ = select.select([proc.fileobj], [], [], 0.05)
        if not r:
            break
        try:
            data = proc.read(65536)
        except EOFError:
            break
        if not data:
            break
        out.append(data)
    status = proc.exitstatus
    for _ in range(40):
        if status is not None:
            break
        time.sleep(0.05)
        status = proc.exitstatus
    return (status if status is not None else 1), "".join(out).encode("utf-8", "replace")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--input", default="")
    ap.add_argument("--log", default="")
    ap.add_argument("--timeout", type=float, default=30.0)
    ap.add_argument("cmd", nargs=argparse.REMAINDER)
    args = ap.parse_args()
    cmd = args.cmd[1:] if args.cmd and args.cmd[0] == "--" else args.cmd
    if not cmd:
        ap.error("no command given")
    keys = args.input.encode("utf-8").decode("unicode_escape").encode("latin-1")

    runner = run_windows if os.name == "nt" else run_posix
    status, out = runner(cmd, keys, args.timeout)
    if args.log:
        with open(args.log, "wb") as f:
            f.write(out)
    return status


if __name__ == "__main__":
    sys.exit(main())
