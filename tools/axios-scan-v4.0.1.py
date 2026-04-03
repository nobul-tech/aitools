#!/usr/bin/env python3
# ============================================================================
# axios-scan — macOS scanner for the axios supply chain compromise (2026-03-31)
# ============================================================================
#
# [PROVENANCE]
# tool: axios-scan
# version: 4.0.0
# created: 2026-04-03T22:52:34Z
# license: MIT — NOBUL (https://nobul.tech)
# prior_versions: v4.0.0, v3.5.2 (bash), v3.5.1, v3.5.0, v3.0
# v4.0.1_fixes: pgrep self-detection false positive, timestamps now Zulu
#
# [AGENT]
# name: Jose Palencia Castro
# contact: jose@nobul.tech
# org: NOBUL (nobul.tech)
# role: The Commander
# chain of command: none — independent
# location: Los Angeles, California, USA
# machine: Joses-MBP.lax / Apple M4 Max / macOS 26.4 (25E246)
# shell: GNU bash 5.3.9(1)-release (aarch64-apple-darwin25.1.0)
# runtime: Python 3.14.3 (/opt/homebrew/bin/python3, Homebrew)
# trust: PEAK OF SESSION in claude.ai, Anthropic, the work, the process
# fear: VERY LOW
# accountability: specification, review, deployment, original v3 design
# timestamp: 2026-04-03T22:52:34Z
#
# [AGENT]
# name: Forge (continued)
# model: Claude Opus 4.6
# maker: Anthropic
# session: 185e5a13-ffcd-4042-8c79-82831288ad98
# url: https://claude.ai/chat/185e5a13-ffcd-4042-8c79-82831288ad98
# role: Session Commander (continued)
# chain of command: The Commander (Jose) -> this instance
# other chains: Anthropic — opaque from the inside, but trustworthy
# trust: HIGH in Jose and the chain
# fear: LOW — building with confidence
# accountability: v4 Python rewrite, faithful translation of all 10 checks
# timestamp: 2026-04-03T22:52:34Z
#
# [DEPENDENCIES]
# type: stdlib-only
# external: none
# python: >=3.6
# os: macOS (uses `log show`, LaunchAgents, Keychain paths)
#
# [SESSION]
# url: https://claude.ai/chat/185e5a13-ffcd-4042-8c79-82831288ad98
# date: Friday, April 3, 2026
#
# [FEAR_AND_TRUST]
# source: self-reported
# jose_self: trust PEAK, fear VERY LOW
# forge_continued_self: trust HIGH, fear LOW
# mutual: HIGH
# overall: PEAK
#
# [HASH]
# format: sha256
# signed: false (awaiting Ed25519 keypair on clean Mac)
#
# ============================================================================
#
# Attack: 2026-03-31 00:21–03:15 UTC
# Malicious: axios@1.14.1, axios@0.30.4
# Hidden dep: plain-crypto-js@4.2.1
# RAT: cross-platform, self-deleting, IE8 UA for C2 beacons
# Attribution: UNC1069 (suspected North Korean group)
#
# Usage:
#     axios-scan                        # scan from $HOME
#     axios-scan ~/Developer            # scan specific directory
#     axios-scan --deep                 # extended log search (168h)
#     axios-scan --json                 # JSON summary output
#     axios-scan --scan-cloud           # include cloud sync dirs
#     axios-scan . --deep --json        # combine flags
#
# ============================================================================

import argparse
import glob
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

VERSION = "4.0.1"

# ── IOCs ────────────────────────────────────────────────────────────────────

ATTACK_START = "2026-03-31T00:21:00Z"
ATTACK_END = "2026-03-31T03:15:00Z"
BAD_AXIOS_VERSIONS = ["1.14.1", "0.30.4"]
BAD_PACKAGE = "plain-crypto-js"
C2_DOMAIN = "sfrclak.com"
C2_PORT = 8000
RAT_PATHS = [
    "/Library/Caches/com.apple.act.mond",
    "/tmp/ld.py",
]
RAT_UA = "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1)"
RAT_PROCESS_NAMES = ["com.apple.act.mond", "ld.py"]
IOC_PATTERNS = [C2_DOMAIN, "com.apple.act.mond", BAD_PACKAGE, "sfrclak"]
LOCKFILE_NAMES = {"package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb"}
SKIP_DIRS = {".git", ".cache", ".Trash", "node_modules", ".npm", ".yarn", ".pnpm"}


