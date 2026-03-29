#!/usr/bin/env python3
"""Extract user messages from JSONL session transcripts."""
import json
import sys
import os

def extract_user_messages(filepath: str, outpath: str) -> None:
    """Read JSONL file and write user message content to output file."""
    count = 0
    with open(filepath) as f, open(outpath, 'w') as out:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if obj.get("type") == "user":
                msg = obj.get("message", {})
                content = msg.get("content", "")
                if isinstance(content, list):
                    texts = [
                        item.get("text", "")
                        for item in content
                        if item.get("type") == "text"
                    ]
                    content = "\n".join(texts)
                if content.strip():
                    count += 1
                    out.write(f"=== USER MSG #{count} (line {line_num}) ===\n")
                    out.write(content.strip())
                    out.write("\n\n")
    print(f"  {os.path.basename(filepath)}: {count} user messages -> {outpath}")

def show_structure(filepath: str) -> None:
    """Show type/role/length of each line for debugging."""
    with open(filepath) as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                print(f"  line {i}: PARSE ERROR")
                continue
            t = obj.get('type', 'unknown')
            msg = obj.get('message', {})
            role = ''
            clen = 0
            content_types = []
            if isinstance(msg, dict):
                role = msg.get('role', '')
                c = msg.get('content', '')
                if isinstance(c, list):
                    for block in c:
                        if isinstance(block, dict):
                            bt = block.get('type', '?')
                            content_types.append(bt)
                            if bt == 'text':
                                clen += len(block.get('text', ''))
                elif isinstance(c, str):
                    clen = len(c)
                    content_types.append('str')
            ctypes = ','.join(content_types) if content_types else 'empty'
            if t == 'user' and role == 'user':
                print(f"  line {i}: type={t} content_types=[{ctypes}] text_len={clen}")

if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "structure":
        for path in sys.argv[2:]:
            print(f"\n=== {os.path.basename(path)} ===")
            show_structure(path)
    else:
        outdir = mode
        os.makedirs(outdir, exist_ok=True)
        for path in sys.argv[2:]:
            basename = os.path.basename(path).replace('.jsonl', '')
            outpath = os.path.join(outdir, f"{basename}-user-msgs.txt")
            extract_user_messages(path, outpath)
