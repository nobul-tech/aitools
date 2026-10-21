# S3-Gate row 25 draft: intents for the migrated tool setup scripts

**Intent**: **Purpose**: Draft, for approval in one pass, the code intent headers of the 26 tool setup scripts that M2 batches B5-B17 migrate onto the tool support decision tree, so each batch can be delegated with an approved intent (D-TS9; S4-Review §5.1 row 25). **Scope**: The `# Intent:` header block per script, following `shared/skills/intent-writing/SKILL.md` "Code files". NOT the rest of the header (name line, "safe to re-run", platform, `tool-registry` reference, which script-standards block order already requires). NOT B18+ (new scripts via `/tool-adopt`). **Audience**: The commander (approves), the M2 batch delegates (paste verbatim).

## Template (one per script; the `.ps1` swaps the platform sentence)

```
# Intent: Make <display name> supported on <platforms> by running the tool
# support decision tree for registry slug <slug> (tool_support_run /
# Invoke-ToolSupport), then <post-config, or "nothing else">. NOT install-method
# choice (tool registry via /tool-registry) or detection/update/removal logic
# (aitools-lib helpers). NOT <tool-specific exclusion>. Consumed by:
# aitools-install.sh Step <N> (validate_and_run), aitools install, aitools sync.
```

`.ps1` variant: "on Windows" instead of "on macOS and Linux", `aitools-install.ps1 Step <N> (Invoke-ValidatedScript)`, and `Invoke-ToolSupport` named first.

## Per script (M2 batch order; step numbers from `aitools-install.sh` at origin/main c8573ed)

| Batch | Script pair | Slug | Step | Post-config clause | Tool-specific NOT clause |
|---|---|---|---|---|---|
| B5 | setup-typst | `typst` | 13 | nothing else | NOT document builds that call typst (pandoc and project scripts) |
| B6 | setup-vercelcli | `vercel-cli` | 10 | check Vercel authentication (`vercel whoami`) and report ACTION when signed out | NOT Vercel project linking or the Vercel MCP server (setup-user-mcp) |
| B7 | setup-pandoc | `pandoc` | 11 | nothing else | NOT PDF engines or document templates |
| B8 | setup-rust | `rust-cargo` | 12 | make `~/.cargo/bin` resolvable (Windows: `%USERPROFILE%\.cargo\bin` on the persistent PATH, and report a missing MSVC build toolchain) | NOT crates installed with cargo by other tools (datadog Windows builds its own) |
| B9 | setup-go | `go` | 17 | put `GOPATH/bin` on PATH (persistent on Windows) | NOT Go modules or go-installed binaries of other tools |
| B10 | setup-datadog | `datadog-pup` | 18 | check `pup auth status` output and report ACTION when signed out | NOT Datadog log shipping or the Datadog MCP server |
| B11 | setup-uv | `uv` | 14 | nothing else | NOT Python interpreters (setup-python) or uv-installed tools of other scripts (setup-modal) |
| B12 | setup-gh-cli | `gh-cli` | 1 | nothing else (authentication is installer Step 2) | NOT `gh auth login` (installer Step 2) |
| B13 | setup-python | `python` | 15 | nothing else (channel `pinned-minor` 3.14 through uv) | NOT the harness Python resolver (`harness_python`) or virtualenvs |
| B14 | setup-modal | `modal-cli` | 16 | check for `~/.modal.toml` and report ACTION when absent | NOT Modal apps or deployments |
| B15 | setup-perl | `perl` | 19 | nothing else | NOT Git Bash's bundled perl, which check-lib shadows on purpose |
| B16 | setup-bash | `bash` | 20 | nothing else (`resolveBy: knownPaths` on Windows, rev 4 §6) | NOT WSL bash, which is never managed (cross-platform.md "Windows: managed bash") |
| B17 | setup-google-chrome | `google-chrome` (and `nss-tools`) | 20b | install nss-tools and trust the Claude Code web proxy CA (claude-code-web only) | NOT the chrome-devtools MCP server arguments (setup-user-mcp, D-CHR2) |

## Example, filled (B9, setup-go.sh)

```
# Intent: Make Go supported on macOS and Linux by running the tool support
# decision tree for registry slug go (tool_support_run), then put GOPATH/bin on
# PATH. NOT install-method choice (tool registry via /tool-registry) or
# detection/update/removal logic (aitools-lib helpers). NOT Go modules or
# go-installed binaries of other tools. Consumed by: aitools-install.sh Step 17
# (validate_and_run), aitools install, aitools sync.
```

## Notes

- `vercel-cli`, `modal-cli`, `datadog-pup`, `rust-cargo` are the registry slugs. The scripts are `setup-vercelcli`, `setup-modal`, `setup-datadog`, `setup-rust`. Slugs were read with a programmatic key listing of `registries/tool-registry.json` (python, read-only), not through `/tool-registry`.
- Step numbers come from the `log "Step N: ..."` lines in `scripts/aitools-install.sh`. If M3 B3/B3b or installer reordering (tooling-resolution decision 9) lands first, renumber them in the batch that writes the header.
- Each intent is protected (sources-of-truth.md "Intent statements"). Approving this table approves all 26 headers. A batch that changes the post-config clause must re-present that script's intent.
