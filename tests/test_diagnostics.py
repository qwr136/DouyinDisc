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
                for addition in ADDITIONS:
                    self.assertEqual(text.count(addition),1)
                    text=text.replace(addition,'')
                content=text.encode()
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
