#!/usr/bin/env python3
"""fake-pty-run.py -- scratch stand-in for tests/managed-files/pty-run.py on a
machine without pywinpty: same arguments, input on a pipe (no terminal), \\x04
ends the input, stdout+stderr written to --log. Pair with lib-fake (its
/dev/tty I/O goes to stdin/stderr, with terminal-like echo)."""
from __future__ import annotations

import argparse
import subprocess
import sys


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", default="")
    ap.add_argument("--log", default="")
    ap.add_argument("--timeout", type=float, default=30.0)
    ap.add_argument("cmd", nargs=argparse.REMAINDER)
    a = ap.parse_args()
    cmd = a.cmd[1:] if a.cmd and a.cmd[0] == "--" else a.cmd
    keys = a.input.encode("utf-8").decode("unicode_escape").encode("latin-1")
    keys = keys.split(b"\x04", 1)[0]
    try:
        p = subprocess.run(cmd, input=keys, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=a.timeout)
    except subprocess.TimeoutExpired as e:
        sys.stderr.write(f"fake-pty-run: timeout after {a.timeout}s\n")
        out, rc = e.stdout or b"", 124
    else:
        out, rc = p.stdout, p.returncode
    if a.log:
        with open(a.log, "wb") as f:
            f.write(out)
    return rc


if __name__ == "__main__":
    sys.exit(main())
