import json, sys
path = sys.argv[1]
mode = sys.argv[2] if len(sys.argv) > 2 else "user"
n = 0
with open(path) as f:
    for i, line in enumerate(f):
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get("type") != mode:
            continue
        if d.get("isSidechain"):
            continue
        msg = d.get("message", {})
        c = msg.get("content")
        texts = []
        if isinstance(c, str):
            texts.append(c)
        elif isinstance(c, list):
            for part in c:
                if isinstance(part, dict) and part.get("type") == "text":
                    texts.append(part["text"])
        if not texts:
            continue
        t = "\n".join(texts)
        if mode == "user" and (t.startswith("<system-reminder>") or "<command-name>" in t[:200] or t.startswith("<local-command") or t.startswith("Caveat:")):
            print("=== SKIPPED line %d ts=%s len=%d head=%r" % (i, d.get("timestamp"), len(t), t[:120]))
            continue
        n += 1
        print("=== %s #%d line %d ts=%s len=%d" % (mode, n, i, d.get("timestamp"), len(t)))
        print(t)
