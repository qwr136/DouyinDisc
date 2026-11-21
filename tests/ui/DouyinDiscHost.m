#import <UIKit/UIKit.h>
#import "../../Sources/DouyinDiscDisplay.m"

static NSUInteger douyindisc_checks;
static NSMutableArray<NSString *> *douyindisc_results;
#define DD_CHECK(condition, message) do { \
    ++douyindisc_checks; \
    [douyindisc_results addObject:[NSString stringWithFormat:@"%@: %s", (condition) ? @"PASS" : @"FAIL", message]]; \
} while (0)

@interface DouyinDiscTestApp : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic) NSUInteger douyindisc_clicks;
@end

@implementation DouyinDiscTestApp
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    (void)app; (void)options;
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [UIViewController new];
    self.window.rootViewController.view.backgroundColor = UIColor.blackColor;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    (void)application;
    dispatch_async(dispatch_get_main_queue(), ^{ [self douyindisc_run]; });
}

- (void)douyindisc_nativeTap:(id)sender {
    (void)sender;
    ++self.douyindisc_clicks;
}

- (void)douyindisc_run {
    douyindisc_results = [NSMutableArray array];
    UIWindow *window = self.window;
    CGFloat width = window.bounds.size.width, height = window.bounds.size.height;
    UIView *rail = [[UIView alloc] initWithFrame:CGRectMake(width - 72, height * 0.55, 72, height * 0.4)];
    [window.rootViewController.view addSubview:rail];
    UIButton *share = [[UIButton alloc] initWithFrame:CGRectMake(14, 50, 44, 44)];
    share.accessibilityLabel = @"分享";
    [rail addSubview:share];
    UIButton *disc = [[UIButton alloc] initWithFrame:CGRectMake(15, 120, 42, 42)];
    disc.accessibilityLabel = @"音乐详情";
    [disc addTarget:self action:@selector(douyindisc_nativeTap:) forControlEvents:UIControlEventTouchUpInside];
    [rail addSubview:disc];
    UIImage *art = [UIImage imageWithData:[NSData dataWithBytes:douyindisc_artwork length:sizeof(douyindisc_artwork)]];
    DD_CHECK(art.CGImage != NULL, "embedded PNG decodes under UIKit");
    UIImageView *cover = [[UIImageView alloc] initWithImage:art];
    cover.frame = disc.bounds;
    [disc addSubview:cover];
    [window layoutIfNeeded];
    [cover.layer displayIfNeeded];
    DD_CHECK(douyindisc_keyWindow(UIApplication.sharedApplication) == window, "unique active normal window");
    DD_CHECK(douyindisc_findDisc(window) == disc, "music disc found below share");
    DD_CHECK(douyindisc_findCover(disc) == cover, "unique centered original image renderer");
    DouyinDiscDisplay *driver = [DouyinDiscDisplay new];
    driver.douyindisc_image = art;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(1, 1)];
    driver.douyindisc_clear = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) { (void)context; }];
    id original = cover.layer.contents;
    NSArray *actions = [disc actionsForTarget:self forControlEvent:UIControlEventTouchUpInside];
    [driver douyindisc_tick];
    DD_CHECK(driver.douyindisc_cover == cover, "actual production tick installs artwork layer");
    DD_CHECK(driver.douyindisc_overlay.superlayer == cover.layer, "art inherits native layer transform");
    DD_CHECK(cover.layer.contents != original && cover.image == art, "only visible pixels replaced; source UIImage retained");
    DD_CHECK([[disc actionsForTarget:self forControlEvent:UIControlEventTouchUpInside] isEqualToArray:actions], "native click actions untouched");
    [disc sendActionsForControlEvents:UIControlEventTouchUpInside];
    DD_CHECK(self.douyindisc_clicks == 1, "native registered action still invoked once");
    DD_CHECK(disc.userInteractionEnabled && !disc.hidden && cover.alpha == 1, "native control remains visible and interactive");
    [driver douyindisc_tick]; [driver douyindisc_tick];
    DD_CHECK(driver.douyindisc_samples == 3, "fallback waits for three native spin samples");
    DD_CHECK(UIAccessibilityIsReduceMotionEnabled() || [driver.douyindisc_overlay animationForKey:douyindisc_spinKey], "owned fallback rotation installed only when necessary");
    CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    spin.fromValue = @0; spin.toValue = @(M_PI * 2); spin.duration = 8; spin.repeatCount = HUGE_VALF;
    [cover.layer addAnimation:spin forKey:@"host-native-spin"];
    [driver douyindisc_tick];
    DD_CHECK([cover.layer animationForKey:@"host-native-spin"] != nil, "native spin retained");
    DD_CHECK(![driver.douyindisc_overlay animationForKey:douyindisc_spinKey], "fallback removed when native spin exists");
    [driver douyindisc_resignedActive:nil];
    DD_CHECK(cover.layer.contents == original && driver.douyindisc_overlay == nil, "deactivation restores original pixels and layer");
    [driver douyindisc_tick];
    id lateNative = (__bridge id)driver.douyindisc_clear.CGImage;
    cover.layer.contents = (__bridge id)art.CGImage;
    lateNative = cover.layer.contents;
    [driver douyindisc_restore];
    DD_CHECK(cover.layer.contents == lateNative, "late native contents not clobbered by cleanup");
    [cover.layer removeAnimationForKey:@"host-native-spin"];
    share.hidden = YES;
    DD_CHECK(!douyindisc_findDisc(window), "missing share rejects image replacement");
    share.hidden = NO;
    disc.accessibilityLabel = @"分享";
    DD_CHECK(!douyindisc_findDisc(window), "share arrow itself cannot be a disc");
    disc.accessibilityLabel = @"音乐详情";
    UIImageView *duplicate = [[UIImageView alloc] initWithImage:art];
    duplicate.frame = disc.bounds; [disc addSubview:duplicate];
    DD_CHECK(!douyindisc_findCover(disc), "ambiguous image renderers fail closed");
    [duplicate removeFromSuperview];
    cover.userInteractionEnabled = YES;
    DD_CHECK(!douyindisc_findCover(disc), "interactive image renderer is not altered");
    cover.userInteractionEnabled = NO;
    disc.hidden = YES;
    DD_CHECK(!douyindisc_findDisc(window), "hidden controls rejected");
    disc.hidden = NO;
    rail.hidden = YES;
    DD_CHECK(!douyindisc_findDisc(window), "hidden ancestor rejected");
    rail.hidden = NO;
    share.accessibilityLabel = @"转发"; disc.accessibilityLabel = @"拍同款";
    DD_CHECK(douyindisc_findDisc(window) == disc, "拍同款 and 转发 roles supported");
    UIButton *other = [[UIButton alloc] initWithFrame:disc.frame];
    other.accessibilityLabel = @"音乐详情"; [rail addSubview:other];
    DD_CHECK(!douyindisc_findDisc(window), "two possible disc controls rejected");
    [other removeFromSuperview];
    [driver douyindisc_restore];
    NSUInteger failures = 0;
    for (NSString *line in douyindisc_results) if ([line hasPrefix:@"FAIL"]) ++failures;
    [douyindisc_results addObject:[NSString stringWithFormat:@"UIKit host: %lu checks, %lu failures", (unsigned long)douyindisc_checks, (unsigned long)failures]];
    NSString *report = [douyindisc_results componentsJoinedByString:@"\n"];
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"uikit-report.txt"];
    [report writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"%@", report);
    exit(failures ? 1 : 0);
}
@end

int main(int argc, char **argv) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(DouyinDiscTestApp.class)); }
}
