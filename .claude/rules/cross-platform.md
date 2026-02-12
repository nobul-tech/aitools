## Cross-Platform Awareness

Jose works across two machines:
- **Windows 11 workstation** (primary): PowerShell, Git Bash, VS Code
- **macOS laptop** (secondary): zsh, VS Code

When writing scripts or paths:
- Always provide both `.ps1` and `.sh` variants for setup scripts
- Use forward slashes in paths when possible (works on both platforms)
- Google Drive mount differs: `G:\My Drive\` (Windows) vs `~/Google Drive/My Drive/` (macOS)
- Use `$HOME` or `~` for user directory references, not hardcoded paths
- Test commands in both PowerShell and bash/zsh contexts
- **After creating `.sh` files on Windows**, always run `git update-index --chmod=+x <file>` before committing — Windows doesn't set the Unix executable bit, so macOS/Linux checkouts will lack +x without this
