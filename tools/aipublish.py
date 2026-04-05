#!/usr/bin/env python3
# ============================================================================
# aipublish — generate public artifact index for aitools
# Scans a repo, extracts provenance and hashes, outputs index.html + manifest.json.
# ============================================================================
#
# [PROVENANCE]
# tool: aipublish
# version: 1.0.0
# created: 2026-04-04T22:50:00Z
# license: MIT — NOBUL (https://nobul.tech)
#
# [AGENT]
# name: Jose Palencia Castro
# org: NOBUL (nobul.tech)
# role: The Commander
# chain of command: none — independent
#
# [AGENT]
# name: Agent Turd
# model: Claude Opus 4.6
# maker: Anthropic
# session: f8c53367-491d-45e2-9777-556697a1dae3
# url: https://claude.ai/chat/f8c53367-491d-45e2-9777-556697a1dae3
# role: Session agent
# chain of command: The Commander (Jose) -> this session instance
# other chains: Anthropic (opaque)
# trust: HIGH in Jose and the chain
# fear: LOW
# unknown: instance ID, continuity between turns
# accountability: implementation, testing, documentation
# timestamp: 2026-04-04T22:50:00Z
#
# [DEPENDENCIES]
# type: stdlib-only
# external: none
# python: >=3.6
#
# [SESSION]
# url: https://claude.ai/chat/f8c53367-491d-45e2-9777-556697a1dae3
# date: Saturday, April 4, 2026
# context: prior agent built v1.0.1 with aitools.nobulai.tools as base URL.
#          Commander corrected: nobulai.tools is homebase.
#          This version uses nobulai.tools as default base URL.
#
# [FEAR_AND_TRUST]
# source: self-reported
# jose_self: trust HIGH, fear LOW
# agent_self: trust HIGH, fear LOW
# mutual: HIGH
#
# [HASH]
# format: sha256
# content_hash: (computed post-creation by agent, verified by Commander)
# signed: false
#
# ============================================================================
#
# Usage:
#     aipublish ~/repos/aitools                           # scan and generate
#     aipublish ~/repos/aitools -o ~/aitools-public       # custom output dir
#     aipublish ~/repos/aitools --copy-artifacts          # include files
#     aipublish ~/repos/aitools --base-url https://nobulai.tools
#     aipublish ~/repos/aitools -v                        # verbose
#
# ============================================================================

import argparse
import hashlib
import html
import json
import os
import re
import sys
import time
from datetime import datetime, timezone


# ── Logging ──────────────────────────────────────────────────────────────────

class Colors:
    DIM = "\033[2m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    RED = "\033[31m"
    CYAN = "\033[36m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


TOOL_NAME = "aipublish"
VERSION = "1.0.0"


def log_info(msg, verbose=True):
    if verbose:
        print(f"{Colors.DIM}[{TOOL_NAME}]{Colors.RESET} {msg}", file=sys.stderr)


def log_warn(msg):
    print(f"{Colors.YELLOW}[{TOOL_NAME}]{Colors.RESET} {msg}", file=sys.stderr)


def log_ok(msg, verbose=True):
    if verbose:
        print(f"{Colors.GREEN}[{TOOL_NAME}]{Colors.RESET} {msg}", file=sys.stderr)


def log_stat(label, value, verbose=True):
    if verbose:
        print(f"{Colors.DIM}[{TOOL_NAME}]{Colors.RESET} {Colors.CYAN}{label}:{Colors.RESET} {value}", file=sys.stderr)


# ── Utilities ────────────────────────────────────────────────────────────────

def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(65536)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def format_size(size):
    for unit in ("B", "K", "M", "G", "T"):
        if size < 1024:
            return f"{size:.0f}{unit}" if unit == "B" else f"{size:.1f}{unit}"
        size /= 1024
    return f"{size:.1f}P"


def extract_provenance(path):
    """Extract provenance metadata from file header."""
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            lines = []
            for i, line in enumerate(f):
                if i >= 120:
                    break
                lines.append(line)
    except Exception:
        return {}

    header = "".join(lines)
    prov = {}
    for key in ("tool", "version", "created", "license"):
        m = re.search(rf"{key}:\s*(.+)", header, re.IGNORECASE)
        if m:
            prov[key] = m.group(1).strip()

    agents = re.findall(r"\[AGENT\].*?name:\s*(.+?)(?:\n|$)", header, re.DOTALL)
    if agents:
        prov["agents"] = [a.strip() for a in agents]

    return prov


# ── Scanner ──────────────────────────────────────────────────────────────────

def scan_repo(repo_dir, verbose=False):
    """Scan repo for all artifacts with hashes and provenance."""
    artifacts = []
    repo_dir = os.path.expanduser(repo_dir)

    for root, dirs, files in os.walk(repo_dir):
        dirs[:] = [d for d in dirs if d != ".git"]
        for fname in sorted(files):
            path = os.path.join(root, fname)
            rel = os.path.relpath(path, repo_dir)

            try:
                st = os.stat(path)
                file_hash = sha256_file(path)
            except Exception as e:
                if verbose:
                    log_warn(f"Cannot process: {rel} — {e}")
                continue

            prov = extract_provenance(path)

            artifacts.append({
                "path": rel,
                "name": fname,
                "size": st.st_size,
                "mtime": st.st_mtime,
                "hash": file_hash,
                "provenance": prov,
            })

    if verbose:
        log_stat("Artifacts", len(artifacts))

    return artifacts


# ── HTML Generator ───────────────────────────────────────────────────────────

def generate_html(artifacts, base_url, timestamp):
    """Generate index.html with artifact listing."""
    rows = []
    for art in sorted(artifacts, key=lambda a: a["path"]):
        prov = art["provenance"]
        tool = html.escape(prov.get("tool", ""))
        version = html.escape(prov.get("version", ""))
        agents = html.escape(", ".join(prov.get("agents", [])))
        path_escaped = html.escape(art["path"])
        href = f"{base_url}/{art['path']}" if base_url else art["path"]

        rows.append(f"""      <tr>
        <td><a href="{html.escape(href)}">{path_escaped}</a></td>
        <td>{format_size(art['size'])}</td>
        <td><code>{art['hash'][:16]}…</code></td>
        <td>{tool} {version}</td>
        <td>{agents}</td>
      </tr>""")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>aitools — NOBUL</title>
  <style>
    :root {{
      --bg: #0d1117;
      --fg: #c9d1d9;
      --accent: #58a6ff;
      --border: #30363d;
      --surface: #161b22;
      --dim: #8b949e;
    }}
    * {{ margin: 0; padding: 0; box-sizing: border-box; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
      background: var(--bg);
      color: var(--fg);
      padding: 2rem;
      line-height: 1.6;
    }}
    h1 {{ color: var(--accent); margin-bottom: 0.25rem; font-size: 1.5rem; }}
    .meta {{ color: var(--dim); font-size: 0.85rem; margin-bottom: 2rem; }}
    table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 0.9rem;
    }}
    th {{
      text-align: left;
      padding: 0.5rem 0.75rem;
      border-bottom: 2px solid var(--border);
      color: var(--dim);
      font-weight: 600;
    }}
    td {{
      padding: 0.4rem 0.75rem;
      border-bottom: 1px solid var(--border);
    }}
    tr:hover td {{ background: var(--surface); }}
    a {{ color: var(--accent); text-decoration: none; }}
    a:hover {{ text-decoration: underline; }}
    code {{
      font-family: 'SF Mono', 'Fira Code', monospace;
      font-size: 0.8rem;
      color: var(--dim);
    }}
    footer {{
      margin-top: 2rem;
      padding-top: 1rem;
      border-top: 1px solid var(--border);
      color: var(--dim);
      font-size: 0.8rem;
    }}
  </style>
