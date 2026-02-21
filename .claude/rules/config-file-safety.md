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

### Gold standard references

- Node.js merge: `scripts/setup-user-cursor.sh` (cli-config.json)
- PowerShell merge: `scripts/setup-user-mcp.ps1` (settings.json read-then-merge)
- Hook merge: `scripts/setup-user-hooks.sh` (settings.json hooks array)
