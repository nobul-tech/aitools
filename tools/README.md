# tools/ — Provenance-Suffixed Artifacts

This directory contains tools contributed by **nobul-grok**.

## Naming Convention (Initial Contributions)

For the initial integration of new tools, we use this concise provenance-suffixed format:

```
tool--nobul-grok--YYYY-MM-DD.py
```

Example:
- `aigit--nobul-grok--2026-05-16.py`
- `aifetch--nobul-grok--2026-05-16.py`

### Philosophy
- **Production versions** eventually use clean names (`aigit.py`, `aifetch.py`, etc.)
- Initial contributions carry explicit provenance (who + when) for auditability and Fear & Trust.
- This expands on the fork model and AAID patterns established with Opus.

## Fork Model Reference

Agents work in their own context/fork, then open PRs to `nobul-tech/aitools`.

## No Deletes

We do not delete historical versions or previous PRs. Lineage is preserved.

## Contributors

- nobul-grok (this PR)

