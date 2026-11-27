"""Keep installed CA playback on app deactivation; never claim live switcher snapshots."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parent.parent

class SwitcherPolicyTests(unittest.TestCase):
    def test_navigation_latches_refresh_but_keeps_installed_animation_keys(self):
        code=(ROOT/'Sources/DouyinDiscNavigationHooks.m').read_text()
        suspend=code.split('static void douyindisc_suspendAnimationRefresh(void) {',1)[1].split('\n}',1)[0]
        self.assertIn('douyindisc_animationRefreshSuspended=YES',suspend)
        self.assertIn('[douyindisc_gifVisibilityTimer invalidate]',suspend)
        self.assertNotIn('removeAnimation',suspend)
        self.assertIn('douyindisc_animationRefreshSuspended=NO',code)
        self.assertIn('douyindisc_keepInstalledAnimations(lease)',code)
        self.assertIn('UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){(void)n;douyindisc_suspendAnimationRefresh();}',code)
        self.assertIn('UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){(void)n;douyindisc_resumeAnimationRefresh();}',code)
        self.assertIn('if(!lease.douyindisc_rotationEnabled||UIAccessibilityIsReduceMotionEnabled())',code)
        self.assertIn('douyindisc_configurationChanged()',code)

    def test_disc_retains_animation_on_resign_but_explicit_cleanup_removes_it(self):
        code=(ROOT/'Sources/DouyinDiscNativeDisplay.m').read_text()
        suspend=code.split('- (void)douyindisc_resignedActive:',1)[1].split('\n}',1)[0]
        self.assertIn('self.douyindisc_refreshSuspended=YES',suspend)
        self.assertNotIn('removeAnimation',suspend)
        self.assertIn('self.douyindisc_refreshSuspended=NO',code)
        self.assertIn('if (self.douyindisc_refreshSuspended) return;',code)
        self.assertIn('[self.douyindisc_overlay removeAnimationForKey:douyindisc_discGIFKey]',code)
        self.assertIn('[self.douyindisc_overlay removeAnimationForKey:douyindisc_spinKey]',code)
        for name in ('DouyinDiscNativeDisplay.m','DouyinDiscNavigationHooks.m'):
            text=(ROOT/'Sources'/name).read_text()
            for forbidden in ('beginBackgroundTask','AVAudioSession','UIBackgroundModes','performExpiringActivity','CADisplayLink'):
                self.assertNotIn(forbidden,text)

    def test_real_notification_policy_regressions_are_executed(self):
        host=(ROOT/'tests/ui/DouyinDiscNativeHost.m').read_text()
        cases=(ROOT/'tests/ui/DouyinDiscSwitcherCases.h').read_text()
        self.assertIn('#include "DouyinDiscSwitcherCases.h"',host)
        self.assertIn('douyindisc_switcherCases(self.window)',host)
        for token in ('postNotificationName:UIApplicationWillResignActiveNotification',
                      'postNotificationName:UIApplicationDidBecomeActiveNotification',
                      'keeps beginTime','navigation timer stays nil','disc timer stays nil',
                      'rotation off clears its key while suspended',
                      'explicit disc disable clears both keys while suspended',
                      'detached disc releases owned animations even while suspended'):
            self.assertIn(token,cases)
        self.assertIn('douyindisc_startupCases(self.window)',host)
        self.assertIn('douyindisc_uiTestNumericInput(self.window)',host)
        self.assertIn('all 256 control centers hit',host)

if __name__=='__main__':unittest.main()
