#!/usr/bin/env bash
# verify-99.sh -- post-merge local checks for PR #99 on a clean export of a commit.
# Usage: verify-99.sh <commit>
set -euo pipefail
REPO=/Users/new-jose/repos/aitools
COMMIT="${1:?commit required}"
OUT=/Users/new-jose/repos/aitools/.scratch/session-mm99/export-$COMMIT
rm -rf "$OUT"
git clone -q --shared --no-checkout "$REPO" "$OUT"
git -C "$OUT" checkout -q --detach "$COMMIT"
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] export ok: $OUT"

rc=0
echo "== check-path-refs.py (pre-commit step 20) =="
python3 "$OUT/scripts/check-path-refs.py" --root "$OUT" || rc=$?
echo "path-refs exit: $rc"

echo "== JSON parse registries =="
jrc=0
for f in "$OUT"/registries/*.json; do
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" || { echo "BAD JSON: $f"; jrc=1; }
done
echo "json exit: $jrc"

echo "== tool-ops verifications (mock-json-pipe) for claude-code hooks =="
vrc=0
python3 - "$OUT" <<'PY' || vrc=$?
import json, subprocess, sys, re, os, tempfile
root = sys.argv[1]
reg = json.load(open(os.path.join(root, "registries/tool-ops.json")))
fails = 0
home = tempfile.mkdtemp(prefix="mm99home-")
env = dict(os.environ, HOME=home)
for tool, t in reg["tools"].items():
    for v in t.get("verifications", []):
        if v.get("type") != "mock-json-pipe":
            continue
        script = os.path.join(root, "shared/hooks", v["target"])
        for c in v["cases"]:
            p = subprocess.run(["bash", script], input=json.dumps(c["input"]), capture_output=True, text=True, env=env, cwd=home)
            ok = p.returncode == c["expectExit"]
            es = c.get("expectStdout")
            if es is None:
                ok = ok and p.stdout.strip() == ""
            else:
                ok = ok and re.search(es, p.stdout) is not None
            if "expectStderr" in c:
                ee = c["expectStderr"]
                ok = ok and ((p.stderr.strip() == "") if ee is None else (ee in p.stderr))
            print(("PASS" if ok else "FAIL"), tool, v["target"], "exit", p.returncode)
            if not ok:
                fails += 1
                print("  stdout:", p.stdout[:300]); print("  stderr:", p.stderr[:300])
sys.exit(1 if fails else 0)
PY
echo "verifications exit: $vrc"

echo "== summary: path-refs=$rc json=$jrc verifications=$vrc =="
if [ "$rc" -ne 0 ] || [ "$jrc" -ne 0 ] || [ "$vrc" -ne 0 ]; then exit 1; fi
