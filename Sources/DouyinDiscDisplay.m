#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include "DouyinDiscPolicy.h"
#include "DouyinDiscArtwork.inc"

static const NSTimeInterval douyindisc_interval = 0.25;
static NSString *const douyindisc_spinKey = @"com.minis.douyindisc.spin";

static BOOL douyindisc_visible(UIView *view) {
    return !view.hidden && view.alpha > 0.05;
}

static DouyinDiscRect douyindisc_rect(UIView *view, UIView *space) {
    CGRect b = view.bounds;
    CGPoint c = [view convertPoint:CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b)) toView:space];
    return (DouyinDiscRect){ c.x - b.size.width / 2, c.y - b.size.height / 2, b.size.width, b.size.height };
}

static BOOL douyindisc_localPair(UIView *disc, UIView *share, UIWindow *window) {
    if ([disc isDescendantOfView:share] || [share isDescendantOfView:disc]) return NO;
    UIView *root = window.rootViewController.viewIfLoaded;
    unsigned int fromDisc = 0;
    for (UIView *a = disc.superview; a && a != root && a != window && fromDisc++ < 8; a = a.superview) {
        unsigned int fromShare = 0;
        for (UIView *b = share.superview; b && b != root && b != window && fromShare++ < 8; b = b.superview) {
            if (a == b) return YES;
        }
    }
    return NO;
}

static UIControl *douyindisc_findDisc(UIWindow *window) {
    CGRect bounds = window.bounds;
    DouyinDiscRect size = { bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height };
    CGRect rail = CGRectMake(bounds.origin.x + size.w * 0.68, bounds.origin.y + size.h * 0.23,
                             size.w * 0.32, size.h * 0.77);
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:window];
    NSMutableArray<UIControl *> *discs = [NSMutableArray array], *shares = [NSMutableArray array];
    NSUInteger visited = 0;
    while (stack.count) {
        if (++visited > 1400) return nil;
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        if (!douyindisc_visible(view)) continue;
        if (view.clipsToBounds && !CGRectIntersectsRect(rail, [view convertRect:view.bounds toView:window])) continue;
        if ([view isKindOfClass:UIControl.class]) {
            NSString *label = view.accessibilityLabel;
            if ([label isEqualToString:@"分享"] || [label isEqualToString:@"转发"]) {
                [shares addObject:(UIControl *)view];
            } else if (douyindisc_disc_inside_rail(douyindisc_rect(view, window), size)) {
                BOOL role = [label isEqualToString:@"音乐详情"] || [label isEqualToString:@"拍同款"];
                // The class name is a cross-version hint, not a private method or a layout guarantee.
                if (role || (!label.length && [NSStringFromClass(view.class) isEqualToString:@"AWEMusicCoverButton"])) {
                    [discs addObject:(UIControl *)view];
                }
            }
        }
        if (stack.count + view.subviews.count > 1400 || discs.count > 8 || shares.count > 20) return nil;
        [stack addObjectsFromArray:view.subviews];
    }
    UIControl *match = nil;
    for (UIControl *disc in discs) {
        NSUInteger nearby = 0;
        for (UIControl *share in shares) {
            if (douyindisc_share_above(douyindisc_rect(disc, window), douyindisc_rect(share, window), size) &&
                douyindisc_localPair(disc, share, window)) ++nearby;
        }
        if (nearby > 1 || (nearby && match)) return nil;
        if (nearby) match = disc;
    }
    return match;
}

