"""Convert a chrome-devtools evaluate_script JSON output (a JSON string) to plain text.

Usage: python3 -I json2txt.py <in.json> <out.txt>
"""
import json
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, str):
        data = json.dumps(data, indent=1)
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        f.write(data)
    print(f"wrote {len(data)} chars, {data.count(chr(10))} lines")
    return 0


if __name__ == "__main__":
    sys.exit(main())
