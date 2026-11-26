#import <UIKit/UIKit.h>
#import "../../Sources/DouyinDiscNavigation.h"

@protocol AWENormalModeTabBarInnerView @end
@interface AWENormalModeTabBar : UIView
@end
@implementation AWENormalModeTabBar
@end
@interface AWENormalModeTabBarGeneralButton : UIButton { @public UIView<AWENormalModeTabBarInnerView> *_innerView; }
@end
@implementation AWENormalModeTabBarGeneralButton
- (void)layoutSubviews { [super layoutSubviews]; }
@end
@interface AWENormalModeTabBarTextView : UIView<AWENormalModeTabBarInnerView> { @public UILabel *_label; }
@end
@implementation AWENormalModeTabBarTextView
- (void)layoutSubviews { [super layoutSubviews]; }
- (void)updateTitle:(NSString *)title { _label.text=title; }
- (void)updateTitle:(NSString *)title animated:(BOOL)animated { (void)animated; _label.text=title; }
- (void)tabbarStatusDidChanged:(NSInteger)status animated:(BOOL)animated { (void)status; (void)animated; }
@end
@interface AWENormalModeTabBarIconTextView : UIView<AWENormalModeTabBarInnerView> { @public UILabel *_textLabel; }
@end
@implementation AWENormalModeTabBarIconTextView
- (void)layoutSubviews { [super layoutSubviews]; }
- (void)updateTitle:(NSString *)title { _textLabel.text=title; }
- (void)tabbarStatusDidChanged:(NSInteger)status animated:(BOOL)animated { (void)status; (void)animated; }
@end
@class AWEHPTopTabItemTextContentView;
@interface AWEHPTopTabItemUIModel : NSObject { @public NSString *_title; }
@end
@implementation AWEHPTopTabItemUIModel
@end
@interface AWEHPTopTabItemView : UIView { @public AWEHPTopTabItemTextContentView *_textContentView; AWEHPTopTabItemUIModel *_item; }
@end
@implementation AWEHPTopTabItemView
- (void)updateSelected:(BOOL)selected animated:(BOOL)animated { (void)selected; (void)animated; }
@end
@interface AWEHPTopTabItemTextContentView : UIView { @public UILabel *_titleLabel; }
@end
@implementation AWEHPTopTabItemTextContentView
- (void)layoutSubviews { [super layoutSubviews]; }
- (void)setContentText:(NSString *)text { _titleLabel.text=text; }
@end
@interface AWEFeedTopBarContainer : UIView { @public UIView *_segmentControlView; }
@end
@implementation AWEFeedTopBarContainer
@end
static UIImage *douyindisc_rootPlaceholderFixture;
@interface AWESettingItemModel : NSObject
@property (nonatomic,copy) NSString *identifier;
@property (nonatomic,copy) NSString *title;
@property (nonatomic,strong) UIColor *titleColor;
@property (nonatomic,strong) UIImage *specificIconImage;
@property (nonatomic,strong) NSString *iconImageName;
@property (nonatomic,strong) UIImage *placeholderIconImage;
@property (nonatomic,strong) NSString *businessID;
@property (nonatomic) NSInteger type;
@property (nonatomic) NSInteger cellType;
@property (nonatomic) BOOL isEnable;
@property (nonatomic) BOOL isUserInteractionEnabled;
@property (nonatomic) BOOL isForbidChangeColor;
@property (nonatomic) BOOL useStandardArrowImage;
@property (nonatomic,copy) void (^cellTappedBlock)(void);
@property (nonatomic) double cellHeight;
- (instancetype)initWithIdentifier:(NSString *)identifier;
@end
@implementation AWESettingItemModel
- (instancetype)initWithIdentifier:(NSString *)identifier { self=[super init]; if(self){_identifier=[identifier copy];self.placeholderIconImage=douyindisc_rootPlaceholderFixture;} return self; }
- (void)setIconImageName:(NSString *)iconImageName { _iconImageName=[iconImageName copy];if(!iconImageName.length)self.specificIconImage=self.placeholderIconImage?:douyindisc_rootPlaceholderFixture; }
- (void)setUserInteractionEnabled:(BOOL)enabled { _isUserInteractionEnabled=enabled; }
@end
@interface AWESettingsTableViewCell : UITableViewCell
@property (nonatomic,strong) AWESettingItemModel *itemModel;
@property (nonatomic,strong) UIImageView *iconImageView;
@property (nonatomic,strong) UIImageView *arrowImageView;
- (void)willDisplayItemModel:(AWESettingItemModel *)model;
@end
@implementation AWESettingsTableViewCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier { self=[super initWithStyle:style reuseIdentifier:reuseIdentifier];if(self){_iconImageView=[UIImageView new];_arrowImageView=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"chevron.right"]];_iconImageView.hidden=YES;_arrowImageView.hidden=YES;}return self; }
- (void)willDisplayItemModel:(AWESettingItemModel *)model { self.arrowImageView.hidden=!model.useStandardArrowImage;if(model.useStandardArrowImage&&!self.arrowImageView.image)self.arrowImageView.image=[UIImage systemImageNamed:@"chevron.right"]; }
@end
@interface AWESettingSectionModel : NSObject
@property (nonatomic) NSInteger type;
@property (nonatomic,copy) NSArray<AWESettingItemModel *> *itemArray;
@end
@implementation AWESettingSectionModel @end
@interface AWESettingsViewModel : NSObject
@property (nonatomic,copy) NSArray<AWESettingSectionModel *> *sectionDataArray;
@end
@implementation AWESettingsViewModel @end
@interface AWESettingBaseViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic) NSUInteger douyindisc_nativeSelectCount;
@property(nonatomic) NSUInteger douyindisc_nativeWillDisplayCount;
@property (nonatomic,strong) UITableView *douyindisc_table;
@property (nonatomic,strong) AWESettingsViewModel *viewModel;
- (UITableView *)tableView;
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
@end
@implementation AWESettingBaseViewController
- (UITableView *)tableView { return self.douyindisc_table; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return self.viewModel.sectionDataArray.count; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView;return section<self.viewModel.sectionDataArray.count?self.viewModel.sectionDataArray[section].itemArray.count:0; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath { (void)tableView; AWESettingItemModel *item=self.viewModel.sectionDataArray[indexPath.section].itemArray[indexPath.row];AWESettingsTableViewCell *cell=[[AWESettingsTableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];cell.itemModel=item;cell.textLabel.text=item.title;cell.textLabel.textColor=item.titleColor;cell.iconImageView.image=nil;cell.arrowImageView.image=nil;return cell; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath { (void)tableView; self.douyindisc_nativeSelectCount++; AWESettingItemModel *item=self.viewModel.sectionDataArray[indexPath.section].itemArray[indexPath.row];if(item.cellTappedBlock)item.cellTappedBlock(); }
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath { (void)tableView;++self.douyindisc_nativeWillDisplayCount;AWESettingItemModel *item=self.viewModel.sectionDataArray[indexPath.section].itemArray[indexPath.row];if([cell isKindOfClass:AWESettingsTableViewCell.class]){AWESettingsTableViewCell *native=(AWESettingsTableViewCell *)cell;native.itemModel=item;[native willDisplayItemModel:item];} }
- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath { (void)tableView;(void)cell;(void)indexPath; }
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; }
@end
@interface AWESettingsTableViewController : AWESettingBaseViewController
@property (nonatomic) BOOL douyindisc_searchStatus;
- (BOOL)onSearchStatus;
@end
@implementation AWESettingsTableViewController
- (BOOL)onSearchStatus { return self.douyindisc_searchStatus; }
@end
@interface AWEGeneralSettingViewController : UIViewController
@end
@implementation AWEGeneralSettingViewController @end

@interface AWEButton : UIButton { @public UIImageView *_imageContentView; }
@property (nonatomic) NSUInteger douyindisc_layoutCalls;
@property (nonatomic) NSUInteger douyindisc_moveCalls;
@end
@implementation AWEButton
- (void)layoutSubviews { ++self.douyindisc_layoutCalls; [super layoutSubviews]; }
- (void)didMoveToWindow { ++self.douyindisc_moveCalls; [super didMoveToWindow]; }
@end
@interface AWEMusicCoverButton : AWEButton {
@public UIView *_imageBgView;
    UIImageView *_ownerImageView;
    UILabel *_guidanceLabel;
    UIView *_guidanceView;
    UIImageView *_topCoverNoteImgV;
}
@end
@implementation AWEMusicCoverButton
@end
@interface AWEGradientView : UIView
@end
@implementation AWEGradientView
@end
@interface AWEPlayInteractionListenFeedView : UIView {
@public UIImageView *_listenIconView;
    AWEMusicCoverButton *_musicButton;
    UILabel *_listenTitleLabel;
    AWEGradientView *_backgroundView;
}
@end
@implementation AWEPlayInteractionListenFeedView
@end
@interface AWEPlayInteractionStyleOneMusicView : UIView {
@public AWEMusicCoverButton *_musicButton;
    UIView *_playInteractionCircleMaskView;
    UIImageView *_playInteractionMaskView;
    UILabel *_playInteractionLabel;
}
@end
@implementation AWEPlayInteractionStyleOneMusicView
@end
@interface AWEPlayInteractionSingleSongMusicStyleView : UIView {
@public AWEMusicCoverButton *_musicButton;
    UILabel *_playInteractionLabel;
    UIView *_playInteractionCircleMaskView;
    UIImageView *_playInteractionMaskView;
    UIView *_playInteractionColorMaskView;
    UIImageView *_playInteractionIconView;
}
@end
@implementation AWEPlayInteractionSingleSongMusicStyleView
@end
@interface DouyinDiscDerivedSingleSongMusicStyleView : AWEPlayInteractionSingleSongMusicStyleView
@end
@implementation DouyinDiscDerivedSingleSongMusicStyleView
@end

#import "../../Sources/DouyinDiscNativeDisplay.m"
static NSUInteger douyindisc_checks;
static NSMutableArray<NSString *> *douyindisc_results;
static BOOL douyindisc_storeTestsStarted;
static void douyindisc_writeProgress(void) {
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"uikit-report.txt"];
    [[douyindisc_results componentsJoinedByString:@"\n"] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
#define DD_CHECK(condition, message) do { \
    ++douyindisc_checks; \
    NSString *line = [NSString stringWithFormat:@"%@: %s", (condition) ? @"PASS" : @"FAIL", message]; \
    [douyindisc_results addObject:line]; NSLog(@"DD_CHECK %@", line); douyindisc_writeProgress(); \
} while (0)
#define DD_CHECK_NS(condition, message) do { \
    ++douyindisc_checks; \
    NSString *line = [NSString stringWithFormat:@"%@: %@", (condition) ? @"PASS" : @"FAIL", message]; \
    [douyindisc_results addObject:line]; NSLog(@"DD_CHECK %@", line); douyindisc_writeProgress(); \
} while (0)

#import "../../Sources/DouyinDiscNavigationHooks.m"
#include "DouyinDiscClarityCases.h"
#include "DouyinDiscCaptionCases.h"
#if defined(DOUYINDISC_UI_TEST)
#include "DouyinDiscNavigationStoreCases.h"
#include "DouyinDiscCustomDiscCases.h"
#include "DouyinDiscGIFCases.h"
#endif
#include "DouyinDiscNavigationCases.h"

static void douyindisc_styleOneCases(DouyinDiscDisplay *driver, AWEMusicCoverButton *button);

static AWEMusicCoverButton *douyindisc_makeButton(UIImage *image) {
    AWEMusicCoverButton *button = [[AWEMusicCoverButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
    button->_imageContentView = [[UIImageView alloc] initWithImage:image];
    button->_imageContentView.frame = button.bounds;
    [button addSubview:button->_imageContentView];
    button->_imageBgView = [[UIView alloc] initWithFrame:button.bounds];
    button->_imageBgView.backgroundColor = UIColor.blackColor;
    button->_imageBgView.userInteractionEnabled = NO;
    [button insertSubview:button->_imageBgView atIndex:0];
    button->_guidanceView = [[UIView alloc] initWithFrame:CGRectMake(0, 22, 44, 22)];
    button->_guidanceView.backgroundColor = UIColor.blackColor;
    button->_guidanceView.userInteractionEnabled = NO;
    button->_guidanceView.alpha = .7;
    [button addSubview:button->_guidanceView];
    button->_guidanceLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 28, 44, 14)];
    button->_guidanceLabel.text = @"拍同款";
    [button addSubview:button->_guidanceLabel];
    return button;
}

static NSUInteger douyindisc_darkPixels(UIView *view) {
    size_t w = (size_t)ceil(view.bounds.size.width), h = (size_t)ceil(view.bounds.size.height);
    NSMutableData *data = [NSMutableData dataWithLength:w*h*4];
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data.mutableBytes, w, h, 8, w*4, rgb, kCGImageAlphaPremultipliedLast);
    [view.layer renderInContext:context];
    CGContextRelease(context); CGColorSpaceRelease(rgb);
    const unsigned char *pixels = data.bytes; NSUInteger dark = 0;
    for (size_t i = 0; i < w*h; ++i) {
        const unsigned char *p = pixels + i*4;
        if (p[3] > 30 && MAX(p[0],MAX(p[1],p[2])) < p[3] * .5) ++dark;
    }
    return dark;
}