static UIImageView *douyindisc_findCover(UIControl *disc) {
    if (!disc) return nil;
    CGRect b = disc.bounds;
    DouyinDiscRect area = { b.origin.x, b.origin.y, b.size.width, b.size.height };
    NSMutableArray<UIView *> *stack = [disc.subviews mutableCopy];
    UIImageView *match = nil;
    NSUInteger visited = 0;
    while (stack.count) {
        if (++visited > 96) return nil;
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        if (!douyindisc_visible(view) || [view isKindOfClass:UIControl.class]) continue;
        if ([view isKindOfClass:UIImageView.class] && !view.userInteractionEnabled &&
            douyindisc_cover_fits(douyindisc_rect(view, disc), area)) {
            UIImageView *image = (UIImageView *)view;
            if (image.image.CGImage && image.layer.contents) {
                if (match) return nil;
                match = image;
            }
        }
        if (stack.count + view.subviews.count > 96) return nil;
        [stack addObjectsFromArray:view.subviews];
    }
    return match;
}

static BOOL douyindisc_rotationAnimation(CAAnimation *animation, unsigned int depth) {
    if ([animation isKindOfClass:CAPropertyAnimation.class]) {
        NSString *path = ((CAPropertyAnimation *)animation).keyPath;
        if ([path isEqualToString:@"transform.rotation"] || [path isEqualToString:@"transform.rotation.z"]) return YES;
    }
    if (depth && [animation isKindOfClass:CAAnimationGroup.class]) {
        NSArray<CAAnimation *> *children = ((CAAnimationGroup *)animation).animations;
        if (children.count > 16) return NO;
        for (CAAnimation *child in children) if (douyindisc_rotationAnimation(child, depth - 1)) return YES;
    }
    return NO;
}

static BOOL douyindisc_sampleRotation(CALayer *layer, CALayer *discLayer, double *angle) {
    double accumulated = 0;
    BOOL rotating = NO;
    for (CALayer *part = layer; part; part = part.superlayer) {
        CALayer *presentation = part.presentationLayer;
        CATransform3D t = part.transform, p = presentation ? presentation.transform : t;
        double before = atan2(t.m12, t.m11), current = atan2(p.m12, p.m11);
        accumulated += current;
        if (fabs(remainder(current - before, 2.0 * M_PI)) > 0.035) rotating = YES;
        for (NSString *key in part.animationKeys) {
            if (douyindisc_rotationAnimation([part animationForKey:key], 2)) rotating = YES;
        }
        if (part == discLayer) break;
    }
    *angle = accumulated;
    return rotating;
}

static UIWindow *douyindisc_keyWindow(UIApplication *app) {
    UIWindow *key = nil;
    NSSet<UIScene *> *scenes = app.connectedScenes;
    for (UIScene *scene in scenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (!window.isKeyWindow || window.windowLevel != UIWindowLevelNormal || !douyindisc_visible(window)) continue;
            if (key) return nil;
            key = window;
        }
    }
    if (!scenes.count && [app.delegate respondsToSelector:@selector(window)]) {
        UIWindow *window = app.delegate.window;
        if (window.isKeyWindow && window.windowLevel == UIWindowLevelNormal && douyindisc_visible(window)) key = window;
    }
    return key;
}

#include "DouyinDiscVisualLease.inc"

@interface DouyinDiscDisplay : NSObject
@property (nonatomic, strong) NSTimer *douyindisc_timer;
@property (nonatomic, strong) UIImage *douyindisc_image;
@property (nonatomic, strong) UIImage *douyindisc_clear;
@property (nonatomic, weak) UIImageView *douyindisc_cover;
@property (nonatomic, weak) UIControl *douyindisc_disc;
@property (nonatomic, weak) UIWindow *douyindisc_window;
@property (nonatomic, strong) NSArray<DouyinDiscTextLease *> *douyindisc_titles;
@property (nonatomic, strong) CALayer *douyindisc_overlay;
@property (nonatomic, strong) id douyindisc_original;
@property (nonatomic) NSUInteger douyindisc_samples;
@property (nonatomic) double douyindisc_angle;
@property (nonatomic) BOOL douyindisc_nativeSpin;
@end

@implementation DouyinDiscDisplay

