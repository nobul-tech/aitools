---
paths:
  - scripts/**
  - deploy/**
  - shared/**
  - reference/**
  - plans/**
  - rfcs/**
  - .claude/rules/**
  - .cursor/rules/**
  - CLAUDE.md
  - RELEASE_NOTES.md
  - ROADMAP.md
  - README.md
---

## Config File Write Safety (this repo)

Scripts that write JSON config files (`config.json`, `settings.json`, `cli-config.json`,
`mcp.json`) must follow read-then-merge by default. Blind overwrites silently drop
user data and non-managed fields.

### Default: read-then-merge

1. Read the existing file
2. Parse JSON (handle missing vs corrupt -- see below)
3. Set only the fields the script manages
4. Write the merged result

### Managed vs preserved fields

Every config-writing script must document in its header comment which fields it
owns (manages) and which it preserves. Example:

```
# Managed fields: mcpServers.chrome-devtools, mcpServers.vercel, mcpServers.webflow
# Preserved: all other mcpServers entries, all other top-level keys
```

### Overwrite exceptions

A script may overwrite (not merge) only when it is the **sole owner** of the entire
file (e.g., `setup-user-claude` owns `~/.claude/CLAUDE.md`). The script header must
document: `# Overwrites: yes (sole owner of this file)`.

### Empty `catch {}` anti-pattern

When reading JSON before merge, distinguish file-not-found (start fresh) from
parse errors (warn the user). Never silently swallow parse errors:

```javascript
let config = {};
try {
    config = JSON.parse(fs.readFileSync(f, 'utf8'));
} catch (e) {
    if (e.code !== 'ENOENT') {
        console.error('Warning: ' + f + ' is invalid JSON, starting with empty config');
    }
}
```

### Anti-patterns

- `cat > file << EOF` for any JSON file not solely owned by the script
- `ConvertTo-Json | WriteAllText` without reading existing content first
- `try { ... } catch {}` that swallows both ENOENT and parse errors

### Backup before overwrite

Scripts must back up targets before writing, regardless of ownership model.

- **Single files**: `<file>.bak.<TIMESTAMP>`, keep at most 20, auto-prune oldest
- **Directories**: `<dir>.bak.<TIMESTAMP>/`, keep at most 5, auto-prune oldest
- Skip if target doesn't exist (first run — nothing to back up)

Backup failures are non-fatal (warn and proceed) — a failed backup should not
block deployment.

### Diff logging on overwrite

Before overwriting an existing file, compare old and new content:

- **Identical**: skip the write, log "unchanged"
- **Different**: log unified diff to deploy log, then overwrite
- **New file** (no target): log "added", no diff needed

This applies to both single-file overwrites and directory deployments.
Console shows summary counts; the deploy log captures full diffs.

### Directory deployment (additive pattern)

When a script manages a directory of files (not a single file), use the additive
pattern — deploy managed files, preserve everything else:

1. Declare managed scope in script header (e.g., `# Managed: ~/.claude/rules/*.md
   matching <userRepoPath>/claude/rules/`)
2. Back up target directory (see "Backup before overwrite")
3. For each source file: compare with target, add new, update changed (with diff
   logging), skip unchanged
4. Preserve unmanaged files (in target but not in source), log each
5. Validate each deployed file (non-empty)
6. Log counts: added, updated, unchanged, preserved
7. If source directory is empty or missing: log info, leave target untouched

This is the directory-level equivalent of read-then-merge for config files.

### Post-write validation

Every config-writing script must validate output immediately after writing.
A successful write that produces malformed content is worse than a visible error.

#### JSON configs (bash)

Use `validate_json_config` for standalone scripts that write JSON. The function
checks: non-empty file, valid JSON (via `python3` or `node`), required keys,
double-slash paths. Defined inline in each script (deploy scripts must be
self-contained).

Call site: `validate_json_config "$FILE" key1 key2 key3 || true`

The `|| true` prevents `set -e` from exiting; `log_error` already incremented
`ERRORS`.

For scripts that write JSON via `node -e`, add inline validation inside the
existing Node.js block after `fs.writeFileSync`:

```javascript
const _v = JSON.parse(fs.readFileSync(f, 'utf8'));
const _missing = ['key1','key2'].filter(k => !(k in _v));
if (_missing.length) { console.error('Validation failed: missing ' + _missing.join(', ')); process.exit(1); }
```

#### JSON configs (PowerShell)

Use `ValidateJsonConfig` for PS1 scripts. Checks: non-empty file,
`ConvertFrom-Json` parse, required keys, double-slash regex.

Call site: `ValidateJsonConfig -File $file -RequiredKeys @("key1", "key2")`

#### Markdown configs (CLAUDE.md)

Check non-empty file and required sections (e.g., `## Machine-Specific`).

### Reference examples

These scripts demonstrate the patterns above. Do not assume they are
violation-free -- always verify copied code against these rules.

- Node.js merge: `scripts/setup-user-cursor.sh` (cli-config.json)
- PowerShell merge: `scripts/setup-user-mcp.ps1` (settings.json read-then-merge)
- Hook merge: `scripts/setup-user-hooks.sh` (settings.json hooks array)
- Bash `validate_json_config`: `scripts/aitools-install.sh`
- PS1 `ValidateJsonConfig`: `scripts/aitools-install.ps1`
- Inline Node.js validation: `scripts/setup-user-mcp.sh`
