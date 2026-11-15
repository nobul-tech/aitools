"""M4-Winpty: map the pin's sha256 hashes to PyPI file names (pywinpty 3.1.2), verbatim from the JSON API."""
import json
import re
import sys
import urllib.request

pin = sys.argv[1]
with urllib.request.urlopen("https://pypi.org/pypi/pywinpty/3.1.2/json", timeout=30) as r:
    data = json.load(r)
by_hash = {u["digests"]["sha256"]: u for u in data["urls"]}
hashes = re.findall(r"sha256:([0-9a-f]{64})", open(pin, encoding="utf-8").read())
print(f"pin hashes: {len(hashes)}")
for h in hashes:
    u = by_hash.get(h)
    print(h, u["filename"] if u else "NOT ON PYPI", u["upload_time_iso_8601"] if u else "", "yanked" if u and u.get("yanked") else "")
print("--- all 3.1.2 files ---")
for u in data["urls"]:
    print(u["filename"], u["digests"]["sha256"], "IN PIN" if u["digests"]["sha256"] in hashes else "-")
print("latest version:", data["info"]["version"])