- (void)douyindisc_restore {
    for (DouyinDiscTextLease *title in self.douyindisc_titles) [title douyindisc_restore];
    self.douyindisc_titles = nil;
    self.douyindisc_disc = nil;
    self.douyindisc_window = nil;
    CALayer *overlay = self.douyindisc_overlay;
    CALayer *target = self.douyindisc_cover.layer;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (overlay && target.contents == (__bridge id)self.douyindisc_clear.CGImage) {
        target.contents = self.douyindisc_original;
    }
    [overlay removeFromSuperlayer];
    [CATransaction commit];
    self.douyindisc_cover = nil;
    self.douyindisc_overlay = nil;
    self.douyindisc_original = nil;
    self.douyindisc_samples = 0;
    self.douyindisc_nativeSpin = NO;
}

- (BOOL)douyindisc_leaseValid {
    UIControl *disc = self.douyindisc_disc;
    UIImageView *cover = self.douyindisc_cover;
    UIWindow *window = self.douyindisc_window;
    if (!disc || !cover || !window || disc.window != window || cover.window != window ||
        ![cover isDescendantOfView:disc] || !douyindisc_discRole(disc) ||
        !douyindisc_ancestorsVisible(disc, window)) return NO;
    if (window.windowScene && window.windowScene.activationState != UISceneActivationStateForegroundActive) return NO;
    CGRect b = window.bounds;
    DouyinDiscRect area = { b.origin.x, b.origin.y, b.size.width, b.size.height };
    return douyindisc_disc_inside_rail(douyindisc_rect(disc, window), area) &&
           douyindisc_findCover(disc) == cover;
}

- (void)douyindisc_updateTitles:(UIControl *)disc window:(UIWindow *)window {
    NSArray<UILabel *> *labels = douyindisc_localTitles(disc, window);
    NSMutableArray<DouyinDiscTextLease *> *next = [NSMutableArray array];
    for (DouyinDiscTextLease *old in self.douyindisc_titles) {
        UILabel *label = old.douyindisc_label;
        if (!label || ![labels containsObject:label]) [old douyindisc_restore];
    }
    for (UILabel *label in labels) {
        DouyinDiscTextLease *lease = nil;
        for (DouyinDiscTextLease *old in self.douyindisc_titles) {
            if (old.douyindisc_label == label) { lease = old; break; }
        }
        if (!lease) {
            lease = [DouyinDiscTextLease new];
            lease.douyindisc_label = label;
            lease.douyindisc_originalAlpha = label.alpha;
        }
        [lease douyindisc_suppress];
        [next addObject:lease];
    }
    self.douyindisc_titles = next;
}

