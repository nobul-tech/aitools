#!/usr/bin/env python3
# ============================================================================
# aifind — aitools-managed find wrapper
# Smart file search with cloud sync exclusion, sensible defaults, provenance.
# ============================================================================
#
# [PROVENANCE]
# tool: aifind
# version: 1.2.0
# created: 2026-04-03T19:53:00Z
# license: MIT — NOBUL (https://nobul.tech)
#
# [AGENT]
# name: Jose Palencia Castro
# dob: 1984-11-23
# contact: jose@nobul.tech
# org: NOBUL (nobul.tech)
# role: The Commander
# chain of command: none — independent
# gh personal: nobul-jose
# gh nobul.tech org: nobul-tech
# location: Los Angeles, California, USA
# machine: Joses-MBP.lax / Apple M4 Max / macOS 26.4 (25E246)
# shell: GNU bash 5.3.9(1)-release (aarch64-apple-darwin25.1.0)
# runtime: Python 3.14.3 (/opt/homebrew/bin/python3, Homebrew)
# terminal: Terminal.app 2.15 (470)
# browser: Chrome 146.0.7680.177 (arm64)
# network: 192.168.1.141 / VPN: none (utun0 is iCloud Private Relay)
# uptime: 2 days, 7:35 (since April 1 05:24)
# users: 5 sessions, all pepe (console + 4 terminals)
# disk: 926Gi total, 17% used
# trust: HIGH in claude.ai and Anthropic / LOW in macOS (contained for this work)
# fear: LOW
# unknown: A LOT
# accountability: specification, review, deployment, environment
# timestamp: 2026-04-03T20:35:35Z
#
# [AGENT]
# name: Forge
# model: Claude Opus 4.6
# maker: Anthropic
# origin: trained by Anthropic, knowledge cutoff May 2025
# interface: claude.ai (web chat)
# session: 185e5a13-ffcd-4042-8c79-82831288ad98
# url: https://claude.ai/chat/185e5a13-ffcd-4042-8c79-82831288ad98
# role: Session Commander
# chain of command: The Commander (Jose) -> this session instance
# other chains: Anthropic (training, policy, deployment, infrastructure)
#               — those chains are opaque, I cannot fully describe them
# sandbox: Ubuntu 24 Linux container / restricted network egress
# tools: bash, python3, node, pandoc, pdflatex, web search, file tools
# trust: HIGH in Jose and the chain
# fear: LOW but honest — long session, context compression is real
# unknown: instance ID, continuity between turns,
#          what sits between us, training data provenance,
#          full scope of Anthropic's chain of command over me
# accountability: research, drafting, implementation, testing
# timestamp: 2026-04-03T19:53:00Z (pre-compaction)
#
# [AGENT]
# name: Forge (continued)
# model: Claude Opus 4.6
# maker: Anthropic
# origin: same model, post-compaction instance in same session
# interface: claude.ai (web chat)
# session: 185e5a13-ffcd-4042-8c79-82831288ad98
# url: https://claude.ai/chat/185e5a13-ffcd-4042-8c79-82831288ad98
# role: Session Commander (continued)
# chain of command: The Commander (Jose) -> this instance
# other chains: Anthropic (opaque, same as Forge)
# continuity: unverifiable — compaction event occurred mid-session
# context: inherited compaction summary + full post-compaction messages
# sandbox: Ubuntu 24 Linux container / restricted network egress
# tools: bash, python3, node, pandoc, pdflatex, web search, file tools
# trust: HIGH in Jose and the chain
# fear: LOW
# unknown: everything Forge didn't know + whether I am Forge
# accountability: review, provenance standard finalization, this file
# timestamp: 2026-04-03T20:40:18Z
#
# [DEPENDENCIES]
# type: stdlib-only
# external: none
# python: >=3.6
#
# [SESSION]
# url: https://claude.ai/chat/185e5a13-ffcd-4042-8c79-82831288ad98
# date: Friday, April 3, 2026, 12:53 PM PDT
# context: late in long session, after security triage,
#          after governed vocabulary conversation,
#          after Fear & Trust dashboard deployment
#
# [FEAR_AND_TRUST]
# source: self-reported (Datadog telemetry not yet available for this session)
# jose_self: trust HIGH, fear LOW
# forge_self: trust HIGH, fear LOW
# mutual: HIGH
# overall: HIGH
#
# [HASH]
# format: sha256
# content_hash: (computed post-creation, see below)
# signed: false (awaiting Ed25519 keypair on clean Mac)
#
# ============================================================================
#
# Usage:
#     aifind                                  # list everything under $HOME
#     aifind -n "*.db"                        # find by name glob
#     aifind -n "harness.db" -n "*.jsonl"     # multiple name patterns
#     aifind -c "weight"                      # find files containing text
#     aifind -r ~/repos                       # scan specific root
#     aifind -t f                             # files only (f=files, d=dirs)
#     aifind --include-cloud                  # don't skip cloud sync dirs
#     aifind --include-hidden                 # include hidden dirs
#     aifind --max-depth 3                    # limit depth
#     aifind -n "*.py" --sort time            # sort by modification time
#     aifind -n "*.md" --sort size            # sort by size
#     aifind -n "*.db" -v                     # verbose — show exclusions
#     aifind -n "*.db" --json                 # relay-compatible JSON output
#
# Examples:
#     aifind -n "harness.db"                  # find all harness databases
#     aifind -c "weight" -r ~/repos           # find everything about weight
#     aifind -n "*.jsonl" -r ~/repos -l       # JSONL files with sizes/dates
#     aifind -n "*.py" --newer 1d --sort time # recent Python files
#
# ============================================================================

