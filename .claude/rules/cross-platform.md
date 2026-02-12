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