#include "DouyinDiscStyleOneCases.h"
#include "DouyinDiscSingleSongCases.h"

static UIView *douyindisc_item(UIWindow *window, UIScrollView *scroll, CGFloat y,
                              AWEMusicCoverButton *button, UIControl **outShare) {
    UIView *item = [[UIView alloc] initWithFrame:CGRectMake(0, y, window.bounds.size.width, window.bounds.size.height)];
    UIView *rail = [[UIView alloc] initWithFrame:CGRectMake(window.bounds.size.width - 70, window.bounds.size.height * .6, 70, 190)];
    [item addSubview:rail];
    UIButton *share = [[UIButton alloc] initWithFrame:CGRectMake(13, 0, 44, 44)];
    share.accessibilityLabel = @"分享"; [rail addSubview:share];
    button.frame = CGRectMake(13, 72, 44, 44); [rail addSubview:button];
    [scroll addSubview:item];
    if (outShare) *outShare = share;
    return item;
}

@interface DouyinDiscTestApp : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic) BOOL douyindisc_running;
@property (nonatomic) NSUInteger douyindisc_clicks;
@end
@implementation DouyinDiscTestApp
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    (void)app; (void)options;
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [UIViewController new];
    [self.window makeKeyAndVisible]; return YES;
}
- (void)applicationDidBecomeActive:(UIApplication *)application {
    (void)application;
    if (self.douyindisc_running) return;
    self.douyindisc_running = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        douyindisc_results=[NSMutableArray array];
        douyindisc_installNavigationHooks();
        douyindisc_gifCases(self.window, ^{[self douyindisc_run];});
    });
}
- (void)douyindisc_nativeTap:(id)sender { (void)sender; ++self.douyindisc_clicks; }
- (void)douyindisc_run {
    UIImage *art = [UIImage imageWithData:[NSData dataWithBytes:douyindisc_artwork length:sizeof(douyindisc_artwork)]];
    DD_CHECK(art.CGImage != NULL, "embedded original PNG decodes");
    DD_CHECK(douyindisc_uiTestPickerAppearanceStable(art), "numeric controls and picker card layout pass UIKit interaction checks");
    douyindisc_installNavigationHooks();
    UIWindow *window = self.window;
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:window.bounds];
    scroll.contentSize = CGSizeMake(window.bounds.size.width, window.bounds.size.height*3);
    [window.rootViewController.view addSubview:scroll];
    AWEMusicCoverButton *first = douyindisc_makeButton(art);
    UIControl *share;
    UIView *item = douyindisc_item(window, scroll, 0, first, &share);
    [first.layer displayIfNeeded];
    DD_CHECK(douyindisc_darkPixels(first) > 10, "native fixture reproduces dark guidance/background pixels");
    DouyinDiscDisplay *driver = [DouyinDiscDisplay new]; driver.douyindisc_image = douyindisc_loadArtwork();
    douyindisc_driver = driver;
    DD_CHECK(douyindisc_installLifecycle(douyindisc_changed), "exact public lifecycle ABI accepted");
    DD_CHECK(douyindisc_voidLifecycle(class_getInstanceMethod(AWEMusicCoverButton.class, @selector(layoutSubviews))), "inherited public method keeps verified void signature");
    DD_CHECK(!douyindisc_voidLifecycle(class_getInstanceMethod(NSObject.class, @selector(description))), "object return ABI rejected");
    NSUInteger layouts = first.douyindisc_layoutCalls;
    [first layoutSubviews];
    DD_CHECK(first.douyindisc_layoutCalls == layouts + 1, "inherited original layout forwarded exactly once");
    DouyinDiscSurface *a = objc_getAssociatedObject(first, &douyindisc_leaseKey);
    DD_CHECK(a && a.douyindisc_overlay.superlayer == a.douyindisc_artworkGroup && a.douyindisc_artworkGroup.superlayer == a.douyindisc_canvas.layer, "layout attaches artwork before any timer fires");
    DD_CHECK(first->_guidanceLabel.alpha == 0 && first->_guidanceView.alpha == 0, "caption and its separate dark plate suppressed together");
    DD_CHECK(first->_imageContentView.alpha == 0 && first->_imageBgView.alpha == 0, "native bitmap and background kept but visually suppressed");
    DD_CHECK(douyindisc_darkPixels(first) == 0, "actual rendered model pixels contain no native black half-disc");
    DD_CHECK(first.alpha == 1 && !first.hidden && first.userInteractionEnabled, "button hit target itself never hidden");
    [first addTarget:self action:@selector(douyindisc_nativeTap:) forControlEvents:UIControlEventTouchUpInside];
    [first sendActionsForControlEvents:UIControlEventTouchUpInside];
    DD_CHECK(self.douyindisc_clicks == 1, "original registered native click still fires once");
    NSUInteger clicksBeforeDiscTest=self.douyindisc_clicks;
    douyindisc_customDiscCases(driver,first);
    [first sendActionsForControlEvents:UIControlEventTouchUpInside];
    DD_CHECK(self.douyindisc_clicks==clicksBeforeDiscTest+1,"custom disc replacement keeps the original share-below music action working");
    self.douyindisc_clicks=clicksBeforeDiscTest;
    a=objc_getAssociatedObject(first,&douyindisc_leaseKey);
    DD_CHECK(a.douyindisc_overlay.contents==(__bridge id)driver.douyindisc_image.CGImage,"cleared custom icon restores the embedded default artwork");
    DD_CHECK(a.douyindisc_overlay.contents == (__bridge id)driver.douyindisc_image.CGImage, "overlay uses actual production clarity artwork");
    DD_CHECK(![douyindisc_nativeObject(first, "AWEMusicCoverButton", "_guidanceView", "@\"UIImageView\"") isKindOfClass:UIView.class], "mismatched field type rejected without private dispatch");
    douyindisc_clarityCases(driver, first, a, window);
    a = objc_getAssociatedObject(first, &douyindisc_leaseKey);
    douyindisc_styleOneCases(driver,first);
    a = objc_getAssociatedObject(first, &douyindisc_leaseKey);
    douyindisc_captionCases(driver,first);
    AWEMusicCoverButton *incoming = douyindisc_makeButton(art);
    douyindisc_item(window, scroll, window.bounds.size.height, incoming, NULL);
    [incoming layoutSubviews];
    DouyinDiscSurface *b = objc_getAssociatedObject(incoming, &douyindisc_leaseKey);
    DD_CHECK(b && b.douyindisc_overlay.superlayer == b.douyindisc_artworkGroup && b.douyindisc_artworkGroup.superlayer == b.douyindisc_canvas.layer, "incoming offscreen feed item prepared before entering viewport");
    DD_CHECK(a != b && a.douyindisc_overlay.superlayer == a.douyindisc_artworkGroup && a.douyindisc_artworkGroup.superlayer == a.douyindisc_canvas.layer, "old and incoming items hold independent visual surfaces");
    CABasicAnimation *spinA = (CABasicAnimation *)[a.douyindisc_overlay animationForKey:douyindisc_spinKey];
    CABasicAnimation *spinB = (CABasicAnimation *)[b.douyindisc_overlay animationForKey:douyindisc_spinKey];
    DD_CHECK(UIAccessibilityIsReduceMotionEnabled() || (spinA && spinB && fabs(spinA.beginTime - spinB.beginTime) < .001), "all video items use one absolute rotation epoch");
    DD_CHECK(UIAccessibilityIsReduceMotionEnabled() || spinA.duration == 7, "continuous rotation period remains seven seconds");
    CABasicAnimation *nativeSpin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    nativeSpin.fromValue = @0; nativeSpin.toValue = @(2*M_PI); nativeSpin.duration = 3; nativeSpin.repeatCount = HUGE_VALF;
    [first->_imageContentView.layer addAnimation:nativeSpin forKey:@"host-native-spin"];
    [driver douyindisc_refresh:first];
    DD_CHECK([first->_imageContentView.layer animationForKey:@"host-native-spin"] != nil, "native animation left intact on its own hidden renderer");
    DD_CHECK(a.douyindisc_overlay.superlayer == a.douyindisc_artworkGroup && a.douyindisc_artworkGroup.superlayer == a.douyindisc_canvas.layer && a.douyindisc_overlay.superlayer != first->_imageContentView.layer, "new image never inherits native renderer rotation");
    first.enabled = NO;
    [driver douyindisc_refresh:first];
    DD_CHECK(UIAccessibilityIsReduceMotionEnabled() || [a.douyindisc_overlay animationForKey:douyindisc_spinKey], "native playback/control pause does not stop independent rotation");
    first.enabled = YES;
    UIGraphicsImageRenderer *blueRenderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(2, 2)];
    UIImage *blue = [blueRenderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [UIColor.blueColor setFill]; CGContextFillRect(context.CGContext, CGRectMake(0, 0, 2, 2));
    }];
    first->_imageContentView.image = blue;
    [first->_imageContentView.layer displayIfNeeded];
    DD_CHECK(first->_imageContentView.alpha == 0, "asynchronous native image replacement cannot reveal old artwork between ticks");
    DD_CHECK(douyindisc_darkPixels(first) == 0 && a.douyindisc_overlay.superlayer == a.douyindisc_artworkGroup && a.douyindisc_artworkGroup.superlayer == a.douyindisc_canvas.layer, "native image update leaves only custom artwork visible");
    DD_CHECK(first->_imageContentView.image == blue, "native model continues receiving current artwork");
    [scroll setContentOffset:CGPointMake(0, window.bounds.size.height) animated:NO];
    [scroll layoutIfNeeded];
    [driver douyindisc_tick];
    DD_CHECK(objc_getAssociatedObject(incoming, &douyindisc_leaseKey) == b, "feed scrolling keeps the incoming image surface instead of recreating it");
    spinB = (CABasicAnimation *)[b.douyindisc_overlay animationForKey:douyindisc_spinKey];
    DD_CHECK(UIAccessibilityIsReduceMotionEnabled() || fabs(spinB.beginTime - spinA.beginTime) < .001, "scrolling does not restart the rotation phase");
    UILabel *unrelated = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 20)];
    unrelated.text = @"拍同款"; [window.rootViewController.view addSubview:unrelated];
    [driver douyindisc_tick];
    DD_CHECK(unrelated.alpha == 1, "same text outside identified native fields untouched");
    share.hidden = YES;
    [a douyindisc_restore];
    [driver douyindisc_refresh:first];
    DD_CHECK(objc_getAssociatedObject(first, &douyindisc_leaseKey) == a, "temporary share disappearance does not revoke known surface");
    share.hidden = NO;
    UIButton *ordinary = [[UIButton alloc] initWithFrame:incoming.frame];
    ordinary.accessibilityLabel = @"拍同款";
    [incoming.superview addSubview:ordinary];
    [driver douyindisc_refresh:ordinary];
    DD_CHECK(!objc_getAssociatedObject(ordinary, &douyindisc_leaseKey), "generic controls cannot match by label or geometry alone");
    [ordinary removeFromSuperview];
    AWEMusicCoverButton *left = douyindisc_makeButton(art);
    left.frame = CGRectMake(20, 450, 44, 44); [window.rootViewController.view addSubview:left];
    [left layoutSubviews];
    DD_CHECK(!objc_getAssociatedObject(left, &douyindisc_leaseKey) && left->_imageContentView.alpha == 1, "left-side music class not treated as right rail");
    [left removeFromSuperview];
    [driver douyindisc_start];
    NSTimer *timer = driver.douyindisc_timer;
    DD_CHECK(timer.isValid, "active lightweight known-control timer installed");
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    DD_CHECK(!timer.isValid && !driver.douyindisc_timer, "deactivation stops all active scanning work");
    DD_CHECK(a.douyindisc_overlay.superlayer == a.douyindisc_artworkGroup && a.douyindisc_artworkGroup.superlayer == a.douyindisc_canvas.layer && b.douyindisc_overlay.superlayer == b.douyindisc_artworkGroup && b.douyindisc_artworkGroup.superlayer == b.douyindisc_canvas.layer, "inactive snapshot retains both existing artwork surfaces");
    DD_CHECK(first->_guidanceView.alpha == 0, "guidance background stays hidden through inactive notification");
    UIWindow *panel = [[UIWindow alloc] initWithFrame:window.bounds];
    panel.rootViewController = [UIViewController new]; [panel makeKeyAndVisible];
    DD_CHECK(panel.isKeyWindow && !window.isKeyWindow, "real alternate window obtains key status");
    [driver douyindisc_tick];
    DD_CHECK(objc_getAssociatedObject(incoming, &douyindisc_leaseKey) == b, "temporary key transfer retains known original window surface");
    panel.hidden = YES; [window makeKeyAndVisible];
    first->_guidanceView.alpha = .35;
    [driver douyindisc_refresh:first];
    [item removeFromSuperview];
    DD_CHECK(!objc_getAssociatedObject(first, &douyindisc_leaseKey), "real didMoveToWindow invalidation revokes detached surface");
    DD_CHECK(fabs(first->_guidanceView.alpha - .35) < .001, "detachment restores latest nonzero native alpha");
    DD_CHECK(first->_imageContentView.alpha == 1 && first->_imageContentView.image == blue, "detachment never writes back a stale original image");
    [scroll addSubview:item]; [first layoutSubviews];
    DouyinDiscSurface *reattached = objc_getAssociatedObject(first, &douyindisc_leaseKey);
    DD_CHECK(reattached && reattached != a, "reattachment receives fresh strictly checked surface");
    CABasicAnimation *again = (CABasicAnimation *)[reattached.douyindisc_overlay animationForKey:douyindisc_spinKey];
    DD_CHECK(UIAccessibilityIsReduceMotionEnabled() || fabs(again.beginTime-spinA.beginTime)<.001, "fresh surface after detach still preserves global phase");
    UIView *originalParent = first.superview;
    CGRect originalFrame = first.frame;
    UIView *unpaired = [[UIView alloc] initWithFrame:window.bounds];
    [window.rootViewController.view addSubview:unpaired];
    first.frame = CGRectMake(window.bounds.size.width - 57, window.bounds.size.height * .6, 44, 44);
    [unpaired addSubview:first]; [first layoutSubviews];
    DD_CHECK(!objc_getAssociatedObject(first, &douyindisc_leaseKey), "same-window reparenting cannot inherit an old share authorization");
    DD_CHECK(first->_imageContentView.alpha == 1, "unpaired new scope restores original native visuals");
    first.frame = originalFrame; [originalParent addSubview:first]; [first layoutSubviews];
    DD_CHECK(objc_getAssociatedObject(first, &douyindisc_leaseKey) != nil, "return to genuine paired scope authorizes a new surface");
    [unpaired removeFromSuperview];
    AWEPlayInteractionListenFeedView *listen = [[AWEPlayInteractionListenFeedView alloc] initWithFrame:incoming.frame];
    listen->_musicButton = incoming;
    listen->_backgroundView = [[AWEGradientView alloc] initWithFrame:listen.bounds];
    listen->_backgroundView.backgroundColor = UIColor.blackColor;
    listen->_backgroundView.userInteractionEnabled = NO;
    listen->_listenIconView = [[UIImageView alloc] initWithImage:blue];
    listen->_listenIconView.frame = CGRectMake(8, 6, 28, 28);
    listen->_listenTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 29, 44, 14)];
    listen->_listenTitleLabel.text = @"听抖音";
    [listen addSubview:listen->_backgroundView]; [listen addSubview:listen->_listenIconView];
    [listen addSubview:listen->_listenTitleLabel];
    UIView *rail = incoming.superview; [rail addSubview:listen];
    incoming.frame = listen.bounds; [listen insertSubview:incoming atIndex:0];
    incoming.accessibilityLabel = @"听抖音";
    incoming->_imageContentView.hidden = YES; incoming->_imageBgView.hidden = YES;
    [incoming layoutSubviews];
    DD_CHECK(douyindisc_nativeListenHost(incoming) == listen, "listen host identified by actual class and original button identity");
    DD_CHECK(listen->_listenIconView.alpha == 0 && listen->_backgroundView.alpha == 0, "earphone sibling image and gradient background suppressed");
    DD_CHECK(listen->_listenTitleLabel.alpha == 0 && [listen->_listenTitleLabel.text isEqualToString:@"听抖音"], "listen caption hidden without rewriting its text");
    DD_CHECK(incoming.alpha == 1 && !incoming.hidden && listen.alpha == 1, "listen host and native entry button remain interactive");
    DouyinDiscSurface *listenSurface = objc_getAssociatedObject(incoming, &douyindisc_leaseKey);
    DD_CHECK(listenSurface.douyindisc_overlay.superlayer == listenSurface.douyindisc_artworkGroup && listenSurface.douyindisc_artworkGroup.superlayer == listenSurface.douyindisc_canvas.layer, "listen artwork uses independent entry-button layer");
    DD_CHECK(douyindisc_darkPixels(listen) == 0, "real rasterization shows no listen gradient/earphone remnants");
    CABasicAnimation *listenSpin = (CABasicAnimation *)[listenSurface.douyindisc_overlay animationForKey:douyindisc_spinKey];
    DD_CHECK(UIAccessibilityIsReduceMotionEnabled() || fabs(listenSpin.beginTime-spinA.beginTime)<.001, "listen-mode switch shares the continuous rotation epoch");
    [incoming addTarget:self action:@selector(douyindisc_nativeTap:) forControlEvents:UIControlEventTouchUpInside];
    [incoming sendActionsForControlEvents:UIControlEventTouchUpInside];
    DD_CHECK(self.douyindisc_clicks == 2, "listen native entry action still delivered once");
    AWEMusicCoverButton *expectedButton = listen->_musicButton;
    listen->_musicButton = first;
    DD_CHECK(!douyindisc_nativeListenHost(incoming), "unrelated ancestor field cannot authorize sibling suppression");
    listen->_musicButton = expectedButton;
    __weak AWEMusicCoverButton *released;
    @autoreleasepool {
        AWEMusicCoverButton *temporary = douyindisc_makeButton(art);
        released = temporary; [driver douyindisc_refresh:temporary];
    }
    DD_CHECK(released == nil, "weak registry does not retain native controls");
    DD_CHECK(driver.douyindisc_controls.count < 64, "known-control registry remains bounded");

    NSLog(@"DD_PHASE share-init");
    UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[@"share-sheet-regression"] applicationActivities:nil];
    sheet.popoverPresentationController.sourceView = incoming;
    [window.rootViewController presentViewController:sheet animated:NO completion:^{
        DD_CHECK(window.rootViewController.presentedViewController == sheet, "real UIKit share sheet presented");
        [driver douyindisc_tick];
        DD_CHECK(objc_getAssociatedObject(incoming, &douyindisc_leaseKey) == listenSurface, "actual share sheet retains installed custom image");
        DD_CHECK(listen->_backgroundView.alpha == 0 && listen->_listenTitleLabel.alpha == 0, "actual share sheet does not reveal native listen visuals");
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 70, 20)]; label.text = @"听抖音";
        [sheet.view addSubview:label]; [driver douyindisc_tick];
        DD_CHECK(label.alpha == 1, "same title inside share sheet is never hidden");
        [window.rootViewController dismissViewControllerAnimated:NO completion:^{
            [driver douyindisc_tick];
            DD_CHECK(objc_getAssociatedObject(incoming, &douyindisc_leaseKey) == listenSurface, "share dismissal does not recreate or reset the artwork");
            CABasicAnimation *afterShare = (CABasicAnimation *)[listenSurface.douyindisc_overlay animationForKey:douyindisc_spinKey];
            DD_CHECK(UIAccessibilityIsReduceMotionEnabled() || fabs(afterShare.beginTime-spinA.beginTime)<.001, "rotation epoch unchanged through share presentation and dismissal");
            [listen removeFromSuperview];
            DD_CHECK(!objc_getAssociatedObject(incoming, &douyindisc_leaseKey), "listen renderer teardown revokes only its own surface");
            DD_CHECK(listen->_backgroundView.alpha == 1 && listen->_listenTitleLabel.alpha == 1 && listen->_listenIconView.alpha == 1, "listen siblings restored when its native owner is detached");
            DD_CHECK(incoming->_imageContentView.hidden && incoming->_imageBgView.hidden, "cleanup preserves native hidden flags");
            [listen removeFromSuperview];
            [driver douyindisc_resignedActive:nil];
            AWEMusicCoverButton *singleButton=douyindisc_makeButton(art);
            singleButton.accessibilityLabel=@"音乐详情";
            UIControl *singleShare=[UIButton buttonWithType:UIButtonTypeSystem];
            singleShare.accessibilityLabel=@"分享";
            singleShare.frame=CGRectMake(0,0,44,44);
            [singleButton.superview addSubview:singleShare];
            UIView *singleRail=[[UIView alloc] initWithFrame:CGRectMake(window.bounds.size.width-60,window.bounds.size.height*.55,50,150)];
            [window.rootViewController.view addSubview:singleRail];
            singleShare.frame=CGRectMake(3,0,44,44);[singleRail addSubview:singleShare];
            singleButton.frame=CGRectMake(3,72,44,44);[singleRail addSubview:singleButton];
            [singleButton layoutSubviews];[singleShare layoutSubviews];
            [driver douyindisc_refresh:singleButton];
            douyindisc_singleSongCases(driver,singleButton);
            [singleRail removeFromSuperview];
            [driver douyindisc_resignedActive:nil];
            [NSNotificationCenter.defaultCenter removeObserver:driver];
            [self douyindisc_finish];
        }];
    }];
}
- (void)douyindisc_finish {
    if(douyindisc_storeTestsStarted)return;
    douyindisc_storeTestsStarted=YES;
    douyindisc_navigationCases(self.window);
    douyindisc_navigationStoreCases(^{
      douyindisc_pickerCases(self.window, ^{
        NSUInteger failures=0;
        for(NSString *line in douyindisc_results)if([line hasPrefix:@"FAIL"])++failures;
        [douyindisc_results addObject:[NSString stringWithFormat:@"UIKit host: %lu checks, %lu failures",(unsigned long)douyindisc_checks,(unsigned long)failures]];
        douyindisc_writeProgress();NSLog(@"%@",douyindisc_results.lastObject);exit(failures?1:0);
      });
    });
}
@end
int main(int argc, char **argv) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(DouyinDiscTestApp.class)); }
}
