#!/usr/bin/env python3
"""cv-pty.py -- run setup-user-cursor.sh under a pseudo-terminal, answer every review prompt.

usage: cv-pty.py ROOT PHASEDIR ANSWER [BASH_BIN]
  ROOT      fixture root (ROOT/aitools, ROOT/home); must be under the session scratch dir
  PHASEDIR  output dir: cursor.out (raw transcript), cursor.summary, prompts.txt, exit.txt
  ANSWER    the letter sent at every "choice [...]: " prompt (s, x, o, ...)
Isolation: HOME=ROOT/home; refuses the real HOME. Times out after 600 s.
"""
import os
import pty
import re
import select
import sys
import time

SCRATCH = "/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh"
REAL_HOME = "/Users/new-jose"


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        return 3
    root, outdir, answer = sys.argv[1], sys.argv[2], sys.argv[3]
    bash_bin = sys.argv[4] if len(sys.argv) > 4 else "/opt/homebrew/bin/bash"
    home = os.path.join(root, "home")
    script = os.path.join(root, "aitools", "scripts", "setup-user-cursor.sh")
    if not root.startswith(SCRATCH + "/") or home.rstrip("/") == REAL_HOME:
        print("refusing: ROOT not under scratch or HOME is real", file=sys.stderr)
        return 3
    if not os.path.isdir(os.path.join(home, ".aitools")):
        print("refusing: no isolated HOME", file=sys.stderr)
        return 3
    os.makedirs(os.path.join(outdir, "bin"), exist_ok=True)
    for name, text in (("rg", 'echo "ripgrep 14.1.0"'), ("agent", 'echo "2026.05.21-stub"')):
        p = os.path.join(outdir, "bin", name)
        with open(p, "w") as fh:
            fh.write("#!/usr/bin/env bash\n" + text + "\n")
        os.chmod(p, 0o755)
    summary = os.path.join(outdir, "cursor.summary")
    open(summary, "w").close()

    env = {k: v for k, v in os.environ.items()
           if k not in ("AITOOLS_FORCE", "AITOOLS_DRY_RUN", "AITOOLS_LOG_DIR", "AITOOLS_USER_REPO_PATH")}
    env.update(HOME=home, USERPROFILE=home, AITOOLS_SUMMARY_FILE=summary, NO_COLOR="1",
               PATH=os.path.join(outdir, "bin") + ":" + os.environ.get("PATH", ""), TERM="xterm")

    pid, fd = pty.fork()
    if pid == 0:
        os.execve(bash_bin, [bash_bin, script], env)

    transcript = bytearray()
    since_answer = bytearray()
    prompts = []
    prompt_re = re.compile(rb"choice \[[a-z/]+\]: ?$")
    deadline = time.time() + 600
    while True:
        if time.time() > deadline:
            os.kill(pid, 9)
            prompts.append("TIMEOUT")
            break
        r, _, _ = select.select([fd], [], [], 1.0)
        if not r:
            continue
        try:
            data = os.read(fd, 4096)
        except OSError:
            break
        if not data:
            break
        transcript += data
        since_answer += data
        if prompt_re.search(bytes(since_answer).rstrip(b"\r\n") + b" ") or prompt_re.search(bytes(since_answer)):
            # the [REVIEW] header of this prompt names the file
            m = re.findall(rb"\[REVIEW\][^\r\n]*", bytes(since_answer))
            prompts.append((m[-1].decode("utf-8", "replace") if m else "(no [REVIEW] line)")
                           + " -> answered " + answer)
            os.write(fd, (answer + "\n").encode())
            since_answer = bytearray()
    _, status = os.waitpid(pid, 0)
    rc = os.waitstatus_to_exitcode(status)
    with open(os.path.join(outdir, "cursor.out"), "wb") as fh:
        fh.write(bytes(transcript))
    with open(os.path.join(outdir, "prompts.txt"), "w") as fh:
        for p in prompts:
            fh.write(p + "\n")
    with open(os.path.join(outdir, "exit.txt"), "a") as fh:
        fh.write("cursor-pty-%s\t%d\n" % (answer, rc))
    print("cursor (pty, answer %s) exit %d, %d prompt(s)" % (answer, rc, len(prompts)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
