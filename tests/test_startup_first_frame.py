"""Cold-start ordering and bounded PNG preparation contracts; UIKit tests execute the real Store."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent

class StartupFirstFrameTests(unittest.TestCase):
    def test_cached_first_frame_precedes_both_renderers(self):
        entry = (ROOT/'Sources/DouyinDiscEntry.m').read_text()
        start = entry.split('dispatch_async(dispatch_get_main_queue(), ^{', 1)[1]
        prepare = '[[DouyinDiscNavigationStore douyindisc_sharedStore] douyindisc_prepareStartupImages];'
        self.assertEqual(entry.count(prepare), 1)
        self.assertLess(start.index(prepare), start.index('douyindisc_startDisplay();'))
        self.assertLess(start.index(prepare), start.index('douyindisc_installNavigationHooks();'))
        self.assertLess(start.index('douyindisc_installNavigationHooks();'), start.index('douyindisc_preloadImagesWithCompletion:nil'))
        self.assertNotIn('dispatch_sync', entry)

    def test_startup_only_reads_bounded_static_cache_and_never_writes_settings(self):
        store = (ROOT/'Sources/DouyinDiscNavigationStore.m').read_text()
        prepare = store.split('- (void)douyindisc_prepareStartupImages {', 1)[1].split('- (void)douyindisc_preloadImagesWithCompletion:', 1)[0]
        for token in ('NSThread.isMainThread', 'self.douyindisc_loadFailed',
                      'douyindisc_itemTable()', '@autoreleasepool',
                      'douyindisc_imagePickingEnabledForIdentifier:key', 'douyindisc_validImageName(name)',
                      'NSURLIsRegularFileKey', 'NSURLFileSizeKey', 'size.unsignedLongLongValue>6*1024*1024',
                      'readDataOfLength:6*1024*1024+1', '[file closeFile]',
                      'CGImageSourceGetCount(source)==1', 'kCGImageStatusComplete',
                      'width>512 || height>512', 'douyindisc_decodeImage(data,YES,nil)',
                      'self.douyindisc_images[key]=image'):
            self.assertIn(token, prepare)
        for token in ('douyindisc_decodeGIF(', 'douyindisc_gifNameForImageName(',
                      'dispatch_async', 'postNotificationName:', 'writeTo',
                      'douyindisc_commitLatestConfig:', 'removeObjectForKey:'):
            self.assertNotIn(token, prepare)
        self.assertIn('douyindisc_imageGeneration[key]', store)
        self.assertIn('self.douyindisc_preloadGeneration == preloadGeneration', store)

    def test_cold_store_and_first_layout_cases_are_wired_into_host(self):
        host = (ROOT/'tests/ui/DouyinDiscNativeHost.m').read_text()
        cases = (ROOT/'tests/ui/DouyinDiscStartupCases.h').read_text()
        self.assertIn('#include "DouyinDiscStartupCases.h"', host)
        self.assertIn('douyindisc_startupCases(self.window);', host)
        self.assertIn('fileHandleForReadingFromURL:error:', cases)
        for token in ('real cold Store reads legacy config with zero seeded caches',
                      'prepare makes navigation and default-enabled video-disc PNGs available in the same turn',
                      'does not read or decode the GIF sidecar',
                      'first navigation layout rasterizes the prepared PNG',
                      'first disc layout rasterizes custom pixels',
                      'original navigation, music and share hit targets',
                      'startup finally restores shared configuration'):
            self.assertIn(token, cases)
        self.assertIn('douyindisc_gifCases(self.window', host)
        self.assertIn('douyindisc_uiTestNumericInput(self.window)', host)
        self.assertIn('all 256 control centers hit', host)

if __name__ == '__main__': unittest.main()