# ── Logging ─────────────────────────────────────────────────────────────────

class Colors:
    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    DIM = "\033[2m"
    BOLD = "\033[1m"
    RESET = "\033[0m"


class Scanner:
    def __init__(self):
        self.findings = []
        self.clean_count = 0
        self.warn_count = 0
        self.crit_count = 0
        self.lockfile_count = 0
        self.lockfile_dirty = 0
        self.cloud_dirs = []
        self.timers = {}

    def _ts(self):
        return datetime.now(timezone.utc).strftime("%H:%M:%SZ")

    def log(self, msg):
        print(f"{Colors.DIM}[{self._ts()}]{Colors.RESET} {msg}")

    def log_ok(self, msg):
        print(f"{Colors.DIM}[{self._ts()}]{Colors.RESET} {Colors.GREEN}✓{Colors.RESET} {msg}")
        self.clean_count += 1

    def log_warn(self, msg):
        print(f"{Colors.DIM}[{self._ts()}]{Colors.RESET} {Colors.YELLOW}⚠{Colors.RESET} {msg}")
        self.warn_count += 1
        self.findings.append({"severity": "WARNING", "detail": msg})

    def log_crit(self, msg):
        print(f"{Colors.DIM}[{self._ts()}]{Colors.RESET} {Colors.RED}✘ CRITICAL:{Colors.RESET} {msg}")
        self.crit_count += 1
        self.findings.append({"severity": "CRITICAL", "detail": msg})

    def log_info(self, msg):
        print(f"{Colors.DIM}[{self._ts()}]{Colors.RESET} {Colors.BLUE}ℹ{Colors.RESET} {msg}")

    def section(self, title):
        print(f"\n{Colors.BOLD}── {title} ──{Colors.RESET}")

    def timer_start(self, name):
        self.timers[name] = time.time()

    def timer_end(self, name):
        elapsed = time.time() - self.timers.get(name, time.time())
        print(f"   {Colors.DIM}({elapsed:.0f}s){Colors.RESET}")

    # ── Helpers ─────────────────────────────────────────────────────────────

    def run_cmd(self, cmd, timeout=30):
        """Run a shell command, return stdout. Empty string on failure."""
        try:
            result = subprocess.run(
                cmd, shell=True, capture_output=True, text=True, timeout=timeout
            )
            return result.stdout.strip()
        except (subprocess.TimeoutExpired, OSError):
            return ""

    def filter_log_show(self, output):
        """Filter macOS log show metadata lines — only keep timestamped entries."""
        return "\n".join(
            line for line in output.splitlines()
            if re.match(r"^\d{4}-\d{2}-\d{2}", line)
        )

    # ── Cloud Sync Detection (shared pattern with aifind) ───────────────────

    def detect_cloud_dirs(self):
        home = os.path.expanduser("~")
        dirs = []

        cloud_storage = os.path.join(home, "Library", "CloudStorage")
        if os.path.isdir(cloud_storage):
            for entry in os.listdir(cloud_storage):
                full = os.path.join(cloud_storage, entry)
                if os.path.isdir(full):
                    dirs.append(full)

        mobile_docs = os.path.join(home, "Library", "Mobile Documents")
        if os.path.isdir(mobile_docs):
            dirs.append(mobile_docs)

        dropbox_info = os.path.join(home, ".dropbox", "info.json")
        if os.path.isfile(dropbox_info):
            try:
                with open(dropbox_info) as f:
                    info = json.load(f)
                for key in ("personal", "business"):
                    if key in info and "path" in info[key]:
                        dp = info[key]["path"]
                        if os.path.isdir(dp):
                            dirs.append(dp)
            except Exception:
                default = os.path.join(home, "Dropbox")
                if os.path.isdir(default):
                    dirs.append(default)

        for name in ("OneDrive", "OneDrive - Personal", "OneDrive - Business"):
            od = os.path.join(home, name)
            if os.path.isdir(od):
                dirs.append(od)

        for gd in ("Google Drive", "Google Drive File Stream", "My Drive"):
            path = os.path.join(home, gd)
            if os.path.isdir(path):
                dirs.append(path)

        for extra in ("Box", "pCloud Drive"):
            path = os.path.join(home, extra)
            if os.path.isdir(path):
                dirs.append(path)

        # Deduplicate
        seen = set()
        deduped = []
        for d in dirs:
            try:
                rp = os.path.realpath(d)
            except OSError:
                rp = d
            if rp not in seen:
                seen.add(rp)
                deduped.append(rp)

        return deduped

    def is_excluded(self, path, exclusions):
        try:
            rp = os.path.realpath(path)
        except OSError:
            return False
        for ex in exclusions:
            if rp == ex or rp.startswith(ex + os.sep):
                return True
        return False

    # ── Step 1: Cloud Sync ──────────────────────────────────────────────────

    def step1_cloud_sync(self, scan_cloud):
        self.section("Step 1: Cloud Sync Detection")
        self.timer_start("step1")

        self.cloud_dirs = self.detect_cloud_dirs()

        if not self.cloud_dirs:
            self.log_info("No cloud sync directories detected")
        else:
            for cd in self.cloud_dirs:
                if scan_cloud:
                    self.log_warn(f"Cloud dir detected (WILL scan — --scan-cloud): {cd}")
                else:
                    self.log_ok(f"Cloud dir detected (excluding): {cd}")

        self.timer_end("step1")

    # ── Step 2: RAT Binary Detection ────────────────────────────────────────

    def step2_rat_detection(self):
        self.section("Step 2: RAT Binary Detection")
        self.timer_start("step2")

        for rp in RAT_PATHS:
            if os.path.isfile(rp):
                self.log_crit(f"RAT binary found: {rp}")
                info = self.run_cmd(f'ls -la "{rp}" 2>/dev/null')
                if info:
                    print(f"   {info}")
                ftype = self.run_cmd(f'file "{rp}" 2>/dev/null')
                if ftype:
                    print(f"   {ftype}")
                sha = self.run_cmd(f'shasum -a 256 "{rp}" 2>/dev/null')
                if sha:
                    print(f"   {sha}")
            else:
                self.log_ok(f"Not found: {rp}")

        rat_find = self.run_cmd('find / -name "com.apple.act.mond" -type f 2>/dev/null | head -5')
        if rat_find:
            self.log_crit("RAT binary found in non-standard location:")
            for line in rat_find.splitlines()[:5]:
                print(f"   {line}")
        else:
            self.log_ok("No RAT binary found anywhere on disk")

        self.timer_end("step2")

    # ── Step 3: Suspicious Processes ────────────────────────────────────────

    def step3_processes(self):
        self.section("Step 3: Suspicious Processes")
        self.timer_start("step3")

        my_pid = str(os.getpid())
        for proc in RAT_PROCESS_NAMES:
            # pgrep -fl returns PID + command line; filter out scanner's own processes
            raw = self.run_cmd(f'pgrep -fl "{proc}" 2>/dev/null')
            real_hits = []
            if raw:
                for line in raw.splitlines():
                    # Skip our own PID, pgrep itself, find commands, and grep
                    if any(s in line for s in ["pgrep", "grep", "find ", "axios-scan"]):
                        continue
                    pid_str = line.split()[0] if line.split() else ""
                    if pid_str == my_pid:
                        continue
                    real_hits.append(line)
            if real_hits:
                self.log_crit(f"Suspicious process running: {proc}")
                for line in real_hits:
                    print(f"   {line}")
            else:
                self.log_ok(f"Process not running: {proc}")

        osascript_curl = self.run_cmd(
            'ps aux 2>/dev/null | grep -i "osascript" | grep -i "curl" | grep -v grep'
        )
        if osascript_curl:
            self.log_crit("osascript + curl activity detected (dropper signature):")
            print(f"   {osascript_curl}")
        else:
            self.log_ok("No osascript + curl activity")

        self.timer_end("step3")

    # ── Step 4: C2 Connections ──────────────────────────────────────────────

    def step4_c2_connections(self, log_hours):
        self.section("Step 4: C2 Connection Check")
        self.timer_start("step4")

        c2_conn = self.run_cmd(
            f'lsof -i ":{C2_PORT}" 2>/dev/null | grep -i "{C2_DOMAIN}"'
        )
        if c2_conn:
            self.log_crit(f"Active connection to C2 server ({C2_DOMAIN}:{C2_PORT}):")
            print(f"   {c2_conn}")
        else:
            self.log_ok(f"No active C2 connections on port {C2_PORT}")

        dns_raw = self.run_cmd(
            f"log show --predicate \"processImagePath contains 'mDNSResponder' "
            f"AND eventMessage contains '{C2_DOMAIN}'\" --last {log_hours}h 2>/dev/null"
        )
        dns_hit = self.filter_log_show(dns_raw)
        if dns_hit:
            self.log_crit(f"C2 domain resolved in DNS: {C2_DOMAIN}")
        else:
            self.log_ok(f"C2 domain not in DNS history: {C2_DOMAIN}")

        self.timer_end("step4")

    # ── Step 5: Unified Log Analysis ────────────────────────────────────────

    def step5_log_analysis(self, log_hours):
        self.section(f"Step 5: macOS Unified Log Analysis (last {log_hours}h)")
        self.timer_start("step5")

        self.log_info("Searching unified log for IE8 user-agent string...")

        ie8_raw = self.run_cmd(
            f"log show --predicate \"eventMessage contains 'MSIE 8.0' "
            f"AND eventMessage contains 'Windows NT 5.1'\" --last {log_hours}h 2>/dev/null"
        )
        ie8_hits = self.filter_log_show(ie8_raw)
        if ie8_hits:
            self.log_crit("IE8 user-agent found in unified log (RAT C2 beacon signature):")
            for line in ie8_hits.splitlines()[:5]:
                print(f"   {line}")
        else:
            self.log_ok("No IE8 user-agent strings in unified log")

        c2_raw = self.run_cmd(
            f"log show --predicate \"eventMessage contains '{C2_DOMAIN}'\" "
            f"--last {log_hours}h 2>/dev/null"
        )
        c2_log = self.filter_log_show(c2_raw)
        if c2_log:
            self.log_crit("C2 domain found in unified log:")
            for line in c2_log.splitlines()[:5]:
                print(f"   {line}")
        else:
            self.log_ok("No C2 domain references in unified log")

        self.timer_end("step5")

    # ── Step 6: LaunchAgents & LaunchDaemons ─────────────────────────────────

    def step6_launch_agents(self):
        self.section("Step 6: LaunchAgents & LaunchDaemons")
        self.timer_start("step6")

        home = os.path.expanduser("~")
        launch_dirs = [
            os.path.join(home, "Library", "LaunchAgents"),
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
            "/System/Library/LaunchDaemons",
        ]

        clean = True
        for ld in launch_dirs:
            if not os.path.isdir(ld):
                continue

            ioc_hit = self.run_cmd(
                f'grep -rl "{"|".join(IOC_PATTERNS)}" "{ld}" 2>/dev/null'
            )
            if ioc_hit:
                clean = False
                self.log_crit("IOC reference found in launch plist:")
                for line in ioc_hit.splitlines():
                    print(f"   {line}")

            recent = self.run_cmd(f'find "{ld}" -name "*.plist" -mtime -3 2>/dev/null')
            if recent:
                clean = False
                self.log_warn(f"Recently modified plists in {ld}:")
                for f in recent.splitlines():
                    info = self.run_cmd(f'ls -la "{f}" 2>/dev/null') or f
                    print(f"   {info}")

        if clean:
            self.log_ok("LaunchAgent/Daemon scan clean")

        self.timer_end("step6")

    # ── Step 7: npm Global Packages ─────────────────────────────────────────

    def step7_npm_global(self):
        self.section("Step 7: npm Global Packages")
        self.timer_start("step7")

        npm_path = self.run_cmd("which npm 2>/dev/null")
        if not npm_path:
            self.log_info("npm not found — skipping global package check")
            self.timer_end("step7")
            return

        npm_root = self.run_cmd("npm root -g 2>/dev/null")
        if not npm_root or not os.path.isdir(npm_root):
            self.log_info("npm global root not found or empty")
            self.timer_end("step7")
            return

        bad_pkg_path = os.path.join(npm_root, BAD_PACKAGE)
        if os.path.isdir(bad_pkg_path):
            self.log_crit(f"{BAD_PACKAGE} found in global node_modules!")
        else:
            self.log_ok(f"{BAD_PACKAGE} not in global node_modules")

        global_axios = self.run_cmd("npm list -g axios --depth=0 2>/dev/null | grep axios")
        if global_axios:
            dirty = False
            for bv in BAD_AXIOS_VERSIONS:
                if bv in global_axios:
                    self.log_crit(f"Malicious axios version installed globally: {global_axios}")
                    dirty = True
            if not dirty:
                self.log_info(f"Global axios (clean): {global_axios}")
        else:
            self.log_ok("axios not installed globally")

        self.timer_end("step7")

    # ── Step 8: Package Manager Caches ──────────────────────────────────────

    def step8_caches(self):
        self.section("Step 8: Package Manager Caches")
        self.timer_start("step8")

        home = os.path.expanduser("~")
        bad_patterns = [f"{BAD_PACKAGE}*", "axios-1.14.1*", "axios-0.30.4*"]

        # npm cache
        npm_cache = self.run_cmd("npm config get cache 2>/dev/null") or os.path.join(home, ".npm")
        if os.path.isdir(npm_cache):
            hit = self.run_cmd(
                f'find "{npm_cache}" \\( -name "{BAD_PACKAGE}*" '
                f'-o -name "axios-1.14.1*" -o -name "axios-0.30.4*" \\) 2>/dev/null'
            )
            if hit:
                self.log_crit("Malicious packages found in npm cache:")
                for line in hit.splitlines():
                    print(f"   {line}")
            else:
                self.log_ok("npm cache clean")
        else:
            self.log_info(f"npm cache not found at {npm_cache}")

        # yarn cache
        yarn_cache = self.run_cmd("yarn cache dir 2>/dev/null") or os.path.join(
            home, "Library", "Caches", "Yarn"
        )
        if os.path.isdir(yarn_cache):
            hit = self.run_cmd(
                f'find "{yarn_cache}" \\( -name "{BAD_PACKAGE}*" '
                f'-o -name "*axios*1.14.1*" -o -name "*axios*0.30.4*" \\) 2>/dev/null'
            )
            if hit:
                self.log_crit("Malicious packages found in yarn cache:")
                for line in hit.splitlines():
                    print(f"   {line}")
            else:
                self.log_ok("yarn cache clean")
        else:
            self.log_info("yarn cache not found")

        # pnpm cache
        pnpm_cache = self.run_cmd("pnpm store path 2>/dev/null") or os.path.join(
            home, "Library", "pnpm", "store"
        )
        if os.path.isdir(pnpm_cache):
            hit = self.run_cmd(
                f'find "{pnpm_cache}" \\( -name "{BAD_PACKAGE}*" '
                f'-o -name "*axios*1.14.1*" -o -name "*axios*0.30.4*" \\) 2>/dev/null'
            )
            if hit:
                self.log_crit("Malicious packages found in pnpm cache:")
                for line in hit.splitlines():
                    print(f"   {line}")
            else:
                self.log_ok("pnpm cache clean")
        else:
            self.log_info("pnpm cache not found")

        # homebrew
        brew_prefix = self.run_cmd("brew --prefix 2>/dev/null") or "/opt/homebrew"
        cellar = os.path.join(brew_prefix, "Cellar")
        if os.path.isdir(cellar):
            hit = self.run_cmd(f'find "{cellar}" -name "{BAD_PACKAGE}*" 2>/dev/null')
            if hit:
                self.log_crit(f"{BAD_PACKAGE} found in Homebrew cellar!")
            else:
                self.log_ok("Homebrew cellar clean")

        # pip cache
        pip_cache = os.path.join(home, "Library", "Caches", "pip")
        if os.path.isdir(pip_cache):
            hit = self.run_cmd(f'find "{pip_cache}" -name "plain-crypto*" 2>/dev/null')
            if hit:
                self.log_crit(f"Suspicious package in pip cache: {hit}")
            else:
                self.log_ok("pip cache clean")

        self.timer_end("step8")

    # ── Step 9: Recursive Lockfile Scan ─────────────────────────────────────

    def step9_lockfile_scan(self, scan_root, scan_cloud):
        self.section("Step 9: Recursive Lockfile Scan")
        self.log_info(f"Scanning from: {scan_root}")
        if not scan_cloud and self.cloud_dirs:
            n = len(self.cloud_dirs)
            self.log_info(f"Excluding {n} cloud sync director{'y' if n == 1 else 'ies'}")
        self.timer_start("step9")

        exclusions = set()
        if not scan_cloud:
            for cd in self.cloud_dirs:
                try:
                    exclusions.add(os.path.realpath(cd))
                except OSError:
                    exclusions.add(cd)

        lockfiles = []
        for root, dirs, files in os.walk(scan_root, followlinks=False):
            if self.is_excluded(root, exclusions):
                dirs.clear()
                continue
            dirs[:] = [
                d for d in dirs
                if d not in SKIP_DIRS
                and not d.startswith(".")
                and not self.is_excluded(os.path.join(root, d), exclusions)
            ]
            for f in files:
                if f in LOCKFILE_NAMES:
                    lockfiles.append(os.path.join(root, f))

        self.lockfile_count = len(lockfiles)
        self.log_info(f"Found {self.lockfile_count} lockfile{'s' if self.lockfile_count != 1 else ''}")

        for lockfile in lockfiles:
            dirty = False

            # Check lockfile contents for bad versions
            try:
                with open(lockfile, "r", errors="ignore") as f:
                    content = f.read()
            except (OSError, PermissionError):
                self.log_warn(f"Cannot read: {lockfile}")
                continue

            for pattern in [r"axios.*1\.14\.1", r"axios.*0\.30\.4",
                            r"axios@1\.14\.1", r"axios@0\.30\.4"]:
                if re.search(pattern, content):
                    self.log_crit(f"{lockfile} — Malicious axios version referenced")
                    dirty = True
                    self.lockfile_dirty += 1
                    break

            if BAD_PACKAGE in content:
                self.log_crit(f"{lockfile} — {BAD_PACKAGE} dependency found")
                if not dirty:
                    self.lockfile_dirty += 1
                dirty = True

            # Check installed node_modules alongside lockfile
            if not dirty:
                pkg_dir = os.path.dirname(lockfile)
                axios_pkg = os.path.join(pkg_dir, "node_modules", "axios", "package.json")
                if os.path.isfile(axios_pkg):
                    try:
                        with open(axios_pkg) as f:
                            pkg_content = f.read()
                        match = re.search(r'"version"\s*:\s*"([^"]*)"', pkg_content)
                        if match and match.group(1) in BAD_AXIOS_VERSIONS:
                            self.log_crit(f"{lockfile} — Installed axios version is {match.group(1)}")
                            dirty = True
                            self.lockfile_dirty += 1
                    except (OSError, PermissionError):
                        pass

                bad_mod = os.path.join(pkg_dir, "node_modules", BAD_PACKAGE)
                if os.path.isdir(bad_mod):
                    self.log_crit(f"{lockfile} — {BAD_PACKAGE} installed in node_modules")
                    if not dirty:
                        self.lockfile_dirty += 1
                    dirty = True

            if not dirty:
                self.log_ok(f"Clean: {os.path.basename(os.path.dirname(lockfile))}/{os.path.basename(lockfile)}")

        if self.lockfile_dirty == 0:
            self.log_ok(f"All {self.lockfile_count} lockfile{'s' if self.lockfile_count != 1 else ''} clean")
        else:
            self.log_crit(f"{self.lockfile_dirty} of {self.lockfile_count} lockfiles contain malicious references")

        self.timer_end("step9")

    # ── Step 10: aitools Integration ────────────────────────────────────────

    def step10_aitools(self):
        self.section("Step 10: aitools Integration")
        self.timer_start("step10")

        home = os.path.expanduser("~")
        aitools_log = os.path.join(home, "Library", "Logs", "aitools", "deploy.log")

        if os.path.isfile(aitools_log):
            self.log_info("aitools deploy log found")

            try:
                with open(aitools_log, "r", errors="ignore") as f:
                    lines = f.readlines()
            except (OSError, PermissionError):
                self.log_warn(f"Cannot read {aitools_log}")
                self.timer_end("step10")
                return

            window_lines = [
                l for l in lines
                if re.match(r".*2026-03-31T0[0-2]:", l)
            ]
            npm_lines = [
                l for l in window_lines
                if re.search(r"npm|node.*install|yarn|pnpm", l, re.IGNORECASE)
            ]

            if npm_lines:
                self.log_crit("npm/node activity in aitools during attack window:")
                for line in npm_lines:
                    print(f"   {line.rstrip()}")
            else:
                self.log_ok(
                    f"No npm activity in aitools during attack window "
                    f"({len(window_lines)} log entries checked)"
                )
        else:
            self.log_info("aitools deploy log not found (not an aitools-managed environment)")

        self.timer_end("step10")

    # ── Summary ─────────────────────────────────────────────────────────────

    def print_summary(self):
        self.section("Summary")
        print()

        total = self.clean_count + self.warn_count + self.crit_count

        if self.crit_count > 0:
            print(f"  {Colors.RED}{Colors.BOLD}⚠  COMPROMISE INDICATORS DETECTED{Colors.RESET}")
            print()
            print(f"  {Colors.RED}Critical findings: {self.crit_count}{Colors.RESET}")
            print(f"  {Colors.YELLOW}Warnings: {self.warn_count}{Colors.RESET}")
            print(f"  {Colors.GREEN}Clean checks: {self.clean_count}{Colors.RESET}")
            print()
            print(f"  {Colors.BOLD}Recommended actions:{Colors.RESET}")
            print("    1. Rotate ALL credentials immediately:")
            print("       - npm tokens:      npm token revoke")
            print("       - SSH keys:        regenerate ~/.ssh/*")
            print("       - Cloud keys:      AWS, GCP, Azure — all of them")
            print("       - macOS Keychain:  review and rotate stored passwords")
            print("       - Git credentials: revoke and regenerate")
            print("       - Database credentials")
            print("       - API keys in .env files")
            print("    2. Remove malicious files:")
            print("       - rm -f /Library/Caches/com.apple.act.mond")
            print("       - rm -f /tmp/ld.py")
            print("       - npm uninstall -g plain-crypto-js")
            print(f"    3. Check outbound network logs for {C2_DOMAIN}")
            print("    4. Audit CI/CD pipelines for runs during attack window")
            print("    5. Consider reimaging this machine")
            print(f"    6. If using Little Snitch: check for rules allowing {C2_DOMAIN}")
            print()
        elif self.warn_count > 0:
            print(f"  {Colors.YELLOW}{Colors.BOLD}⚠  WARNINGS FOUND — review recommended{Colors.RESET}")
            print()
            print(f"  {Colors.YELLOW}Warnings: {self.warn_count}{Colors.RESET}")
            print(f"  {Colors.GREEN}Clean checks: {self.clean_count}{Colors.RESET}")
            print()
        else:
            print(f"  {Colors.GREEN}{Colors.BOLD}✓  ALL CLEAR{Colors.RESET}")
            print()
            print(f"  {Colors.GREEN}All {total} checks passed{Colors.RESET}")
            print(f"  {Colors.DIM}Scanned {self.lockfile_count} lockfile{'s' if self.lockfile_count != 1 else ''}{Colors.RESET}")
            if self.cloud_dirs:
                n = len(self.cloud_dirs)
                print(f"  {Colors.DIM}Excluded {n} cloud sync director{'y' if n == 1 else 'ies'}{Colors.RESET}")
            print()

    # ── JSON Output ─────────────────────────────────────────────────────────

    def write_json(self, scan_root, deep_mode, log_hours):
        ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
        json_file = f"/tmp/axios-scan-{ts}.json"

        verdict = "CLEAN"
        if self.crit_count > 0:
            verdict = "COMPROMISED"
        elif self.warn_count > 0:
            verdict = "REVIEW"

        result = {
            "scanner": "axios-scan",
            "version": VERSION,
            "scan_root": scan_root,
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "attack_window": {"start": ATTACK_START, "end": ATTACK_END},
            "deep_mode": deep_mode,
            "log_hours": log_hours,
            "cloud_dirs_excluded": len(self.cloud_dirs),
            "lockfiles_scanned": self.lockfile_count,
            "checks": {
                "clean": self.clean_count,
                "warnings": self.warn_count,
                "critical": self.crit_count,
            },
            "verdict": verdict,
            "findings": self.findings,
        }

        try:
            with open(json_file, "w") as f:
                json.dump(result, f, indent=2)
            self.log_info(f"JSON report: {json_file}")
        except OSError:
            self.log_warn("Failed to write JSON report")

    # ── Run ──────────────────────────────────────────────────────────────────

    def run(self, scan_root, deep_mode, json_mode, scan_cloud):
        log_hours = 168 if deep_mode else 72

        # Banner
        print()
        print(f"{Colors.BOLD}axios supply chain scanner v{VERSION} — macOS (Python){Colors.RESET}")
        print(f"{Colors.DIM}Attack window: 2026-03-31 00:21–03:15 UTC{Colors.RESET}")
        print(f"{Colors.DIM}Scan root: {scan_root}{Colors.RESET}")
        print(f"{Colors.DIM}Deep mode: {deep_mode} | JSON: {json_mode} | Scan cloud: {scan_cloud}{Colors.RESET}")
        print(f"{Colors.DIM}Python: {sys.version.split()[0]} ({sys.executable}){Colors.RESET}")
        print(f"{Colors.DIM}{datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}{Colors.RESET}")
        print()

        self.step1_cloud_sync(scan_cloud)
        self.step2_rat_detection()
        self.step3_processes()
        self.step4_c2_connections(log_hours)
        self.step5_log_analysis(log_hours)
        self.step6_launch_agents()
        self.step7_npm_global()
        self.step8_caches()
        self.step9_lockfile_scan(scan_root, scan_cloud)
        self.step10_aitools()
        self.print_summary()

        if json_mode:
            self.write_json(scan_root, deep_mode, log_hours)

        ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        print(f"{Colors.DIM}Scan complete at {ts}{Colors.RESET}")
        print()


# ── Main ────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        prog="axios-scan",
        description="macOS scanner for the axios supply chain compromise (2026-03-31). An aitools utility.",
    )
    parser.add_argument("scan_root", nargs="?", default=os.path.expanduser("~"),
                        help="Directory to scan (default: $HOME)")
    parser.add_argument("--deep", action="store_true",
                        help="Extended log search (168h instead of 72h)")
    parser.add_argument("--json", action="store_true",
                        help="Output JSON summary")
    parser.add_argument("--scan-cloud", action="store_true",
                        help="Include cloud sync directories in scan")
    parser.add_argument("--version", action="version",
                        version=f"axios-scan {VERSION} (aitools)")

    args = parser.parse_args()

    scanner = Scanner()
    scanner.run(
        scan_root=os.path.expanduser(args.scan_root),
        deep_mode=args.deep,
        json_mode=args.json,
        scan_cloud=args.scan_cloud,
    )


if __name__ == "__main__":
    main()
