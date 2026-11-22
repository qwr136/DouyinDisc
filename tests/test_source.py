"""Source and mocked wrapper contracts; never runs clang, codesign or prepare."""

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from source_checks import check_project
from test_verify_dylib import specimen
from verify_dylib import verify_dylib

ROOT = Path(__file__).resolve().parent.parent
SOURCE = Path('Sources/DouyinDiscEntry.m')


class SourceContractTests(unittest.TestCase):
    def test_navigation_replacement_and_import_contracts(self):
        hooks=(ROOT/'Sources/DouyinDiscNavigationHooks.m').read_text(encoding='utf-8')
        panel=(ROOT/'Sources/DouyinDiscNavigation.m').read_text(encoding='utf-8')
        store=(ROOT/'Sources/DouyinDiscNavigationStore.m').read_text(encoding='utf-8')
        host=(ROOT/'tests/ui/DouyinDiscNavigationCases.h').read_text(encoding='utf-8')
        self.assertIn('douyindisc_uiTestSetNavigationImage(@"bottom_home",testIcon,YES)',host)
        self.assertIn('overlay.frame=[l convertRect:icon toView:host]',hooks)
        self.assertIn('originalAlpha=l.alpha',hooks)
        self.assertIn('if(l.alpha!=0)l.alpha=0',hooks)
        self.assertIn('douyindisc_uiTestPickerTitleStable',host)
        self.assertIn('[row douyindisc_setHasImage:YES]',panel)
        self.assertIn('[self.douyindisc_imageButton setImage:nil forState:UIControlStateNormal]',panel)
        self.assertIn('douyindisc_decodeImageData:data',panel)
        self.assertIn('NSFileCoordinator',panel)
        self.assertIn('!hasSize||!size||!size.unsignedLongLongValue',panel)
        self.assertIn('douyindisc_uiTestPickerTitleStable',host)
        self.assertIn('original label visibility and glyph pixels',host)
        self.assertIn('CGImageSourceCreateWithData',store)

    def test_static_policy_on_generated_project(self):
        meta = json.loads((ROOT / 'tweak.json').read_text(encoding='utf-8'))
        self.assertEqual(check_project(ROOT, meta), [])

    def test_mutations_fail_static_policy(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / 'project'
            shutil.copytree(ROOT, root, ignore=shutil.ignore_patterns('.git', 'artifacts', 'reports', '__pycache__'))
            meta = json.loads((root / 'tweak.json').read_text(encoding='utf-8'))
            for relative, edit, message in (
                (SOURCE, lambda src: '/*' + src + '*/', 'contains comments'),
                (SOURCE, lambda src: src.replace('return;', ''), 'hard-guarded'),
                (SOURCE, lambda src: src.replace('isEqualToString:@"399017"', 'isEqualToString:@"999999"'), 'documented target build'),
                (SOURCE, lambda src: src.replace('douyindisc_entry', 'other_entry'), 'hard-guarded'),
                (SOURCE, lambda src: src.replace('@"com.ss.iphone.ugc.Aweme"', '@"com.example.other"'), 'hard-guarded'),
                (SOURCE, lambda src: '#import <substrate.h>\n' + src, 'jailbreak header'),
                (Path('scripts/build_dylib.py'), lambda src: src.replace('arm64-apple-ios', 'arm64e-apple-ios'), 'TARGET differs'),
                (Path('scripts/build_dylib.py'), lambda src: src.replace("*SOURCE_FILES, '-o'", "*SOURCE_FILES, '-lsubstrate', '-o'"), 'Apple-only'),
                (Path('scripts/build_dylib.py'), lambda src: src.replace("'PhotosUI'", "'Substrate'"), 'framework list'),
                (Path('build.sh'), lambda src: src.replace('\npython3 scripts/toolchain.py', '\n# python3 scripts/toolchain.py'), 'verify before'),
            ):
                with self.subTest(file=relative, message=message):
                    path = root / relative
                    original = path.read_text(encoding='utf-8')
                    path.write_text(edit(original), encoding='utf-8')
                    self.assertTrue(any(message in error for error in check_project(root, meta)))
                    path.write_text(original, encoding='utf-8')
            if meta['github_actions']:
                flow = root / '.github/workflows/build.yml'
                flow.write_text(flow.read_text(encoding='utf-8') + '\n    permissions:\n      contents: write\n', encoding='utf-8')
                self.assertTrue(any('not create releases' in error for error in check_project(root, meta)))

    @unittest.skipUnless(shutil.which('sh') and shutil.which('python3'), 'POSIX wrapper needs sh and python3')
    def test_verified_compile_order_and_fail_closed_publication(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shutil.copyfile(ROOT / 'build.sh', root / 'build.sh')
            (root / 'scripts').mkdir()
            build = (ROOT / 'scripts/build_dylib.py').read_text(encoding='utf-8')
            (root / 'scripts/build_dylib.py').write_text(build.replace('/usr/bin/xcrun', './mock-clang')
                                                          .replace('/usr/bin/codesign', './mock-codesign'), encoding='utf-8')
            for name, text in {
                'mock-clang': '''#!/bin/sh
set -eu
printf '%s\\n' clang >> order
printf '%s\\n' "$@" > compile.args
[ "$FAIL_STAGE" != clang ] || exit 41
for out do :; done
cp fixture.bin "$out"
''',
                'mock-codesign': '''#!/bin/sh
set -eu
stage=sign
[ "$1" != --verify ] || stage=native-verify
printf '%s\\n' "$stage" >> order
[ "$FAIL_STAGE" != "$stage" ]
''',
            }.items():
                path = root / name
                path.write_text(text, encoding='utf-8')
                path.chmod(0o755)
            (root / 'scripts/toolchain.py').write_text(
                'import os, sys\nfrom pathlib import Path\n'
                'assert sys.argv[1:] == ["verify", "--output", "reports/local-toolchain.json"]\n'
                'with Path("order").open("a") as f: f.write("verify\\n")\n'
                'sys.exit(42 if os.environ["FAIL_STAGE"] == "verify" else 0)\n', encoding='utf-8')
            (root / 'tests').mkdir()
            shutil.copyfile(ROOT / 'tests/verify_dylib.py', root / 'tests/verify_dylib.py')
            shutil.copyfile(ROOT / 'tweak.json', root / 'tweak.json')
            theos = root / 'test SDK tree'
            sdk = theos / 'sdks/iPhoneOS16.5.sdk'
            sdk.mkdir(parents=True)
            artifact = root / 'artifacts/DouyinDisc.dylib'
            artifact.parent.mkdir()
            verified = ['verify', 'verify']
            signed = verified + ['clang', 'sign', 'native-verify']
            for phase, order in (('verify', ['verify']), ('clang', verified + ['clang']),
                                 ('sign', verified + ['clang', 'sign']),
                                 ('native-verify', signed), ('offline', signed), ('', signed)):
                with self.subTest(phase=phase):
                    (root / 'order').unlink(missing_ok=True)
                    artifact.write_bytes(b'stale')
                    (root / 'fixture.bin').write_bytes(b'not Mach-O' if phase == 'offline' else specimen())
                    env = dict(os.environ, THEOS=str(theos), FAIL_STAGE=phase, PYTHONDONTWRITEBYTECODE='1')
                    proc = subprocess.run(['sh', str(root / 'build.sh')], cwd=root.parent, env=env,
                                          capture_output=True, text=True)
                    self.assertEqual(proc.returncode == 0, phase == '', proc.stderr)
                    self.assertEqual((root / 'order').read_text().splitlines(), order)
                    self.assertEqual(artifact.is_file(), phase == '')
                    self.assertFalse(list(artifact.parent.glob('.build.*')))
                    if phase == 'offline':
                        self.assertIn('truncated Mach-O header', proc.stderr)
            expected_frameworks = [value for framework in ('Foundation','UIKit','QuartzCore','CoreGraphics','ImageIO','PhotosUI','UniformTypeIdentifiers') for value in ('-framework',framework)]
            expected_sources = [str(SOURCE), 'Sources/DouyinDiscPolicy.c', 'Sources/DouyinDiscNativeDisplay.m',
                                'Sources/DouyinDiscNavigationStore.m', 'Sources/DouyinDiscNavigation.m',
                                'Sources/DouyinDiscNavigationHooks.m']
            self.assertEqual((root / 'compile.args').read_text().splitlines()[:-1],
                             ['--sdk', 'iphoneos', 'clang', '-target', 'arm64-apple-ios15.0',
                              '-isysroot', str(sdk), '-dynamiclib', '-fobjc-arc', '-fvisibility=hidden',
                              '-Wall', '-Wextra', '-install_name', '@loader_path/DouyinDisc.dylib',
                              *expected_frameworks, *expected_sources, '-o'])
            self.assertEqual(verify_dylib(artifact, project=root)['architecture'], 'arm64')
