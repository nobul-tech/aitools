# S3-RulesSpec: cross-reference lines for protected files (drafts, old -> new)

Author: S3-RulesSpec, 2026-10-26. These three files are protected
(`.claude/rules/sources-of-truth.md`: `.claude/rules/*.md` and
`reference/harness.md`), so the lines are drafts for the commander's
approval; none was written. The non-protected `reference/README.md` got its
row directly in the same commit as `reference/rules.md`.

## 1. `.claude/rules/documentation-standards.md`, "Layered reference architecture"

Old:

```
- **Rules** (`.claude/rules/`) = concise behavioral directives, ~40-100 lines
```

New:

```
- **Rules** (`.claude/rules/`) = concise behavioral directives, ~40-100 lines
  (what a rule is, its anatomy, scopes and deployment: `@reference/rules.md`)
```

## 2. `.claude/rules/frameworks.md`, "Cross-references"

Old:

```
- Three-layer pattern: `@reference/framework-three-layer-governance.md`
```

New:

```
- Three-layer pattern: `@reference/framework-three-layer-governance.md`
- Rules (anatomy, scopes, deployment): `@reference/rules.md`
```

## 3. `reference/harness.md`, "Cross-References"

Old:

```
- Deployed harness: `@scripts/deploy-harness.sh` / `.ps1`;
  managed-file model: `@reference/managed-file-deployment.md`
```

New:

```
- Deployed harness: `@scripts/deploy-harness.sh` / `.ps1`;
  managed-file model: `@reference/managed-file-deployment.md`
- Rules, their scopes and the rules fan-out: `@reference/rules.md`
```

Twin: `.cursor/rules/documentation-standards.mdc` mirrors draft 1
(`reference/cursor-practices.md` "Rule Correspondence"); add the same
parenthesis there if draft 1 is approved.
