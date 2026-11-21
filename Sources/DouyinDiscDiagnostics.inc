// Temporary, opt-in local visual trace. Never reads message/video/image contents.
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <dlfcn.h>
#import <mach-o/loader.h>

static NSString *douyindisc_diag_imageUUID(void) {
    Dl_info info={0};
    if (!dladdr((const void *)douyindisc_diag_install,&info) || !info.dli_fbase) return @"unknown";
    const struct mach_header_64 *header=info.dli_fbase;
    if (header->magic!=MH_MAGIC_64 || header->sizeofcmds>1024*1024 || header->ncmds>512) return @"unknown";
    const unsigned char *cursor=(const unsigned char *)(header+1), *end=cursor+header->sizeofcmds;
    for (uint32_t i=0; i<header->ncmds && cursor+sizeof(struct load_command)<=end; ++i) {
        const struct load_command *command=(const struct load_command *)cursor;
        if (command->cmdsize<sizeof(*command) || cursor+command->cmdsize>end) break;
        if (command->cmd==LC_UUID && command->cmdsize==sizeof(struct uuid_command)) {
            return [[NSUUID alloc] initWithUUIDBytes:((const struct uuid_command *)command)->uuid].UUIDString;
        }
        cursor+=command->cmdsize;
    }
    return @"unknown";
}

static const NSUInteger douyindisc_diag_eventLimit = 1024;
static const NSUInteger douyindisc_diag_byteLimit = 256 * 1024;
static id douyindisc_diagnostics;

static NSNumber *douyindisc_diag_number(double value) {
    return @(isfinite(value) ? round(value * 10000.0) / 10000.0 : 0);
}
static NSArray *douyindisc_diag_rect(CGRect r) {
    return @[douyindisc_diag_number(r.origin.x), douyindisc_diag_number(r.origin.y),
             douyindisc_diag_number(r.size.width), douyindisc_diag_number(r.size.height)];
}
static NSArray *douyindisc_diag_transform(CATransform3D t) {
    const CGFloat values[] = {t.m11,t.m12,t.m13,t.m14,t.m21,t.m22,t.m23,t.m24,
                              t.m31,t.m32,t.m33,t.m34,t.m41,t.m42,t.m43,t.m44};
    NSMutableArray *out = [NSMutableArray array];
    for (unsigned int i=0; i<16; ++i) [out addObject:douyindisc_diag_number(values[i])];
    return out;
}
static NSArray *douyindisc_diag_color(CGColorRef color) {
    if (!color) return @[];
    CGFloat red=0, green=0, blue=0, alpha=0;
    if (![[UIColor colorWithCGColor:color] getRed:&red green:&green blue:&blue alpha:&alpha]) return @[];
    return @[douyindisc_diag_number(red),douyindisc_diag_number(green),
             douyindisc_diag_number(blue),douyindisc_diag_number(alpha)];
}

@interface DouyinDiscDiagnostics : NSObject
@property (nonatomic, weak) DouyinDiscDisplay *douyindisc_driver;
@property (nonatomic, strong) UIButton *douyindisc_button;
@property (nonatomic, weak) UIWindow *douyindisc_window;
@property (nonatomic, strong) NSTimer *douyindisc_timer;
@property (nonatomic, strong) NSURL *douyindisc_file;
@property (nonatomic, strong) NSMapTable<id,NSNumber *> *douyindisc_ids;
@property (nonatomic) NSUInteger douyindisc_nextID;
@property (nonatomic, strong) NSMutableDictionary<NSString *,NSDictionary *> *douyindisc_lastState;
@property (nonatomic, strong) NSMapTable<UIControl *,NSNumber *> *douyindisc_lastBefore;
@property (nonatomic, strong) NSHashTable<UIControl *> *douyindisc_pending;
@property (nonatomic, strong) NSHashTable<UIControl *> *douyindisc_selected;
@property (nonatomic) int douyindisc_fd;
@property (nonatomic) NSUInteger douyindisc_events;
@property (nonatomic) NSUInteger douyindisc_bytes;
@property (nonatomic) CFTimeInterval douyindisc_deadline;
@property (nonatomic) CFTimeInterval douyindisc_started;
@property (nonatomic) BOOL douyindisc_completed;
@property (nonatomic) BOOL douyindisc_exported;
@property (nonatomic, copy) ssize_t (^douyindisc_writeOverride)(const void *,NSUInteger);
@property (nonatomic) BOOL douyindisc_wroteCaptureStart;
- (void)douyindisc_attach;
- (void)douyindisc_begin;
- (void)douyindisc_stop:(NSString *)reason;
- (void)douyindisc_sample;
- (void)douyindisc_note:(UIControl *)control surface:(DouyinDiscSurface *)surface phase:(const char *)phase;
@end

