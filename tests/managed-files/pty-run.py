#!/usr/bin/env python3
"""pty-run.py -- run a command on a pseudo-terminal and feed it keyboard input.

The managed-file review prompts only appear when stdin is a terminal and
/dev/tty opens, so interactive test cases run the command here: pty.fork()
makes the child a session leader with the pty as its controlling terminal.

Usage: pty-run.py --input TEXT [--log FILE] [--timeout SECONDS] -- CMD [ARGS...]
  --input    keystrokes; backslash escapes are decoded (\\n newline, \\x04 EOF)
  --log      write everything the command printed on the terminal to FILE
  --timeout  kill the command after this many seconds (default 60)
Exit code: the command's exit code (124 on timeout).
"""
import argparse
import os
import pty
import select
import signal
import sys
import time


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--input", default="")
    ap.add_argument("--log", default="")
    ap.add_argument("--timeout", type=float, default=60.0)
    ap.add_argument("cmd", nargs=argparse.REMAINDER)
    args = ap.parse_args()
    cmd = args.cmd[1:] if args.cmd and args.cmd[0] == "--" else args.cmd
    if not cmd:
        ap.error("no command given")
    keys = args.input.encode("utf-8").decode("unicode_escape").encode("latin-1")

    pid, fd = pty.fork()
    if pid == 0:
        try:
            os.execvp(cmd[0], cmd)
        except OSError as e:
            sys.stderr.write(f"pty-run: cannot exec {cmd[0]}: {e}\n")
        os._exit(127)

    out = bytearray()
    deadline = time.monotonic() + args.timeout
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
            status = 124
            break
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                data = os.read(fd, 65536)
            except OSError:
                data = b""
            if data:
                out += data
                last_out = time.monotonic()
            else:
                pass
        done, st = os.waitpid(pid, os.WNOHANG)
        if done:
            status = st
            break
        quiet = time.monotonic() - last_out > 0.4
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
    if args.log:
        with open(args.log, "wb") as f:
            f.write(bytes(out))
    if status == 124:
        return 124
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status)
    return 128 + os.WTERMSIG(status) if os.WIFSIGNALED(status) else 1


if __name__ == "__main__":
    sys.exit(main())
