"""Verify pywinpty 3.1.2 wheel hashes from PyPI JSON (orchestrator spot-check of M3-Fixes-D)."""
import json
import urllib.request

with urllib.request.urlopen("https://pypi.org/pypi/pywinpty/3.1.2/json", timeout=30) as r:
    data = json.load(r)
print("latest:", json.load(urllib.request.urlopen("https://pypi.org/pypi/pywinpty/json", timeout=30))["info"]["version"])
for f in data["urls"]:
    if "win_amd64" in f["filename"]:
        print(f["filename"], f["digests"]["sha256"])