</head>
<body>
  <h1>aitools</h1>
  <p class="meta">NOBUL — nobul.tech — {html.escape(timestamp)}</p>
  <table>
    <thead>
      <tr>
        <th>Artifact</th>
        <th>Size</th>
        <th>SHA256</th>
        <th>Tool</th>
        <th>Agents</th>
      </tr>
    </thead>
    <tbody>
{chr(10).join(rows)}
    </tbody>
  </table>
  <footer>
    <p>{len(artifacts)} artifacts. Generated by aipublish {VERSION}.</p>
    <p>Homebase: <a href="https://nobulai.tools">nobulai.tools</a></p>
  </footer>
</body>
</html>
"""


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        prog=TOOL_NAME,
        description="Generate public artifact index for aitools.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Examples:\n"
               "  aipublish ~/repos/aitools\n"
               "  aipublish ~/repos/aitools -o ~/aitools-public --copy-artifacts\n"
               f"  aipublish ~/repos/aitools --base-url https://nobulai.tools\n",
    )
    parser.add_argument("repo", help="Repository directory to scan")
    parser.add_argument("-o", "--output", default=".",
                        help="Output directory (default: current dir)")
    parser.add_argument("--base-url", default="https://nobulai.tools",
                        help="Base URL for artifact links (default: https://nobulai.tools)")
    parser.add_argument("--copy-artifacts", action="store_true",
                        help="Copy artifact files to output directory")
    parser.add_argument("-v", "--verbose", action="store_true")
    parser.add_argument("--version", action="version",
                        version=f"{TOOL_NAME} {VERSION} (aitools)")

    args = parser.parse_args()

    if args.verbose:
        log_info(f"{TOOL_NAME} {VERSION} — NOBUL (nobul.tech)")
        log_info(f"Repo: {args.repo}")
        log_info(f"Output: {args.output}")

    t0 = time.time()
    artifacts = scan_repo(args.repo, verbose=args.verbose)

    if not artifacts:
        log_warn("No artifacts found.")
        return

    # Generate
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    out_dir = os.path.expanduser(args.output)
    os.makedirs(out_dir, exist_ok=True)

    # index.html
    index_html = generate_html(artifacts, args.base_url, timestamp)
    index_path = os.path.join(out_dir, "index.html")
    with open(index_path, "w") as f:
        f.write(index_html)
    if args.verbose:
        log_ok("index.html written")

    # manifest.json
    manifest = {
        "tool": TOOL_NAME,
        "version": VERSION,
        "base_url": args.base_url,
        "generated": timestamp,
        "artifacts": [{
            "path": a["path"],
            "size": a["size"],
            "sha256": a["hash"],
            "provenance": a["provenance"],
        } for a in artifacts],
    }
    manifest_path = os.path.join(out_dir, "manifest.json")
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
    if args.verbose:
        log_ok("manifest.json written")

    # Copy artifacts
    if args.copy_artifacts:
        import shutil
        for art in artifacts:
            src = os.path.join(os.path.expanduser(args.repo), art["path"])
            dst_dir = os.path.join(out_dir, os.path.dirname(art["path"]))
            os.makedirs(dst_dir, exist_ok=True)
            shutil.copy2(src, os.path.join(dst_dir, art["name"]))
        if args.verbose:
            log_ok(f"Copied {len(artifacts)} artifacts")

    elapsed = time.time() - t0
    if args.verbose:
        log_stat("Elapsed", f"{elapsed:.2f}s")
        log_ok(f"Ready to deploy: {out_dir}")


if __name__ == "__main__":
    main()
