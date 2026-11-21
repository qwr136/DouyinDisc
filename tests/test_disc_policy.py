"""Exercise the actual production C policy; no mocked reimplementation."""
import ctypes
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent

class Rect(ctypes.Structure):
    _fields_ = [(k, ctypes.c_double) for k in ('x', 'y', 'w', 'h')]

class PolicyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        compiler = shutil.which('cc') or shutil.which('clang')
        if not compiler:
            raise AssertionError('native C compiler required for selection regression')
        cls.work = tempfile.TemporaryDirectory()
        out = Path(cls.work.name) / 'policy.so'
        subprocess.run([compiler, '-shared', '-fPIC', '-Wall', '-Wextra', '-Werror',
                        str(ROOT / 'Sources/DouyinDiscPolicy.c'), '-lm', '-o', str(out)], check=True)
        cls.lib = ctypes.CDLL(str(out))
        for name, args in [('version_supported', [ctypes.c_char_p]), ('disc_inside_rail', [Rect, Rect]),
                           ('share_above', [Rect, Rect, Rect]), ('cover_fits', [Rect, Rect])]:
            fn = getattr(cls.lib, 'douyindisc_' + name)
            fn.argtypes, fn.restype = args, ctypes.c_bool
        cls.window, cls.disc, cls.share = Rect(0, 0, 390, 844), Rect(340, 728, 42, 42), Rect(339, 661, 44, 44)

    @classmethod
    def tearDownClass(cls):
        cls.work.cleanup()

    def test_exact_supported_versions(self):
        fn = self.lib.douyindisc_version_supported
        for version in (b'39.90', b'39.9.0'):
            self.assertTrue(fn(version))
        for version in (None, b'', b'39.9', b'39.90.1', b'39.9.0beta', b'41.2.0'):
            self.assertFalse(fn(version))

    def test_disc_geometry(self):
        self.assertTrue(self.lib.douyindisc_disc_inside_rail(self.disc, self.window))
        for bad in [Rect(340, 150, 42, 42), Rect(150, 728, 42, 42), Rect(340, 728, 10, 10),
                    Rect(340, 728, 90, 90), Rect(340, 728, 42, 12), Rect(math.nan, 728, 42, 42),
                    Rect(math.inf, 728, 42, 42), Rect(380, 728, 42, 42)]:
            self.assertFalse(self.lib.douyindisc_disc_inside_rail(bad, self.window))

    def test_only_share_above_same_rail(self):
        self.assertTrue(self.lib.douyindisc_share_above(self.disc, self.share, self.window))
        for bad in [Rect(339, 790, 44, 44), Rect(240, 661, 44, 44), Rect(339, 400, 44, 44),
                    Rect(339, 710, 44, 44), Rect(0, 0, 390, 844)]:
            self.assertFalse(self.lib.douyindisc_share_above(self.disc, bad, self.window))

    def test_only_centered_cover(self):
        disc = Rect(0, 0, 42, 42)
        self.assertTrue(self.lib.douyindisc_cover_fits(Rect(0, 0, 42, 42), disc))
        self.assertTrue(self.lib.douyindisc_cover_fits(Rect(4, 4, 34, 34), disc))
        for bad in [Rect(0, 0, 12, 12), Rect(20, 20, 42, 42), Rect(0, 0, 80, 80), Rect(0, 0, -42, 42)]:
            self.assertFalse(self.lib.douyindisc_cover_fits(bad, disc))

    def test_original_artwork_bytes(self):
        data = (ROOT / 'Sources/DouyinDiscArtwork.inc').read_text()
        image = bytes(int(n, 16) for n in re.findall(r'0x([0-9a-f]{2})', data))
        self.assertEqual(len(image), 11639)
        self.assertEqual(hashlib.sha256(image).hexdigest(), 'c5aac6bff1e679c638af93d240535678a87d07aed2d912327483284fe30bd4ee')

    def test_no_private_dispatch_or_input_changes(self):
        code = (ROOT / 'Sources/DouyinDiscNativeDisplay.m').read_text() + (ROOT / 'Sources/DouyinDiscNative.h').read_text()
        for forbidden in ['objc_msgSend', 'method_exchangeImplementations', 'method_setImplementation',
                          'addGestureRecognizer:', 'sendActionsForControlEvents:', 'NSURLSession', 'writeToFile:',
                          'setHidden:', 'removeAllAnimations', 'setImage:']:
            self.assertNotIn(forbidden, code)
        self.assertNotIn('target.contents =', code)
        self.assertIn('object_getIvar', code)
        self.assertIn('ivar_getTypeEncoding', code)
        self.assertIn('UIAccessibilityIsReduceMotionEnabled()', code)
        self.assertIn('UIApplicationWillResignActiveNotification', code)

    def test_lifecycle_retains_without_background_work(self):
        code = (ROOT / 'Sources/DouyinDiscNativeDisplay.m').read_text()
        resigned = re.search(r'- \(void\)douyindisc_resignedActive:[^\n]+\n(.*?)\n}', code, re.S).group(1)
        self.assertIn('[self.douyindisc_timer invalidate]', resigned)
        self.assertNotIn('douyindisc_restore', resigned)
        self.assertIn('if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;', code)
        self.assertIn('forMode:NSRunLoopCommonModes', code)
        self.assertIn('self.douyindisc_controls.allObjects', code)
        self.assertIn('spin.beginTime = [overlay convertTime:self.douyindisc_epoch fromLayer:nil]', code)

    def test_core_behavior_is_frozen_against_010(self):
        fixture = json.loads((ROOT / 'tests/fixtures/visual-retain-baseline.json').read_text())
        self.assertEqual(fixture['source_sha'], '5c58edd54554c95c92a02b238b139242538906da')
        for relative, expected in fixture['files'].items():
            with self.subTest(file=relative):
                content = (ROOT / relative).read_bytes()
                if relative == 'scripts/build_dylib.py':
                    content = content.replace(b'DouyinDiscNativeDisplay.m', b'DouyinDiscDisplay.m')
                self.assertEqual(hashlib.sha256(content).hexdigest(), expected)
