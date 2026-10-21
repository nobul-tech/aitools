## 4. INCIDENT findings, merged and de-duplicated

Checked against #1-#86 in origin/main 26c37b2 `registries/incidents.json`. PR #52 merged, so main already has #74-#86; the table was extracted with `S4-Review-scratch/list-incidents.sh`. Full entries, with every required field from incident-governance.md: `S4-Review-incidents-draft.json`.
- All drafts are `status: open`, because the mission plans are not repo plans yet.
- `linked` names the batch that would fix each one.
- Filing is the commander's call. The `/incident` skill still points to `reference/incidents.json` (#84); file into `registries/incidents.json`.

### New drafts (#87-#113)

| Draft id | Sev | Title (short) | From |
|---|---|---|---|
| 87 | high | Exit 2 / `[x]abort` treated as ordinary failure by both installers and `scripts/aitools` | M2 I-02 + I-24 |
| 88 | high | setup-datadog.sh `rm -f`s unknown-origin pup | M2 I-03 |
| 89 | high | Tool setup scripts ignore AITOOLS_DRY_RUN (dry run can `sudo rm -rf /usr/local/go`) | M2 I-22 |
| 90 | medium | Registry detection/platformStatus data not machine-usable | M2 I-07 + I-08 |
| 91 | medium | Step 8 OK for any node; preferred node@22 keg-only off PATH | M2 I-09 |
| 92 | medium | setup-perl.sh requires brew although system perl is preferred | M2 I-10 |
| 93 | medium | Framework registry Tool-ops path / Tool-lifecycle entry stale | M2 I-05 |
| 94 | medium | managed-file-deployment.md dangling pointer; tool-lifecycle.mdc drift | M2 I-14 + I-23 |
| 95 | high | build-deploy.sh hardcodes one user's identity defaults, used silently | M3 |
| 96 | medium | MDM embeds shared template, dev path the dotprofile template | M3 |
| 97 | medium | user init writes config/profile without backup; swallowed write error | M3 |
| 98 | medium | `inline_lib_*` replace any line naming the lib | M3 review I-a/H1 |
| 99 | medium | `adopt_claude_md` perl program built from shell values (`@`, `/`) | M3 review I-b/H6 |
| 100 | medium | Empty catches in `aitools`, `aitools.ps1`, `hh.ps1` (re-verified, line numbers corrected) | M3 review I-c |
| 101 | medium | UNVERIFIED: Git Bash user init writes MSYS-form userRepoPath | M3 |
| 102 | low | sources-of-truth omits project skills and tool-registry.md | M2 I-15 |
| 103 | low | 30-char summary limit "compliance-checked" but unchecked | M2 I-16 |
| 104 | low | Missing intents (D-TS9) | M2 I-17 |
| 105 | low | /tool-registry required fields absent in 16/18 entries | M2 I-19 |
| 106 | low | `reference/evaluations/` gate unmet (1 file / 18 tools) | M2 I-12 |
| 107 | low | ripgrep installed with no registry entry | M2 I-13 |
| 108 | low | cross-platform.md names nonexistent `install_via_brew/apt` | M2 I-25 |
| 109 | low | build-deploy `eval` of profile values | M3 |
| 110 | low | Token interpolation breaks on `&` / `$` | M3 |
| 111 | low | ait-harvest.py utf-8 without BOM handling | M3 |
| 112 | low | cross-platform.md `C:\repos\` vs `%USERPROFILE%\repos` | M3 review I-e |
| 113 | low | "Standard 4" cited as a rule section | S4-Review-C |

### Dropped as covered (update the existing entry instead)

| Finding | Covered by | Suggested update |
|---|---|---|
| M2 I-01 (7 scripts remove before verify; rule "SHOULD") | #55 (go, typst, rule ordering) | extend `affected`: setup-pandoc.sh, setup-rust.sh, setup-vercelcli.sh, setup-go.ps1, setup-datadog.sh |
| M2 I-04, M3 glossary-path finding | #59 (+ #84 for /incident) | add `.claude/skills/frameworks/SKILL.md` to `affected` |
| M2 I-18 (setup-bash headers cite `reference/tool-registry.json`) | #59 (same class) | add `scripts/setup-bash.sh/.ps1` |
| M2 I-06, I-11 (tool-registry.md / tool-versions.json drift, checks parse md, `TOOL_CMDS`) | #21 | update observation: JSON exists, md and tool-versions still parsed by check-post-push steps 9, 10, 21, 25 |
| M2 I-21 (criteria omit Linux) | #54 | none |
| M2 I-26 (sources-of-truth lists JSON paths) | #50 | none |
| M3 "build-deploy interpolates the building machine's profile" | #78 | none |
| M3 user-repo.md:139 "detects machineAlias" | #75 / #76 (user-repo rewrite) | none |
| M3 carried S2-Host items (Path 1 never persists alias, first-profile fallback, check_profile, NO_MACHINE_MATCH, PS1 COMPUTERNAME, parked defect) | #74, #75, #76, #77, #79 | none |
| C: managed-file-deployment.md still says "first profile" fallback | #76 | add `.claude/rules/managed-file-deployment.md` to `affected` |

Routed to `/glossary`, not incidents: M2 I-20 (provenance); C's TODO(glossary) items (`detection`, `user config` example, "profile" with three meanings, "recovered"). These are listed in `glossary.terms-draft.json` `open_glossary_items`.
