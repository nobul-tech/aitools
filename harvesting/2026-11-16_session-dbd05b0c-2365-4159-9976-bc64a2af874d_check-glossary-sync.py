"""Compare governed terms in registries/glossary.json with the word list in .claude/rules/glossary.md."""
import json
import sys

repo = sys.argv[1]
terms = set(json.load(open(f"{repo}/registries/glossary.json"))["terms"])
lines = open(f"{repo}/.claude/rules/glossary.md").read().splitlines()
start = lines.index("### Terms")
end = next(i for i, l in enumerate(lines) if i > start and l.startswith("### When"))
words = {l.strip() for l in lines[start + 1:end] if l.strip()}
print("in JSON, not in word list:", sorted(terms - words))
print("in word list, not in JSON:", sorted(words - terms))
print("deviation in both:", "deviation" in terms and "deviation" in words)
