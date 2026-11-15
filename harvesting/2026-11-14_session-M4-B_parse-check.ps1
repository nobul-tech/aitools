$e = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile("C:\Users\jdpal\repos\aitools\.claude\worktrees\pywinpty\scripts\setup-pywinpty.ps1", [ref]$null, [ref]$e)
if ($e) { $e; exit 1 } else { "parse OK" }
$nonAscii = Select-String -Path "C:\Users\jdpal\repos\aitools\.claude\worktrees\pywinpty\scripts\setup-pywinpty.ps1" -Pattern '[^\x00-\x7F]'
if ($nonAscii) { "non-ASCII:"; $nonAscii } else { "ascii OK" }
