"""Keyword sweep of registries/incidents.json for overlap with remediation items (scratch, read-only)."""
import json

d = json.load(open("/Users/new-jose/repos/aitools/registries/incidents.json"))
keys = {
    "shell-unbound": ["$SHELL", "SHELL unbound", "basename \"$SHELL"],
    "bash_profile": ["bash_profile", ".profile"],
    "ait-harvest-cwd": ["PROJECT_ROOT/scripts", "cwd repo", "ait-harvest.py from"],
    "winget-scope": ["--scope", "winget scope", "machine scope"],
    "unknown-option": ["Unknown option", "unknown option"],
    "ps-stamp": ["AITOOLS_INSTALLED_VERSION", "version stamp"],
    "trap-leak": ["MDM_TMP", "BUILD_TMP"],
    "lastexitcode": ["LASTEXITCODE"],
    "sudo": ["sudo apt-get", "unconditional sudo", "as_root"],
    "run-context": ["console user", "SYSTEM context", "run context", "as root"],
    "jsonl-rotate": ["deploy.jsonl"],
    "log-failsafe": ["fail-safe", "failsafe", "swallow"],
    "dry-run-shell": ["setup-user-shell"],
    "bak-tracked": [".bak.2026"],
    "hooks-settings-backup": ["setup-user-hooks"],
    "order-lists": ["order list", "deploy_configs", "Step 21"],
    "mdm-deploy-rows": ["MDM deploy"],
    "registry-linux": ["linux: supported", "claims unverified", "Linux install method"],
    "cursor-ide-mcp": ["agent mcp disable", "agent mcp remove"],
    "create-dotprofile": ["gh repo create"],
    "bootstrap-ps51": ["bootstrap.ps1"],
    "deploy-harness-git": ["not a git checkout", "git work tree"],
    "size-gate": ["200 KB", "200,000", "size gate"],
    "lib-twice": ["RESOLVER_SH_FILES", "library twice", "inlined twice"],
    "sync-managed-json": ["sync_managed_json", "auto-adopt"],
    "cursor-model": ["hasChangedDefaultModel", "model reset"],
    "mcp-ps1-row": ["setup-user-mcp.ps1"],
    "ripgrep": ["ripgrep"],
    "typst-uv-linux": ["setup-typst", "setup-uv"],
    "datadog": ["datadog"],
}
for arr in ("incidents", "closed"):
    for i in d.get(arr, []):
        blob = " ".join(str(i.get(k, "")) for k in ("title", "observation", "affected"))
        hits = [name for name, ws in keys.items() if any(w in blob for w in ws)]
        if hits:
            print(f"{arr[:4]} #{i.get('id')} {i.get('status')} {i.get('severity')} {hits} | {i.get('title','')[:120]}")
