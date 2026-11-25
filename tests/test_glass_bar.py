"""Glass bar source contracts; actual UIKit state is checked in the CI host."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parent.parent
class GlassBarTests(unittest.TestCase):
    def test_only_exact_native_bar_and_verified_fields(self):
        src=(ROOT/'Sources/DouyinDiscGlassBar.inc').read_text()
        for token in ('object_getClass(bar)!=cls','[list count]!=5','button.superview!=bar','ivar_getTypeEncoding','_tabBarButtons','AWENormalModeTabBarButton','UIVisualEffectView','userInteractionEnabled=NO','UIAccessibilityIsReduceTransparencyEnabled'):
            self.assertIn(token,src)
        self.assertNotIn('objc_msgSend',src)
        self.assertNotIn('setHidden:',src)
        self.assertNotIn('bar.frame=',src)
        self.assertNotIn('button.frame=',src)
        self.assertIn('view.layer.mask==self.douyindisc_mask',src)
        self.assertIn('NSHashTable weakObjectsHashTable',src)
        self.assertEqual(src.count('((void(*)(id,SEL))douyindisc_glassOriginalLayout)(object,selector);'),1)
        self.assertEqual(src.count('((void(*)(id,SEL))douyindisc_glassOriginalMove)(object,selector);'),1)
    def test_opt_in_separate_atomic_configuration(self):
        src=(ROOT/'Sources/DouyinDiscNavigationStore.m').read_text()
        self.assertIn('@"glass.plist"',src)
        self.assertIn('douyindisc_glassPreference && !self.douyindisc_glassLoadFailed',src)
        self.assertIn('CFBooleanGetTypeID()',src)
        self.assertIn('NSDataWritingAtomic',src)
        self.assertIn('com.minis.douyindisc.glass.changed',src)
        panel=(ROOT/'Sources/DouyinDiscNavigation.m').read_text()
        self.assertIn('@"悬浮玻璃底栏"',panel)
        self.assertIn('douyindisc_saveGlassEnabled:',panel)
        self.assertNotIn('UIDocumentPicker',panel)
    def test_glass_and_restore_cases_are_executed(self):
        host=(ROOT/'tests/ui/DouyinDiscNativeHost.m').read_text()
        self.assertIn('douyindisc_glassCases(window);',host)
        self.assertIn('douyindisc_glassStoreCases();',host)
        hooks=(ROOT/'Sources/DouyinDiscNavigationHooks.m').read_text()
        self.assertIn('#include "DouyinDiscGlassBar.inc"',hooks)
        self.assertIn('douyindisc_installGlassHooks();douyindisc_reload();',hooks)
        cases=(ROOT/'tests/ui/DouyinDiscGlassCases.h').read_text()
        for label in ('all five original actions','latest native decoration','nonstandard tab count','native message badge','unexpected button hierarchy','native campaign cover'):
            self.assertIn(label,cases)
