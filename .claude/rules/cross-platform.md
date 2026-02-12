## Cross-Platform Awareness (this repo)

This repo is explicitly cross-platform — it provides tooling for both machines.

When writing scripts or paths **in this repo**:
- Provide both `.ps1` and `.sh` variants for setup/utility scripts
- Use forward slashes in paths when possible (works on both platforms)
- Google Drive mount differs: `G:\My Drive\` (Windows) vs `~/Google Drive/My Drive/` (macOS)
- Use `$HOME` or `~` for user directory references, not hardcoded paths

Note: The dual-script rule is specific to this repo. Most projects are platform-specific and don't need both variants.
