"""Summarise PyPI JSON for pywinpty: info, latest release files, release dates."""
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    d = json.load(f)
info = d["info"]
for k in ("name", "version", "author", "author_email", "maintainer", "maintainer_email",
          "license", "license_expression", "requires_python", "home_page", "project_urls",
          "summary", "classifiers", "requires_dist"):
    print(f"{k}: {info.get(k)}")
print()
print("Latest release files:")
for u in d["urls"]:
    print(f"  {u['filename']}  py={u['python_version']}  yanked={u['yanked']}  uploaded={u['upload_time_iso_8601']}  sha256={u['digests']['sha256'][:16]}...")
print()
print("Release history (version: first upload):")
rows = []
for ver, files in d["releases"].items():
    if not files:
        continue
    first = min(x["upload_time_iso_8601"] for x in files)
    rows.append((first, ver, len(files)))
rows.sort()
for first, ver, n in rows[-25:]:
    print(f"  {ver}: {first} ({n} files)")
print(f"Total releases with files: {len(rows)}")
print("vulnerabilities field:", d.get("vulnerabilities"))
