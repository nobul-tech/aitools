#!/usr/bin/env python3
"""Find .sh/.ps1 parity gaps in aitools/scripts/."""
import os

scripts_dir = "/Users/pepe/repos/aitools/scripts"
sh_files = set()
ps1_files = set()

for f in os.listdir(scripts_dir):
    if f.endswith(".sh"):
        sh_files.add(f[:-3])
    elif f.endswith(".ps1"):
        ps1_files.add(f[:-4])

sh_only = sh_files - ps1_files
ps1_only = ps1_files - sh_files

print("=== .sh without .ps1 pair ===")
for f in sorted(sh_only):
    print(f"  {f}.sh")

print("\n=== .ps1 without .sh pair ===")
for f in sorted(ps1_only):
    print(f"  {f}.ps1")

print("\n=== Paired scripts ===")
for f in sorted(sh_files & ps1_files):
    print(f"  {f}.sh / {f}.ps1")

# Also check deploy/
deploy_dir = "/Users/pepe/repos/aitools/deploy"
if os.path.isdir(deploy_dir):
    dsh = set()
    dps = set()
    for f in os.listdir(deploy_dir):
        if f.endswith(".sh"):
            dsh.add(f[:-3])
        elif f.endswith(".ps1"):
            dps.add(f[:-4])

    dsh_only = dsh - dps
    dps_only = dps - dsh

    print("\n=== deploy/ .sh without .ps1 ===")
    for f in sorted(dsh_only):
        print(f"  {f}.sh")
    print("\n=== deploy/ .ps1 without .sh ===")
    for f in sorted(dps_only):
        print(f"  {f}.ps1")
    print(f"\n=== deploy/ paired: {len(dsh & dps)} scripts ===")
