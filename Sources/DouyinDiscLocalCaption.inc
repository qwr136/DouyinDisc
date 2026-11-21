// Reuse the 0.30 device-confirmed exact-caption fallback. Scope is only the
// already matched music button and its immediate non-control container.
static NSArray<UIView *> *douyindisc_localCaptions(UIControl *control) {
    UIView *scope = control.superview ?: control;
    if ([scope isKindOfClass:UIControl.class] && scope != control) scope = control;
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:scope];
    NSMutableArray<UIView *> *labels = [NSMutableArray array];
    UIWindow *window = control.window;
    DouyinDiscRect disc = douyindisc_rect(control, window);
    NSUInteger visited = 0;
    while (pending.count) {
        if (++visited > 96) return @[];
        UIView *view = pending.lastObject; [pending removeLastObject];
        if (view.hidden || ([view isKindOfClass:UIControl.class] && view != control && view != scope)) continue;
        if ([view isKindOfClass:UILabel.class] && !view.userInteractionEnabled && view.window == window) {
            UILabel *label = (UILabel *)view;
            NSString *text = label.attributedText.length ? label.attributedText.string : label.text;
            if ([text isEqualToString:@"拍同款"]) {
                DouyinDiscRect r = douyindisc_rect(label, window);
                double dx = fabs((r.x+r.w*.5)-(disc.x+disc.w*.5));
                double cy = r.y+r.h*.5;
                if (r.w > 0 && r.w <= disc.w*2.2 && r.h > 0 && r.h <= 28 &&
                    dx <= disc.w*.6 && cy >= disc.y+disc.h*.45 && cy <= disc.y+disc.h+28) {
                    [labels addObject:label];
                    if (labels.count > 4) return @[];
                }
            }
        }
        if (pending.count + view.subviews.count > 96) return @[];
        [pending addObjectsFromArray:view.subviews];
    }
    return labels;
}