- (void)douyindisc_tick {
    UIApplication *app = UIApplication.sharedApplication;
    if (app.applicationState != UIApplicationStateActive) return;

    // Preserve the known renderer through temporary modal/key-window changes.
    // Retention is not permission to acquire another renderer without a fresh match.
    BOOL continuing = [self douyindisc_leaseValid];
    UIWindow *window = continuing ? self.douyindisc_window : douyindisc_keyWindow(app);
    UIControl *disc = continuing ? self.douyindisc_disc : (window ? douyindisc_findDisc(window) : nil);
    UIImageView *cover = continuing ? self.douyindisc_cover : douyindisc_findCover(disc);
    if (!continuing) [self douyindisc_restore];
    if (!cover) return;
    self.douyindisc_disc = disc;
    self.douyindisc_window = window;
    [self douyindisc_updateTitles:disc window:window];

    CALayer *target = cover.layer;
    id clear = (__bridge id)self.douyindisc_clear.CGImage;
    CALayer *overlay = self.douyindisc_overlay;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (!overlay) {
        overlay = [CALayer layer];
        overlay.name = @"DouyinDiscCover";
        overlay.contentsGravity = kCAGravityResizeAspect;
        overlay.contents = (__bridge id)self.douyindisc_image.CGImage;
        self.douyindisc_overlay = overlay;
        self.douyindisc_cover = cover;
    }
    if (target.contents != clear) {
        self.douyindisc_original = target.contents;
        // Suppress artwork pixels only; the native layer, masks and animations stay in place.
        target.contents = clear;
    }
    overlay.contentsScale = window.screen.scale;
    if (!CGRectEqualToRect(overlay.bounds, (CGRect){CGPointZero, target.bounds.size})) {
        overlay.bounds = (CGRect){CGPointZero, target.bounds.size};
    }
    overlay.position = CGPointMake(CGRectGetMidX(target.bounds), CGRectGetMidY(target.bounds));
    if (overlay.superlayer != target) [target addSublayer:overlay];

    double angle = 0;
    BOOL rotating = douyindisc_sampleRotation(target, disc.layer, &angle);
    if (self.douyindisc_samples && fabs(remainder(angle - self.douyindisc_angle, 2.0 * M_PI)) > 0.035) rotating = YES;
    self.douyindisc_nativeSpin |= rotating;
    self.douyindisc_angle = angle;
    self.douyindisc_samples = MIN(self.douyindisc_samples + 1, (NSUInteger)3);
    BOOL useFallback = self.douyindisc_samples >= 3 && !self.douyindisc_nativeSpin && !UIAccessibilityIsReduceMotionEnabled();
    if (!useFallback) {
        [overlay removeAnimationForKey:douyindisc_spinKey];
    } else if (![overlay animationForKey:douyindisc_spinKey]) {
        CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        spin.fromValue = @0.0;
        spin.toValue = @(2.0 * M_PI);
        spin.duration = 7.0;
        spin.repeatCount = HUGE_VALF;
        [overlay addAnimation:spin forKey:douyindisc_spinKey];
    }
    [CATransaction commit];
}

- (void)douyindisc_becameActive:(NSNotification *)notification {
    (void)notification;
    if (self.douyindisc_timer) return;
    __weak DouyinDiscDisplay *weakSelf = self;
    self.douyindisc_timer = [NSTimer timerWithTimeInterval:douyindisc_interval repeats:YES block:^(NSTimer *timer) {
        (void)timer;
        [weakSelf douyindisc_tick];
    }];
    self.douyindisc_timer.tolerance = 0.07;
    // Default mode deliberately avoids walking the feed mid-pan.
    [NSRunLoop.mainRunLoop addTimer:self.douyindisc_timer forMode:NSDefaultRunLoopMode];
    [self douyindisc_tick];
}

- (void)douyindisc_resignedActive:(NSNotification *)notification {
    (void)notification;
    [self.douyindisc_timer invalidate];
    self.douyindisc_timer = nil;
    // The compositor/switcher may snapshot this exact inactive view hierarchy.
    // Keep its already-owned artwork and label suppression, without background work.
}

- (void)douyindisc_start {
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(douyindisc_becameActive:)
                   name:UIApplicationDidBecomeActiveNotification object:nil];
    [center addObserver:self selector:@selector(douyindisc_resignedActive:)
                   name:UIApplicationWillResignActiveNotification object:nil];
    if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) [self douyindisc_becameActive:nil];
}
@end

void douyindisc_startDisplay(void) {
    static DouyinDiscDisplay *driver;
    // Called once on the main thread by the bundle/version-guarded entry.
    if (driver) return;
    NSData *bytes = [NSData dataWithBytesNoCopy:(void *)douyindisc_artwork length:sizeof(douyindisc_artwork) freeWhenDone:NO];
    UIImage *image = [UIImage imageWithData:bytes];
    if (!image.CGImage) return;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat new];
    format.scale = 1;
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(1, 1) format:format];
    UIImage *clear = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) { (void)context; }];
    if (!clear.CGImage) return;
    driver = [DouyinDiscDisplay new];
    driver.douyindisc_image = image;
    driver.douyindisc_clear = clear;
    [driver douyindisc_start];
}