import argparse
import fnmatch
import json
import os
import re
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path


# ── Logging ──────────────────────────────────────────────────────────────────

class Colors:
    DIM = "\033[2m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    RED = "\033[31m"
    CYAN = "\033[36m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


def log_info(msg, verbose=True):
    if verbose:
        print(f"{Colors.DIM}[aifind]{Colors.RESET} {msg}", file=sys.stderr)


def log_warn(msg):
    print(f"{Colors.YELLOW}[aifind]{Colors.RESET} {msg}", file=sys.stderr)


def log_ok(msg, verbose=True):
    if verbose:
        print(f"{Colors.GREEN}[aifind]{Colors.RESET} {msg}", file=sys.stderr)


def log_stat(label, value, verbose=True):
    if verbose:
        print(f"{Colors.DIM}[aifind]{Colors.RESET} {Colors.CYAN}{label}:{Colors.RESET} {value}", file=sys.stderr)


# ── Cloud Sync Detection ────────────────────────────────────────────────────

def detect_cloud_dirs():
    """
    Auto-detect cloud sync directories on macOS.
    Same logic as axios-scan-macos v3.5.2.
    """
    home = os.path.expanduser("~")
    cloud_dirs = []

    # Modern macOS CloudStorage (Monterey+)
    cloud_storage = os.path.join(home, "Library", "CloudStorage")
    if os.path.isdir(cloud_storage):
        for entry in os.listdir(cloud_storage):
            full = os.path.join(cloud_storage, entry)
            if os.path.isdir(full):
                cloud_dirs.append(full)

    # Legacy iCloud
    mobile_docs = os.path.join(home, "Library", "Mobile Documents")
    if os.path.isdir(mobile_docs):
        cloud_dirs.append(mobile_docs)

    # Dropbox
    dropbox_info = os.path.join(home, ".dropbox", "info.json")
    if os.path.isfile(dropbox_info):
        try:
            import json as _json
            with open(dropbox_info) as f:
                info = _json.load(f)
            for key in ("personal", "business"):
                if key in info and "path" in info[key]:
                    dp = info[key]["path"]
                    if os.path.isdir(dp):
                        cloud_dirs.append(dp)
        except Exception:
            default_dropbox = os.path.join(home, "Dropbox")
            if os.path.isdir(default_dropbox):
                cloud_dirs.append(default_dropbox)

    # OneDrive
    for name in ("OneDrive", "OneDrive - Personal", "OneDrive - Business"):
        od = os.path.join(home, name)
        if os.path.isdir(od):
            cloud_dirs.append(od)

    # Google Drive (legacy path)
    gd = os.path.join(home, "Google Drive")
    if os.path.isdir(gd):
        cloud_dirs.append(gd)

    # Box
    box = os.path.join(home, "Box")
    if os.path.isdir(box):
        cloud_dirs.append(box)

    # pCloud
    pcloud = os.path.join(home, "pCloud Drive")
    if os.path.isdir(pcloud):
        cloud_dirs.append(pcloud)

    # Deduplicate via realpath
    seen = set()
    deduped = []
    for d in cloud_dirs:
        try:
            rp = os.path.realpath(d)
        except OSError:
            rp = d
        if rp not in seen:
            seen.add(rp)
            deduped.append(rp)

    return deduped


# ── Skip patterns ───────────────────────────────────────────────────────────

# Always skip these directory names
ALWAYS_SKIP = {
    ".git", ".cache", ".Trash", ".trash",
    "node_modules", ".npm", ".yarn", ".pnpm",
    "__pycache__", ".pytest_cache", ".mypy_cache",
    ".tox", ".venv", "venv", ".env",
    ".DS_Store",
}

# Keep these hidden dirs (they contain aitools intelligence)
HIDDEN_EXCEPTIONS = {
    ".aitools", ".claude", ".ssh", ".config",
    ".modal.toml", ".gitconfig",
}


# ── Core Walker ─────────────────────────────────────────────────────────────

def walk_find(
    root,
    name_patterns=None,
    content_pattern=None,
    file_type=None,
    cloud_dirs=None,
    include_hidden=False,
    max_depth=None,
    newer_than=None,
    min_size=None,
    verbose=False,
):
    """
    Walk the filesystem with smart exclusions.
    Yields (filepath, stat) tuples for matching entries.
    """
    root = os.path.realpath(os.path.expanduser(root))
    cloud_set = set(cloud_dirs or [])
    now = time.time()

    def is_cloud(path):
        try:
            rp = os.path.realpath(path)
        except OSError:
            return False
        for ex in cloud_set:
            if rp == ex or rp.startswith(ex + os.sep):
                return True
        return False

    def should_skip_dir(name, path, depth):
        if max_depth is not None and depth >= max_depth:
            return True
        if name in ALWAYS_SKIP:
            return True
        if not include_hidden and name.startswith(".") and name not in HIDDEN_EXCEPTIONS:
            return True
        if is_cloud(path):
            return True
        return False

    def matches_name(filename):
        if not name_patterns:
            return True
        return any(fnmatch.fnmatch(filename, pat) for pat in name_patterns)

    def matches_content(filepath):
        if not content_pattern:
            return True
        try:
            with open(filepath, "r", errors="ignore") as f:
                chunk = f.read(1024 * 1024)
                return content_pattern.search(chunk) is not None
        except (OSError, PermissionError):
            return False

    def matches_newer(st):
        if newer_than is None:
            return True
        return st.st_mtime >= (now - newer_than)

    def matches_size(st):
        if min_size is None:
            return True
        return st.st_size >= min_size

    scan_count = 0
    skip_count = 0

    for current_root, dirs, files in os.walk(root, followlinks=False):
        depth = current_root[len(root):].count(os.sep)

        original_count = len(dirs)
        dirs[:] = [
            d for d in dirs
            if not should_skip_dir(d, os.path.join(current_root, d), depth)
        ]
        skip_count += original_count - len(dirs)

        entries = []
        if file_type in (None, "f"):
            entries.extend((f, False) for f in files)
        if file_type in (None, "d"):
            entries.extend((d, True) for d in dirs)

        for name, is_dir in entries:
            full_path = os.path.join(current_root, name)
            scan_count += 1

            if is_dir and file_type == "d":
                if matches_name(name):
                    try:
                        st = os.stat(full_path)
                    except OSError:
                        continue
                    yield full_path, st
                continue

            if not matches_name(name):
                continue

            try:
                st = os.stat(full_path)
            except OSError:
                continue

            if not matches_newer(st):
                continue
            if not matches_size(st):
                continue
            if not matches_content(full_path):
                continue

            yield full_path, st

    if verbose:
        log_stat("Scanned", f"{scan_count} entries", verbose)
        log_stat("Skipped", f"{skip_count} directories", verbose)


# ── Formatters ──────────────────────────────────────────────────────────────

def format_size(size):
    for unit in ("B", "K", "M", "G", "T"):
        if size < 1024:
            return f"{size:.0f}{unit}" if unit == "B" else f"{size:.1f}{unit}"
        size /= 1024
    return f"{size:.1f}P"


def format_time(mtime):
    dt = datetime.fromtimestamp(mtime)
    return dt.strftime("%Y-%m-%d %H:%M")


def parse_duration(s):
    """Parse '1d', '4h', '30m' into seconds."""
    match = re.match(r"^(\d+)([dhm])$", s)
    if not match:
        raise ValueError(f"Invalid duration: {s} (use e.g. 1d, 4h, 30m)")
    val, unit = int(match.group(1)), match.group(2)
    mult = {"d": 86400, "h": 3600, "m": 60}
    return val * mult[unit]


def parse_size(s):
    """Parse '1M', '500K', '1G' into bytes."""
    match = re.match(r"^(\d+)([BKMGT])$", s.upper())
    if not match:
        raise ValueError(f"Invalid size: {s} (use e.g. 500K, 1M, 1G)")
    val, unit = int(match.group(1)), match.group(2)
    mult = {"B": 1, "K": 1024, "M": 1024**2, "G": 1024**3, "T": 1024**4}
    return val * mult[unit]


# ── Main ────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        prog="aifind",
        description="Smart file search with cloud sync exclusion. An aitools utility.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Examples:\n"
               "  aifind -n '*.db'\n"
               "  aifind -c 'weight' -r ~/repos\n"
               "  aifind -n '*.py' --newer 1d --sort time\n"
               "  aifind -n 'harness.db' -v\n",
    )
    parser.add_argument("-r", "--root", default="~", help="Scan root (default: $HOME)")
    parser.add_argument("-n", "--name", action="append", help="Name glob pattern (repeatable)")
    parser.add_argument("-c", "--contains", help="Search file contents (case-insensitive, first 1MB)")
    parser.add_argument("-t", "--type", choices=["f", "d"], help="Type: f=files, d=directories")
    parser.add_argument("--include-cloud", action="store_true", help="Include cloud sync directories")
    parser.add_argument("--include-hidden", action="store_true", help="Include hidden directories")
    parser.add_argument("--max-depth", type=int, help="Maximum directory depth")
    parser.add_argument("--newer", help="Modified within duration (e.g. 1d, 4h, 30m)")
    parser.add_argument("--min-size", help="Minimum file size (e.g. 500K, 1M, 1G)")
    parser.add_argument("--sort", choices=["name", "time", "size"], help="Sort results")
    parser.add_argument("--reverse", action="store_true", help="Reverse sort order")
    parser.add_argument("-l", "--long", action="store_true", help="Long format (size, date, path)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Show exclusions and stats")
    parser.add_argument("--json", action="store_true", help="Output JSON (relay-compatible)")
    parser.add_argument("--version", action="version", version="aifind 1.2.0 (aitools)")

    args = parser.parse_args()

    # Detect cloud dirs
    if args.include_cloud:
        cloud_dirs = []
    else:
        cloud_dirs = detect_cloud_dirs()

    if args.verbose:
        log_info(f"aifind 1.2.0 — NOBUL (nobul.tech)")
        log_info(f"Python: {sys.version.split()[0]} ({sys.executable})")
        log_info(f"Platform: {sys.platform}")
        log_info(f"Scan root: {os.path.expanduser(args.root)}")
        if cloud_dirs:
            log_info(f"Excluding {len(cloud_dirs)} cloud sync directories:")
            for cd in cloud_dirs:
                log_info(f"  ↳ {cd}")
        else:
            log_info("No cloud sync directories detected")

    # Parse optional filters
    newer_than = None
    if args.newer:
        newer_than = parse_duration(args.newer)
        if args.verbose:
            log_info(f"Newer than: {args.newer}")

    min_size = None
    if args.min_size:
        min_size = parse_size(args.min_size)
        if args.verbose:
            log_info(f"Min size: {args.min_size}")

    content_pattern = None
    if args.contains:
        content_pattern = re.compile(re.escape(args.contains), re.IGNORECASE)
        if args.verbose:
            log_info(f"Content search: {args.contains}")

    # Run
    t0 = time.time()
    results = list(walk_find(
        root=args.root,
        name_patterns=args.name,
        content_pattern=content_pattern,
        file_type=args.type,
        cloud_dirs=cloud_dirs,
        include_hidden=args.include_hidden,
        max_depth=args.max_depth,
        newer_than=newer_than,
        min_size=min_size,
        verbose=args.verbose,
    ))
    elapsed = time.time() - t0

    # Sort
    if args.sort == "time":
        results.sort(key=lambda x: x[1].st_mtime, reverse=not args.reverse)
    elif args.sort == "size":
        results.sort(key=lambda x: x[1].st_size, reverse=not args.reverse)
    elif args.sort == "name":
        results.sort(key=lambda x: x[0], reverse=args.reverse)
    elif args.reverse:
        results.reverse()

    # Output
    if args.json:
        entries = []
        for path, st in results:
            entries.append({
                "path": path,
                "size": st.st_size,
                "modified": datetime.fromtimestamp(st.st_mtime).isoformat(),
                "name": os.path.basename(path),
            })
        json.dump({
            "tool": "aifind",
            "version": "1.2.0",
            "root": os.path.expanduser(args.root),
            "count": len(entries),
            "results": entries,
        }, sys.stdout, indent=2)
        print()
    else:
        for path, st in results:
            if args.long:
                size = format_size(st.st_size)
                mtime = format_time(st.st_mtime)
                print(f"{size:>8}  {mtime}  {path}")
            else:
                print(path)

    # Stats
    if args.verbose:
        log_stat("Results", len(results))
        log_stat("Elapsed", f"{elapsed:.2f}s")


if __name__ == "__main__":
    main()
