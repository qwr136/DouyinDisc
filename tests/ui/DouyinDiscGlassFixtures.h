// Synthetic UIKit double. Field spellings/types from AwemeCore build 399017 metadata;
// this is not evidence for runtime topology on other Douyin builds.
@interface AWENormalModeTabBarButton : UIButton @end
@implementation AWENormalModeTabBarButton @end
@interface AWETabBarSkinContainerView : UIView @end
@implementation AWETabBarSkinContainerView @end
@interface AWETabBarElementContainerView : UIView @end
@implementation AWETabBarElementContainerView @end
@interface AWENormalModeTabBarBlurView : UIView @end
@implementation AWENormalModeTabBarBlurView @end
@interface AWENormalModeTabBar : UIView {
@public UIView *_backgroundView;
    UIImageView *_darkBackgroundImageView;
    UIImageView *_lightBackgroundImageView;
    AWETabBarSkinContainerView *_skinContainerView;
    UIView *_separatorLine;
    UIView *_compactModeBackgroundView;
    AWETabBarElementContainerView *_leftElementContainerView;
    AWETabBarElementContainerView *_rightElementContainerView;
    AWENormalModeTabBarBlurView *_awe_blurView;
    NSArray *_tabBarButtons;
    UIView *_customCoverView;
}
@property(nonatomic) NSUInteger douyindisc_glassLayoutCalls;
@property(nonatomic) NSUInteger douyindisc_glassMoveCalls;
@end
@implementation AWENormalModeTabBar
- (void)layoutSubviews { ++self.douyindisc_glassLayoutCalls;[super layoutSubviews]; }
- (void)didMoveToWindow { ++self.douyindisc_glassMoveCalls;[super didMoveToWindow]; }
@end
@interface DouyinDiscGlassUnknownBar : AWENormalModeTabBar @end
@implementation DouyinDiscGlassUnknownBar @end
@interface DouyinDiscGlassTapProbe : NSObject
@property(nonatomic) NSUInteger douyindisc_taps;
- (void)douyindisc_tapped:(id)sender;
@end
@implementation DouyinDiscGlassTapProbe
- (void)douyindisc_tapped:(id)sender {(void)sender;++self.douyindisc_taps;}
@end
