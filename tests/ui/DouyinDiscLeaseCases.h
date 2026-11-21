// Real UIKit objects exercising the actual production visual-lease methods.
static void douyindisc_runLeaseCases(DouyinDiscDisplay *driver, UIWindow *window,
                                    UIControl *disc, UIControl *share, UIImageView *cover,
                                    UILabel *title, UILabel *siblingTitle) {
    [driver douyindisc_tick];
    CALayer *installed = driver.douyindisc_overlay;
    DD_CHECK(title.alpha == 0 && siblingTitle.alpha == 0, "disc and adjacent exact title text hidden");
    DD_CHECK([title.text isEqualToString:@"拍同款"] && CGRectEqualToRect(title.frame, CGRectMake(-5, 28, 52, 14)), "title text and layout not rewritten");
    UILabel *caption = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 55, 16)];
    caption.text = @"拍同款";
    [disc.superview addSubview:caption];
    UIButton *separate = [[UIButton alloc] initWithFrame:disc.frame];
    UILabel *otherTitle = [[UILabel alloc] initWithFrame:disc.bounds];
    otherTitle.text = @"拍同款";
    [separate addSubview:otherTitle];
    [disc.superview addSubview:separate];
    [driver douyindisc_tick];
    DD_CHECK(caption.alpha == 1 && otherTitle.alpha == 1, "unrelated caption and separate control text untouched");
    [caption removeFromSuperview]; [separate removeFromSuperview];

    [driver douyindisc_start];
    NSTimer *timer = driver.douyindisc_timer;
    DD_CHECK(timer.isValid, "active display owns its scan timer");
    NSUInteger samples = driver.douyindisc_samples;
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    DD_CHECK(!timer.isValid && !driver.douyindisc_timer, "inactive notification stops scan timer");
    DD_CHECK(driver.douyindisc_overlay == installed && driver.douyindisc_samples == samples, "inactive notification neither removes nor rebuilds artwork");
    [driver douyindisc_resignedActive:nil];
    DD_CHECK(driver.douyindisc_overlay == installed && title.alpha == 0, "repeated inactive callbacks preserve pixels and hidden label");

    share.hidden = YES;
    DD_CHECK(!douyindisc_findDisc(window), "temporary source scan failure actually reproduced");
    [driver douyindisc_tick];
    DD_CHECK(driver.douyindisc_overlay == installed, "known valid lease survives temporary share disappearance");
    share.hidden = NO;

    UIWindow *panel = [[UIWindow alloc] initWithFrame:window.bounds];
    panel.rootViewController = [UIViewController new];
    [panel makeKeyAndVisible];
    DD_CHECK(panel.isKeyWindow && !window.isKeyWindow, "alternate UIKit panel really becomes key");
    [driver douyindisc_tick];
    DD_CHECK(driver.douyindisc_window == window && driver.douyindisc_overlay == installed, "key-window transfer retains original known renderer only");
    DD_CHECK(driver.douyindisc_cover == cover && title.alpha == 0, "no image or label mutation is moved into the panel");
    panel.hidden = YES;
    [window makeKeyAndVisible];

    title.text = @"其他文案";
    [driver douyindisc_tick];
    DD_CHECK(fabs(title.alpha - 0.65) < 0.001 && [title.text isEqualToString:@"其他文案"], "label reuse restores visibility without writing stale text");
    DD_CHECK(siblingTitle.alpha == 0, "another still-valid local title remains hidden");
    title.attributedText = [[NSAttributedString alloc] initWithString:@"拍同款"];
    [driver douyindisc_tick];
    DD_CHECK(title.alpha == 0, "attributed exact title is suppressed");
    title.alpha = 0.4;
    [driver douyindisc_tick];
    [driver douyindisc_restore];
    DD_CHECK(fabs(title.alpha - 0.4) < 0.001, "native alpha update is retained as the latest restoration baseline");
    [driver douyindisc_tick];
    UIView *parent = disc.superview;
    id pixels = driver.douyindisc_original;
    [disc removeFromSuperview];
    [driver douyindisc_tick];
    DD_CHECK(!driver.douyindisc_overlay && cover.layer.contents == pixels, "detached target ends lease instead of leaking artwork");
    DD_CHECK(fabs(title.alpha - 0.4) < 0.001 && siblingTitle.alpha == 1, "detached target restores its local labels");
    [parent addSubview:disc];
    [driver douyindisc_tick];
    DD_CHECK(driver.douyindisc_cover == cover, "newly attached target needs and passes a fresh guarded match");
    disc.accessibilityLabel = @"分享";
    [driver douyindisc_tick];
    DD_CHECK(!driver.douyindisc_overlay, "role reuse invalidates retained lease");
    disc.accessibilityLabel = @"拍同款";
    [driver douyindisc_tick];
    UIImageView *replacement = [[UIImageView alloc] initWithImage:cover.image];
    replacement.frame = cover.frame;
    [cover removeFromSuperview];
    [disc addSubview:replacement];
    [replacement.layer displayIfNeeded];
    [driver douyindisc_tick];
    DD_CHECK(driver.douyindisc_cover == replacement && driver.douyindisc_overlay.superlayer == replacement.layer, "renderer replacement relinquishes old owner and matches new image");
    [driver douyindisc_restore];
    [replacement removeFromSuperview];
    [disc addSubview:cover];
    [cover.layer displayIfNeeded];
    [driver douyindisc_tick];
}
