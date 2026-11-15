#!/usr/bin/env bash
# Per-job and per-step durations of a GitHub Actions run (seconds), sorted by
# duration within each job. Usage: ci-step-times.sh <run id> [top N]
set -euo pipefail
RUN="$1"
TOP="${2:-12}"
gh api "repos/nobul-tech/aitools/actions/runs/$RUN/jobs?per_page=100" > "/tmp/ci-jobs-$RUN.json"
python3 - "$RUN" "$TOP" <<'PY'
import json, sys
from datetime import datetime
run, top = sys.argv[1], int(sys.argv[2])
data = json.load(open(f"/tmp/ci-jobs-{run}.json"))
def t(s):
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ") if s else None
for j in data["jobs"]:
    js, je = t(j.get("started_at")), t(j.get("completed_at"))
    total = (je - js).total_seconds() if js and je else None
    print(f"== {j['name']}  runner={j.get('runner_name')} labels={j.get('labels')} "
          f"conclusion={j.get('conclusion')} total={total}s steps={len(j.get('steps', []))}")
    steps = []
    for s in j.get("steps", []):
        ss, se = t(s.get("started_at")), t(s.get("completed_at"))
        if ss and se:
            steps.append(((se - ss).total_seconds(), s["name"], s.get("conclusion")))
    steps.sort(reverse=True)
    for d, n, c in steps[:top]:
        print(f"   {d:7.0f}s  {n}  [{c}]")
    print(f"   sum of steps: {sum(d for d, _, _ in steps):.0f}s")
PY