@implementation DouyinDiscDiagnostics
- (instancetype)init {
    self=[super init];
    if (self) _douyindisc_fd=-1;
    return self;
}
- (NSNumber *)douyindisc_id:(id)object {
    if (!object || (![object isKindOfClass:UIView.class] && ![object isKindOfClass:CALayer.class])) return @0;
    // Weak pointer-identity keys disappear with their owners. The monotonic counter
    // never reuses IDs even when UIKit allocates a new object at an old address.
    NSNumber *number=[self.douyindisc_ids objectForKey:object];
    if (!number && self.douyindisc_nextID<2048) {
        number=@(++self.douyindisc_nextID);
        [self.douyindisc_ids setObject:number forKey:object];
    }
    return number ?: @0;
}
- (ssize_t)douyindisc_writeBytes:(const void *)bytes length:(NSUInteger)length {
    if (self.douyindisc_writeOverride) return self.douyindisc_writeOverride(bytes,length);
    return write(self.douyindisc_fd,bytes,length);
}
- (void)douyindisc_append:(NSDictionary *)event {
    if (!douyindisc_diag_enabled || self.douyindisc_fd<0) return;
    BOOL startingRecord=[event[@"event"] isEqual:@"capture-start"];
    NSMutableDictionary *record=[event mutableCopy];
    record[@"t"]=douyindisc_diag_number(CACurrentMediaTime()-self.douyindisc_started);
    NSData *json=[NSJSONSerialization dataWithJSONObject:record options:0 error:NULL];
    if (!json) { [self douyindisc_stop:@"serialization-failed"]; return; }
    if (self.douyindisc_events>=douyindisc_diag_eventLimit-1 ||
        self.douyindisc_bytes+json.length+1>douyindisc_diag_byteLimit-512) {
        [self douyindisc_stop:@"budget-limit"]; return;
    }
    NSMutableData *line=[json mutableCopy]; [line appendBytes:"\n" length:1];
    const unsigned char *bytes=line.bytes; NSUInteger left=line.length;
    while (left) {
        ssize_t count=[self douyindisc_writeBytes:bytes length:left];
        if (count<=0) {
            if (startingRecord) {
                douyindisc_diag_enabled=NO;
                close(self.douyindisc_fd); self.douyindisc_fd=-1;
                unlink(self.douyindisc_file.fileSystemRepresentation); self.douyindisc_file=nil;
                self.douyindisc_completed=NO; self.douyindisc_wroteCaptureStart=NO;
                [self.douyindisc_button setTitle:@"取证写入失败·重试" forState:UIControlStateNormal];
                return;
            }
            [self douyindisc_stop:@"write-failed"]; return;
        }
        left-=(NSUInteger)count; bytes+=count;
    }
    self.douyindisc_bytes+=line.length; ++self.douyindisc_events;
    if (startingRecord) self.douyindisc_wroteCaptureStart=YES;
}
- (void)douyindisc_state:(NSDictionary *)state kind:(NSString *)kind identity:(NSNumber *)identity {
    if (!douyindisc_diag_enabled) return;
    NSString *key=[NSString stringWithFormat:@"%@:%@",kind,identity];
    if ([self.douyindisc_lastState[key] isEqual:state]) return;
    self.douyindisc_lastState[key]=state;
    NSMutableDictionary *event=[state mutableCopy]; event[@"event"]=kind; event[@"id"]=identity;
    [self douyindisc_append:event];
}
- (void)douyindisc_stop:(NSString *)reason {
    BOOL wasEnabled=douyindisc_diag_enabled;
    if (!self.douyindisc_wroteCaptureStart) {
        douyindisc_diag_enabled=NO;
        [self.douyindisc_timer invalidate]; self.douyindisc_timer=nil;
        if (self.douyindisc_fd>=0) { close(self.douyindisc_fd); self.douyindisc_fd=-1; }
        self.douyindisc_completed=NO;
        [self.douyindisc_button setTitle:@"取证写入失败·重试" forState:UIControlStateNormal];
        return;
    }
    douyindisc_diag_enabled=NO;
    [self.douyindisc_timer invalidate]; self.douyindisc_timer=nil;
    if (self.douyindisc_fd>=0) {
        if (wasEnabled) {
            NSDictionary *end=@{@"event":@"capture-end",@"reason":reason,
                @"events":@(self.douyindisc_events),@"t":douyindisc_diag_number(CACurrentMediaTime()-self.douyindisc_started)};
            NSData *data=[NSJSONSerialization dataWithJSONObject:end options:0 error:NULL];
            if (data.length && self.douyindisc_bytes+data.length+1<=douyindisc_diag_byteLimit) {
                write(self.douyindisc_fd,data.bytes,data.length); write(self.douyindisc_fd,"\n",1);
                self.douyindisc_bytes+=data.length+1; ++self.douyindisc_events;
            }
        }
        close(self.douyindisc_fd); self.douyindisc_fd=-1;
    }
    self.douyindisc_completed=wasEnabled || self.douyindisc_completed;
    [self.douyindisc_button setTitle:self.douyindisc_completed ? @"导出取证" : @"圆盘取证" forState:UIControlStateNormal];
}

