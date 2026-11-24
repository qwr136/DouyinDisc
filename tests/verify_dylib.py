#!/usr/bin/env python3
"""Offline validation of the signed TrollFools dylib contract, not device trust."""

import argparse
import hashlib
import json
import re
import struct
import sys
from pathlib import Path
from uuid import UUID

MH_MAGIC_64, CPU_TYPE_ARM64, MH_DYLIB = 0xFEEDFACF, 0x0100000C, 6
LC_SEGMENT_64, LC_UUID, LC_CODE_SIGNATURE = 0x19, 0x1B, 0x1D
LC_ID_DYLIB, LC_VERSION_MIN_IPHONEOS, LC_BUILD_VERSION = 0xD, 0x25, 0x32
LOAD_DYLIBS = {0xC, 0x80000018, 0x8000001F, 0x20, 0x80000023}
LOAD_DYLIB_BASES = {cmd & 0x7FFFFFFF for cmd in LOAD_DYLIBS}
# No loader search paths, alternate dylinkers, legacy dynamic loads or executable entrypoints.
FORBIDDEN_LOADS = {0x6, 0x7, 0x9, 0xE, 0xF, 0x10, 0x1C, 0x27, 0x28}
OTHER_MIN_VERSION = {0x24, 0x2F, 0x30}
MAX_FILE_SIZE = 128 * 1024 * 1024

