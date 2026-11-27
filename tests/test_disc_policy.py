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
        for version in (b'39.90', b'39.9.0', b'39.91', b'39.10.0', b'40.00', b'40.12',
                        b'40.12.34', b'41.09', b'41.1.999', b'41.20', b'41.2.0'):
            self.assertTrue(fn(version), version)
        for version in (None, b'', b'39.9', b'39.89', b'39.8.99', b'41.21', b'41.2.1',
                        b'41.10.0', b'42.00', b'40..0', b'40.0.', b'40.00.0', b'40.1.0.0',
                        b'40.1.0beta', b' 40.10', b'40.10\n', b'+40.10', b'40.1.-1',
                        b'40.1.999999999999999999999', '４０.10'.encode()):
            self.assertFalse(fn(version), version)

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
        for name,size,sha in [('DouyinDiscBaseArtwork.inc',12039,'7a3a553ff33ba714611b1c8ac69343a714d1a9c802b967dd9d84c0cb81c89da5'),('DouyinDiscAccentArcs.inc',6161,'0aebb35205323f4851bc4abd66286200d37a29628138b65653a0b8670b196a74')]:
            payload=bytes(int(n,16) for n in re.findall(r'0x([0-9a-f]{2})',(ROOT/'Sources'/name).read_text()))
            self.assertEqual(len(payload),size); self.assertEqual(hashlib.sha256(payload).hexdigest(),sha)
        display=(ROOT/'Sources/DouyinDiscNativeDisplay.m').read_text()
        self.assertIn('douyindisc_loadArtwork()', display); self.assertIn('douyindisc_loadAccentArcs()', display)
        self.assertIn('douyindisc_base_artwork length:sizeof(douyindisc_base_artwork)', display)


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
        self.assertNotIn('removeAnimationForKey:', resigned)
        self.assertIn('self.douyindisc_refreshSuspended=YES', resigned)
        self.assertIn('BOOL globalSpeedChanged=fabs(self.douyindisc_spinSpeed-spinSpeed)>.001', code)
        self.assertIn('self.douyindisc_epoch=now-phase*(7.0/spinSpeed)', code)
        self.assertIn('spin.beginTime=[overlay convertTime:self.douyindisc_epoch fromLayer:nil]', code)
        self.assertIn('copy.beginTime=[layer convertTime:self.douyindisc_epoch fromLayer:nil]', code)
        self.assertIn('spin.duration=7.0/spinSpeed', code)
        self.assertIn('surface.douyindisc_customImage=customImage', code)
        self.assertIn('douyindisc_navigationChanged:', code)

    def test_core_behavior_is_frozen_against_010(self):
        fixture = json.loads((ROOT / 'tests/fixtures/visual-retain-baseline.json').read_text())
        self.assertEqual(fixture['source_sha'], '5c58edd54554c95c92a02b238b139242538906da')
        for relative, expected in fixture['files'].items():
            with self.subTest(file=relative):
                content = (ROOT / relative).read_bytes()
                if relative == 'Sources/DouyinDiscEntry.m':
                    # Startup PNG preparation is separately behavior-tested; retain
                    # the original host guard and installation scheduling here.
                    content = content.replace(b'        [[DouyinDiscNavigationStore douyindisc_sharedStore] douyindisc_prepareStartupImages];\n', b'')
                    content = content.replace(b'#import "DouyinDiscNavigation.h"\n', b'')
                    content = content.replace(b'#import "DouyinDiscHostVersion.h"', b'#include "DouyinDiscPolicy.h"')
                    content = content.replace(b'    if (!douyindisc_hostVersionAllowed()) return;',
                                              b'    id value = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];\n    if (![value isKindOfClass:NSString.class] || !douyindisc_version_supported([(NSString *)value UTF8String])) return;')
                    content = content.replace(b'''    dispatch_async(dispatch_get_main_queue(), ^{
        douyindisc_startDisplay();
        douyindisc_installNavigationHooks();
        [[DouyinDiscNavigationStore douyindisc_sharedStore] douyindisc_preloadImagesWithCompletion:nil];
    });
''', b'    dispatch_async(dispatch_get_main_queue(), ^{ douyindisc_startDisplay(); });\n')
                if relative == 'Sources/DouyinDiscPolicy.c':
                    # Only the version predicate changed. Pin both unchanged geometry regions.
                    geometry = content.split(b'bool douyindisc_disc_inside_rail', 1)[1]
                    helpers = content.split(b'static bool douyindisc_valid', 1)[1].split(b'// Parse canonical', 1)[0]
                    self.assertEqual(hashlib.sha256(helpers + geometry).hexdigest(), '81f61877132c8cd8285d37d53b32f00eb5b840215d6b99d4165e432f0d673e3e')
                    continue
                if relative == 'scripts/build_dylib.py':
                    # Build-only size optimization must not be mistaken for a runtime behavior change.
                    content = content.replace(b"'-dynamiclib', '-fobjc-arc', '-Oz',", b"'-dynamiclib', '-fobjc-arc',")
                    content = content.replace(b'DouyinDiscNativeDisplay.m', b'DouyinDiscDisplay.m')
                    content = content.replace(b"FRAMEWORKS = ('Foundation', 'UIKit', 'QuartzCore', 'CoreGraphics', 'ImageIO', 'Photos')\n", b'')
                    content = content.replace(b", 'Sources/DouyinDiscNavigationStore.m', 'Sources/DouyinDiscNavigation.m', 'Sources/DouyinDiscNavigationHooks.m'", b'')
                    content = content.replace(b"            '-install_name', '@loader_path/' + output.name,\n            *[value for framework in FRAMEWORKS for value in ('-framework', framework)],\n            *SOURCE_FILES, '-o', str(staged))", b"            '-install_name', '@loader_path/' + output.name, '-framework', 'Foundation',\n            '-framework', 'UIKit', '-framework', 'QuartzCore', '-framework', 'CoreGraphics',\n            *SOURCE_FILES, '-o', str(staged))")
                if relative == 'tests/verify_dylib.py':
                    content = content.replace(b'"Metal", "VideoToolbox",\n                 "Photos")', b'"Metal", "VideoToolbox")')
                self.assertEqual(hashlib.sha256(content).hexdigest(), expected)

    def test_clarity_artwork_changes_only_alpha(self):
        import struct
        import zlib
        def decode(relative):
            text = (ROOT / relative).read_text()
            png = bytes(int(x, 16) for x in re.findall(r'0x([0-9a-f]{2})', text))
            width, height, depth, kind = struct.unpack('>IIBB', png[16:26])
            self.assertEqual((width, height, depth, kind), (512, 512, 8, 6))
            cursor, compressed = 8, b''
            while cursor < len(png):
                size = int.from_bytes(png[cursor:cursor+4], 'big')
                if png[cursor+4:cursor+8] == b'IDAT':
                    compressed += png[cursor+8:cursor+8+size]
                cursor += 12+size
            stream = zlib.decompress(compressed)
            pixels, previous = bytearray(), bytearray(width*4)
            for row in range(height):
                start = row*(1+width*4)
                mode, raw = stream[start], stream[start+1:start+1+width*4]
                current = bytearray(width*4)
                for i, value in enumerate(raw):
                    a = current[i-4] if i >= 4 else 0
                    b = previous[i]
                    c = previous[i-4] if i >= 4 else 0
                    if mode == 0: predictor = 0
                    elif mode == 1: predictor = a
                    elif mode == 2: predictor = b
                    elif mode == 3: predictor = (a+b)//2
                    else:
                        self.assertEqual(mode, 4)
                        p = a+b-c
                        ds = (abs(p-a), abs(p-b), abs(p-c))
                        predictor = a if ds[0] <= min(ds[1:]) else (b if ds[1] <= ds[2] else c)
                    current[i] = (value+predictor)&255
                pixels.extend(current)
                previous = current
            return png, pixels
        original, before = decode('Sources/DouyinDiscArtwork.inc')
        clear, outer = decode('Sources/DouyinDiscClearArtwork.inc')
        ring_png, ring=decode('Sources/DouyinDiscCenterRing.inc')
        self.assertEqual((len(clear),hashlib.sha256(clear).hexdigest()),(8327,'4e939abb82feb89df5d56d6405632448a4323f588b48f04ec5ca31b5ba4a9609'))
        self.assertEqual((len(ring_png),hashlib.sha256(ring_png).hexdigest()),(5109,'dc8f0d996252c57e666932a6d5d98b9cad08ee9f9739f98132e14e033a0a30b8'))
        self.assertEqual(len(before),len(outer)); self.assertEqual(len(before),len(ring))
        for i in range(0,len(before),4):
            source=before[i+3]; outer_alpha=outer[i+3]; ring_alpha=ring[i+3]
            self.assertLessEqual(outer_alpha,min(255,source*2))
            self.assertLessEqual(ring_alpha,min(255,source*2))
            self.assertLessEqual(outer_alpha+ring_alpha,255)
            if ring_alpha:
                self.assertEqual(tuple(ring[i:i+3]),tuple(before[i:i+3]))
            if outer_alpha:
                self.assertEqual(tuple(outer[i:i+3]),tuple(before[i:i+3]))
        base_png,base=decode('Sources/DouyinDiscBaseArtwork.inc')
        accent_png,accents=decode('Sources/DouyinDiscAccentArcs.inc')
        self.assertEqual(len(base_png),12039); self.assertEqual(len(accent_png),6161)
        self.assertEqual(len(before),len(base)); self.assertEqual(len(before),len(accents))
        self.assertEqual(sum(x>0 for x in base[3::4]),20283)
        self.assertEqual(sum(x>0 for x in accents[3::4]),9040)
        self.assertEqual(max(accents[3::4]),204)
        self.assertEqual(sum(base[i+3]!=outer[i+3] for i in range(0,len(outer),4)),9040)
        for i in range(0,len(before),4):
            ba,aa,oa=base[i+3],accents[i+3],outer[i+3]
            self.assertLessEqual(ba,oa); self.assertLessEqual(aa,204); self.assertLessEqual(ba+aa,oa)
            if aa: self.assertEqual(tuple(accents[i:i+3]),(255,255,255))
            if aa==0: self.assertEqual(ba,oa)
        self.assertEqual(sum(x>0 for x in ring[3::4]),9530)
        self.assertEqual(sum(x>0 for x in outer[3::4]),27723)

    def test_native_visual_mask_is_owned_and_hit_alpha_unchanged(self):
        code = (ROOT / 'Sources/DouyinDiscNativeDisplay.m').read_text()
        self.assertIn('view.layer.mask == self.douyindisc_zeroMask', code)
        self.assertIn('visual.douyindisc_preserveAlpha = view == control', code)
        self.assertIn('canvas.layer addSublayer:group', code)
        self.assertNotIn('control.alpha =', code)
        self.assertNotIn('control.hidden =', code)
        self.assertIn('UIImage *image = douyindisc_loadArtwork()', code)
        self.assertIn('#include "DouyinDiscAccentArcs.inc"', code)
        self.assertIn('douyindisc_accent_arcs length:sizeof(douyindisc_accent_arcs)',code)
        self.assertIn('group.opacity=customOpacity;',code)
        self.assertIn('arcs.opacity=1.0f',code)
        self.assertIn('copy.beginTime=[layer convertTime:self.douyindisc_epoch fromLayer:nil]',code)
        self.assertIn('CALayer *spinLayers[3]={overlay,arcs,ring}',code)
        self.assertIn('douyindisc_loadAccentArcs()',code)
        self.assertIn('ring.opacity=0.9f', code)
        self.assertIn('overlay.opacity = customImage?1.0f:0.5f;', code)
        self.assertIn('douyindisc_accentArcs removeFromSuperlayer', code)
        startup=code.split('void douyindisc_startDisplay(void) {',1)[1]
        self.assertNotIn('douyindisc_diag_install(driver);',startup)
        self.assertNotIn('douyindisc_diag_',code)
        self.assertIn('[driver douyindisc_start];',startup)
        caption = (ROOT / 'Sources/DouyinDiscLocalCaption.inc').read_text()
        self.assertIn('isEqualToString:@"拍同款"', caption)
        self.assertIn('visited > 96', caption)
        self.assertIn('r.w <= disc.w*2.2', caption)
