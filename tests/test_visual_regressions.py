"""Regression checks for the retained visual repair and its device evidence."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent


class VisualRegressionTests(unittest.TestCase):
    def test_runtime_diagnostic_capture_is_absent(self):
        production = '\\n'.join(path.read_text() for path in (ROOT / 'Sources').iterdir() if path.is_file())
        self.assertFalse((ROOT / 'Sources/DouyinDiscDiagnostics.inc').exists())
        for forbidden in ('douyindisc_diag_', 'DouyinDiscDiagnostics', 'visual-trace', '圆盘取证', '导出取证'):
            self.assertNotIn(forbidden, production)
        self.assertNotIn('UIActivityViewController', production)

    def test_caption_allowlist_stays_exact_and_local(self):
        caption = (ROOT / 'Sources/DouyinDiscLocalCaption.inc').read_text()
        self.assertIn('[text isEqualToString:@"拍同款"] || [text isEqualToString:@"玩同款"]', caption)
        self.assertNotIn('containsString:', caption)
        self.assertIn('visited > 96', caption)
        self.assertIn('r.w <= disc.w*2.2', caption)

    def test_style_one_device_evidence_matches_exact_visual_tree(self):
        fixture = json.loads((ROOT / 'tests/fixtures/device-style-one-080.json').read_text())
        self.assertEqual(fixture['app_build'], '399017')
        views = {item['id']: item for item in fixture['views']}
        layers = {item['id']: item for item in fixture['layers']}
        self.assertEqual(views[18]['class'], 'AWEPlayInteractionStyleOneMusicView')
        self.assertEqual(views[22]['parent'], views[26]['parent'])
        self.assertEqual(views[24]['parent'], 22)
        self.assertEqual(layers[23]['background'], [0, 0, 0, 0.6])
        self.assertEqual(layers[23]['mask'], 0)
        self.assertGreater(layers[25]['mask'], 0)

    def test_single_song_evidence_matches_exact_visual_tree(self):
        fixture = json.loads((ROOT / 'tests/fixtures/device-single-song-120.json').read_text())
        self.assertEqual(fixture['app_build'], '399017')
        self.assertTrue(fixture['example_ids_are_ephemeral'])
        self.assertEqual(fixture['host']['class'], 'AWEPlayInteractionSingleSongMusicStyleView')
        self.assertEqual(fixture['button']['parent'], 275)
        self.assertEqual(fixture['circle']['parent'], 275)
        self.assertEqual(fixture['plate']['parent'], 279)
        self.assertEqual(fixture['plate_layer']['background'], [0, 0, 0, .6])
        self.assertFalse(fixture['refresh_matched_plate'])

    def test_precise_native_visual_rules_and_opacity_remain(self):
        native = (ROOT / 'Sources/DouyinDiscNative.h').read_text()
        one = native.split('static NSArray<UIView *> *douyindisc_nativeStyleOneVisuals(', 1)[1].split(
            'static NSArray<UIView *> *douyindisc_nativeSingleSongVisuals(', 1)[0]
        single = native.split('static NSArray<UIView *> *douyindisc_nativeSingleSongVisuals(', 1)[1].split(
            'static NSArray<UIView *> *douyindisc_nativeVisuals(', 1)[0]
        self.assertIn('object_getClass(host)!=owner', single)
        self.assertIn('container.userInteractionEnabled', single)
        for block, name in ((one, 'AWEPlayInteractionStyleOneMusicView'),
                            (single, 'AWEPlayInteractionSingleSongMusicStyleView')):
            for token in (name, '_musicButton', '_playInteractionCircleMaskView',
                          '_playInteractionMaskView', 'view.userInteractionEnabled', 'return @[view]'):
                self.assertIn(token, block)
            self.assertNotIn('setHidden:', block)
        source = (ROOT / 'Sources/DouyinDiscNativeDisplay.m').read_text()
        self.assertEqual(source.count('overlay.opacity = 0.5f;'), 1)
        self.assertIn('ring.opacity=0.9f', source)
        self.assertIn('[ring addAnimation:centerSpin forKey:douyindisc_spinKey]', source)
        self.assertIn('UIAccessibilityIsReduceMotionEnabled()', source)
        self.assertNotIn('control.alpha =', source)


if __name__ == '__main__':
    unittest.main()
