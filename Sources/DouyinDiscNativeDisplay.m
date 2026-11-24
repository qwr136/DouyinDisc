#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "DouyinDiscNative.h"
#include <math.h>
#import "DouyinDiscHostVersion.h"
#include "DouyinDiscArtwork.inc"
#include "DouyinDiscBaseArtwork.inc"
#include "DouyinDiscAccentArcs.inc"
#include "DouyinDiscCenterRing.inc"
#include "DouyinDiscLifecycle.inc"

static UIImage *douyindisc_loadArtwork(void) {
    NSData *original = [NSData dataWithBytesNoCopy:(void *)douyindisc_artwork length:sizeof(douyindisc_artwork) freeWhenDone:NO];
    UIImage *fallback = [UIImage imageWithData:original];
    NSData *base = [NSData dataWithBytesNoCopy:(void *)douyindisc_base_artwork length:sizeof(douyindisc_base_artwork) freeWhenDone:NO];
    UIImage *image = [UIImage imageWithData:base];
    return image.CGImage && CGSizeEqualToSize(image.size, fallback.size) ? image : fallback;
}

static UIImage *douyindisc_loadAccentArcs(void) {
    NSData *data=[NSData dataWithBytesNoCopy:(void *)douyindisc_accent_arcs length:sizeof(douyindisc_accent_arcs) freeWhenDone:NO];
    UIImage *image=[UIImage imageWithData:data];
    return image.CGImage && CGSizeEqualToSize(image.size, CGSizeMake(512,512)) ? image : nil;
}

static UIImage *douyindisc_loadCenterRing(void) {
    NSData *data = [NSData dataWithBytesNoCopy:(void *)douyindisc_center_ring length:sizeof(douyindisc_center_ring) freeWhenDone:NO];
    UIImage *image=[UIImage imageWithData:data];
    return image.CGImage && CGSizeEqualToSize(image.size, CGSizeMake(512,512)) ? image : nil;
}

static NSString *const douyindisc_spinKey = @"com.minis.douyindisc.continuous";
static char douyindisc_leaseKey;
@class DouyinDiscSurface, DouyinDiscDisplay;

static DouyinDiscRect douyindisc_rect(UIView *view, UIView *space) {
    CGRect bounds = view.bounds;
    CGPoint center = [view convertPoint:CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds)) toView:space];
    return (DouyinDiscRect){center.x - bounds.size.width/2, center.y - bounds.size.height/2, bounds.size.width, bounds.size.height};
}

static BOOL douyindisc_visibleToWindow(UIView *view, UIWindow *window) {
    for (unsigned int n = 0; view && n < 48; view = view.superview, ++n) {
        if (view.hidden || view.alpha <= .05) return NO;
        if (view == window) return YES;
    }
    return NO;
}

static BOOL douyindisc_preparedGeometry(UIControl *control) {
    UIWindow *window = control.window;
    if (!window || window.windowLevel != UIWindowLevelNormal || !douyindisc_visibleToWindow(control, window)) return NO;
    if (window.windowScene && window.windowScene.activationState != UISceneActivationStateForegroundActive) return NO;
    DouyinDiscRect d = douyindisc_rect(control, window);
    CGRect b = window.bounds;
    // A verified incoming feed item is prepared before it crosses the viewport.
    if (!isfinite(d.y) || d.y < -b.size.height || d.y > b.size.height * 2) return NO;
    d.y = b.origin.y + b.size.height * .75;
    return douyindisc_disc_inside_rail(d, (DouyinDiscRect){b.origin.x,b.origin.y,b.size.width,b.size.height});
}

static UIView *douyindisc_scopedShare(UIControl *control) {
    UIWindow *window = control.window;
    CGRect b = window.bounds;
    DouyinDiscRect original = douyindisc_rect(control, window), normalized = original;
    normalized.y = b.origin.y + b.size.height * .75;
    for (UIView *scope = control.superview; scope && scope != window && scope != window.rootViewController.viewIfLoaded; scope = scope.superview) {
        NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:scope];
        NSUInteger visited = 0, matches = 0;
        while (pending.count) {
            if (++visited > 320) return nil;
            UIView *view = pending.lastObject; [pending removeLastObject];
            if (view.hidden || view.alpha <= .05 || view == control) continue;
            if ([view isKindOfClass:UIControl.class]) {
                NSString *label = view.accessibilityLabel;
                if ([label isEqualToString:@"分享"] || [label isEqualToString:@"转发"]) {
                    DouyinDiscRect share = douyindisc_rect(view, window);
                    share.y += normalized.y - original.y;
                    if (douyindisc_share_above(normalized, share, (DouyinDiscRect){b.origin.x,b.origin.y,b.size.width,b.size.height})) ++matches;
                }
            }
            if (pending.count + view.subviews.count > 320) return nil;
            [pending addObjectsFromArray:view.subviews];
        }
        if (matches) return matches == 1 ? scope : nil;
    }
    return nil;
}

