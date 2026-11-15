"""Print pywinpty-related requires_dist lines of known dependents (PyPI JSON API)."""
import json
import urllib.request

for pkg in ("terminado", "jupyter_server", "notebook", "jupyterlab", "spyder", "spyder-kernels", "pexpect", "ptyprocess", "winpty"):
    url = f"https://pypi.org/pypi/{pkg}/json"
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            d = json.load(r)
    except Exception as e:  # report and continue: one missing package must not hide the rest
        print(f"{pkg}: ERROR {e}")
        continue
    info = d["info"]
    deps = [x for x in (info.get("requires_dist") or []) if "winpty" in x.lower() or "terminado" in x.lower()]
    print(f"{pkg} {info['version']}: {deps}  summary={info.get('summary')!r}")

with urllib.request.urlopen("https://pypistats.org/api/packages/pywinpty/recent", timeout=20) as r:
    print("pypistats recent:", r.read().decode())
