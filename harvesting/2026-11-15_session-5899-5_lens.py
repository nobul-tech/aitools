"""Count lengths of plan 2.2 panel texts and the bash rule line (read-only check)."""
src = open('/Users/new-jose/repos/aitools/scripts/aitools-lib.sh', encoding='utf-8').read().splitlines()
print('rule chars:', len(src[4335].split('"')[1]))
texts = [
    '23 deploy/*.ps1 over the Intune script limit (200000) -- FX-35',
    'this machine is not registered -- run: aitools user init',
    'not authenticated -- run: vercel login',
    'not authenticated -- run: modal setup (browser flow)',
    'on PATH for this session only -- add ~/go/bin to your shell profile',
    'not authenticated -- run: pup auth login',
    'skipped (user review): local differs from source',
    'brew install failed: Error: No available formula with the nam...',
]
for t in texts:
    print(len(t), t)
full = 'brew install failed: Error: No available formula with the name "pandoc".'
print('full red', len(full))
what, reason = 'brew install failed', 'Error: No available formula with the name "pandoc".'
budget = 70 - len(what) - 2
print('grammar red:', what + ': ' + reason[:budget - 3] + '...')