# Compare complete, canonical install names. A prefix match on /usr/lib, or even
# on /System/Library/Frameworks, would admit non-Apple libraries on some devices.
APPLE_DEPENDENCIES = {"/usr/lib/libSystem.B.dylib", "/usr/lib/libobjc.A.dylib"} | {
    f"/System/Library/Frameworks/{name}.framework/{name}"
    for name in ("Foundation", "CoreFoundation", "UIKit", "CoreGraphics", "QuartzCore",
                 "Security", "CoreText", "ImageIO", "Accelerate", "AudioToolbox",
                 "AVFoundation", "CFNetwork", "CoreMedia", "CoreVideo", "Metal", "VideoToolbox",
                 "PhotosUI", "UniformTypeIdentifiers")
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def version_text(value):
    return f"{value >> 16}.{(value >> 8) & 255}.{value & 255}"


def parse_version(text):
    require(isinstance(text, str) and re.fullmatch(r"[0-9]+\.[0-9]+(?:\.[0-9]+)?", text),
            "invalid manifest deployment version")
    fields = [int(value) for value in text.split(".")]
    major, minor, patch = (fields + [0])[:3]
    require(major <= 65535 and minor <= 255 and patch <= 255, "deployment version does not fit Mach-O")
    return (major << 16) | (minor << 8) | patch


def c_string(data, offset, end, label):
    terminator = data.find(b"\0", offset, end)
    require(offset < terminator, "missing or empty " + label)
    return data[offset:terminator].decode("ascii")


def dylib_command(data, offset, size):
    require(size >= 24, "short dylib command")
    nameoff, _, current, compatibility = struct.unpack_from("<4I", data, offset + 8)
    require(24 <= nameoff < size, "dylib path offset out of range")
    return c_string(data, offset + nameoff, offset + size, "dylib path"), current, compatibility


def inspect_macho(data):
    require(len(data) >= 32, "truncated Mach-O header")
    magic, cpu, subtype, kind, ncmds, cmdbytes, _, reserved = struct.unpack_from("<8I", data)
    require(magic == MH_MAGIC_64, "not a little-endian thin 64-bit Mach-O")
    require(cpu == CPU_TYPE_ARM64 and subtype == 0, "requires arm64 with CPU subtype 0")
    require(kind == MH_DYLIB and reserved == 0, "not a supported MH_DYLIB header")
    end = 32 + cmdbytes
    require(0 < ncmds <= cmdbytes // 8 and end <= len(data), "invalid load-command table")
    cursor = 32
    dependencies, segments = [], {}
    install = deployment = signature = text = uuid = None
    for _ in range(ncmds):
        require(cursor + 8 <= end, "truncated load command")
        cmd, size = struct.unpack_from("<2I", data, cursor)
        require(size >= 8 and size % 8 == 0 and cursor + size <= end, "invalid load command size")
        base = cmd & 0x7FFFFFFF
        require(base not in FORBIDDEN_LOADS, "forbidden loader command: " + hex(cmd))
        require(base not in OTHER_MIN_VERSION, "non-iOS deployment command")
        if cmd in (LC_BUILD_VERSION, LC_VERSION_MIN_IPHONEOS):
            require(deployment is None, "multiple deployment commands")
            if cmd == LC_BUILD_VERSION:
                require(size >= 24, "short LC_BUILD_VERSION")
                platform, minimum, sdk, ntools = struct.unpack_from("<4I", data, cursor + 8)
                require(platform == 2, "requires iOS device platform (not simulator or Mac Catalyst)")
                require(size == 24 + ntools * 8, "malformed LC_BUILD_VERSION tool list")
            else:
                require(size == 16, "malformed LC_VERSION_MIN_IPHONEOS")
                minimum, sdk = struct.unpack_from("<2I", data, cursor + 8)
            require(minimum >> 16 >= 15, "requires minimum iOS 15.0 or newer")
            deployment = minimum, sdk
        elif base in LOAD_DYLIB_BASES:
            require(cmd in LOAD_DYLIBS, "malformed dependency command opcode")
            name, _, _ = dylib_command(data, cursor, size)
            require(name in APPLE_DEPENDENCIES, "dependency is not an approved Apple install name: " + name)
            dependencies.append(name)
        elif cmd == LC_ID_DYLIB:
            require(install is None, "multiple LC_ID_DYLIB commands")
            install = dylib_command(data, cursor, size)
            require(re.fullmatch(r"@loader_path/[A-Za-z][A-Za-z0-9]*\.dylib", install[0]),
                    "unexpected dylib install name")
        elif cmd == LC_UUID:
            require(uuid is None and size == 24, "malformed or duplicate LC_UUID")
            uuid = str(UUID(bytes=data[cursor + 8:cursor + 24]))
        elif cmd == LC_CODE_SIGNATURE:
            require(signature is None and size == 16, "malformed or duplicate LC_CODE_SIGNATURE")
            signature = struct.unpack_from("<2I", data, cursor + 8)
        elif cmd == LC_SEGMENT_64:
            require(size >= 72, "short LC_SEGMENT_64")
            name, addr, vmsize, fileoff, filesize, _, prot, nsects, _ = struct.unpack_from(
                "<16s4Q4I", data, cursor + 8)
            name = name.rstrip(b"\0")
            require(name and name not in segments and size == 72 + nsects * 80,
                    "duplicate segment or malformed section count")
            require(filesize <= vmsize and fileoff + filesize <= len(data), "segment data out of bounds")
            segments[name] = fileoff, filesize, prot
            if name == b"__TEXT":
                for i in range(nsects):
                    section = struct.unpack_from("<16s16sQQ8I", data, cursor + 72 + i * 80)
                    sect, seg, loc, count, start = section[:5]
                    if sect.rstrip(b"\0") != b"__text":
                        continue
                    require(text is None and seg.rstrip(b"\0") == name and count >= 4 and
                            start % 4 == count % 4 == 0 and not (section[8] & 0xFF) and
                            end <= start and fileoff <= start and start + count <= fileoff + filesize and
                            loc == addr + start - fileoff, "missing or invalid file-backed __TEXT,__text")
                    text = start, count
        elif base in (LC_BUILD_VERSION, LC_VERSION_MIN_IPHONEOS, LC_ID_DYLIB,
                      LC_CODE_SIGNATURE, LC_SEGMENT_64, LC_UUID):
            raise ValueError("unexpected LC_REQ_DYLD flag on known command")
        cursor += size

    require(cursor == end, "load-command size/count disagreement")
    require(deployment is not None and install is not None, "missing deployment or LC_ID_DYLIB command")
    require(text is not None and segments[b"__TEXT"][0] == 0 and segments[b"__TEXT"][2] & 5 == 5,
            "missing executable, file-backed __TEXT,__text")
    ranges = sorted((off, off + size) for off, size, _ in segments.values() if size)
    require(all(a[1] <= b[0] for a, b in zip(ranges, ranges[1:])), "overlapping file-backed segments")
    require(signature is not None and b"__LINKEDIT" in segments, "missing signature or __LINKEDIT")
    sigoff, sigsize = signature
    linkoff, linksize, _ = segments[b"__LINKEDIT"]
    require(end <= linkoff <= sigoff and sigsize >= 12 and
            sigoff + sigsize == linkoff + linksize == len(data), "signature range outside final __LINKEDIT")
    return deployment, install, dependencies, uuid, signature


CODEDIRECTORY, EMBEDDED_SIGNATURE = 0xFADE0C02, 0xFADE0CC0
HASHES = {1: ("sha1", 20), 2: ("sha256", 32), 3: ("sha256", 20), 4: ("sha384", 48)}
CD_HEADERS = {0x20000: 44, 0x20100: 48, 0x20200: 52, 0x20300: 64,
              0x20400: 88, 0x20500: 96, 0x20600: 108}


def check_directory(directory, image, code_limit, requirements):
    require(len(directory) >= 44, "short CodeDirectory")
    version, flags, hashoff, identoff, special, slots, limit32 = struct.unpack_from(
        ">7I", directory, 8)
    hashsize, hashtype, _, page_shift = struct.unpack_from(">4B", directory, 36)
    header = max((size for floor, size in CD_HEADERS.items() if version >= floor), default=0)
    require(header and version <= 0x20600 and len(directory) >= header, "unsupported CodeDirectory version")
    require(flags & 0x2, "signature is not ad-hoc")
    for position, since, label in ((44, 0x20100, "scatter"), (48, 0x20200, "team ID"),
                                   (92, 0x20500, "pre-encryption"), (100, 0x20600, "linkage"),
                                   (104, 0x20600, "linkage size")):
        require(version < since or not struct.unpack_from(">I", directory, position)[0],
                "unsupported CodeDirectory " + label)
    limit64 = struct.unpack_from(">Q", directory, 56)[0] if version >= 0x20300 else 0
    require((limit64 or limit32) == code_limit and (not limit64 or limit32 in (0, code_limit, 0xFFFFFFFF)),
            "CodeDirectory does not cover the complete unsigned prefix")
    require(hashtype in HASHES and HASHES[hashtype][1] == hashsize, "invalid CodeDirectory hash algorithm/size")
    require(page_shift == 0 or 12 <= page_shift <= 16, "invalid CodeDirectory page size")
    page = (1 << page_shift) if page_shift else code_limit
    require(slots == (code_limit + page - 1) // page, "wrong CodeDirectory code hash count")
    specialoff = hashoff - special * hashsize
    require(header <= identoff < specialoff <= hashoff and hashoff + slots * hashsize <= len(directory),
            "CodeDirectory identifier or hash table out of bounds")
    ident = c_string(directory, identoff, specialoff, "CodeDirectory identifier")
    algorithm = HASHES[hashtype][0]
    if requirements is not None:
        require(special >= 2, "missing CodeDirectory requirements hash")
    for i in range(1, special + 1):
        offset = hashoff - i * hashsize
        want = (hashlib.new(algorithm, requirements).digest()[:hashsize]
                if i == 2 and requirements is not None else bytes(hashsize))
        require(directory[offset:offset + hashsize] == want, f"CodeDirectory special-slot hash mismatch: {i}")
    for i, start in enumerate(range(0, code_limit, page)):
        offset = hashoff + i * hashsize
        want = hashlib.new(algorithm, image[start:min(start + page, code_limit)]).digest()[:hashsize]
        require(directory[offset:offset + hashsize] == want, f"CodeDirectory page hash mismatch: {i}")
    return {"identifier": ident, "hash_type": hashtype, "hash_algorithm": algorithm,
            "page_size": page, "page_count": slots}


def check_signature(data, sigoff, sigsize):
    magic, size, count = struct.unpack_from(">3I", data, sigoff)
    index_end = 12 + count * 8
    require(magic == EMBEDDED_SIGNATURE and 0 < count <= 8 and index_end <= size <= sigsize,
            "invalid embedded signature SuperBlob")
    require(not any(memoryview(data)[sigoff + size:]), "nonzero bytes after signature SuperBlob")
    slots, ranges = {}, []
    for i in range(count):
        slot, offset = struct.unpack_from(">2I", data, sigoff + 12 + i * 8)
        require(index_end <= offset <= size - 8 and slot not in slots, "invalid or duplicate signature slot")
        start = sigoff + offset
        kind, length = struct.unpack_from(">2I", data, start)
        require(8 <= length <= size - offset, "signature blob out of bounds")
        slots[slot] = (kind, start, start + length)
        ranges.append((start, start + length))
    ranges.sort()
    require(all(a[1] <= b[0] for a, b in zip(ranges, ranges[1:])), "overlapping signature slots")
    require(0 in slots, "missing primary CodeDirectory")
    requirements, directories = None, []
    for slot, (kind, start, end) in slots.items():
        if slot == 0 or 0x1000 <= slot < 0x1005:
            require(kind == CODEDIRECTORY, "invalid CodeDirectory magic")
            directories.append((slot, start, end))
        elif slot == 2:
            require(kind == 0xFADE0C01 and end - start >= 12, "invalid requirements blob")
            requirements = data[start:end]
        elif slot == 0x10000:
            require(kind == 0xFADE0B01 and end - start == 8, "unexpected CMS signature payload")
        else:
            raise ValueError("unexpected signature slot (e.g. entitlements): " + hex(slot))
    checked = [check_directory(data[start:end], memoryview(data), sigoff, requirements)
               for _, start, end in sorted(directories)]
    require(any(cd["hash_type"] in (2, 4) for cd in checked), "missing full-strength CodeDirectory hash")
    require(len({cd["identifier"] for cd in checked}) == 1, "CodeDirectory identifiers disagree")
    return {"ad_hoc": True, "offset": sigoff, "size": sigsize, "code_directories": checked}


def verify_embedded_artwork(data, project):
    """Prove the current source PNG payloads occur verbatim in this built image."""
    root = Path(project)
    evidence = []
    for filename in ("DouyinDiscBaseArtwork.inc", "DouyinDiscAccentArcs.inc"):
        source = (root / "Sources" / filename).read_text(encoding="utf-8")
        payload = bytes(int(value, 16) for value in re.findall(r"0x([0-9a-fA-F]{2})", source))
        require(payload.startswith(b"\x89PNG\r\n\x1a\n"), filename + " is not a PNG")
        require(payload in data, filename + " PNG bytes are not embedded in dylib")
        evidence.append({"source": filename, "size": len(payload), "sha256": hashlib.sha256(payload).hexdigest(),
                         "embedded": True})
    return evidence


def inspect_dylib(path, manifest=None, artwork_project=None):
    """Return JSON-ready verification evidence for one read; raise ValueError/OSError on failure."""
    path = Path(path)
    require(path.is_file(), "dylib is not a regular file: " + str(path))
    with path.open("rb") as stream:
        data = stream.read(MAX_FILE_SIZE + 1)
    require(len(data) <= MAX_FILE_SIZE, "dylib exceeds the verifier size limit")
    (minimum, sdk), (install, current, compatibility), deps, uuid, sig = inspect_macho(data)
    signature = check_signature(data, *sig)
    if manifest is not None:
        meta = manifest
        require(isinstance(meta, dict) and meta.get("target_type") == "dylib" and
                meta.get("scheme") == "trollfools", "project is not a TrollFools dylib project")
        name = meta.get("name")
        require(isinstance(name, str) and re.fullmatch(r"[A-Z][A-Za-z0-9]*", name), "invalid manifest name")
        require(install == "@loader_path/" + name + ".dylib", "install name differs from project")
        require(minimum == parse_version(meta.get("minimum_ios")), "deployment version differs from project")
        identifier = signature["code_directories"][0]["identifier"]
        require(identifier == meta.get("package") == "com.minis." + name.lower(),
                "signing identifier differs from project package")
    artwork = verify_embedded_artwork(data, artwork_project) if artwork_project is not None else None
    return {"filename": path.name, "size": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "embedded_artwork": artwork,
            "architecture": "arm64", "cpu_subtype": 0, "filetype": "MH_DYLIB", "platform": "iOS",
            "minimum_ios": version_text(minimum), "sdk": version_text(sdk), "install_name": install,
            "current_version": version_text(current), "compatibility_version": version_text(compatibility),
            "dependencies": deps, "uuid": uuid, "signature": signature}


def verify_dylib(path, *, project=None, verify_artwork=False):
    manifest = None
    if project is not None:
        manifest = json.loads((Path(project) / 'tweak.json').read_text(encoding='utf-8'))
        require(isinstance(manifest, dict), 'project manifest must be a JSON object')
    return inspect_dylib(path, manifest, project if verify_artwork else None)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    parser.add_argument("--verify-artwork", action="store_true", help="require current base/accent PNGs embedded from project")
    parser.add_argument("--project", type=Path, help="also enforce manifest and optionally source assets")
    args = parser.parse_args()
    if args.verify_artwork:
        require(args.project is not None, "--verify-artwork requires --project")
    try:
        print(json.dumps(verify_dylib(args.path, project=args.project, verify_artwork=args.verify_artwork), indent=2))
        return 0
    except (ValueError, OSError) as error:
        print("ERROR: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
