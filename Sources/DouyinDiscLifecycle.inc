// Only subclass-local public UIView lifecycle methods are replaced. Original
// implementations, including inherited implementations, are forwarded once.
static void (*douyindisc_originalLayout)(id, SEL);
static void (*douyindisc_originalMove)(id, SEL);
static void (*douyindisc_viewChanged)(UIControl *);

static BOOL douyindisc_voidLifecycle(Method method) {
    if (!method || method_getNumberOfArguments(method) != 2) return NO;
    char result[32] = {0}, receiver[32] = {0}, selector[32] = {0};
    method_getReturnType(method, result, sizeof(result));
    method_getArgumentType(method, 0, receiver, sizeof(receiver));
    method_getArgumentType(method, 1, selector, sizeof(selector));
    return !strcmp(result, "v") && !strcmp(receiver, "@") && !strcmp(selector, ":");
}

static void douyindisc_afterLayout(id object, SEL selector) {
    douyindisc_originalLayout(object, selector);
    if (NSThread.isMainThread && douyindisc_viewChanged) douyindisc_viewChanged(object);
}

static void douyindisc_afterMove(id object, SEL selector) {
    douyindisc_originalMove(object, selector);
    if (NSThread.isMainThread && douyindisc_viewChanged) douyindisc_viewChanged(object);
}

static BOOL douyindisc_installLifecycle(void (*callback)(UIControl *)) {
    Class cls = NSClassFromString(@"AWEMusicCoverButton");
    if (!cls || ![cls isSubclassOfClass:UIControl.class]) return NO;
    Method layout = class_getInstanceMethod(cls, @selector(layoutSubviews));
    Method move = class_getInstanceMethod(cls, @selector(didMoveToWindow));
    if (!douyindisc_voidLifecycle(layout) || !douyindisc_voidLifecycle(move)) return NO;
    if (douyindisc_viewChanged) return douyindisc_viewChanged == callback;
    douyindisc_originalLayout = (void (*)(id, SEL))method_getImplementation(layout);
    douyindisc_originalMove = (void (*)(id, SEL))method_getImplementation(move);
    douyindisc_viewChanged = callback;
    if (!class_addMethod(cls, @selector(layoutSubviews), (IMP)douyindisc_afterLayout, method_getTypeEncoding(layout))) {
        method_setImplementation(class_getInstanceMethod(cls, @selector(layoutSubviews)), (IMP)douyindisc_afterLayout);
    }
    if (!class_addMethod(cls, @selector(didMoveToWindow), (IMP)douyindisc_afterMove, method_getTypeEncoding(move))) {
        method_setImplementation(class_getInstanceMethod(cls, @selector(didMoveToWindow)), (IMP)douyindisc_afterMove);
    }
    return YES;
}
