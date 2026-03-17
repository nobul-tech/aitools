#!/usr/bin/env python3
"""Comprehensive test suite for the /tool-ops skill and tool-ops.json registry.

Tests schema integrity, drift detection, governed access enforcement, and
cross-reference validity. Run from the aitools repo root.

Exit 0 = all pass, Exit 1 = failures found.
"""
import json, os, re, subprocess, sys

PASS = 0
FAIL = 0
WARN = 0

def test(name, condition, detail=""):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  [PASS] {name}")
    else:
        FAIL += 1
        print(f"  [FAIL] {name}" + (f" — {detail}" if detail else ""))

def warn(name, detail=""):
    global WARN
    WARN += 1
    print(f"  [WARN] {name}" + (f" — {detail}" if detail else ""))

# Load files
with open("reference/tool-ops.json") as f:
    tool_ops = json.load(f)

settings_path = os.path.expanduser("~/.claude/settings.json")
with open(settings_path) as f:
    settings = json.load(f)

# ============================================================
print("\n=== SUITE 1: Schema & Structural Integrity ===")
# ============================================================

# 1.1 Meta section
meta = tool_ops.get("meta", {})
test("meta.governance exists", "governance" in meta)
test("meta.framework exists", "framework" in meta)
test("meta.intent exists", "intent" in meta)
test("meta.intent has purpose/scope/audience",
     all(k in meta.get("intent", {}) for k in ["purpose", "scope", "audience"]))
test("meta.lastUpdated exists", "lastUpdated" in meta)
test("meta.governance file exists", os.path.exists(meta.get("governance", "")))
test("meta.framework file exists", os.path.exists(meta.get("framework", "")))

# 1.2 Tools structure
tools = tool_ops.get("tools", {})
test("tools section exists", len(tools) > 0)

for tool_name, tool_data in tools.items():
    print(f"\n  --- Tool: {tool_name} ---")

    # 1.3 Governance modes
    modes = tool_data.get("governanceModes", {})
    expected_mode_keys = {"denyRules", "hooks", "contextInjection", "kpis", "versionDeps", "verifications"}
    test(f"{tool_name}: governanceModes present", bool(modes))
    test(f"{tool_name}: all 6 mode categories",
         set(modes.keys()) == expected_mode_keys,
         f"missing: {expected_mode_keys - set(modes.keys())}" if set(modes.keys()) != expected_mode_keys else "")
    for mode_key, mode_val in modes.items():
        test(f"{tool_name}: {mode_key} is audit|active",
             mode_val in ("audit", "active"),
             f"got '{mode_val}'")

    # 1.4 Deny rules schema
    deny_rules = tool_data.get("denyRules", [])
    deny_required = {"id", "permissionPattern", "hook", "reason", "incidentRef"}
    for dr in deny_rules:
        dr_id = dr.get("id", "?")
        missing = deny_required - set(dr.keys())
        test(f"{tool_name}: denyRule '{dr_id}' has required fields",
             len(missing) == 0,
             f"missing: {missing}")

    # 1.5 Hooks schema
    hooks = tool_data.get("hooks", [])
    hook_required = {"event", "matcher", "script", "purpose"}
    for h in hooks:
        h_script = h.get("script", "?")
        missing = hook_required - set(h.keys())
        test(f"{tool_name}: hook '{h_script}' has required fields",
             len(missing) == 0,
             f"missing: {missing}")

    # 1.6 KPIs schema
    kpis = tool_data.get("kpis", [])
    kpi_required = {"name", "source", "unit"}
    for k in kpis:
        k_name = k.get("name", "?")
        missing = kpi_required - set(k.keys())
        test(f"{tool_name}: kpi '{k_name}' has required fields",
             len(missing) == 0,
             f"missing: {missing}")

    # 1.7 Verifications schema
    verifications = tool_data.get("verifications", [])
    ver_required = {"type", "target", "cases"}
    case_required = {"input", "expectExit", "expectStdout"}
    for v in verifications:
        v_target = v.get("target", "?")
        missing = ver_required - set(v.keys())
        test(f"{tool_name}: verification '{v_target}' has required fields",
             len(missing) == 0,
             f"missing: {missing}")
        for idx, case in enumerate(v.get("cases", [])):
            missing_c = case_required - set(case.keys())
            test(f"{tool_name}: verification case {idx} has required fields",
                 len(missing_c) == 0,
                 f"missing: {missing_c}")

    # 1.8 Hook scripts exist on disk
    hooks_dir = os.path.expanduser("~/.claude/hooks")
    for h in hooks:
        script = h.get("script", "")
        script_path = os.path.join(hooks_dir, script)
        test(f"{tool_name}: hook script '{script}' exists on disk",
             os.path.exists(script_path),
             f"not found at {script_path}")
    for dr in deny_rules:
        hook = dr.get("hook", "")
        hook_path = os.path.join(hooks_dir, hook)
        test(f"{tool_name}: deny rule hook '{hook}' exists on disk",
             os.path.exists(hook_path),
             f"not found at {hook_path}")

# ============================================================
print("\n=== SUITE 2: Drift Detection ===")
# ============================================================

# 2.1 Deny rule drift: tool-ops.json vs settings.json
settings_deny = settings.get("permissions", {}).get("deny", [])
for tool_name, tool_data in tools.items():
    for dr in tool_data.get("denyRules", []):
        pattern = dr.get("permissionPattern", "")
        test(f"deny rule '{pattern}' present in settings.json",
             pattern in settings_deny,
             f"not found in {settings_deny}")

