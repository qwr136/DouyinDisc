
// Visual leases stay attached while the app is temporarily inactive. They never
// scan or run timers in the background, and are revalidated on the next active tick.
@interface DouyinDiscTextLease : NSObject
@property (nonatomic, weak) UILabel *douyindisc_label;
@property (nonatomic) CGFloat douyindisc_originalAlpha;
- (void)douyindisc_suppress;
- (void)douyindisc_restore;
@end

@implementation DouyinDiscTextLease
- (void)douyindisc_suppress {
    UILabel *label = self.douyindisc_label;
    if (label.alpha != 0) self.douyindisc_originalAlpha = label.alpha;
    label.alpha = 0;
}
- (void)douyindisc_restore {
    UILabel *label = self.douyindisc_label;
    if (label && label.alpha == 0) label.alpha = self.douyindisc_originalAlpha;
}
@end

static BOOL douyindisc_ancestorsVisible(UIView *view, UIWindow *window) {
    for (unsigned int depth = 0; view && depth < 48; view = view.superview, ++depth) {
        if (!douyindisc_visible(view)) return NO;
        if (view == window) return YES;
    }
    return NO;
}

static BOOL douyindisc_discRole(UIControl *disc) {
    NSString *label = disc.accessibilityLabel;
    return [label isEqualToString:@"音乐详情"] || [label isEqualToString:@"拍同款"] ||
           (!label.length && [NSStringFromClass(disc.class) isEqualToString:@"AWEMusicCoverButton"]);
}

static BOOL douyindisc_titleFits(UILabel *label, UIControl *disc, UIWindow *window) {
    NSString *text = label.attributedText.length ? label.attributedText.string : label.text;
    if (![text isEqualToString:@"拍同款"] || label.hidden || label.userInteractionEnabled ||
        label.window != window || !douyindisc_ancestorsVisible(label.superview, window)) return NO;
    DouyinDiscRect d = douyindisc_rect(disc, window), t = douyindisc_rect(label, window);
    double dx = fabs((t.x + t.w * .5) - (d.x + d.w * .5));
    double cy = t.y + t.h * .5;
    return isfinite(dx) && isfinite(cy) && t.w > 0 && t.w <= d.w * 2.2 &&
           t.h > 0 && t.h <= 28 && dx <= d.w * .6 &&
           cy >= d.y + d.h * .45 && cy <= d.y + d.h + 28;
}

static NSArray<UILabel *> *douyindisc_localTitles(UIControl *disc, UIWindow *window) {
    // Only this disc and non-control siblings in its immediate container.
    // A separate button, captions elsewhere, and image-baked text are not edited.
    UIView *scope = disc.superview ?: disc;
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:scope];
    NSMutableArray<UILabel *> *titles = [NSMutableArray array];
    NSUInteger visited = 0;
    while (stack.count) {
        if (++visited > 96) return @[];
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        if (view.hidden || ([view isKindOfClass:UIControl.class] && view != disc && view != scope)) continue;
        if ([view isKindOfClass:UILabel.class] && douyindisc_titleFits((UILabel *)view, disc, window)) {
            [titles addObject:(UILabel *)view];
            if (titles.count > 4) return @[];
        } else if (!douyindisc_visible(view)) {
            continue;
        }
        if (stack.count + view.subviews.count > 96) return @[];
        [stack addObjectsFromArray:view.subviews];
    }
    return titles;
}
