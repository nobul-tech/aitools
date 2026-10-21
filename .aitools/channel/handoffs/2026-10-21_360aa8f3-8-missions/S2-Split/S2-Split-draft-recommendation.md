# S2-Split draft recommendation (for adversarial review)

Repo: /Users/new-jose/repos/aitools (main 51a34d8). Question: should the 9 project skills in
.claude/skills/ (audit, frameworks, glossary, governed-data, harvest, incident, tool-eval,
tool-ops, tool-registry) move to shared/skills/ (deployed by setup-user-skills to ~/.claude/skills
and ~/.cursor/skills, every repo, every machine, embedded in dotprofile deploy/ by build-deploy.sh)?
Commander's position: "it made no sense to have them in .claude; everything should have been in shared."
He made untracked byte-identical copies under shared/skills/ and copied the dotprofile user rule
delegation.md into .claude/rules/.

## Evidence collected
FOR moving:
F1 dotprofile claude/CLAUDE.md:8 tells agents in NON-aitools repos to use "the tool-registry and
   tool-ops skills in aitools" and "the tool-eval skill" -- unreachable outside aitools today.
F2 Harvesting runs in every repo: scripts/ait-harvest.py:779 writes <project_root>/harvesting;
   .claude/rules/aitools-workspace.md: "Any project aitools touches gets these capabilities" --
   but /harvest skill + artifact-harvesting rule exist only in aitools.
F3 Cursor agent CLI reads only ~/.cursor/skills (reference/cursor-practices.md:130-133); repo has no
   .cursor/skills, so Cursor in aitools has none of the 9 governance skills.
F4 Existing shared skills already cite aitools-only paths (intent-audit: reference/incidents.json,
   glossary.json, tool-ops.json; optimize-plan: reference/incidents.json) -- "project-agnostic" bar
   not enforced.
F5 The CLAUDE.md design principle "Skills as enablement" + project tree that explained the split
   were deleted in b504c43 "swan song" (2026-03-28). Current CLAUDE.md lists shared/ as skill source
   and never mentions .claude/skills/.
F6 The trigger directives for the cross-repo cards (/aitool-ops, /aitool-eval: "when ANY of these
   arise outside the aitools repo") live in PROJECT rules .claude/rules/aitool-ops.md:30 and
   aitool-eval.md:33, which are never loaded outside aitools.
F7 delegation.md is harness policy (D-DEL1..4) but has no shared source: user rules deploy only from
   <userRepoPath>/claude/rules (setup-user-claude.sh:262-393); shared/claude-shared.md:133 points at
   ~/.claude/rules/delegation.md, which a non-dotprofile user never gets.
AGAINST moving as-is:
A1 7 of 9 skills read/write repo-relative aitools paths (registries/*.json, reference/framework-*.md,
   .claude/rules/*); in another repo these resolve against that repo's cwd. /incident is
   model-invocable and writes reference/incidents.json (also a stale path; real file is
   registries/incidents.json).
A2 Claude Code docs (code.claude.com/docs/en/skills, "Resolve skills that share a name"):
   "personal over project". With copies at both levels the deployed copy shadows the repo copy;
   this Mac's ~/.claude/skills is ~4 months behind shared/ (delegate not deployed; 5 skills stale).
A3 Docs: personal skills load in "All your projects on this machine, but not Cowork or cloud
   sessions"; project skills load in cloud sessions -> moving would remove governance skills from
   Claude Code web sessions on aitools (PR #48 targets that environment). Not empirically tested.
A4 Project skills change with git branch/pull, live; user skills need an `aitools` deploy run.
A5 The governing rules (trigger directives) are project rules; a user-level skill without a loaded
   rule is "ungoverned process" (reference/framework-three-layer-governance.md).
A6 Deliberate, documented design: plans/governance-and-compliance-framework.md decision 7 + "Skill
   Architecture"; .claude/rules/documentation-standards.md "Skill placement"; reference-card pattern
   (v0.65.1) built for exactly the cross-repo need; reference/framework-provenance.md:212-214 plans
   the same split for provenance.
A7 No check script enforces "no same-name skills at both levels" (grep of check-*.sh: none).

## Draft recommendation
- Delete the 9 untracked shared/skills copies (byte-identical; no loss) -- except harvest.
- MOVE harvest to shared/skills (git mv), edit to be repo-agnostic (cross-repo by nature, F2).
- KEEP audit, frameworks, glossary, governed-data, incident, tool-eval, tool-ops, tool-registry in
  .claude/skills (they CRUD protected aitools registries; branch/review flow; cloud sessions).
- Meet cross-repo needs with user-level read-only cards (aitool-ops, aitool-eval exist; add
  aitool-registry for F1), and fix F6/F7 with a user-level rule source: either new shared/rules/
  (deployed like claude-shared.md, dotprofile wins) or dotprofile-only.
- Delete .claude/rules/delegation.md copy (duplicate of the user rule; loads twice once deployed;
  real fix is to run the pending deploy).
- Add pre-commit check: no skill name in both shared/skills and .claude/skills.
- Restore a placement paragraph in CLAUDE.md "How the harness is organized" (.claude/skills line).
