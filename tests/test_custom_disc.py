"""Regression contracts for the independently configurable video music disc."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent

class VideoDiscContractTests(unittest.TestCase):
    def test_dedicated_setting_is_last_and_does_not_map_to_a_nav_tab(self):
        store = (ROOT / "Sources/DouyinDiscNavigationStore.m").read_text()
        hooks = (ROOT / "Sources/DouyinDiscNavigationHooks.m").read_text()
        self.assertIn('@[@"video_disc", @"视频唱片", @"opticaldisc"', store)
        self.assertIn('@"adjustmentTitle":[identifier isEqualToString:@"video_disc"]?@"转速"', store)
        self.assertIn('@"视频页唱片"', (ROOT / "Sources/DouyinDiscNavigation.m").read_text())
        self.assertIn('BOOL needsHeader = self.douyindisc_stack.arrangedSubviews.count == 1 || [identifier isEqual:@"bottom_home"] || [identifier isEqual:@"video_disc"]', (ROOT / "Sources/DouyinDiscNavigation.m").read_text())
        self.assertIn('static NSString *douyindisc_bottomIdentifier', hooks)
        self.assertNotIn('@"视频唱片":@"video_disc"', hooks)

    def test_store_has_separate_bounded_speed_and_default_enabled_state(self):
        store = (ROOT / "Sources/DouyinDiscNavigationStore.m").read_text()
        self.assertIn('@"speed"', store)
        self.assertIn('speed < .25 || speed > 3', store)
        self.assertIn('NSNumber *enabled=stored[@"enabled"] ?: @(videoDisc);', store)
        self.assertIn('return enabled?[enabled boolValue]:[identifier isEqualToString:@"video_disc"];', store)
        self.assertIn('entry[@"speed"]=@(scale);else entry[@"scale"]=@(scale);', store)

    def test_display_uses_circle_crop_opacity_and_rotation_multiplier(self):
        display = (ROOT / "Sources/DouyinDiscNativeDisplay.m").read_text()
        self.assertIn('douyindisc_imageForIdentifier:@"video_disc"', display)
        self.assertIn('overlay.contentsGravity=customImage?kCAGravityResizeAspectFill:kCAGravityResizeAspect;', display)
        self.assertIn('overlay.cornerRadius=customImage?MIN(overlay.bounds.size.width,overlay.bounds.size.height)*.5:0;', display)
        self.assertIn('group.opacity=customOpacity;', display)
        self.assertIn('overlay.opacity = customImage?1.0f:0.5f;', display)
        self.assertIn('spin.duration=7.0/spinSpeed', display)
        self.assertIn('animationWithKeyPath:@"contents"', display)
        self.assertIn('customImage&&customAnimation&&douyindisc_onScreen(control)', display)
        self.assertIn('douyindisc_discGIFKey', display)
        self.assertNotIn('control.userInteractionEnabled=', display)
        self.assertNotIn('addGestureRecognizer:', display)

    def test_ui_host_covers_switch_opacity_speed_and_original_action(self):
        host = (ROOT / "tests/ui/DouyinDiscNativeHost.m").read_text()
        cases = (ROOT / "tests/ui/DouyinDiscCustomDiscCases.h").read_text()
        self.assertIn('douyindisc_customDiscCases(driver,first)', host)
        self.assertIn('self.douyindisc_clicks==clicksBeforeDiscTest+1', host)
        for contract in ('video-page disc displays the user-selected icon',
                         'clipped to a circular icon',
                         'rasterized composite alpha matches',
                         'custom GIF includes terminal-frame hold',
                         'new feed controls join the same adjusted rotation phase',
                         'switch-off restores original pixels'):
            self.assertIn(contract, cases)

if __name__ == "__main__":
    unittest.main()
