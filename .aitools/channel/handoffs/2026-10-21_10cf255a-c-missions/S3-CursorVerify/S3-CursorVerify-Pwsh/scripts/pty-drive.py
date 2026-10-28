#!/usr/bin/env python3
"""pty-drive.py ANSWER RAWLOG -- CMD... : run CMD under a pseudo-terminal (S3-CursorVerify-Pwsh P5).

Reads the child's output as raw bytes (the PS1 review prompt has no trailing
newline, so nothing line-buffered is used), and each time a review prompt
"choice [" ... "]: " appears it writes ANSWER + newline. Saves every byte to
RAWLOG, prints the prompt count and the exit code, and exits with the child's
exit code. Overall timeout 300 s (the child is killed; exit 124).
"""
import os
import pty
import re
import select
import signal
import sys
import time

def main() -> int:
    if len(sys.argv) < 5 or sys.argv[3] != "--":
        print(__doc__, file=sys.stderr)
        return 64
    answer, rawlog, cmd = sys.argv[1], sys.argv[2], sys.argv[4:]
    pid, fd = pty.fork()
    if pid == 0:
        os.execvp(cmd[0], cmd)
    buf = b""
    scanned = 0
    prompts = []
    deadline = time.time() + 300
    status = None
    with open(rawlog, "wb") as log:
        while True:
            if time.time() > deadline:
                os.kill(pid, signal.SIGKILL)
                os.waitpid(pid, 0)
                print("TIMEOUT", flush=True)
                return 124
            r, _, _ = select.select([fd], [], [], 0.5)
            if fd in r:
                try:
                    chunk = os.read(fd, 65536)
                except OSError:
                    chunk = b""
                if not chunk:
                    break
                log.write(chunk)
                log.flush()
                buf += chunk
                base = scanned
                for m in re.finditer(rb"choice \[[a-z/]+\]: ", buf[base:]):
                    # the file under review: the last "[REVIEW] <path> differs" before the prompt
                    head = buf[: base + m.end()]
                    rv = re.findall(rb"\[REVIEW\] (\S+) differs from source", head)
                    prompts.append((rv[-1].decode(errors="replace") if rv else "?", m.group(0).decode()))
                    os.write(fd, answer.encode() + b"\n")
                    scanned = base + m.end()
            else:
                done, st = os.waitpid(pid, os.WNOHANG)
                if done:
                    status = st
                    # drain what is left
                    try:
                        while True:
                            r2, _, _ = select.select([fd], [], [], 0.2)
                            if fd not in r2:
                                break
                            chunk = os.read(fd, 65536)
                            if not chunk:
                                break
                            log.write(chunk)
                    except OSError:
                        pass
                    break
    if status is None:
        _, status = os.waitpid(pid, 0)
    rc = os.waitstatus_to_exitcode(status)
    for f, p in prompts:
        print(f"PROMPT {p!r} for {f} -> answered {answer!r}")
    print(f"prompts={len(prompts)} exit={rc}")
    return rc

if __name__ == "__main__":
    sys.exit(main())
