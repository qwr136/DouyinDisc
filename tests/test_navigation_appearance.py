"""Per-navigation-icon static angle, continuous rotation, and corner radius."""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parent.parent

class NavigationAppearanceTests(unittest.TestCase):
    def test_only_thirteen_navigation_ids_accept_appearance_fields(self):
        store=(ROOT/"Sources/DouyinDiscNavigationStore.m").read_text()
        self.assertIn('!douyindisc_validIdentifier(identifier)||!douyindisc_isNavigationIconIdentifier(identifier)',store)
        self.assertIn('angle<0||angle>=360',store)
        self.assertIn('entry[@"angle"]&&(!douyindisc_isNavigationIconIdentifier(key)',store)
        self.assertIn('entry[@"cornerRadius"]&&(!douyindisc_isNavigationIconIdentifier(key)',store)
        self.assertIn('entry[@"rotationEnabled"]&&(!douyindisc_isNavigationIconIdentifier(key)',store)
        self.assertIn('entry[@"rotationSpeed"]&&(!douyindisc_isNavigationIconIdentifier(key)',store)
        self.assertIn('cornerRadius<0||cornerRadius>50',store)
        self.assertIn('rotationSpeed<.25||rotationSpeed>3',store)
        self.assertIn('stored[@"rotationEnabled"]?:@NO',store)

    def test_row_exposes_default_off_controls_and_persists_each_step(self):
        panel=(ROOT/"Sources/DouyinDiscNavigation.m").read_text()
        self.assertIn('navigationIcon?350:198',panel)
        for token in ('@"静态角度"','@"圆角"','@"持续旋转"','@"douyindisc.rotation.enabled"',
                      'douyindisc_changeAngle:(NSInteger)delta','douyindisc_changeCorner:(NSInteger)delta',
                      'douyindisc_changeRotationSpeed:(NSInteger)delta','douyindisc_saveNavigationAppearanceForIdentifier:'):
            self.assertIn(token,panel)
        self.assertIn('self.douyindisc_rotationEnabled=[entry[@"rotationEnabled"] boolValue]',panel)
        self.assertIn('self.douyindisc_cornerRadius=MAX(0,MIN(50',panel)
        self.assertIn('MAX(25,MIN(300',panel)

    def test_layer_transform_corner_and_rotation_are_separate_from_gif(self):
        hooks=(ROOT/"Sources/DouyinDiscNavigationHooks.m").read_text()
        self.assertIn('@"com.minis.douyindisc.navigation.rotation"',hooks)
        self.assertIn('CATransform3DMakeRotation(angle*M_PI/180.0,0,0,1)',hooks)
        self.assertIn('overlay.layer.cornerRadius=radius;overlay.layer.masksToBounds=radius>.01',hooks)
        self.assertIn('spin.additive=YES',hooks)
        self.assertIn('douyindisc_animation.duration',hooks)
        self.assertIn('douyindisc_spinSetVisible(lease,visible)',hooks)
        self.assertIn('UIAccessibilityReduceMotionStatusDidChangeNotification',hooks)
        self.assertIn('douyindisc_stopAnimations()',hooks)
        self.assertIn('imageChanged=lease.douyindisc_image!=image',hooks)

    def test_settings_layout_anchors_and_window_hit_gate(self):
        panel=(ROOT/"Sources/DouyinDiscNavigation.m").read_text()
        for part in ('angle','corner'):
            self.assertIn(f'self.douyindisc_{part}Value.centerYAnchor constraintEqualToAnchor:self.douyindisc_{part}Minus.centerYAnchor',panel)
        self.assertIn('UIView *switchHit=[window hitTest:switchPoint withEvent:nil]',panel)
        self.assertNotIn('[row.douyindisc_switch hitTest:',panel)
        helper=(ROOT/"tests/ui/DouyinDiscSettingsLayoutCases.inc").read_text()
        self.assertIn('[window hitTest:point withEvent:nil]',helper)
        self.assertIn('hasAmbiguousLayout',helper)
        self.assertIn('CGRectContainsRect(row.bounds,r)',helper)
        self.assertIn('settings-layout.png',helper)
        host=(ROOT/"tests/ui/DouyinDiscNativeHost.m").read_text()
        self.assertIn('douyindisc_uiTestSettingsLayout(self.window)',host)
        self.assertIn('all 217 control centers hit',host)

    def test_host_covers_static_angle_auto_rotation_and_restore(self):
        host=(ROOT/"tests/ui/DouyinDiscNativeHost.m").read_text()
        tests=(ROOT/"tests/ui/DouyinDiscNavigationCases.h").read_text()
        self.assertIn('douyindisc_navigationCases(self.window);',host)
        for token in ('per-item static angle rotates the image layer',
                      'continuous rotation uses an independent layer animation',
                      'zero corner and disabled rotation restore the legacy static appearance'):
            self.assertIn(token,tests)

if __name__=="__main__":
    unittest.main()
