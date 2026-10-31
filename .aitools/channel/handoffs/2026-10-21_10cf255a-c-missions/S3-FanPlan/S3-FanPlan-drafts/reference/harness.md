# Draft: reference/harness.md (protected) -- S3-FanPlan-Planner, awaiting commander approval

Base: main, plus PR #100's S3-H2-Manifest draft for this file (its Edit 1 "No
deletion, except retired rules" and its new "### Rules manifest and retired
rules" subsection). Two edits; Edit 2 applies to #100's draft text.

## Edit 1 -- "### Assumptions and what is not detected", the "Not detected" bullet

OLD:

```
- **Not detected**: the same content under two different names; a name
  shared across kinds (a skill and a rule both called `scratch`, which
  land in different directories); conflicts with files already in a
  tool's own location (`~/.claude/rules/`), which the fan-out in
  `setup-user-claude` / `setup-user-cursor` handles.
```

NEW:

```
- **Not detected**: the same content under two different names; a name
  shared across kinds (a skill and a rule both called `scratch`, which
  land in different directories); conflicts with files already in a
  tool's own location (`~/.claude/rules/`, `~/.cursor/rules/`). The
  fan-outs in `setup-user-claude` and `setup-user-cursor` treat such a
  file as theirs only when it matches a harness copy: they update or
  remove their own copies and preserve every other file.
```

## Edit 2 -- #100's draft subsection "### Rules manifest and retired rules", the "Consumers" bullet

OLD (#100 draft text):

```
- **Consumers** take every non-retired name they are entitled to, and
  back up and remove their own deployed copy of every `retired` name.
  Cursor takes user-level rules only, so it also removes its copies of
  names whose source is `aitools`.
```

NEW:

```
- **Consumers** take every non-retired name they are entitled to, and
  back up and remove their own deployed copy of every `retired` name.
  `setup-user-claude` takes every non-retired rule (all three sources;
  without a manifest, every rule, and nothing is retired) and uses the
  source to find the adopt target. Cursor takes user-level rules only,
  so it also removes its copies of names whose source is `aitools`. A
  consumer recognises its own copy of a retired rule by content (Claude:
  the same bytes as `~/.aitools/rules/<name>` or one of its `.bak.*`
  backups) or by its fan-out marker (Cursor).
```

## Why

On main the "Not detected" bullet describes a setup-user-claude fan-out that
did not exist (S3-FanPlan-Harness INCIDENT); the plan builds it. Plan
`plans/rules-fanout-claude.md` Batch B.
