import json, sys
tx = sys.argv[1]
out = []
with open(tx) as f:
    for i, line in enumerate(f):
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get("isSidechain"):
            continue
        t = d.get("type")
        c = d.get("message", {}).get("content")
        texts = []
        if isinstance(c, str):
            texts.append(c)
        elif isinstance(c, list):
            for p in c:
                if isinstance(p, dict) and p.get("type") == "text":
                    texts.append(p["text"])
        s = "\n".join(texts)
        if t == "user" and s and not s.startswith("<system-reminder>") and not s.startswith("Base directory"):
            print("########## USER PROMPT line %d ts=%s: %r" % (i, d.get("timestamp"), s[:80]))
        if t == "assistant" and "RFI 5899-" in s:
            print("========== ASSISTANT line %d ts=%s len=%d" % (i, d.get("timestamp"), len(s)))
            print(s)
