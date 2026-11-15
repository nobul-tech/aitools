"""Print max incident id and RELEASE_NOTES top headings on each named rev. Usage: python ids-per-branch.py <wt> <rev>..."""
import json
import subprocess
import sys

wt = sys.argv[1]
for rev in sys.argv[2:]:
    raw = subprocess.run(["git", "-C", wt, "show", f"{rev}:registries/incidents.json"], capture_output=True, check=True).stdout
    d = json.loads(raw.decode("utf-8"))
    ids = sorted(i["id"] for i in d["incidents"] + d["closed"])
    rn = subprocess.run(["git", "-C", wt, "show", f"{rev}:RELEASE_NOTES.md"], capture_output=True, check=True).stdout.decode("utf-8")
    heads = [l for l in rn.splitlines() if l.startswith("## v")][:3]
    print(rev, "max id", ids[-1], "count", len(ids), "| top:", [h[:40] for h in heads])
