"""Local trace policy and exact 0.60 visual baseline; UIKit executes the writer."""
from pathlib import Path
import hashlib
import json
import unittest

ROOT=Path(__file__).resolve().parent.parent
ADDITIONS=[
    '\n@class DouyinDiscSurface, DouyinDiscDisplay;\nstatic BOOL douyindisc_diag_enabled;\nstatic void douyindisc_diag_note(UIControl *control, DouyinDiscSurface *surface, const char *phase);\nstatic void douyindisc_diag_install(DouyinDiscDisplay *driver);',
    '    if (douyindisc_diag_enabled) douyindisc_diag_note(control, surface, "refresh-before");\n',
    '    if (douyindisc_diag_enabled) douyindisc_diag_note(control, surface, "refresh-after");\n',
    '#include "DouyinDiscDiagnostics.inc"\n\n',
    '    douyindisc_diag_install(driver);\n',
]

class DiagnosticPolicyTests(unittest.TestCase):
    def test_060_visual_behavior_is_frozen_except_explicit_diagnostic_edges(self):
        fixture=json.loads((ROOT/'tests/fixtures/diagnostic-060-baseline.json').read_text())
        self.assertEqual(fixture['source_sha'],'3cb7eea82a8df663d56d9353957968daa2a0647d')
        for relative,expected in fixture['files'].items():
            content=(ROOT/relative).read_bytes()
            if relative=='Sources/DouyinDiscNativeDisplay.m':
                text=content.decode()
                self.assertEqual(text.count('    overlay.opacity = 0.5f;\n'),1)
                text=text.replace('    overlay.opacity = 0.5f;\n','')
                removed='    // Temporary diagnostic entry removed after the user\'s capture; no new log UI.\n'
                self.assertEqual(text.count(removed),1)
                text=text.replace(removed,'    douyindisc_diag_install(driver);\n')
                for addition in ADDITIONS:
                    self.assertEqual(text.count(addition),1)
                    text=text.replace(addition,'')
                content=text.encode()
            if relative=='Sources/DouyinDiscNative.h':
                text=content.decode()
                start=text.index('// 0.80 device trace: StyleOne host view18')
                stop=text.index('static NSArray<UIView *> *douyindisc_nativeVisuals(',start)
                text=text[:start]+text[stop:]
                addition='    [views addObjectsFromArray:douyindisc_nativeStyleOneVisuals(control)];\n'
                self.assertEqual(text.count(addition),1)
                content=text.replace(addition,'').encode()
            with self.subTest(file=relative):
                self.assertEqual(hashlib.sha256(content).hexdigest(),expected)

    def test_bounded_opt_in_trace_contract(self):
        code=(ROOT/'Sources/DouyinDiscDiagnostics.inc').read_text()
        source=(ROOT/'Sources/DouyinDiscNativeDisplay.m').read_text()
        for token in ['douyindisc_diag_eventLimit = 1024','douyindisc_diag_byteLimit = 256 * 1024',
                      'self.douyindisc_started+20','if (!douyindisc_diag_enabled) return;',
                      'O_NOFOLLOW','0600','count>=3','recorded<24','count<64',
                      'NSMapTable weakToStrongObjectsMapTable','NSHashTable weakObjectsHashTable',
                      '@"capture-end"','@"douyindisc-visual-v1"','@"dylibUUID"']:
            self.assertIn(token,code)
        self.assertIn('static BOOL douyindisc_diag_enabled;',source)
        self.assertNotIn('static BOOL douyindisc_diag_enabled = YES',source)
        self.assertEqual(source.count('if (douyindisc_diag_enabled) douyindisc_diag_note'),2)
        for redline in ['NSURLSession','NSURLConnection','UIImagePNGRepresentation','UIGraphicsImageRenderer',
                        'renderInContext:', 'drawViewHierarchy', 'NSLog(', 'accessibilityIdentifier',
                        'valueForKey:', 'stringWithFormat:@"%p', 'view.description']:
            self.assertNotIn(redline,code)

    def test_caption_allowlist_stays_exact_and_local(self):
        caption=(ROOT/'Sources/DouyinDiscLocalCaption.inc').read_text()
        self.assertIn('[text isEqualToString:@"拍同款"] || [text isEqualToString:@"玩同款"]',caption)
        self.assertNotIn('containsString:',caption)
        self.assertIn('visited > 96',caption)
        self.assertIn('r.w <= disc.w*2.2',caption)

    def test_capture_ids_are_weak_identity_and_monotonic(self):
        code=(ROOT/'Sources/DouyinDiscDiagnostics.inc').read_text()
        self.assertIn('NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality',code)
        self.assertIn('number=@(++self.douyindisc_nextID)',code)
        self.assertIn('self.douyindisc_nextID<2048',code)
        self.assertNotIn('NSValue valueWithPointer:',code)
        self.assertNotIn('douyindisc_id:layer.contents',code)

    def test_device_trace_proves_style_plate_is_outside_button_mask(self):
        fixture=json.loads((ROOT/'tests/fixtures/device-style-one-080.json').read_text())
        self.assertEqual(fixture['app_build'],'399017')
        views={r['id']:r for r in fixture['views']}
        layers={r['id']:r for r in fixture['layers']}
        self.assertEqual(views[18]['class'],'AWEPlayInteractionStyleOneMusicView')
        self.assertEqual(views[22]['parent'],views[26]['parent'])
        self.assertEqual(views[24]['parent'],22)
        self.assertEqual(layers[23]['parent'],21)
        self.assertEqual(layers[23]['background'],[0,0,0,0.6])
        self.assertEqual(layers[23]['mask'],0)
        self.assertGreater(layers[25]['mask'],0)
        self.assertEqual(layers[21]['cornerRadius'],22)
        self.assertEqual(layers[52]['opacity'],1)

    def test_precise_style_scope_opacity_and_diagnostic_entry_removed(self):
        native=(ROOT/'Sources/DouyinDiscNative.h').read_text()
        block=native.split('static NSArray<UIView *> *douyindisc_nativeStyleOneVisuals(',1)[1].split('static NSArray<UIView *> *douyindisc_nativeVisuals(',1)[0]
        for token in ['AWEPlayInteractionStyleOneMusicView','_musicButton','_playInteractionCircleMaskView',
                      '_playInteractionMaskView','container.superview != host','view.superview != container','view.userInteractionEnabled']:
            self.assertIn(token,block)
        self.assertNotIn('setHidden:',block)
        source=(ROOT/'Sources/DouyinDiscNativeDisplay.m').read_text()
        self.assertEqual(source.count('overlay.opacity = 0.5f;'),1)
        entry=source.split('void douyindisc_startDisplay(void) {',1)[1]
        self.assertNotIn('douyindisc_diag_install(driver)',entry)
        self.assertNotIn('control.alpha =',source)
