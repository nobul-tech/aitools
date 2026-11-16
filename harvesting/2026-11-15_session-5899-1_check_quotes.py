import json, re, sys
tx = sys.argv[1]
plan = sys.argv[2]
prompts = []
with open(tx) as f:
    for line in f:
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get("type") != "user" or d.get("isSidechain"):
            continue
        c = d.get("message", {}).get("content")
        texts = []
        if isinstance(c, str):
            texts.append(c)
        elif isinstance(c, list):
            for p in c:
                if isinstance(p, dict) and p.get("type") == "text":
                    texts.append(p["text"])
        t = "\n".join(texts)
        if not t or t.startswith("<system-reminder>") or t.startswith("Base directory for this skill"):
            continue
        prompts.append(t)
print("prompt count", len(prompts))
for i, p in enumerate(prompts):
    print(i + 1, repr(p[:60]))
lines = open(plan).read().split("\n")
# section 1 block quotes
for ln, l in enumerate(lines, 1):
    if 74 <= ln <= 97 and l.startswith("> "):
        q = l[2:]
        hits = [i + 1 for i, p in enumerate(prompts) if q in p]
        print("BLOCKQUOTE line", ln, "found in prompts", hits)
        if not hits:
            # find longest matching prefix
            for i, p in enumerate(prompts):
                k = 0
                while k < len(q) and q[:k + 1] in p:
                    k += 1
                if k > 20:
                    print("  prompt", i + 1, "matches prefix len", k, "of", len(q), "diverges at", repr(q[k - 20:k + 30]))
# all inline double-quoted fragments
for ln, l in enumerate(lines, 1):
    for m in re.finditer(r'"([^"]{3,})"', l):
        q = m.group(1)
        hits = [i + 1 for i, p in enumerate(prompts) if q in p]
        print("INLINE line", ln, repr(q[:80]), "->", hits)
