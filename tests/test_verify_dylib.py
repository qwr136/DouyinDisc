"""Synthetic Mach-O specimens only; these are not build artifacts."""

import hashlib
import json
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from verify_dylib import parse_version, verify_dylib, verify_embedded_artwork, version_text

TEXT_OFFSET, LINK_OFFSET, SIGN_OFFSET = 0x400, 0x4000, 0x4020
MINIMUM = parse_version('15.0')
SDK = parse_version('16.5')
INSTALL_NAME = '@loader_path/DouyinDisc.dylib'
IDENTIFIER = 'com.minis.douyindisc'
LIB_SYSTEM = '/usr/lib/libSystem.B.dylib'
FOUNDATION = '/System/Library/Frameworks/Foundation.framework/Foundation'


def dylib_command(opcode, name):
    string = name.encode('ascii') + b'\0'
    string += bytes((-len(string)) % 8)
    return struct.pack('<6I', opcode, 24 + len(string), 24, 0, 0, 0) + string


def segment(name, offset, size, protection, sections=b''):
    return struct.pack('<II16s4Q4I', 0x19, 72 + len(sections), name, offset, (size + 0x3FFF) & ~0x3FFF,
                       offset, size, protection, protection, len(sections) // 80, 0) + sections


def signature(prefix, *, identifier, with_requirements, alternate):
    requirements = struct.pack('>3I', 0xFADE0C01, 12, 0) if with_requirements else None

    def cd(code, algorithm, hashsize):
        hashes = b''.join(hashlib.new(algorithm, prefix[i:i + 4096]).digest()
                          for i in range(0, len(prefix), 4096))
        ident = identifier.encode('ascii') + b'\0'
        special = b'' if requirements is None else hashlib.new(algorithm, requirements).digest() + bytes(hashsize)
        offset = 88 + len(ident) + len(special)
        return struct.pack('>9I4BI', 0xFADE0C02, offset + len(hashes), 0x20400, 2, offset,
                           88, len(special) // hashsize, len(hashes) // hashsize, len(prefix),
                           hashsize, code, 0, 12, 0) + bytes(44) + ident + special + hashes

    slots = [(0, cd(2, 'sha256', 32))]
    if requirements is not None:
        slots.append((2, requirements))
    if alternate:
        slots.append((0x1000, cd(1, 'sha1', 20)))
    indexes, bodies = b'', b''
    start = 12 + 8 * len(slots)
    for slot, blob in slots:
        indexes += struct.pack('>2I', slot, start + len(bodies))
        bodies += blob
    return struct.pack('>3I', 0xFADE0CC0, start + len(bodies), len(slots)) + indexes + bodies + bytes(8)


def specimen(*, subtype=0, kind=6, platform=2, minimum=MINIMUM, legacy=False, extra=(),
             deps=((0xC, LIB_SYSTEM), (0xC, FOUNDATION)), with_text=True, with_signature=True,
             identifier=IDENTIFIER, install=INSTALL_NAME, with_requirements=False, alternate=False):
    sig = {'identifier': identifier, 'with_requirements': with_requirements, 'alternate': alternate}
    sigsize = len(signature(bytes(SIGN_OFFSET), **sig)) if with_signature else 0
    section = struct.pack('<16s16sQQ8I', b'__text', b'__TEXT', TEXT_OFFSET, 4, TEXT_OFFSET,
                          2, 0, 0, 0x80000400, 0, 0, 0) if with_text else b''
    build = (struct.pack('<4I', 0x25, 16, minimum, SDK) if legacy else
             struct.pack('<8I', 0x32, 32, platform, minimum, SDK, 1, 3, 0x00100000))
    cmds = [segment(b'__TEXT', 0, LINK_OFFSET, 5, section),
            segment(b'__LINKEDIT', LINK_OFFSET, SIGN_OFFSET - LINK_OFFSET + sigsize, 1),
            build, dylib_command(0xD, install), *[dylib_command(*dep) for dep in deps], *extra]
    if with_signature:
        cmds.append(struct.pack('<4I', 0x1D, 16, SIGN_OFFSET, sigsize))
    joined = b''.join(cmds)
    header = struct.pack('<8I', 0xFEEDFACF, 0x0100000C, subtype, kind, len(cmds), len(joined), 0, 0)
    prefix = (header + joined).ljust(TEXT_OFFSET, b'\0') + bytes.fromhex('c0035fd6')
    prefix = prefix.ljust(SIGN_OFFSET, b'\0')
    return prefix + signature(prefix, **sig) if with_signature else prefix


def patch(data, offset, fmt, *fields):
    buf = bytearray(data)
    struct.pack_into(fmt, buf, offset, *fields)
    return bytes(buf)


class VerifyDylibTests(unittest.TestCase):
    def setUp(self):
        work = tempfile.TemporaryDirectory()
        self.addCleanup(work.cleanup)
        self.project = Path(work.name)
        self.artifact = self.project / 'DouyinDisc.dylib'

    def verify(self, data, *, project=None):
        self.artifact.write_bytes(data)
        return verify_dylib(self.artifact, project=project)

    def test_current_artwork_payloads_must_be_embedded(self):
        source = self.project / 'Sources'
        source.mkdir()
        payloads = {
            'DouyinDiscBaseArtwork.inc': b'\\x89PNG\\r\\n\\x1a\\nbase-new-png',
            'DouyinDiscAccentArcs.inc': b'\\x89PNG\\r\\n\\x1a\\narcs-new-png',
        }
        for filename, payload in payloads.items():
            (source / filename).write_text(','.join(f'0x{byte:02x}' for byte in payload), encoding='ascii')
        binary = b'Mach-O-image:' + b''.join(payloads.values())
        result = verify_embedded_artwork(binary, self.project)
        self.assertEqual([item['source'] for item in result], list(payloads))
        self.assertTrue(all(item['embedded'] for item in result))
        with self.assertRaisesRegex(ValueError, 'PNG bytes are not embedded'):
            verify_embedded_artwork(binary.replace(b'arcs-new-png', b'old-png---'), self.project)

    def test_arm64_deployment_and_page_evidence(self):
        for legacy in (False, True):
            with self.subTest(legacy=legacy):
                data = specimen(legacy=legacy, with_requirements=True, alternate=True)
                result = self.verify(data)
                self.assertEqual(result['sha256'], hashlib.sha256(data).hexdigest())
                self.assertEqual((result['platform'], result['architecture'], result['cpu_subtype']), ('iOS', 'arm64', 0))
                self.assertEqual(result['dependencies'], [LIB_SYSTEM, FOUNDATION])
                self.assertEqual(result['minimum_ios'], version_text(MINIMUM))
                detached = result['signature']['code_directories']
                self.assertEqual([cd['hash_type'] for cd in detached], [2, 1])
                self.assertGreater(detached[0]['page_count'], 1)

    def test_invalid_headers_and_deployment(self):
        good = specimen()
        cases = (b'', good[:32], patch(good, 0, '>I', 0xCAFEBABE), patch(good, 4, '<I', 0x01000007),
                 specimen(subtype=2), specimen(subtype=0x80000000), specimen(kind=2),
                 specimen(platform=1), specimen(platform=6), specimen(platform=7), specimen(minimum=14 << 16),
                 specimen(extra=(struct.pack('<4I', 0x25, 16, MINIMUM, SDK),)),
                 patch(good, 16, '<I', 0xFFFFFFFF), patch(good, 36, '<I', 0))
        for i, data in enumerate(cases):
            with self.subTest(case=i), self.assertRaises(ValueError):
                self.verify(data)

    def test_reject_all_unsafe_load_paths_and_rpath_commands(self):
        for opcode in (0xC, 0x80000018, 0x8000001F, 0x20, 0x80000023):
            for name in ('/usr/lib/libsubstrate.dylib', '/var/jb/usr/lib/libhooker.dylib',
                         '@rpath/CydiaSubstrate.framework/CydiaSubstrate', '@loader_path/Elsewhere.dylib',
                         '/usr/lib/../lib/libSystem.B.dylib',
                         '/System/Library/Frameworks/Substrate.framework/Substrate'):
                with self.subTest(opcode=opcode, name=name), self.assertRaisesRegex(ValueError, 'approved Apple'):
                    self.verify(specimen(deps=((opcode, name),)))
        with self.assertRaisesRegex(ValueError, 'forbidden loader'):
            self.verify(specimen(extra=(struct.pack('<4I', 0x8000001C, 16, 12, 0),)))
        with self.assertRaisesRegex(ValueError, 'malformed dependency'):
            self.verify(specimen(deps=((0x18, FOUNDATION),)))

    def test_required_text_and_real_signature_ranges(self):
        good = specimen()
        for data in (specimen(with_text=False), specimen(with_signature=False), good[:-1], good + b'\0',
                     patch(good, SIGN_OFFSET, '>I', 0), patch(good, SIGN_OFFSET + 12, '>I', 5),
                     patch(good, SIGN_OFFSET + 16, '>I', 4)):
            with self.subTest(data_size=len(data)), self.assertRaises(ValueError):
                self.verify(data)

    def test_reject_changed_page_short_coverage_and_bad_ad_hoc_claim(self):
        good = specimen()
        cd = SIGN_OFFSET + 20
        for data, error in ((patch(good, TEXT_OFFSET, '<I', 0), 'page hash mismatch'),
                            (patch(good, SIGN_OFFSET - 1, 'B', 42), 'page hash mismatch'),
                            (patch(good, cd + 32, '>I', SIGN_OFFSET - 1), 'complete unsigned prefix'),
                            (patch(good, cd + 12, '>I', 0), 'not ad-hoc'),
                            (patch(good, cd + 16, '>I', 0), 'hash table out of bounds'),
                            (patch(good, cd + 30, '>H', 1), 'hash count')):
            with self.subTest(error=error), self.assertRaisesRegex(ValueError, error):
                self.verify(data)
        alternate = specimen(alternate=True)
        with self.assertRaisesRegex(ValueError, 'page hash mismatch'):
            self.verify(patch(alternate, len(alternate) - 9, 'B', alternate[-9] ^ 1))
        req = specimen(with_requirements=True)
        with self.assertRaisesRegex(ValueError, 'special-slot hash mismatch'):
            self.verify(patch(req, len(req) - 9, 'B', 1))

    def test_approved_navigation_system_dependencies(self):
        from verify_dylib import inspect_dylib
        approved=("/System/Library/Frameworks/ImageIO.framework/ImageIO",
                 "/System/Library/Frameworks/PhotosUI.framework/PhotosUI",
                 "/System/Library/Frameworks/UniformTypeIdentifiers.framework/UniformTypeIdentifiers")
        for name in approved:
            with self.subTest(name=name):
                data=specimen(deps=((0xC,LIB_SYSTEM),(0xC,FOUNDATION),(0xC,name)))
                self.artifact.write_bytes(data)
                self.assertIn(name,inspect_dylib(self.artifact)['dependencies'])

    def test_manifest_matching_and_cli_failure(self):
        path = self.project / 'tweak.json'
        path.write_text(json.dumps(dict(target_type='dylib', scheme='trollfools', name='DouyinDisc',
                                        package=IDENTIFIER, minimum_ios='15.0')), encoding='utf-8')
        self.verify(specimen(), project=self.project)
        for data in (specimen(minimum=MINIMUM + 1), specimen(install='@loader_path/Other.dylib'),
                     specimen(identifier='com.example.other')):
            with self.assertRaisesRegex(ValueError, 'differs from project'):
                self.verify(data, project=self.project)
        self.artifact.write_bytes(b'bad')
        result = subprocess.run([sys.executable, str(Path(__file__).with_name('verify_dylib.py')),
                                 '--project', str(self.project), str(self.artifact)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('truncated Mach-O header', result.stderr)