- (NSDictionary *)douyindisc_layerState:(CALayer *)layer {
    CALayer *presentation=layer.presentationLayer;
    NSMutableDictionary *state=[@{
        @"class":NSStringFromClass(layer.class), @"parent":[self douyindisc_id:layer.superlayer],
        @"bounds":douyindisc_diag_rect(layer.bounds),
        @"position":@[douyindisc_diag_number(layer.position.x),douyindisc_diag_number(layer.position.y)],
        @"opacity":douyindisc_diag_number(layer.opacity), @"hidden":@(layer.hidden),
        @"background":douyindisc_diag_color(layer.backgroundColor), @"opaque":@(layer.opaque),
        @"cornerRadius":douyindisc_diag_number(layer.cornerRadius), @"clips":@(layer.masksToBounds),
        @"transform":douyindisc_diag_transform(layer.transform),
        @"sublayerTransform":douyindisc_diag_transform(layer.sublayerTransform),
        @"mask":[self douyindisc_id:layer.mask],
        @"contentsIsCustom":@(layer.contents == (__bridge id)self.douyindisc_driver.douyindisc_image.CGImage),
        @"contentsPresent":@(layer.contents!=nil), @"shadowOpacity":douyindisc_diag_number(layer.shadowOpacity),
        @"shadowRadius":douyindisc_diag_number(layer.shadowRadius),
        @"shadowOffset":@[douyindisc_diag_number(layer.shadowOffset.width),douyindisc_diag_number(layer.shadowOffset.height)],
        @"shadowColor":douyindisc_diag_color(layer.shadowColor), @"shadowPathPresent":@(layer.shadowPath!=NULL),
        @"rasterized":@(layer.shouldRasterize), @"scale":douyindisc_diag_number(layer.contentsScale)
    } mutableCopy];
    if (layer.shadowPath) state[@"shadowBounds"]=douyindisc_diag_rect(CGPathGetBoundingBox(layer.shadowPath));
    if (layer.mask) {
        state[@"maskBounds"]=douyindisc_diag_rect(layer.mask.bounds);
        state[@"maskOpacity"]=douyindisc_diag_number(layer.mask.opacity);
        state[@"maskContentsPresent"]=@(layer.mask.contents!=nil);
        state[@"maskBackground"]=douyindisc_diag_color(layer.mask.backgroundColor);
        state[@"maskPresentationPresent"]=@(layer.mask.presentationLayer!=nil);
    }
    if (presentation) {
        state[@"presentationOpacity"]=douyindisc_diag_number(presentation.opacity);
        state[@"presentationHidden"]=@(presentation.hidden);
        state[@"presentationTransform"]=douyindisc_diag_transform(presentation.transform);
        state[@"presentationMaskPresent"]=@(presentation.mask!=nil);
        state[@"presentationShadowOpacity"]=douyindisc_diag_number(presentation.shadowOpacity);
    }
    return state;
}
- (void)douyindisc_recordView:(UIView *)view window:(UIWindow *)window {
    if (!douyindisc_diag_enabled) return;
    NSString *role=@"other";
    if (douyindisc_nativeMusic((UIControl *)view)) role=@"verified-music";
    else if ([view isKindOfClass:UILabel.class]) {
        UILabel *label=(UILabel *)view;
        NSString *text=label.attributedText.length ? label.attributedText.string : label.text;
        if ([text isEqualToString:@"拍同款"]) role=@"shoot-same";
        else if ([text isEqualToString:@"玩同款"]) role=@"play-same";
        else role=@"other-label";
    } else if ([view isKindOfClass:UIControl.class]) {
        NSString *label=view.accessibilityLabel;
        if ([label isEqualToString:@"分享"] || [label isEqualToString:@"转发"]) role=@"share";
        else role=@"other-control";
    }
    NSDictionary *state=@{@"class":NSStringFromClass(view.class),@"role":role,
        @"parent":[self douyindisc_id:view.superview],@"window":[self douyindisc_id:view.window],
        @"layer":[self douyindisc_id:view.layer],@"windowRect":douyindisc_diag_rect([view convertRect:view.bounds toView:window]),
        @"alpha":douyindisc_diag_number(view.alpha),@"hidden":@(view.hidden),
        @"interactive":@(view.userInteractionEnabled),@"clips":@(view.clipsToBounds)};
    [self douyindisc_state:state kind:@"view" identity:[self douyindisc_id:view]];
}
- (BOOL)douyindisc_visibleControl:(UIControl *)control {
    UIWindow *window=control.window;
    if (!window || !douyindisc_nativeMusic(control) || !douyindisc_visibleToWindow(control,window)) return NO;
    CGRect frame=[control convertRect:control.bounds toView:window];
    return CGRectIntersectsRect(window.bounds,frame) && CGRectGetMidX(frame)>window.bounds.size.width*.7;
}
- (void)douyindisc_note:(UIControl *)control surface:(DouyinDiscSurface *)surface phase:(const char *)phase {
    if (!douyindisc_diag_enabled || !NSThread.isMainThread ||
        ![self.douyindisc_selected containsObject:control] || ![self douyindisc_visibleControl:control]) return;
    CFTimeInterval now=CACurrentMediaTime();
    if (now>=self.douyindisc_deadline) { [self douyindisc_stop:@"time-limit"]; return; }
    BOOL before=!strcmp(phase,"refresh-before");
    if (before) {
        NSNumber *last=[self.douyindisc_lastBefore objectForKey:control];
        if (last && now-last.doubleValue<.5) return;
        [self.douyindisc_lastBefore setObject:@(now) forKey:control];
        [self.douyindisc_pending addObject:control];
    } else {
        if (![self.douyindisc_pending containsObject:control]) return;
        [self.douyindisc_pending removeObject:control];
    }
    NSMutableArray *visuals=[NSMutableArray array];
    for (DouyinDiscVisual *visual in surface.douyindisc_visuals) {
        if (visuals.count>=16) break;
        UIView *view=visual.douyindisc_view;
        if (!view) continue;
        [visuals addObject:@{@"view":[self douyindisc_id:view],@"alpha":douyindisc_diag_number(view.alpha),
            @"layerOpacity":douyindisc_diag_number(view.layer.opacity),@"maskOwned":@(view.layer.mask==visual.douyindisc_zeroMask),
            @"maskPresent":@(view.layer.mask!=nil),@"preservesAlpha":@(visual.douyindisc_preserveAlpha)}];
    }
    [self douyindisc_append:@{@"event":before ? @"refresh-before" : @"refresh-after",@"control":[self douyindisc_id:control],
        @"canvas":[self douyindisc_id:surface.douyindisc_canvas],@"surfacePresent":@(surface!=nil),
        @"overlayAttached":@(surface.douyindisc_overlay.superlayer!=nil),@"buttonMaskPresent":@(control.layer.mask!=nil),
        @"buttonAlpha":douyindisc_diag_number(control.alpha),@"visuals":visuals}];
}
- (void)douyindisc_graph:(UIControl *)control {
    UIWindow *window=control.window;
    DouyinDiscSurface *surface=objc_getAssociatedObject(control,&douyindisc_leaseKey);
    UIView *scope=surface.douyindisc_canvas ?: control.superview;
    if (!scope || scope==window || scope==window.rootViewController.viewIfLoaded || scope.window!=window) return;
    CGRect region=CGRectInset([control convertRect:control.bounds toView:window],-16,-32);
    NSMutableArray<UIView *> *views=[NSMutableArray arrayWithObject:scope];
    NSMutableArray<CALayer *> *layers=[NSMutableArray array];
    NSUInteger scanned=0,recorded=0;
    while (views.count && ++scanned<=96 && recorded<24 && douyindisc_diag_enabled) {
        UIView *view=views.lastObject; [views removeLastObject];
        if (view.window!=window) continue;
        CGRect frame=[view convertRect:view.bounds toView:window];
        if (!CGRectIntersectsRect(region,frame) && ![control isDescendantOfView:view]) continue;
        [self douyindisc_recordView:view window:window]; ++recorded;
        [layers addObject:view.layer];
        if (views.count+view.subviews.count<=96) [views addObjectsFromArray:view.subviews];
    }
    // Include a few containing views but never traverse their unrelated descendants.
    UIView *ancestor=scope.superview;
    for (unsigned int n=0; ancestor && n<4 && douyindisc_diag_enabled; ++n,ancestor=ancestor.superview) {
        [self douyindisc_recordView:ancestor window:window];
        [self douyindisc_state:[self douyindisc_layerState:ancestor.layer] kind:@"layer" identity:[self douyindisc_id:ancestor.layer]];
        if (ancestor==window) break;
    }
    NSHashTable<CALayer *> *seen=[NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    NSUInteger count=0;
    while (layers.count && count<64 && douyindisc_diag_enabled) {
        CALayer *layer=layers.lastObject; [layers removeLastObject];
        if ([seen containsObject:layer]) continue;
        [seen addObject:layer]; ++count;
        [self douyindisc_state:[self douyindisc_layerState:layer] kind:@"layer" identity:[self douyindisc_id:layer]];
        if (layer==window.layer || count>48) continue;
        NSArray<CALayer *> *children=layer.sublayers;
        if (children.count>64 || layers.count+children.count>128) continue;
        for (CALayer *child in children) {
            CGRect rect=[child convertRect:child.bounds toLayer:window.layer];
            if (CGRectIntersectsRect(rect,region)) [layers addObject:child];
        }
    }
    if (scanned>96 || recorded==24 || layers.count) [self douyindisc_append:@{@"event":@"local-graph-truncated",@"control":[self douyindisc_id:control]}];
}
- (void)douyindisc_sample {
    if (!douyindisc_diag_enabled) return;
    if (UIApplication.sharedApplication.applicationState!=UIApplicationStateActive) { [self douyindisc_stop:@"inactive"]; return; }
    if (CACurrentMediaTime()>=self.douyindisc_deadline) { [self douyindisc_stop:@"time-limit"]; return; }
    NSUInteger count=0;
    self.douyindisc_selected=[NSHashTable weakObjectsHashTable];
    for (UIControl *control in self.douyindisc_driver.douyindisc_controls.allObjects) {
        if (![self douyindisc_visibleControl:control]) continue;
        [self.douyindisc_selected addObject:control];
        [self douyindisc_graph:control];
        if (++count>=3 || !douyindisc_diag_enabled) break;
    }
    if (!count) [self douyindisc_append:@{@"event":@"no-visible-verified-control"}];
}

- (void)douyindisc_begin {
    if (!NSThread.isMainThread || douyindisc_diag_enabled || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive) return;
    NSURL *documents=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *folder=[documents URLByAppendingPathComponent:@"DouyinDisc" isDirectory:YES];
    if (!documents || ![NSFileManager.defaultManager createDirectoryAtURL:folder withIntermediateDirectories:YES
        attributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} error:NULL]) return;
    self.douyindisc_file=[folder URLByAppendingPathComponent:@"DouyinDisc-visual-trace.jsonl"];
    int descriptor=open(self.douyindisc_file.fileSystemRepresentation,O_WRONLY|O_CREAT|O_TRUNC|O_NOFOLLOW,0600);
    if (descriptor<0) { [self.douyindisc_button setTitle:@"取证失败" forState:UIControlStateNormal]; return; }
    fchmod(descriptor,0600);
    self.douyindisc_fd=descriptor;
    self.douyindisc_events=0; self.douyindisc_bytes=0;
    self.douyindisc_completed=NO; self.douyindisc_exported=NO;
    self.douyindisc_ids=[NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality
        valueOptions:NSPointerFunctionsStrongMemory];
    self.douyindisc_nextID=0;
    self.douyindisc_lastState=[NSMutableDictionary dictionary];
    self.douyindisc_lastBefore=[NSMapTable weakToStrongObjectsMapTable];
    self.douyindisc_pending=[NSHashTable weakObjectsHashTable];
    self.douyindisc_started=CACurrentMediaTime(); self.douyindisc_deadline=self.douyindisc_started+20;
    self.douyindisc_wroteCaptureStart=NO;
    douyindisc_diag_enabled=YES;
    [self douyindisc_append:@{@"event":@"capture-start",@"schema":@"douyindisc-visual-v1",@"plugin":@"1.40-diagnostic",
        @"bundle":@"com.ss.iphone.ugc.Aweme",@"pid":@(getpid()),@"dylibUUID":douyindisc_diag_imageUUID(),
        @"appVersion":[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown",
        @"appBuild":[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"unknown",
        @"os":NSProcessInfo.processInfo.operatingSystemVersionString,@"session":NSUUID.UUID.UUIDString,
        @"durationLimit":@20,@"eventLimit":@(douyindisc_diag_eventLimit),@"byteLimit":@(douyindisc_diag_byteLimit),
        @"privacy":@"geometry-and-render-state-only-no-content",@"objectIDs":@"per-capture-not-addresses"}];
    if (!self.douyindisc_wroteCaptureStart || self.douyindisc_fd<0 || !douyindisc_diag_enabled) return;
    __weak DouyinDiscDiagnostics *weakSelf=self;
    self.douyindisc_timer=[NSTimer timerWithTimeInterval:.5 repeats:YES block:^(NSTimer *timer) {
        (void)timer; [weakSelf douyindisc_sample];
    }];
    self.douyindisc_timer.tolerance=.1;
    [NSRunLoop.mainRunLoop addTimer:self.douyindisc_timer forMode:NSRunLoopCommonModes];
    [self.douyindisc_button setTitle:@"停止并导出" forState:UIControlStateNormal];
    [self douyindisc_sample];
}
- (UIViewController *)douyindisc_presenter {
    UIViewController *controller=self.douyindisc_window.rootViewController;
    while (controller.presentedViewController && !controller.presentedViewController.isBeingDismissed) controller=controller.presentedViewController;
    return controller;
}
- (UIActivityViewController *)douyindisc_exportController {
    if (douyindisc_diag_enabled || !self.douyindisc_completed || !self.douyindisc_file) return nil;
    struct stat info;
    if (lstat(self.douyindisc_file.fileSystemRepresentation,&info) || !S_ISREG(info.st_mode) ||
        info.st_size<=0 || info.st_size>(off_t)douyindisc_diag_byteLimit) return nil;
    UIActivityViewController *sheet=[[UIActivityViewController alloc] initWithActivityItems:@[self.douyindisc_file] applicationActivities:nil];
    sheet.popoverPresentationController.sourceView=self.douyindisc_button;
    sheet.popoverPresentationController.sourceRect=self.douyindisc_button.bounds;
    return sheet;
}
- (void)douyindisc_tap:(id)sender {
    (void)sender;
    if (UIApplication.sharedApplication.applicationState!=UIApplicationStateActive) return;
    if (!self.douyindisc_completed && !douyindisc_diag_enabled) { [self douyindisc_begin]; return; }
    if (self.douyindisc_exported && !douyindisc_diag_enabled) { [self douyindisc_begin]; return; }
    if (douyindisc_diag_enabled) [self douyindisc_stop:@"user-stop"];
    UIActivityViewController *sheet=[self douyindisc_exportController];
    UIViewController *presenter=[self douyindisc_presenter];
    if (!sheet || !presenter || presenter.isBeingPresented || presenter.isBeingDismissed || [presenter isKindOfClass:UIActivityViewController.class]) return;
    __weak DouyinDiscDiagnostics *weakSelf=self;
    sheet.completionWithItemsHandler=^(UIActivityType type,BOOL completed,NSArray *items,NSError *error) {
        (void)type; (void)items; (void)error;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completed) {
                weakSelf.douyindisc_exported=YES;
                [weakSelf.douyindisc_button setTitle:@"重新取证" forState:UIControlStateNormal];
            }
        });
    };
    [presenter presentViewController:sheet animated:YES completion:nil];
}
- (void)douyindisc_attach {
    if (!NSThread.isMainThread || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive) return;
    UIWindow *candidate=nil;
    UIApplication *app=UIApplication.sharedApplication;
    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState!=UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow && window.windowLevel==UIWindowLevelNormal && !window.hidden) {
                if (candidate) return;
                candidate=window;
            }
        }
    }
    if (!app.connectedScenes.count && [app.delegate respondsToSelector:@selector(window)]) candidate=app.delegate.window;
    if (!candidate || candidate.windowLevel!=UIWindowLevelNormal || !candidate.isKeyWindow) return;
    if (!self.douyindisc_button) {
        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
        button.backgroundColor=[UIColor colorWithWhite:.12 alpha:.88];
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        button.titleLabel.font=[UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        button.layer.cornerRadius=8;
        button.accessibilityLabel=@"圆盘局部取证，仅主动点击才记录";
        [button setTitle:@"圆盘取证" forState:UIControlStateNormal];
        [button addTarget:self action:@selector(douyindisc_tap:) forControlEvents:UIControlEventTouchUpInside];
        self.douyindisc_button=button;
    }
    self.douyindisc_window=candidate;
    CGFloat y=MAX(candidate.safeAreaInsets.top+70,candidate.bounds.size.height*.35);
    self.douyindisc_button.frame=CGRectMake(10,y,92,34);
    if (self.douyindisc_button.superview!=candidate) [candidate addSubview:self.douyindisc_button];
    [candidate bringSubviewToFront:self.douyindisc_button];
}
- (void)douyindisc_active:(NSNotification *)notification { (void)notification; [self douyindisc_attach]; }
- (void)douyindisc_inactive:(NSNotification *)notification {
    (void)notification;
    if (douyindisc_diag_enabled) [self douyindisc_stop:@"inactive"];
}
@end

static void douyindisc_diag_note(UIControl *control,DouyinDiscSurface *surface,const char *phase) {
    if (!douyindisc_diag_enabled) return;
    [(DouyinDiscDiagnostics *)douyindisc_diagnostics douyindisc_note:control surface:surface phase:phase];
}
static void douyindisc_diag_install(DouyinDiscDisplay *driver) {
    if (douyindisc_diagnostics || !NSThread.isMainThread) return;
    DouyinDiscDiagnostics *diagnostics=[DouyinDiscDiagnostics new];
    diagnostics.douyindisc_driver=driver; douyindisc_diagnostics=diagnostics;
    NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
    [center addObserver:diagnostics selector:@selector(douyindisc_active:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [center addObserver:diagnostics selector:@selector(douyindisc_inactive:) name:UIApplicationWillResignActiveNotification object:nil];
    [diagnostics douyindisc_attach];
}
