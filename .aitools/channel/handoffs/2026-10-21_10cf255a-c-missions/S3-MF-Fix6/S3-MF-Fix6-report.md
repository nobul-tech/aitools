# S3-MF-Fix6 report

PR: https://github.com/nobul-tech/aitools/pull/108. Branch: fix/mf-audit-profile-json, commit b42f9e1 on base origin/main 8a9dcb5.

## Findings

All four were confirmed in the code before fixing; none were rejected.

| id | status | evidence |
|---|---|---|
| A-6 (code part) | fixed | Bash: new `die_internal` logs at detail and then prints the unchanged stderr line, used in jread, jlist, jtype and jsub. The bash snapshot exits and the PS snapshot missing/invalid exits now log at detail. The spec part (I-3) is a draft only. |
| A-7 | fixed | PS exception-set calls `Remove-TempFile $tmp` when the temp write fails. |
| A-8 | fixed | PS `Get-WriteErrorText` unwraps MethodInvocationException and maps "Permission denied" / "No such file or directory". Used in exception-set, register and migrate. Other OS errors still use the .NET text (reviewer n-3). |
| A-9 | fixed | `Set-JValue` now matches keys exactly. A key that differs only in case is refused by both engines with the same message. PS exception-set reports an edit failure the way bash does. |

The A-9 change goes beyond the audit's own suggestion. An exact-match loop alone would still leave PS and perl behaving differently. In addition, the perl sibling key makes profile.json unreadable by `ConvertFrom-Json` (I reproduced this with pwsh 7).

## Verification (macOS, isolated HOME)

- `bash -n` (bash 5 and 3.2), `perl -c` and the pwsh parser are clean.
- test-profile passed 744/0 on bash 5 and on 3.2 (689 before). Against origin/main's scripts, 29 of the new assertions fail.
- test-lib 209/0, test-config 190/0, test-user-init 200/0 on both bash versions.
- pre-commit has 1 FAIL, step 6, which was already failing before this change. It also WARNs on step 3 (build), step 5 (ran before the commit), step 9 (release notes) and step 11 (live dotprofile).
- pre-push has 1 FAIL, step 7: the dotprofile `deploy/` is stale, which was also already failing.
- CI: windows, CodeQL and Analyze passed. linux and macos were still pending when I handed back.

## Not run

- Windows / Git Bash.
- build-deploy.sh: the live dotprofile is read-only for this mission.
- A test for the partial-temp-file case of A-7 (it cannot be reproduced).
- No test reaches `die_internal` (reviewer n-1).

## Drafts awaiting approval

- S3-MF-Fix6-drafts/reference/script-standards-detail.md.edit.txt (I-3).

## Scope addition: PR #98 review m1

Not done. Splitting the message changes what a consumer does. setup-user-config.sh:204 and setup-user-config.ps1:208 detect a bad profile by matching the substring "is not v2". That file is S3-MF-NoMachine's. I listed it as a follow-up in the PR body and sent the evidence to S3-M3Finish.

## Reviewer (S3-MF-Fix6-Review)

- Its draft file says: approve-worthy, 0 blocking, 4 non-blocking (n-1..n-4).
- Its test-results table was still the placeholder "TESTS_TABLE", because its own background test run had not finished when I handed back.
- It had not yet posted its verdict on the PR.
- I did not commit its file. Commit it once it is complete.

## INCIDENT markers

- `INCIDENT:` (reviewer I-5) No spec documents how the JSON engines treat key case. The exact-match rule and the new refusal exist only in the aitools-json headers.
