"""Write each fetched PR's metadata, files, commits and body to pr-<n>-view.tmp. Usage: python show-pr.py <dir> <n>..."""
import json
import os
import sys

out = sys.argv[1]
for n in sys.argv[2:]:
    d = json.load(open(os.path.join(out, f"pr-{n}.json"), encoding="utf-8"))
    lines = [f"# {d['number']} {d['title']}",
             f"merged {d['mergedAt']} {d['mergeCommit']['oid']} {d['headRefName']}",
             "--- files"]
    lines += [f"  {f['path']} +{f['additions']} -{f['deletions']}" for f in d["files"]]
    lines.append("--- commits")
    lines += [f"   {c['oid'][:7]} {c['messageHeadline']}" for c in d["commits"]]
    lines += ["--- body", d["body"]]
    with open(os.path.join(out, f"pr-{n}-view.tmp"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print("wrote", n)