#include "DouyinDiscLocalCaption.inc"

@interface DouyinDiscVisual : NSObject
@property (nonatomic, weak) UIView *douyindisc_view;
@property (nonatomic) CGFloat douyindisc_alpha;
@property (nonatomic) BOOL douyindisc_preserveAlpha;
@property (nonatomic, strong) CALayer *douyindisc_originalMask;
@property (nonatomic, strong) CALayer *douyindisc_zeroMask;
- (void)douyindisc_hide;
- (void)douyindisc_restore;
@end
@implementation DouyinDiscVisual
- (void)douyindisc_hide {
    UIView *view = self.douyindisc_view;
    if (!view) return;
    if (!self.douyindisc_preserveAlpha) {
        if (view.alpha != 0) self.douyindisc_alpha = view.alpha;
        view.alpha = 0;
    }
    if (!self.douyindisc_zeroMask) self.douyindisc_zeroMask = [CALayer layer];
    if (view.layer.mask != self.douyindisc_zeroMask) self.douyindisc_originalMask = view.layer.mask;
    self.douyindisc_zeroMask.frame = view.layer.bounds;
    view.layer.mask = self.douyindisc_zeroMask;
}
- (void)douyindisc_restore {
    UIView *view = self.douyindisc_view;
    if (view.layer.mask == self.douyindisc_zeroMask) view.layer.mask = self.douyindisc_originalMask;
    if (view && !self.douyindisc_preserveAlpha && view.alpha == 0) view.alpha = self.douyindisc_alpha;
}
@end

@interface DouyinDiscSurface : NSObject
@property (nonatomic, weak) UIControl *douyindisc_control;
@property (nonatomic, weak) UIWindow *douyindisc_window;
@property (nonatomic, weak) UIView *douyindisc_scope;
@property (nonatomic, weak) UIView *douyindisc_canvas;
@property (nonatomic, strong) CALayer *douyindisc_overlay;
@property (nonatomic, strong) CALayer *douyindisc_accentArcs;
@property (nonatomic, strong) CALayer *douyindisc_centerOverlay;
@property (nonatomic, strong) NSArray<DouyinDiscVisual *> *douyindisc_visuals;
- (void)douyindisc_restore;
@end
@implementation DouyinDiscSurface
- (void)douyindisc_restore {
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    [self.douyindisc_overlay removeFromSuperlayer];
    [self.douyindisc_accentArcs removeFromSuperlayer];
    [self.douyindisc_centerOverlay removeFromSuperlayer];
    for (DouyinDiscVisual *visual in self.douyindisc_visuals) [visual douyindisc_restore];
    [CATransaction commit];
    self.douyindisc_visuals = nil;
}
@end

@interface DouyinDiscDisplay : NSObject
@property (nonatomic, strong) UIImage *douyindisc_image;
@property (nonatomic, strong) NSHashTable<UIControl *> *douyindisc_controls;
@property (nonatomic, strong) NSTimer *douyindisc_timer;
@property (nonatomic) CFTimeInterval douyindisc_epoch;
@property (nonatomic) BOOL douyindisc_refreshing;
- (void)douyindisc_refresh:(UIControl *)control;
@end

static DouyinDiscDisplay *douyindisc_driver;
static void douyindisc_changed(UIControl *control) {
    [douyindisc_driver douyindisc_refresh:control];
}

@implementation DouyinDiscDisplay
- (instancetype)init {
    self = [super init];
    if (self) {
        _douyindisc_controls = [NSHashTable weakObjectsHashTable];
        _douyindisc_epoch = CACurrentMediaTime();
    }
    return self;
}

