"""Split each job's time into suites the windows job also runs vs suites it
skips (run 41257232100, step times from /tmp/ci-jobs-<run>.json)."""
import json
import re
from datetime import datetime

RUN = "41257232100"
SHARED = re.compile(r"logging|managed-file|adopt|delegation-duty|workflow-delegation|hook output|"
                    r"build-package|harness-db delegation|ait-harvest|build deploy|deploy drift|"
                    r"syntax|checkout|set up job|git bash version|line endings|complete job|"
                    r"post checkout", re.I)


def t(s):
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ")


for j in json.load(open(f"/tmp/ci-jobs-{RUN}.json"))["jobs"]:
    shared = skipped = 0.0
    for s in j["steps"]:
        if not (s.get("started_at") and s.get("completed_at")):
            continue
        d = (t(s["completed_at"]) - t(s["started_at"])).total_seconds()
        if SHARED.search(s["name"]):
            shared += d
        else:
            skipped += d
    print(f"{j['name']:8s} shared-with-windows {shared:6.0f}s   not-on-windows {skipped:6.0f}s")
