#!/usr/bin/env python3
"""pe-sig.py: read-only PE header inspection (no execution).

Usage: python3 -I pe-sig.py <file.exe>
Reports machine, subsystem, CLR (.NET) directory, the Authenticode security
directory (offset/size), and signer-ish strings found inside the certificate
blob (subject CN / O fragments). Does not validate the signature chain.
"""
import struct
import sys


def main(path: str) -> int:
    with open(path, "rb") as f:
        data = f.read()
    if data[:2] != b"MZ":
        print("not a PE (no MZ)")
        return 1
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe:pe + 4] != b"PE\0\0":
        print("not a PE (no PE sig)")
        return 1
    machine, nsec, ts = struct.unpack_from("<HHI", data, pe + 4)
    opt = pe + 24
    magic = struct.unpack_from("<H", data, opt)[0]
    is64 = magic == 0x20B
    subsystem = struct.unpack_from("<H", data, opt + 68)[0]
    dd = opt + (112 if is64 else 96)
    dirs = [struct.unpack_from("<II", data, dd + 8 * i) for i in range(16)]
    sec_off, sec_size = dirs[4]
    clr_rva, clr_size = dirs[14]
    print(f"machine=0x{machine:04x} magic=0x{magic:x} subsystem={subsystem} timestamp={ts}")
    print(f"clr_dir rva=0x{clr_rva:x} size={clr_size} (non-zero means .NET assembly)")
    print(f"security_dir offset={sec_off} size={sec_size} file_size={len(data)}")
    if sec_size == 0:
        print("AUTHENTICODE: none (no security directory)")
        return 0
    blob = data[sec_off:sec_off + sec_size]
    length, rev, ctype = struct.unpack_from("<IHH", blob, 0)
    print(f"WIN_CERTIFICATE length={length} revision=0x{rev:x} type=0x{ctype:x}")
    seen = set()
    for marker in (b"Microsoft Corporation", b"Microsoft Code Signing PCA",
                   b"Microsoft Root Certificate Authority", b"Microsoft Time-Stamp"):
        if marker in blob:
            seen.add(marker.decode())
    print("cert strings found: " + (", ".join(sorted(seen)) if seen else "none of the probed strings"))
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] in ("-h", "--help"):
        print(__doc__)
        sys.exit(0 if len(sys.argv) == 2 else 2)
    sys.exit(main(sys.argv[1]))
