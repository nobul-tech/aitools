# Operational Briefing: Post-Push Check Script Bugs

**Intent**: **Purpose**: Equip S3 with the intelligence and decisions
needed to remediate pre-existing bugs in `scripts/check-post-push.sh`
that produce stderr noise and a non-zero exit code despite 0 FAIL
results. **Scope**: The 3 bugs identified during the v0.62.2 session
(ambiguous redirect, inline Python syntax errors, paste misuse). NOT
the governed-data-access work from that session. NOT the
incident-governance or sources-of-truth overhaul (Incident #50). NOT
the intent skill heuristic updates (R1-R3). NOT the artifact-roles
rule/skill design. **Audience**: S3 (the executing agent) fulfilling
delegation duty when launching sub-agents for investigation and
remediation.

## Source

These bugs were discovered during the v0.62.2 session (2026-03-17)
when running `bash scripts/check-post-push.sh` after pushing. All 13
checks passed but exit code was 1. Post-push log at the time:

```
line 533: 0: ambiguous redirect

File "<stdin>", line 21
    plat_key =  'Windows': 'windows'.get(platform.system(), 'linux')
                         ^
SyntaxError: invalid syntax
(repeated 6 times with slight variations)

usage: paste [-s] [-d delimiters] file ...
```

Post-push summary line reported: `13 PASS, 0 SKIP, 0 WARN, 0 FAIL`
yet script exited 1.

## Decisions

### D1: S2 investigates via /investigate, delivers AAR

S2 (Intelligence) audits this conversation (working backwards from
the user's prompts) and the post-push check script to produce an AAR
covering:

- **What happened**: the 3 specific failures with line numbers, the
  exit code contradiction (0 FAIL but exit 1)
- **RCA per bug**: 5 Whys or contributing factor analysis
- **Scope of fix**: which lines need changing, what dependencies
  exist (does step 22a feed step 26? are they independent?)
- **Script standards that apply**: error handling, logging, cross-
  platform, the check-script block order from script-standards.md
- **Verification criteria**: what "fixed" looks like (clean stderr,
  exit 0 when 0 FAIL)

S2 delivers the AAR. S2 does NOT remediate. Remediation is S3's
mission after the AAR is reviewed.
