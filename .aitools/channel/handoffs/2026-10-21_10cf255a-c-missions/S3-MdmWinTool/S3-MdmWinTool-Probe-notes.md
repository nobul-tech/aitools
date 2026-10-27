# S3-MdmWinTool-Probe notes (v1.0, 2026-10-26)

Delegate: S3-MdmWinTool-Probe (level 2, under S3-MdmWinTool). Host: Darwin arm64
(Mac). Scratch: `/Users/new-jose/repos/aitools/.scratch/session-mdmw-prb/`.

## Summary

1. IntuneWinAppUtil.exe v1.8.7 (commit `1d6cfcb`, SHA256 `c1ba45b5…71f6`, 62,520 bytes) is a **PE32+ x86-64 IL-only .NET Framework 4.7.2 console assembly**, Authenticode-signed (PKCS#7, Microsoft Corporation / Microsoft Code Signing PCA 2011).
2. On this Mac, **the unmodified exe does not run**: the only runtime present is Homebrew dotnet 10.0.9 (arm64), which refuses it ("assembly architecture is not compatible"). Mono, Wine and Rosetta 2 are absent, and installing any of them needs Homebrew or admin rights, so none was installed.
3. Diagnostic only: a copy with the PE Machine field patched to arm64 (which voids the signature) runs `-v` on dotnet 10 (prints `1.8.7.0`). Packaging still fails twice: first `System.IO.Packaging` is missing, then, with that dll from NuGet supplied, a `NullReferenceException` while writing the outer zip. **The official tool cannot produce a package on macOS in any form I tested.**
4. svrooij/ContentPrep (NuGet `SvRooij.ContentPrep` 0.4.2, a library, not a dotnet tool) built and ran in an isolated NuGet cache. It **produced a valid-looking `.intunewin`** from the dummy folder on macOS arm64.
5. Format observed: an outer zip (Stored) holding `IntuneWinPackage/Contents/IntunePackage.intunewin` (encrypted data) and `IntuneWinPackage/Metadata/Detection.xml` (AES key, MAC key, IV, MAC, SHA256 digest). Upload to Intune was not tested, so whether Intune accepts this output is unknown.

## 1. Environment

| Item | Value | Source |
|---|---|---|
| OS | macOS 27.0.1 (26A434), Darwin 27.0.0, arm64 (T6050) | `uname -a`, `sw_vers` |
| dotnet | SDK 10.0.301, host 10.0.9 arm64, runtimes Microsoft.NETCore.App 10.0.9 and Microsoft.AspNetCore.App 10.0.9, at `/opt/homebrew/Cellar/dotnet/10.0.301/libexec` (Homebrew, already installed before this probe) | `dotnet --info` |
| mono | not found; `/Library/Frameworks/Mono.framework` absent | `scripts/env-check.sh` |
| wine / wine64 / wine-stable | not found; Wine Stable.app, Wine Crossover.app, CrossOver.app and Whisky.app all absent | `scripts/env-check.sh` |
| Rosetta 2 | **not installed**. `arch -x86_64 /usr/bin/uname -m` gives `arch: posix_spawnp: /usr/bin/uname: Bad CPU type in executable`, although uname is universal with an x86_64 slice. `pkgutil --pkg-info com.apple.pkg.RosettaUpdateAuto` gives `No receipt … found`. `/Library/Apple/usr/libexec/oah/` contains only `RosettaLinux` | commands as shown |
| osslsigncode | not found | `scripts/env-check.sh` |
| other | python3 3.14.8 (`~/.local/bin`), `/usr/bin/{file,strings,shasum,unzip,objdump,openssl}` | `scripts/env-check.sh` |

## 2. The download

| Field | Value |
|---|---|
| Repo | `microsoft/Microsoft-Win32-Content-Prep-Tool` (org account) |
| Commit (HEAD, pinned) | `1d6cfcbdf8c28edc596337031f74df951f38f718`, 2025-08-13T21:21:15Z, "Merge pull request #156 from microsoft/fix_the_exe" |
| URL | `https://raw.githubusercontent.com/microsoft/Microsoft-Win32-Content-Prep-Tool/1d6cfcbdf8c28edc596337031f74df951f38f718/IntuneWinAppUtil.exe` |
| Local path | `.scratch/session-mdmw-prb/dl-exe/IntuneWinAppUtil.exe` |
| Size | 62520 bytes (`ls -l`; matches the contents API size 62520) |
| SHA256 | `c1ba45b5cb939e84af064bb7ff4b38fb3dfe33c8dc1078fd9b157672eae671f6` |
| git blob SHA | `566b5e0371a82ef5bd4e59f4314d72f0996d57f3` (`git hash-object`), **matches** `gh api repos/.../contents` blob SHA, so it is the file committed at the repo root |
| Repo root listing | `IntuneWinAppUtil.exe 62520`, `Microsoft License Terms For Win32 Content Prep Tool.pdf 95372`, `README.md 3542`, `ReleaseNotes.txt 1153`, `SECURITY.md 2757` |

Prior notes (S3-BuildPkg-PkgWin section 1) are confirmed on three points: the exe is committed at the repo root; it targets .NET Framework 4.7.2; and it is v1.8.7 with a 2025-08-13 commit date (version taken from `-v` output in run 2).

## 3. Static inspection (verbatim)

`file IntuneWinAppUtil.exe`:
```
PE32+ executable (console) x86-64 Mono/.Net assembly, for MS Windows
```

`strings -a … | grep -i -E "v4.0.30319|TargetFramework|NETFramework|mscorlib|System\.|netstandard|Version="`:
```
v4.0.30319
System.IO
mscorlib
System.Collections.Generic
System.Core
TargetFrameworkAttribute
System.IO.Packaging
System.Runtime.Versioning
System.Xml
System.IO.Compression.FileSystem
System.IO.Compression
System.Globalization
System.Xml.Serialization
System.Reflection
System.Linq
System.Diagnostics
System.Runtime.InteropServices
System.Runtime.CompilerServices
System.Diagnostics.CodeAnalysis
System.Collections
System.Text
System.Security.Cryptography
.NETFramework,Version=v4.7.2
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity version="1.0.0.0" name="MyApplication.app"/>
```

`python3 -I scripts/pe-inspect.py IntuneWinAppUtil.exe` (stdlib PE/ECMA-335 metadata parser; reads the file and never executes it):
```
Machine: 0x8664 (0x8664=x64, 0x14c=x86, 0xaa64=arm64)
Sections: 2  TimeDateStamp: 0xa5c37c16  Characteristics: 0x0022
Optional header magic: 0x20b (0x20b=PE32+, 0x10b=PE32)
Subsystem: 3 (3=console, 2=GUI)
Security (Authenticode cert table) dir: offset=0xcc00 size=10296
  WIN_CERTIFICATE: length=10296 revision=0x200 type=0x2 (2=PKCS#7)
CLR runtime header dir: rva=0x2000 size=72
Section table: .text, .rsrc
CLR header: cb=72 runtime=2.5 flags=0x9
  flags: ILONLY, STRONGNAMESIGNED
Metadata sig=0x424a5342 version string: v4.0.30319
Metadata streams: #~, #Strings, #US, #GUID, #Blob
Assembly: IntuneWinAppUtil 5.0.0.0
AssemblyRef rows:
  mscorlib 4.0.0.0
  System.Xml 4.0.0.0
  System 4.0.0.0
  System.Core 4.0.0.0
  WindowsBase 4.0.0.0
  System.IO.Compression 4.2.0.0
  System.IO.Compression.FileSystem 4.0.0.0
TypeRef namespaces: System, System.Collections, System.Collections.Generic, System.Diagnostics, System.Diagnostics.CodeAnalysis, System.Globalization, System.IO, System.IO.Compression, System.IO.Packaging, System.Linq, System.Reflection, System.Runtime.CompilerServices, System.Runtime.InteropServices, System.Runtime.Versioning, System.Security.Cryptography, System.Text, System.Xml, System.Xml.Serialization
```
How to read this output:
- The assembly is IL-only, but its PE header marks it **x64-specific** (PE32+, Machine 0x8664), not AnyCPU. That marking is what blocks it on arm64 CoreCLR (run 1).
- No WinForms or WPF UI references. It does reference `WindowsBase` (the WPF base assembly in .NET Framework), only for `System.IO.Packaging`, which it uses to build the zip.
- The TimeDateStamp looks like a deterministic-build hash, not a date (inference).
- The assembly version is 5.0.0.0; the file/product version is 1.8.7.0 (from `-v`).

Authenticode (`python3 -I scripts/extract-cert.py` copies the PKCS#7 blob to `dl-x/authenticode.p7b`; then `openssl pkcs7 -inform DER -in … -print_certs -noout`):
```
subject=C=US, ST=Washington, L=Redmond, O=Microsoft Corporation, CN=Microsoft Corporation
issuer=C=US, ST=Washington, L=Redmond, O=Microsoft Corporation, CN=Microsoft Code Signing PCA 2011

subject=C=US, ST=Washington, L=Redmond, O=Microsoft Corporation, CN=Microsoft Code Signing PCA 2011
issuer=C=US, ST=Washington, L=Redmond, O=Microsoft Corporation, CN=Microsoft Root Certificate Authority 2011
```
A signature is present and its chain names Microsoft. **Not verified**: whether the Authenticode digest matches the file, and the timestamp countersignature. That needs `osslsigncode verify` or Windows `Get-AuthenticodeSignature` (see section 5).

Dependency check on the host runtime: `Microsoft.NETCore.App/10.0.9/` ships `mscorlib.dll` and `WindowsBase.dll` facades and `System.IO.Compression*.dll`. The `WindowsBase.dll` facade forwards `System.IO.Packaging` types (`ZipPackage`, `PackagePartCollection`, and others, from `strings`) to `System.IO.Packaging 0.0.0.0` (`pe-inspect.py` AssemblyRef rows: System.Runtime, System.ObjectModel, System.IO.Packaging, System.Security.Permissions). `find … -iname "System.IO.Packaging*"` found nothing: that assembly is NuGet-only, not part of the shared framework.

## 4. Run attempts (playbook Step 5 template)

Every run used cwd `/Users/new-jose/repos/aitools` (the Bash tool default), which is outside every download directory. The runtimeconfig used is `scripts/IntuneWinAppUtil.runtimeconfig.json` (Microsoft.NETCore.App 10.0.0, rollForward LatestMajor), written by me in the scripts directory.

```
## Trial 1: IntuneWinAppUtil.exe (unmodified) -v on macOS arm64, dotnet 10.0.9
Date: 2026-10-26
Method: dotnet exec --runtimeconfig .../scripts/IntuneWinAppUtil.runtimeconfig.json .../dl-exe/IntuneWinAppUtil.exe -v
Official source: https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool @ 1d6cfcb
Result: failure (exit 134)
Installed path: n/a (nothing installed)
Version: n/a
Elevation needed: no
PATH integration: n/a
Notes: verbatim:
  Unhandled exception. System.IO.FileLoadException: Could not load file or assembly '/Users/new-jose/repos/aitools/.scratch/session-mdmw-prb/dl-exe/IntuneWinAppUtil.exe'. The assembly architecture is not compatible with the current process architecture.
  File name: '/Users/new-jose/repos/aitools/.scratch/session-mdmw-prb/dl-exe/IntuneWinAppUtil.exe'
```

```
## Trial 2 (DIAGNOSTIC, modified binary): Machine field patched 0x8664 -> 0xaa64, -v
Date: 2026-10-26
Method: python3 -I scripts/patch-machine.py dl-exe/IntuneWinAppUtil.exe dl-x/patched/IntuneWinAppUtil.exe aa64
        dotnet exec --runtimeconfig .../IntuneWinAppUtil.runtimeconfig.json .../dl-x/patched/IntuneWinAppUtil.exe -v
Official source: as trial 1 (copy; original untouched; Authenticode now invalid)
Result: success
Version: 1.8.7.0
Elevation needed: no
Notes: proves the IL starts and runs on arm64 CoreCLR 10 once the x64 marker is removed.
       NOT a usable path: the binary is modified and the signature is void.
```

```
## Trial 3 (DIAGNOSTIC): patched copy, packaging run, no extra assemblies
Date: 2026-10-26
Method: dotnet exec --runtimeconfig ... dl-x/patched/IntuneWinAppUtil.exe -c .../testapp -s install.cmd -o .../dl-out -q
Result: failure (exit 5)
Notes: verbatim (key lines):
  INFO   Compressing the source folder '/Users/new-jose/repos/aitools/.scratch/session-mdmw-prb/testapp' to '/var/folders/9q/.../IntuneWinPackage/Contents/IntunePackage.intunewin'
  ERROR  File '/Users/new-jose/repos/aitools/.scratch/session-mdmw-prb/dl-out/install.intunewin' has failed to be generated
  System.IO.FileNotFoundException: Could not load file or assembly 'System.IO.Packaging, Version=0.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a'. The system cannot find the file specified.
     at Microsoft.Management.Service.IntuneWinAppUtil.ZipUtil.ZipFolder(...)
     at Microsoft.Management.Service.IntuneWinAppUtil.PackageUtil.CreatePackage(...)
     at Microsoft.Management.Service.IntuneWinAppUtil.Program.Main(String[] args)
```

```
## Trial 4 (DIAGNOSTIC): patched copy + System.IO.Packaging.dll (NuGet 10.0.9, lib/net10.0) beside it
Date: 2026-10-26
Method: curl nupkg -> dl-pkg/; unzip -j lib/net10.0/System.IO.Packaging.dll -> dl-pkgx/; cp to dl-x/patched/; same command as trial 3
Result: failure (exit 5); dl-out/install.intunewin left as a 0-byte file
Notes: verbatim (key lines):
  INFO   Compressed folder '.../testapp' successfully within 10 milliseconds
  INFO   Encrypting file '.../IntuneWinPackage/Contents/IntunePackage.intunewin'
  INFO   '...IntunePackage.intunewin' has been encrypted successfully within 2 milliseconds
  INFO   Generating detection XML file '.../IntuneWinPackage/Metadata/Detection.xml'
  INFO   Generated detection XML file within 14 milliseconds
  INFO   Compressing folder '.../IntuneWinPackage' to '/Users/new-jose/repos/aitools/.scratch/session-mdmw-prb/dl-out/install.intunewin'
  ERROR  File '/Users/new-jose/repos/aitools/.scratch/session-mdmw-prb/dl-out/install.intunewin' has failed to be generated
  System.NullReferenceException: Object reference not set to an instance of an object.
     at Microsoft.Management.Service.IntuneWinAppUtil.ZipUtil.CreateFromDirectory(String sourceDirectoryName, String destinationArchiveFileName, CompressionOption compressionOption, Boolean includeBaseDirectory, ReportProgress reportProgress)
     at Microsoft.Management.Service.IntuneWinAppUtil.ZipUtil.CreateFromDirectory(...)
     at Microsoft.Management.Service.IntuneWinAppUtil.ZipUtil.ZipFolder(...)
     at Microsoft.Management.Service.IntuneWinAppUtil.PackageUtil.CreatePackage(...)
     at Microsoft.Management.Service.IntuneWinAppUtil.Program.Main(String[] args)
  Root cause of the NRE: unknown (not debugged; possibly a .NET Framework vs .NET 10
  System.IO.Packaging behaviour difference or a Windows path assumption — inference).
  The inner zip, encryption and Detection.xml steps all completed before the failure.
```

```
## Trial 5: svrooij/ContentPrep library (NuGet SvRooij.ContentPrep 0.4.2) on macOS arm64, dotnet 10
Date: 2026-10-26
Method: scripts/cprep-app/{cprep-app.csproj,Program.cs} (net10.0, PackageReference SvRooij.ContentPrep 0.4.2;
        calls new SvRooij.ContentPrep.Packager().CreatePackage(folder, setupFile, outputFolder, null, ct))
        bash scripts/cprep-build.sh   (NUGET_PACKAGES=<scratch>/dl-nuget, DOTNET_CLI_HOME=<scratch>/dotnet-home,
                                       telemetry opt-out; build -o <scratch>/cprep-bin, obj -> <scratch>/cprep-obj)
        dotnet .../cprep-bin/cprep-app.dll .../testapp .../testapp/install.cmd .../dl-out2
Official source: https://github.com/svrooij/ContentPrep (HEAD 54685857f7ee450fe106591e8dc315b578311b84; personal
        account, GPL-3.0, 32 stars, pushed 2025-10-03); nuget.org SvRooij.ContentPrep 0.4.2 (verified=false,
        13,291 total downloads, packageType Dependency = library, NOT a dotnet tool)
Result: success (after one failed attempt: with a bare file name 'install.cmd' it threw
        "System.IO.FileNotFoundException: File 'install.cmd' can not be found" from
        Packager.CheckSetupFileExistsAndInSetupFolder; the setup file must be a full path)
Installed path: none outside scratch (restore pulled svrooij.contentprep 0.4.2,
        microsoft.extensions.logging.abstractions 8.0.3, microsoft.extensions.dependencyinjection.abstractions 8.0.2
        into <scratch>/dl-nuget)
Version: library 0.4.2
Elevation needed: no
Output: "CreatePackage returned: SvRooij.ContentPrep.Models.ApplicationInfo"; dl-out2/install.intunewin, 1435 bytes
Notes: The README says verbatim (decoded): "This is not a replacement for the Microsoft tool, it is a re-implementation
       of the tool based upon public available information. It is not feature complete and it might not work for your
       use case. If you need a tool that works, use the Microsoft tool." Licence and provenance are for S3-MdmWinTool-Eval
       and S3-MdmWinTool-Research; yellow flags seen here: personal account, unverified NuGet owner, GPL-3.0
       (copyleft, which matters if it is linked into distributed tooling).
```

## 5. Not run (exact command, what it installs, where)

| What | Command | Installs / where | Why not run |
|---|---|---|---|
| Rosetta 2 | `softwareupdate --install-rosetta --agree-to-license` | Apple Rosetta, system (`/Library/Apple/usr/libexec/oah`), needs admin | System-wide; forbidden for this probe. Every x64 route (x64 dotnet, Wine) needs it. |
| x64 dotnet under Rosetta (no admin, after Rosetta) | `curl -sSL -o <dl-dir>/dotnet-install.sh https://dot.net/v1/dotnet-install.sh`, then `bash <dl-dir>/dotnet-install.sh --channel 10.0 --runtime dotnet --architecture x64 --install-dir <scratch>/dotnet-x64` | x64 .NET 10 runtime into scratch | Blocked by Rosetta. Even then, the unmodified exe would still need `System.IO.Packaging.dll` beside it, and trial 4's NRE is probably not architecture-related, so the likely outcome is the same failure (inference). |
| Mono | `brew install mono` | Mono into `/opt/homebrew` (Homebrew, system-wide by the brief's definition) | Forbidden (brew). Whether Mono on arm64 ignores the x64 PE marker for IL-only code, and whether its `System.IO.Packaging` behaves well enough, is unknown. |
| Wine | `brew install --cask wine-stable` (+ Rosetta), then `winetricks dotnet472` or wine-mono | Wine app into `/Applications`, prefix into `~/.wine` | Forbidden (brew, admin for Rosetta). Heavy; .NET Framework 4.7.2 inside Wine is known to be fragile (general knowledge, not tested). |
| Authenticode digest verification | `brew install osslsigncode`, then `osslsigncode verify -in .../dl-exe/IntuneWinAppUtil.exe`; or on Windows: `Get-AuthenticodeSignature IntuneWinAppUtil.exe` | osslsigncode into `/opt/homebrew` | Forbidden (brew). Only the signer chain was read. |
| Unmodified exe on Windows | `IntuneWinAppUtil.exe -c <dir> -s install.cmd -o <out> -q` on Windows 11 with .NET Framework 4.7.2+ | none | Not this host. This is the reference output to compare against trial 5's format. |
| ContentPrep round-trip | `packager.Unpack(<intunewin>, <dir>, ct)` | none | Not done (time); it would confirm that Detection.xml decrypts its own payload. Intune upload acceptance was also not tested. |

## 6. Format observations (from trial 5, ContentPrep output)

`unzip -lv dl-out2/install.intunewin`:
```
 Length   Method    Size  Cmpr    Date    Time   CRC-32   Name
--------  ------  ------- ---- ---------- ----- --------  ----
     256  Stored      256   0% 10-26-2026 19:43 dec56cc3  IntuneWinPackage/Contents/IntunePackage.intunewin
     829  Stored      829   0% 10-26-2026 19:43 311e59ed  IntuneWinPackage/Metadata/Detection.xml
--------          -------  ---                            -------
    1085             1085   0%                            2 files
```
- The outer archive is a plain zip with both entries Stored (no compression).
- The inner `IntunePackage.intunewin` is opaque data (`file`: `data`): the encrypted inner zip of the source folder.
- The 1085-byte total matches the Microsoft tool's own log line in trial 4, `Calculated size for folder '.../IntuneWinPackage' is 1085`, for the same 88-byte input. The layout and sizes are consistent between the two tools.

`IntuneWinPackage/Metadata/Detection.xml` (extracted to `dl-x2/`; keys belong to a throwaway dummy package):
```xml
<ApplicationInfo xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" ToolVersion="1.8.6.0">
  <Name>install.cmd</Name>
  <UnencryptedContentSize>205</UnencryptedContentSize>
  <FileName>IntunePackage.intunewin</FileName>
  <SetupFile>install.cmd</SetupFile>
  <EncryptionInfo>
    <EncryptionKey>pz2esHPQBfGMk4M2VwYhHWS6v+QTTk1seqQ576s/njg=</EncryptionKey>
    <MacKey>EfYSjCa/OXssO2PGJyyMte2sVrz8MgZLAQpSfi6OyQQ=</MacKey>
    <InitializationVector>C8aovrupwJvKzEVOUlMO7Q==</InitializationVector>
    <Mac>vI1RAUXjsJvZUlSV2i0jGqU1pYlNmEzB35VlZGeTBUA=</Mac>
    <ProfileIdentifier>ProfileVersion1</ProfileIdentifier>
    <FileDigest>frz8rmz4mYM6G1A5B3oL/D/zngRB2eADFVcbltTjQUI=</FileDigest>
    <FileDigestAlgorithm>SHA256</FileDigestAlgorithm>
  </EncryptionInfo>
</ApplicationInfo>
```
- 32-byte EncryptionKey and MacKey, 16-byte IV, 32-byte MAC (an HMAC-SHA256 tag, by length) and a SHA256 FileDigest. This is consistent with AES-256-CBC plus HMAC-SHA256 (inference from lengths and field names; not verified by decryption).
- ContentPrep stamps `ToolVersion="1.8.6.0"`, not the current Microsoft 1.8.7.0. Whether Intune checks ToolVersion is unknown.
- The keys in Detection.xml sit in cleartext inside the package, so a `.intunewin` must be handled as sensitive until it is uploaded (format observation; Intune extracts Detection.xml at upload).

## 7. INCIDENT markers

- None against the harness. Observation for the orchestrator (not an incident): dotnet 10.0.301 is on this Mac through Homebrew. Whether it is a registry-managed tool, and so a valid dependency for a macOS packaging path, is unknown; check with the `/tool-registry` skill.

## 8. Honest gaps

- Authenticode digest validity and the signing timestamp were not verified (no osslsigncode).
- The unmodified exe was never run successfully anywhere. The Windows reference output was not produced, so there is no byte-level comparison of Microsoft and ContentPrep output.
- The root cause of trial 4's NullReferenceException is unknown.
- Mono and Wine behaviour is untested and unknown.
- Intune acceptance of a ContentPrep-built `.intunewin` is untested.
- The ContentPrep NuGet package signature (`.signature.p7s` is nuget.org's repository signature) and the System.IO.Packaging nupkg signature were not verified. System.IO.Packaging 10.0.9 nupkg SHA256: `b95453a79f3e48ce42b181b7c9ae22eafee42768e949aa3d6243a0994e450a4d`.

## 9. Files produced (all under `.scratch/session-mdmw-prb/`)

- scripts/: `env-check.sh`, `pe-inspect.py`, `extract-cert.py`, `patch-machine.py`, `IntuneWinAppUtil.runtimeconfig.json`, `cprep-build.sh`, `cprep-app/{cprep-app.csproj,Program.cs}`
- downloads: `dl-exe/IntuneWinAppUtil.exe` (original), `dl-pkg/system.io.packaging.10.0.9.nupkg`, `dl-nuget/` (isolated NuGet cache)
- derived: `dl-x/authenticode.p7b`, `dl-x/patched/{IntuneWinAppUtil.exe (patched copy), System.IO.Packaging.dll}`, `dl-pkgx/System.IO.Packaging.dll`, `dl-out/install.intunewin` (0 bytes, from failed trial 4), `dl-out2/install.intunewin` (ContentPrep output), `dl-x2/IntuneWinPackage/...`, `cprep-bin/`, `cprep-obj/`, `dotnet-home/`, `testapp/install.cmd`
