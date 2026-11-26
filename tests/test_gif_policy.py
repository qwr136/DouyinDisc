"""Animated GIF limits, paired storage, and retained photo-only import contracts."""
from pathlib import Path
import re
import unittest
ROOT=Path(__file__).resolve().parent.parent
class GIFPolicyTests(unittest.TestCase):
    def test_gif_resource_limits_and_static_fallback_are_bounded(self):
        store=(ROOT/'Sources/DouyinDiscNavigationStore.m').read_text()
        for token in ('douyindisc_gifByteLimit = 64 * 1024 * 1024','douyindisc_gifFrameLimit = 1024','douyindisc_gifCanvasLimit = 4096','douyindisc_gifDecodeEdge = 96','douyindisc_gifDurationLimit = 60.0','decodedAnimationBytes','douyindisc_gifDecodedByteLimit = 64 * 1024 * 1024'):
            self.assertIn(token,store)
        self.assertIn('CGImageSourceCreateThumbnailAtIndex(source, 0',store)
        self.assertIn('douyindisc_gifNameForImageName',store)
        self.assertIn('newGIFURL',store)
        self.assertIn('[self.douyindisc_animations removeObjectForKey:identifier]',store)
        self.assertIn('else [self.douyindisc_animations removeObjectForKey:key]',store)
        # Persistent per-item image references remain the old UUID PNG; GIF is an optional sidecar.
        self.assertIn('douyindisc_validImageName(entry[@"image"])',store)
        self.assertIn('stringByAppendingPathExtension:@"gif"',store)
    def test_animation_runs_only_while_visible_and_accessible(self):
        hooks=(ROOT/'Sources/DouyinDiscNavigationHooks.m').read_text()
        for token in ('CAKeyframeAnimation','kCAAnimationDiscrete','douyindisc_gifLeaseVisible','UIAccessibilityIsReduceMotionEnabled()','UIApplicationWillResignActiveNotification','UIApplicationDidBecomeActiveNotification','CGRectIntersection','animationForKey:'):
            self.assertIn(token,hooks)
        self.assertIn('removeAnimationForKey:@"com.minis.douyindisc.animated-gif"',hooks)
    def test_discrete_key_times_have_terminal_boundary(self):
        hooks=(ROOT/'Sources/DouyinDiscNavigationHooks.m').read_text()
        display=(ROOT/'Sources/DouyinDiscNativeDisplay.m').read_text()
        self.assertIn('NSMutableArray *times=[lease.douyindisc_animation.keyTimes mutableCopy];[times addObject:@1.0];',hooks)
        self.assertIn('animation.values=values;animation.keyTimes=times;',hooks)
        self.assertIn('NSMutableArray *times=[customAnimation.keyTimes mutableCopy];[times addObject:@1.0];',display)
        self.assertIn('gif.values=frames;gif.keyTimes=times;',display)
        self.assertNotIn('[values addObject:values.lastObject]',hooks)
        self.assertNotIn('[frames addObject:frames.lastObject]',display)

    def test_photo_picker_uses_original_gif_resource_but_no_files_picker(self):
        panel=(ROOT/'Sources/DouyinDiscNavigation.m').read_text()
        self.assertIn('UIImagePickerControllerDelegate',panel)
        self.assertIn('UIImagePickerControllerPHAsset',panel)
        self.assertIn('requestDataForAssetResource:resource',panel)
        self.assertIn('cancelDataRequest:current',panel)
        self.assertIn('chunk.length>64*1024*1024-buffer.length',panel)
        self.assertNotIn('UIDocumentPicker',panel)
        self.assertNotIn('UniformTypeIdentifiers',panel)
        self.assertNotIn('NSFileCoordinator',panel)
        panel=(ROOT/'Sources/DouyinDiscNavigation.m').read_text()
        start=panel.index('- (void)douyindisc_importGIFResource:(PHAssetResource *)resource identifier:(NSString *)identifier pickingGeneration:(NSUInteger)generation {')
        resource=panel[start:].split('- (void)douyindisc_startPickerMonitor:',1)[0]
        self.assertIn('[self douyindisc_commitImageData:data identifier:identifier pickingGeneration:generation]',resource)
        self.assertNotIn('douyindisc_saveImageData:',resource)
        self.assertIn('douyindisc_uiTestImageCommitFinished',panel)
        self.assertIn('douyindisc_uiTestCommitImageAndCheckPanelPreview',panel)
        self.assertIn('douyindisc_gifCases(self.window', (ROOT/'tests/ui/DouyinDiscNativeHost.m').read_text())