# 2.2 Hook drift: tool-ops.json hooks vs settings.json hooks
settings_hooks = {}
for event, entries in settings.get("hooks", {}).items():
    for entry in entries:
        matcher = entry.get("matcher", "")
        for h in entry.get("hooks", []):
            cmd = h.get("command", "")
            script = cmd.split("/")[-1].rstrip('"')
            settings_hooks[script] = {"event": event, "matcher": matcher}

for tool_name, tool_data in tools.items():
    for h in tool_data.get("hooks", []):
        script = h.get("script", "")
        event = h.get("event", "")
        matcher = h.get("matcher", "")
        if script in settings_hooks:
            sh = settings_hooks[script]
            test(f"hook '{script}' event matches",
                 sh["event"] == event,
                 f"tool-ops says {event}, settings says {sh['event']}")
            test(f"hook '{script}' matcher matches",
                 sh["matcher"] == matcher,
                 f"tool-ops says '{matcher}', settings says '{sh['matcher']}'")
        else:
            test(f"hook '{script}' registered in settings.json", False,
                 "not found")

# ============================================================
print("\n=== SUITE 3: Contract Tests (Live) ===")
# ============================================================

for tool_name, tool_data in tools.items():
    for v in tool_data.get("verifications", []):
        if v.get("type") != "mock-json-pipe":
            continue
        target = v.get("target", "")
        target_path = os.path.join(hooks_dir, target)
        if not os.path.exists(target_path):
            test(f"contract test target '{target}' exists", False)
            continue

        for idx, case in enumerate(v.get("cases", [])):
            input_json = json.dumps(case["input"])
            expect_exit = case.get("expectExit", 0)
            expect_stdout = case.get("expectStdout")

            result = subprocess.run(
                ["bash", target_path],
                input=input_json, capture_output=True, text=True, timeout=10
            )

            test(f"contract {target} case {idx}: exit code {expect_exit}",
                 result.returncode == expect_exit,
                 f"got {result.returncode}")

            if expect_stdout is not None:
                test(f"contract {target} case {idx}: stdout matches /{expect_stdout}/",
                     bool(re.search(expect_stdout, result.stdout)),
                     f"stdout: {result.stdout[:100]}")
            else:
                test(f"contract {target} case {idx}: no deny in stdout",
                     "deny" not in result.stdout.lower() if result.stdout else True,
                     f"stdout: {result.stdout[:100]}")

# ============================================================
print("\n=== SUITE 4: Governed Data Access Enforcement ===")
# ============================================================

# 4.1 Check that rules/CLAUDE.md don't reference tool-ops.json directly
bypass_files = []
for pattern_dir in [".claude/rules", "."]:
    if pattern_dir == ".":
        check_files = ["CLAUDE.md"]
    else:
        check_files = [
            os.path.join(pattern_dir, f) for f in os.listdir(pattern_dir)
            if f.endswith(".md")
        ]

    for fpath in check_files:
        if not os.path.exists(fpath):
            continue
        with open(fpath) as f:
            content = f.read()
        # The tool-ops rule itself may reference the path in its governance pointer
        # The skill SKILL.md is allowed to reference it
        if "tool-ops.json" in content:
            # Allowed: the governing rule's intent/cross-ref
            basename = os.path.basename(fpath)
            if basename == "tool-ops.md":
                continue  # The rule is allowed
            if "sources-of-truth.md" in fpath:
                continue  # Protected files table lists it
            if "frameworks.md" in fpath:
                continue  # Registries table lists it
            bypass_files.append(fpath)

if bypass_files:
    for bf in bypass_files:
        test(f"governed access: {bf} does not reference tool-ops.json directly",
             False, "bypass vector")
else:
    test("governed access: no rule/CLAUDE.md bypass vectors", True)

# 4.2 Check reference files don't reference tool-ops.json
ref_bypass = []
for f in os.listdir("reference"):
    if not f.endswith(".md"):
        continue
    fpath = os.path.join("reference", f)
    with open(fpath) as fh:
        content = fh.read()
    if "tool-ops.json" in content:
        # Allowed: the framework reference file
        if f == "framework-tool-ops.md":
            continue
        ref_bypass.append(fpath)

if ref_bypass:
    for rb in ref_bypass:
        test(f"governed access: {rb} does not reference tool-ops.json",
             False, "bypass vector in reference file")
else:
    test("governed access: no reference file bypass vectors", True)

# ============================================================
print("\n=== SUITE 5: Cross-Reference Integrity ===")
# ============================================================

skill_path = ".claude/skills/tool-ops/SKILL.md"
with open(skill_path) as f:
    skill_content = f.read()

# Extract @-references and file paths
refs = re.findall(r'`([^`]*\.(?:md|json))`', skill_content)
for ref in refs:
    # Strip @ prefix if present
    clean = ref.lstrip("@")
    if clean.startswith("./"):
        clean = clean[2:]
    # Skip template placeholders like <toolname>
    if "<" in clean and ">" in clean:
        continue
    # Skip glob patterns
    if "*" in clean:
        continue
    test(f"skill cross-ref: {clean} exists",
         os.path.exists(clean),
         f"not found")

# ============================================================
print(f"\n{'='*60}")
print(f"TOTAL: {PASS} PASS, {FAIL} FAIL, {WARN} WARN")
print(f"{'='*60}")

sys.exit(1 if FAIL > 0 else 0)