- (void)douyindisc_refresh:(UIControl *)control {
    if (!control || self.douyindisc_refreshing || !NSThread.isMainThread || !douyindisc_nativeMusic(control)) return;
    if (self.douyindisc_controls.count < 64) [self.douyindisc_controls addObject:control];
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    self.douyindisc_refreshing = YES;
    DouyinDiscSurface *surface = objc_getAssociatedObject(control, &douyindisc_leaseKey);
    BOOL sameScope = surface && surface.douyindisc_window == control.window && surface.douyindisc_scope == control.superview &&
        surface.douyindisc_canvas.window == control.window && [control isDescendantOfView:surface.douyindisc_canvas];
    if (surface && !sameScope) {
        [surface douyindisc_restore];
        objc_setAssociatedObject(control, &douyindisc_leaseKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        surface = nil;
    }
    UIView *canvas = sameScope ? surface.douyindisc_canvas : douyindisc_scopedShare(control);
    BOOL valid = douyindisc_preparedGeometry(control) && canvas;
    NSMutableArray<UIView *> *views = valid ? [douyindisc_nativeVisuals(control) mutableCopy] : [NSMutableArray array];
    if (valid) {
        for (UIView *label in douyindisc_localCaptions(control)) if (![views containsObject:label]) [views addObject:label];
        // Mask the verified button's native pixels, never its UIView hit target.
        // The custom artwork is rendered separately on the paired common canvas.
        [views addObject:control];
    }
    if (!views.count) {
        [surface douyindisc_restore];
        objc_setAssociatedObject(control, &douyindisc_leaseKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        self.douyindisc_refreshing = NO;
        return;
    }
    if (!surface) {
        surface = [DouyinDiscSurface new];
        surface.douyindisc_control = control;
        surface.douyindisc_window = control.window;
        surface.douyindisc_scope = control.superview;
        surface.douyindisc_canvas = canvas;
        surface.douyindisc_overlay = [CALayer layer];
        surface.douyindisc_overlay.name = @"DouyinDiscOuterArtwork";
        surface.douyindisc_overlay.contents = (__bridge id)self.douyindisc_image.CGImage;
        surface.douyindisc_overlay.contentsGravity = kCAGravityResizeAspect;
        UIImage *arcs=douyindisc_loadAccentArcs();
        if(arcs.CGImage){
            surface.douyindisc_accentArcs=[CALayer layer];
            surface.douyindisc_accentArcs.name=@"DouyinDiscAccentArcs80";
            surface.douyindisc_accentArcs.contents=(__bridge id)arcs.CGImage;
            surface.douyindisc_accentArcs.contentsGravity=kCAGravityResizeAspect;
        }
        UIImage *ring=douyindisc_loadCenterRing();
        if (ring.CGImage) {
            surface.douyindisc_centerOverlay=[CALayer layer];
            surface.douyindisc_centerOverlay.name=@"DouyinDiscCenterRing";
            surface.douyindisc_centerOverlay.contents=(__bridge id)ring.CGImage;
            surface.douyindisc_centerOverlay.contentsGravity=kCAGravityResizeAspect;
        }
        objc_setAssociatedObject(control, &douyindisc_leaseKey, surface, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    NSMutableArray<DouyinDiscVisual *> *next = [NSMutableArray array];
    for (DouyinDiscVisual *old in surface.douyindisc_visuals) {
        UIView *view = old.douyindisc_view;
        if (!view || ![views containsObject:view]) [old douyindisc_restore];
    }
    for (UIView *view in views) {
        DouyinDiscVisual *visual = nil;
        for (DouyinDiscVisual *old in surface.douyindisc_visuals) {
            if (old.douyindisc_view == view) { visual = old; break; }
        }
        if (!visual) {
            visual = [DouyinDiscVisual new]; visual.douyindisc_view = view; visual.douyindisc_alpha = view.alpha;
            visual.douyindisc_preserveAlpha = view == control;
        }
        [visual douyindisc_hide]; [next addObject:visual];
    }
    surface.douyindisc_visuals = next;
    CALayer *overlay = surface.douyindisc_overlay;
    CGRect frame = [control convertRect:control.bounds toView:canvas];
    CGFloat scale = control.window.screen.scale;
    overlay.bounds = (CGRect){CGPointZero, CGSizeMake(round(frame.size.width*scale)/scale, round(frame.size.height*scale)/scale)};
    overlay.position = CGPointMake(round(CGRectGetMidX(frame)*scale)/scale, round(CGRectGetMidY(frame)*scale)/scale);
    overlay.contentsScale = scale;
    overlay.opacity = 0.5f;
    overlay.minificationFilter = kCAFilterTrilinear;
    overlay.magnificationFilter = kCAFilterLinear;
    if (overlay.superlayer != canvas.layer) [canvas.layer addSublayer:overlay];
    CALayer *arcs=surface.douyindisc_accentArcs;
    if(arcs){
        arcs.bounds=overlay.bounds; arcs.position=overlay.position; arcs.contentsScale=scale;
        arcs.opacity=1.0f; arcs.minificationFilter=kCAFilterTrilinear; arcs.magnificationFilter=kCAFilterLinear;
        if(arcs.superlayer!=canvas.layer)[canvas.layer addSublayer:arcs];
    }
    CALayer *ring=surface.douyindisc_centerOverlay;
    if (ring) {
        ring.bounds=overlay.bounds; ring.position=overlay.position; ring.contentsScale=scale;
        ring.opacity=0.9f; ring.minificationFilter=kCAFilterTrilinear; ring.magnificationFilter=kCAFilterLinear;
        if (ring.superlayer != canvas.layer) [canvas.layer addSublayer:ring];
    }
    CALayer *spinLayers[3]={overlay,arcs,ring};
    if (UIAccessibilityIsReduceMotionEnabled()) {
        for(NSUInteger i=0;i<3;i++)[spinLayers[i] removeAnimationForKey:douyindisc_spinKey];
    } else {
        CABasicAnimation *spin=(CABasicAnimation *)[overlay animationForKey:douyindisc_spinKey];
        if(!spin){
            spin=[CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
            spin.fromValue=@0; spin.toValue=@(2*M_PI); spin.duration=7; spin.repeatCount=HUGE_VALF;
            spin.beginTime=[overlay convertTime:self.douyindisc_epoch fromLayer:nil];
            [overlay addAnimation:spin forKey:douyindisc_spinKey];
            spin=(CABasicAnimation *)[overlay animationForKey:douyindisc_spinKey];
        }
        for(NSUInteger i=1;i<3;i++){
            CALayer *layer=spinLayers[i];
            if(layer&&![layer animationForKey:douyindisc_spinKey]){
                CABasicAnimation *copy=[spin copy];
                copy.beginTime=[layer convertTime:self.douyindisc_epoch fromLayer:nil];
                [layer addAnimation:copy forKey:douyindisc_spinKey];
            }
        }
    }
    [CATransaction commit];
    self.douyindisc_refreshing = NO;
}

- (void)douyindisc_tick {
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    for (UIControl *control in self.douyindisc_controls.allObjects) [self douyindisc_refresh:control];
}

- (void)douyindisc_bootstrap:(UIWindow *)window {
    if (!window || window.windowLevel != UIWindowLevelNormal) return;
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:window];
    NSUInteger visited = 0;
    while (pending.count && ++visited <= 3000) {
        UIView *view = pending.lastObject; [pending removeLastObject];
        if ([view isKindOfClass:UIControl.class] && douyindisc_nativeMusic((UIControl *)view)) [self douyindisc_refresh:(UIControl *)view];
        if (pending.count + view.subviews.count > 3000) break;
        [pending addObjectsFromArray:view.subviews];
    }
}

- (void)douyindisc_becameActive:(NSNotification *)notification {
    (void)notification;
    UIApplication *app = UIApplication.sharedApplication;
    if (app.applicationState != UIApplicationStateActive) return;
    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) [self douyindisc_bootstrap:window];
    }
    if (!app.connectedScenes.count && [app.delegate respondsToSelector:@selector(window)]) [self douyindisc_bootstrap:app.delegate.window];
    if (!self.douyindisc_timer) {
        __weak DouyinDiscDisplay *weakSelf = self;
        self.douyindisc_timer = [NSTimer timerWithTimeInterval:.10 repeats:YES block:^(NSTimer *timer) {
            (void)timer; [weakSelf douyindisc_tick];
        }];
        self.douyindisc_timer.tolerance = .025;
        // Only weak known controls are revisited. No tree scan during a feed pan.
        [NSRunLoop.mainRunLoop addTimer:self.douyindisc_timer forMode:NSRunLoopCommonModes];
    }
    [self douyindisc_tick];
}

- (void)douyindisc_resignedActive:(NSNotification *)notification {
    (void)notification;
    [self.douyindisc_timer invalidate]; self.douyindisc_timer = nil;
    // Already-applied surfaces remain in inactive/system snapshots. No background work.
}

- (void)douyindisc_motionChanged:(NSNotification *)notification {
    (void)notification; [self douyindisc_tick];
}

- (void)douyindisc_start {
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(douyindisc_becameActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [center addObserver:self selector:@selector(douyindisc_resignedActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [center addObserver:self selector:@selector(douyindisc_motionChanged:) name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    [self douyindisc_becameActive:nil];
}
@end

void douyindisc_startDisplay(void) {
    if (douyindisc_driver || !NSThread.isMainThread) return;
    if (!douyindisc_hostVersionAllowed()) return;
    UIImage *image = douyindisc_loadArtwork();
    if (!image.CGImage) return;
    DouyinDiscDisplay *driver = [DouyinDiscDisplay new];
    driver.douyindisc_image = image;
    douyindisc_driver = driver;
    if (!douyindisc_installLifecycle(douyindisc_changed)) { douyindisc_driver = nil; return; }
    [driver douyindisc_start];
}
