#import "DouyinDiscNavigation.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <string.h>
#import <math.h>

@interface NSObject (DouyinDiscRootModelAccessors)
- (instancetype)initWithIdentifier:(NSString *)identifier;
- (id)viewModel;
- (id)sectionDataArray;
- (id)itemArray;
- (NSString *)businessID;
- (NSInteger)type;
- (NSString *)title;
- (NSString *)identifier;
- (double)cellHeight;
- (void)setItemArray:(NSArray *)items;
- (void)setIdentifier:(NSString *)identifier;
- (void)setTitle:(NSString *)title;
- (void)setTitleColor:(UIColor *)color;
- (void)setSpecificIconImage:(UIImage *)image;
- (void)setIconImageName:(NSString *)name;
- (void)setType:(NSInteger)type;
- (void)setCellType:(NSInteger)type;
- (void)setCellHeight:(double)height;
- (void)setIsEnable:(BOOL)enabled;
- (void)setIsForbidChangeColor:(BOOL)forbid;
- (void)setUserInteractionEnabled:(BOOL)enabled;
- (void)setCellTappedBlock:(void (^)(void))block;
- (void)setUseStandardArrowImage:(BOOL)enabled;
- (BOOL)useStandardArrowImage;
@end
@interface DouyinDiscTextLease : NSObject
@property(nonatomic,weak) UILabel *douyindisc_label;
@property(nonatomic,weak) UIView *douyindisc_textView;
@property(nonatomic,copy) NSString *douyindisc_identifier;
@property(nonatomic) CGFloat douyindisc_originalAlpha;
@property(nonatomic,strong) CALayer *douyindisc_originalMask;
@property(nonatomic,strong) CAShapeLayer *douyindisc_ownedMask;
@property(nonatomic,weak) UIView *douyindisc_overlayHost;
@property(nonatomic,strong) UIImageView *douyindisc_overlay;
@property(nonatomic,strong) UIImage *douyindisc_image;
@property(nonatomic,strong) DouyinDiscGIFAnimation *douyindisc_animation;
@property(nonatomic) BOOL douyindisc_animationVisible;
@property(nonatomic) BOOL douyindisc_rotationEnabled;
@property(nonatomic) BOOL douyindisc_rotationConfigured;
@property(nonatomic) CGFloat douyindisc_angle;
@property(nonatomic) CGFloat douyindisc_cornerRadius;
@property(nonatomic) CGFloat douyindisc_rotationSpeed;
@end
static NSMutableSet<NSString *> *douyindisc_installedHooks;
static NSMapTable<UILabel *,DouyinDiscTextLease *> *douyindisc_leases;
static BOOL douyindisc_observersInstalled;
static __weak UIViewController *douyindisc_visibleRootSettingsController;

static BOOL douyindisc_encoding(Class c,SEL s,const char *t){Method m=c?class_getInstanceMethod(c,s):NULL;const char *a=m?method_getTypeEncoding(m):NULL;return a&&strcmp(a,t)==0;}
static BOOL douyindisc_hook(Class c,SEL s,IMP r,const char *t,IMP *o){
 if(!c||!s||!r||!o||!douyindisc_encoding(c,s,t))return NO;
 NSString *key=[NSString stringWithFormat:@"%s/%s",class_getName(c),sel_getName(s)];if([douyindisc_installedHooks containsObject:key])return *o!=NULL;
 Method m=class_getInstanceMethod(c,s);BOOL own=NO;unsigned n=0;Method *list=class_copyMethodList(c,&n);for(unsigned i=0;i<n;i++)if(method_getName(list[i])==s){own=YES;break;}free(list);
 if(!own&&class_addMethod(c,s,r,method_getTypeEncoding(m)))*o=method_getImplementation(m);else if(own)*o=method_setImplementation(class_getInstanceMethod(c,s),r);else return NO;
 if(!*o||*o==r)return NO;[douyindisc_installedHooks addObject:key];return YES;
}
static id douyindisc_ivar(id obj,const char *ownerName,const char *field,const char *type){Class c=NSClassFromString([NSString stringWithUTF8String:ownerName]);if(!obj||!c||![obj isKindOfClass:c])return nil;Ivar v=class_getInstanceVariable(c,field);const char *t=v?ivar_getTypeEncoding(v):NULL;return t&&strcmp(t,type)==0?object_getIvar(obj,v):nil;}
static NSString *douyindisc_bottomIdentifier(NSString *t){static NSDictionary *m;static dispatch_once_t once;dispatch_once(&once,^{m=@{@"首页":@"bottom_home",@"朋友":@"bottom_friends",@"消息":@"bottom_messages",@"我":@"bottom_me"};});return m[t];}
static NSString *douyindisc_topIdentifier(NSString *t){static NSDictionary *m;static dispatch_once_t once;dispatch_once(&once,^{m=@{@"推荐":@"top_recommend",@"关注":@"top_follow",@"同城":@"top_nearby",@"精选":@"top_featured",@"商城":@"top_mall",@"团购":@"top_groupbuy",@"直播":@"top_live",@"热点":@"top_hot",@"经验":@"top_experience"};});return m[t];}
static UILabel *douyindisc_label(UIView *v){if([v isKindOfClass:NSClassFromString(@"AWENormalModeTabBarTextView")])return douyindisc_ivar(v,"AWENormalModeTabBarTextView","_label","@\"UILabel\"");if([v isKindOfClass:NSClassFromString(@"AWENormalModeTabBarIconTextView")])return douyindisc_ivar(v,"AWENormalModeTabBarIconTextView","_textLabel","@\"UILabel\"");if([v isKindOfClass:NSClassFromString(@"AWEHPTopTabItemTextContentView")])return douyindisc_ivar(v,"AWEHPTopTabItemTextContentView","_titleLabel","@\"UILabel\"");return nil;}
static NSString *douyindisc_identifier(UIView *v,UILabel *l){
 if([v isKindOfClass:NSClassFromString(@"AWEHPTopTabItemTextContentView")]){UIView *item=v.superview;if(![item isKindOfClass:NSClassFromString(@"AWEHPTopTabItemView")])return nil;if(douyindisc_ivar(item,"AWEHPTopTabItemView","_textContentView","@\"AWEHPTopTabItemTextContentView\"")!=v)return nil;id model=douyindisc_ivar(item,"AWEHPTopTabItemView","_item","@\"AWEHPTopTabItemUIModel\"");NSString *title=model?douyindisc_ivar(model,"AWEHPTopTabItemUIModel","_title","@\"NSString\""):nil;if(![title isKindOfClass:NSString.class]||![title isEqualToString:l.text])return nil;for(UIView *p=item;p;p=p.superview)if([p isKindOfClass:NSClassFromString(@"AWEFeedTopBarContainer")]){UIView *seg=douyindisc_ivar(p,"AWEFeedTopBarContainer","_segmentControlView","@\"UIView\"");return [seg isKindOfClass:UIView.class]&&[v isDescendantOfView:seg]?douyindisc_topIdentifier(l.text):nil;}return nil;}
 if([v isKindOfClass:NSClassFromString(@"AWENormalModeTabBarTextView")]||[v isKindOfClass:NSClassFromString(@"AWENormalModeTabBarIconTextView")])for(UIView *b=v.superview;b;b=b.superview)if([b isKindOfClass:NSClassFromString(@"AWENormalModeTabBarGeneralButton")])return douyindisc_ivar(b,"AWENormalModeTabBarGeneralButton","_innerView","@\"UIView<AWENormalModeTabBarInnerView>\"")==v?douyindisc_bottomIdentifier(l.text):nil;
 return nil;
}
static NSTimer *douyindisc_gifVisibilityTimer;
static void douyindisc_gifRefresh(void);
static BOOL douyindisc_gifLeaseVisible(DouyinDiscTextLease *lease) {
    UIView *overlay=lease.douyindisc_overlay;UIWindow *window=overlay.window;
    if(!window||window.hidden||!window.isKeyWindow||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive||UIAccessibilityIsReduceMotionEnabled())return NO;
    if(@available(iOS 13.0,*)){if(window.windowScene.activationState!=UISceneActivationStateForegroundActive)return NO;}
    CGFloat alpha=1;CGRect rect=[overlay convertRect:overlay.bounds toView:window],visible=window.bounds;
    for(UIView *v=overlay;v;v=v.superview){if(v.hidden)return NO;alpha*=v.alpha;if(alpha<.01)return NO;if(v.clipsToBounds&&v!=overlay)visible=CGRectIntersection(visible,[v convertRect:v.bounds toView:window]);}
    return CGRectIntersectsRect(rect,visible);
}
static void douyindisc_gifSetVisible(DouyinDiscTextLease *lease,BOOL visible) {
    NSString *key=@"com.minis.douyindisc.animated-gif";
    if(!visible||UIAccessibilityIsReduceMotionEnabled()||!lease.douyindisc_animation){[lease.douyindisc_overlay.layer removeAnimationForKey:key];lease.douyindisc_animationVisible=NO;return;}
    if([lease.douyindisc_overlay.layer animationForKey:key]){lease.douyindisc_animationVisible=YES;return;}
    NSMutableArray *values=[NSMutableArray arrayWithCapacity:lease.douyindisc_animation.frames.count];
    for(UIImage *frame in lease.douyindisc_animation.frames){if(!frame.CGImage)return;[values addObject:(__bridge id)frame.CGImage];}
    // Discrete keyTimes describe N frame boundaries plus the terminal 1.0 boundary.
    NSMutableArray *times=[lease.douyindisc_animation.keyTimes mutableCopy];[times addObject:@1.0];
    CAKeyframeAnimation *animation=[CAKeyframeAnimation animationWithKeyPath:@"contents"];
    animation.values=values;animation.keyTimes=times;animation.duration=lease.douyindisc_animation.duration;
    animation.beginTime=[lease.douyindisc_overlay.layer convertTime:CACurrentMediaTime() fromLayer:nil];
    animation.calculationMode=kCAAnimationDiscrete;animation.repeatCount=HUGE_VALF;animation.removedOnCompletion=NO;animation.fillMode=kCAFillModeBoth;
    [lease.douyindisc_overlay.layer addAnimation:animation forKey:key];lease.douyindisc_animationVisible=YES;
}
static void douyindisc_spinSetVisible(DouyinDiscTextLease *lease,BOOL visible) {
    NSString *key=@"com.minis.douyindisc.navigation.rotation";
    BOOL active=visible&&lease.douyindisc_rotationEnabled&&!UIAccessibilityIsReduceMotionEnabled();
    if(!active){[lease.douyindisc_overlay.layer removeAnimationForKey:key];return;}
    if([lease.douyindisc_overlay.layer animationForKey:key])return;
    CABasicAnimation *spin=[CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    spin.fromValue=@0;spin.toValue=@(2*M_PI);spin.duration=6.0/MAX(.25,MIN(3,lease.douyindisc_rotationSpeed));spin.repeatCount=HUGE_VALF;spin.additive=YES;spin.removedOnCompletion=NO;spin.fillMode=kCAFillModeBoth;
    spin.beginTime=[lease.douyindisc_overlay.layer convertTime:CACurrentMediaTime() fromLayer:nil];
    [lease.douyindisc_overlay.layer addAnimation:spin forKey:key];
}
static void douyindisc_gifRefresh(void) {
    if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{douyindisc_gifRefresh();});return;}
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive){for(DouyinDiscTextLease *lease in douyindisc_leases.objectEnumerator.allObjects){[lease.douyindisc_overlay.layer removeAnimationForKey:@"com.minis.douyindisc.animated-gif"];[lease.douyindisc_overlay.layer removeAnimationForKey:@"com.minis.douyindisc.navigation.rotation"];}[douyindisc_gifVisibilityTimer invalidate];douyindisc_gifVisibilityTimer=nil;return;}
    BOOL any=NO;
    for(DouyinDiscTextLease *lease in douyindisc_leases.objectEnumerator.allObjects){
        BOOL needsTimer=!UIAccessibilityIsReduceMotionEnabled()&&(lease.douyindisc_animation!=nil||lease.douyindisc_rotationEnabled);
        if(!needsTimer){douyindisc_gifSetVisible(lease,NO);douyindisc_spinSetVisible(lease,NO);continue;}
        any=YES;BOOL visible=douyindisc_gifLeaseVisible(lease);douyindisc_gifSetVisible(lease,visible);douyindisc_spinSetVisible(lease,visible);
    }
    if(any&&!douyindisc_gifVisibilityTimer){douyindisc_gifVisibilityTimer=[NSTimer scheduledTimerWithTimeInterval:.25 repeats:YES block:^(NSTimer *timer){(void)timer;douyindisc_gifRefresh();}];}
    else if(!any){[douyindisc_gifVisibilityTimer invalidate];douyindisc_gifVisibilityTimer=nil;}
}
static void douyindisc_stopAnimations(void) {
    if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{douyindisc_stopAnimations();});return;}
    for(DouyinDiscTextLease *lease in douyindisc_leases.objectEnumerator.allObjects){[lease.douyindisc_overlay.layer removeAnimationForKey:@"com.minis.douyindisc.animated-gif"];[lease.douyindisc_overlay.layer removeAnimationForKey:@"com.minis.douyindisc.navigation.rotation"];}[douyindisc_gifVisibilityTimer invalidate];douyindisc_gifVisibilityTimer=nil;
}
static void douyindisc_removeIcon(UILabel *label) {
    DouyinDiscTextLease *lease=[douyindisc_leases objectForKey:label];
    [lease.douyindisc_overlay.layer removeAnimationForKey:@"com.minis.douyindisc.animated-gif"];
    [lease.douyindisc_overlay.layer removeAnimationForKey:@"com.minis.douyindisc.navigation.rotation"];
    [lease.douyindisc_overlay removeFromSuperview];
    if(lease&&label.alpha==0)label.alpha=lease.douyindisc_originalAlpha;
    [douyindisc_leases removeObjectForKey:label];douyindisc_gifRefresh();
}
static DouyinDiscTextLease *douyindisc_installTextIcon(UIView *v,UILabel *l,NSString *identifier,UIImage *image,DouyinDiscGIFAnimation *animation,CGFloat opacity,CGFloat scale,CGFloat angle,CGFloat cornerRadius,BOOL rotationEnabled,CGFloat rotationSpeed){
 UIView *host=l.superview;if(!v||!l||!host||!image.CGImage||![l isDescendantOfView:v])return nil;
 DouyinDiscTextLease *lease=[douyindisc_leases objectForKey:l];
 if(!lease){lease=[DouyinDiscTextLease new];lease.douyindisc_label=l;lease.douyindisc_textView=v;lease.douyindisc_identifier=identifier;lease.douyindisc_originalAlpha=l.alpha;lease.douyindisc_overlay=[UIImageView new];lease.douyindisc_overlay.userInteractionEnabled=NO;lease.douyindisc_overlay.isAccessibilityElement=NO;lease.douyindisc_overlay.contentMode=UIViewContentModeScaleAspectFit;[douyindisc_leases setObject:lease forKey:l];}
 else {if(l.alpha!=0)lease.douyindisc_originalAlpha=l.alpha;if(![lease.douyindisc_identifier isEqualToString:identifier]){[lease.douyindisc_overlay.layer removeAnimationForKey:@"com.minis.douyindisc.animated-gif"];[lease.douyindisc_overlay.layer removeAnimationForKey:@"com.minis.douyindisc.navigation.rotation"];lease.douyindisc_identifier=[identifier copy];lease.douyindisc_image=nil;lease.douyindisc_animation=nil;lease.douyindisc_rotationConfigured=NO;}}
 UIImageView *overlay=lease.douyindisc_overlay;if(overlay.superview!=host){[overlay removeFromSuperview];[host addSubview:overlay];}lease.douyindisc_overlayHost=host;
 BOOL imageChanged=lease.douyindisc_image!=image,animationChanged=lease.douyindisc_animation!=animation;
 if(animationChanged)[overlay.layer removeAnimationForKey:@"com.minis.douyindisc.animated-gif"];
 if(imageChanged||animationChanged){lease.douyindisc_image=image;lease.douyindisc_animation=animation;overlay.image=animation.frames.firstObject?:image;lease.douyindisc_animationVisible=NO;}
 BOOL rotationChanged=!lease.douyindisc_rotationConfigured||fabs(lease.douyindisc_angle-angle)>.001||fabs(lease.douyindisc_cornerRadius-cornerRadius)>.001||lease.douyindisc_rotationEnabled!=rotationEnabled||fabs(lease.douyindisc_rotationSpeed-rotationSpeed)>.001;
 if(rotationChanged)[overlay.layer removeAnimationForKey:@"com.minis.douyindisc.navigation.rotation"];
 lease.douyindisc_angle=angle;lease.douyindisc_cornerRadius=cornerRadius;lease.douyindisc_rotationEnabled=rotationEnabled;lease.douyindisc_rotationSpeed=rotationSpeed;lease.douyindisc_rotationConfigured=YES;
 CGRect fitRect=[l convertRect:l.bounds toView:host];CGPoint center=CGPointMake(CGRectGetMidX(fitRect),CGRectGetMidY(fitRect));
 if([v isKindOfClass:NSClassFromString(@"AWEHPTopTabItemTextContentView")]){UIView *item=v.superview;if([item isKindOfClass:NSClassFromString(@"AWEHPTopTabItemView")]){CGRect itemRect=[item convertRect:item.bounds toView:host];center=CGPointMake(CGRectGetMidX(itemRect),CGRectGetMidY(itemRect));}}
 BOOL bottomItem=[v isKindOfClass:NSClassFromString(@"AWENormalModeTabBarTextView")]||[v isKindOfClass:NSClassFromString(@"AWENormalModeTabBarIconTextView")];CGFloat fit=MIN(fitRect.size.width/image.size.width,fitRect.size.height/image.size.height);scale=fmin(1.5,fmax(.5,scale));CGFloat factor;
 if(bottomItem){CGFloat targetLongEdge=16.0*scale;factor=targetLongEdge/MAX(image.size.width,image.size.height);}else factor=fit*scale;
 overlay.bounds=CGRectMake(0,0,image.size.width*factor,image.size.height*factor);overlay.center=center;overlay.alpha=fmin(1,fmax(0,opacity));
 CGFloat radius=MIN(overlay.bounds.size.width,overlay.bounds.size.height)*fmin(.5,fmax(0,cornerRadius/100.0));
 [CATransaction begin];[CATransaction setDisableActions:YES];overlay.layer.cornerRadius=radius;overlay.layer.masksToBounds=radius>.01;overlay.layer.transform=CATransform3DMakeRotation(angle*M_PI/180.0,0,0,1);[CATransaction commit];
 if(l.alpha!=0)l.alpha=0;
 BOOL visible=douyindisc_gifLeaseVisible(lease);douyindisc_gifSetVisible(lease,visible);douyindisc_spinSetVisible(lease,visible);
 if(animation||rotationEnabled)douyindisc_gifRefresh();return lease;
}
static void douyindisc_apply(UIView *v){
 if(!NSThread.isMainThread||!v)return;UILabel *l=douyindisc_label(v);if(!l)return;NSString *identifier=douyindisc_identifier(v,l);DouyinDiscTextLease *lease=[douyindisc_leases objectForKey:l];if(!identifier){if(lease)douyindisc_removeIcon(l);return;}
 DouyinDiscNavigationStore *store=[DouyinDiscNavigationStore douyindisc_sharedStore];NSDictionary *entry=[store douyindisc_entryForIdentifier:identifier];UIImage *image=[store douyindisc_imageForIdentifier:identifier];if(![entry[@"enabled"] boolValue]||!image.CGImage){if(lease)douyindisc_removeIcon(l);return;}
 douyindisc_installTextIcon(v,l,identifier,image,[store douyindisc_animationForIdentifier:identifier],[entry[@"opacity"] doubleValue],[entry[@"scale"] doubleValue],[entry[@"angle"] doubleValue],[entry[@"cornerRadius"] doubleValue],[entry[@"rotationEnabled"] boolValue],[entry[@"rotationSpeed"] doubleValue]);
}
static IMP douyindisc_originalTopLayout,douyindisc_originalBottomLayout,douyindisc_originalBottomUpdate,douyindisc_originalBottomAnimatedUpdate,douyindisc_originalIconTextUpdate,douyindisc_originalTopUpdate,douyindisc_originalTopSelected,douyindisc_originalBottomStatus,douyindisc_originalIconStatus,douyindisc_originalRootSettingsAppear,douyindisc_originalRootSettingsWillAppear,douyindisc_originalRootDidSelect,douyindisc_originalRootWillDisplay,douyindisc_originalSettingsViewModelSetSections;
static void douyindisc_topLayout(id o,SEL s){((void(*)(id,SEL))douyindisc_originalTopLayout)(o,s);douyindisc_apply(o);}static void douyindisc_bottomLayout(id o,SEL s){((void(*)(id,SEL))douyindisc_originalBottomLayout)(o,s);douyindisc_apply(o);}static void douyindisc_bottomUpdate(id o,SEL s,id t){((void(*)(id,SEL,id))douyindisc_originalBottomUpdate)(o,s,t);douyindisc_apply(o);}static void douyindisc_bottomAnimatedUpdate(id o,SEL s,id t,BOOL a){((void(*)(id,SEL,id,BOOL))douyindisc_originalBottomAnimatedUpdate)(o,s,t,a);douyindisc_apply(o);}static void douyindisc_iconTextUpdate(id o,SEL s,id t){((void(*)(id,SEL,id))douyindisc_originalIconTextUpdate)(o,s,t);douyindisc_apply(o);}static void douyindisc_topUpdate(id o,SEL s,id t){((void(*)(id,SEL,id))douyindisc_originalTopUpdate)(o,s,t);douyindisc_apply(o);}static void douyindisc_topSelected(id o,SEL s,BOOL a,BOOL b){((void(*)(id,SEL,BOOL,BOOL))douyindisc_originalTopSelected)(o,s,a,b);douyindisc_apply(douyindisc_ivar(o,"AWEHPTopTabItemView","_textContentView","@\"AWEHPTopTabItemTextContentView\""));}static void douyindisc_bottomStatus(id o,SEL s,NSInteger a,BOOL b){((void(*)(id,SEL,NSInteger,BOOL))douyindisc_originalBottomStatus)(o,s,a,b);douyindisc_apply(o);}static void douyindisc_iconStatus(id o,SEL s,NSInteger a,BOOL b){((void(*)(id,SEL,NSInteger,BOOL))douyindisc_originalIconStatus)(o,s,a,b);douyindisc_apply(o);}
static void douyindisc_reload(void){if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{douyindisc_reload();});return;}for(UIScene *scene in UIApplication.sharedApplication.connectedScenes){if(![scene isKindOfClass:UIWindowScene.class]||scene.activationState!=UISceneActivationStateForegroundActive)continue;NSMutableArray *stack=[NSMutableArray array];for(UIWindow *w in ((UIWindowScene *)scene).windows)if(w.windowLevel==UIWindowLevelNormal)[stack addObject:w];NSUInteger n=0;while(stack.count&&++n<=2200){UIView *v=stack.lastObject;[stack removeLastObject];if([v isKindOfClass:NSClassFromString(@"AWEHPTopTabItemTextContentView")]||[v isKindOfClass:NSClassFromString(@"AWENormalModeTabBarTextView")]||[v isKindOfClass:NSClassFromString(@"AWENormalModeTabBarIconTextView")])douyindisc_apply(v);if(stack.count+v.subviews.count<=2200)[stack addObjectsFromArray:v.subviews];}}}
static BOOL douyindisc_rootSetObject(id object, SEL selector, id value) {
    if (!object || !value || !douyindisc_encoding(object_getClass(object), selector, "v24@0:8@16")) return NO;
    ((void (*)(id, SEL, id))objc_msgSend)(object, selector, value);
    return YES;
}
static BOOL douyindisc_rootSetInteger(id object, SEL selector, NSInteger value) {
    if (!object || !douyindisc_encoding(object_getClass(object), selector, "v24@0:8q16")) return NO;
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(object, selector, value);
    return YES;
}
static BOOL douyindisc_rootSetBoolean(id object, SEL selector, BOOL value) {
    if (!object || !douyindisc_encoding(object_getClass(object), selector, "v20@0:8B16")) return NO;
    ((void (*)(id, SEL, BOOL))objc_msgSend)(object, selector, value);
    return YES;
}
static BOOL douyindisc_rootSetBlock(id object, SEL selector, dispatch_block_t value) {
    if (!object || !value || !douyindisc_encoding(object_getClass(object), selector, "v24@0:8@?16")) return NO;
    ((void (*)(id, SEL, dispatch_block_t))objc_msgSend)(object, selector, [value copy]);
    return YES;
}
static BOOL douyindisc_rootEntryIdentifier(id item) {
    SEL selector = NSSelectorFromString(@"identifier");
    if (!item || !douyindisc_encoding(object_getClass(item), selector, "@16@0:8")) return NO;
    id value = ((id (*)(id, SEL))objc_msgSend)(item, selector);
    return [value isKindOfClass:NSString.class] && [value isEqualToString:@"com.minis.douyindisc.root-entry"];
}
static void douyindisc_openRootPanel(UIViewController *source) {
    UINavigationController *nav = source.navigationController;
    if (NSThread.isMainThread && nav && nav.topViewController == source)
        [nav pushViewController:[DouyinDiscSettingsViewController new] animated:YES];
}
static id douyindisc_rootItemAtPath(id controller, UITableView *table, NSIndexPath *path) {
    if (!NSThread.isMainThread || ![path isKindOfClass:NSIndexPath.class] || path.length != 2 || path.section < 0 || path.row < 0) return nil;
    Class root = NSClassFromString(@"AWESettingsTableViewController");
    if (!root || ![controller isKindOfClass:root]) return nil;
    SEL tableSel = NSSelectorFromString(@"tableView"), vmSel = NSSelectorFromString(@"viewModel");
    SEL sectionsSel = NSSelectorFromString(@"sectionDataArray"), itemsSel = NSSelectorFromString(@"itemArray");
    if (!douyindisc_encoding(object_getClass(controller), tableSel, "@16@0:8") ||
        !douyindisc_encoding(object_getClass(controller), vmSel, "@16@0:8") ||
        ((id (*)(id, SEL))objc_msgSend)(controller, tableSel) != table) return nil;
    id vm = ((id (*)(id, SEL))objc_msgSend)(controller, vmSel);
    if (!vm || !douyindisc_encoding(object_getClass(vm), sectionsSel, "@16@0:8")) return nil;
    id sections = ((id (*)(id, SEL))objc_msgSend)(vm, sectionsSel);
    if (![sections isKindOfClass:NSArray.class] || (NSUInteger)path.section >= [sections count]) return nil;
    id section = sections[path.section];
    if (!douyindisc_encoding(object_getClass(section), itemsSel, "@16@0:8")) return nil;
    id items = ((id (*)(id, SEL))objc_msgSend)(section, itemsSel);
    return [items isKindOfClass:NSArray.class] && (NSUInteger)path.row < [items count] ? items[path.row] : nil;
}
static void douyindisc_rootDidSelect(id object, SEL selector, UITableView *table, NSIndexPath *path) {
    id item = douyindisc_rootItemAtPath(object, table, path);
    if (douyindisc_rootEntryIdentifier(item)) {
        [table deselectRowAtIndexPath:path animated:YES];
        douyindisc_openRootPanel(object);
        return;
    }
    if (douyindisc_originalRootDidSelect)
        ((void (*)(id, SEL, id, id))douyindisc_originalRootDidSelect)(object, selector, table, path);
}
static void douyindisc_rootWillDisplay(id object, SEL selector, UITableView *table, UITableViewCell *cell, NSIndexPath *path) {
    if (douyindisc_originalRootWillDisplay)
        ((void (*)(id, SEL, id, id, id))douyindisc_originalRootWillDisplay)(object, selector, table, cell, path);
    id item = douyindisc_rootItemAtPath(object, table, path);
    Class cellClass = NSClassFromString(@"AWESettingsTableViewCell");
    if (!douyindisc_rootEntryIdentifier(item) || !cellClass || ![cell isKindOfClass:cellClass]) return;
    SEL modelSel=NSSelectorFromString(@"itemModel"), imageSel=NSSelectorFromString(@"specificIconImage");
    SEL iconSel=NSSelectorFromString(@"iconImageView");
    if (!douyindisc_encoding(object_getClass(cell),modelSel,"@16@0:8") ||
        ((id (*)(id,SEL))objc_msgSend)(cell,modelSel)!=item ||
        !douyindisc_encoding(object_getClass(item),imageSel,"@16@0:8") ||
        !douyindisc_encoding(object_getClass(cell),iconSel,"@16@0:8")) return;
    id image=((id (*)(id,SEL))objc_msgSend)(item,imageSel);
    id icon=((id (*)(id,SEL))objc_msgSend)(cell,iconSel);
    if ([image isKindOfClass:UIImage.class] && [icon isKindOfClass:UIImageView.class]) {
        ((UIImageView *)icon).image=image;
        ((UIImageView *)icon).hidden=NO;
    }
    SEL arrowFlagSel=NSSelectorFromString(@"useStandardArrowImage"),arrowViewSel=NSSelectorFromString(@"arrowImageView");
    if(douyindisc_encoding(object_getClass(item),arrowFlagSel,"B16@0:8")&&((BOOL(*)(id,SEL))objc_msgSend)(item,arrowFlagSel)&&douyindisc_encoding(object_getClass(cell),arrowViewSel,"@16@0:8")){
        id arrow=((id(*)(id,SEL))objc_msgSend)(cell,arrowViewSel);
        if([arrow isKindOfClass:UIImageView.class]){UIImageView *view=arrow;if(!view.image)view.image=[UIImage systemImageNamed:@"chevron.right"];view.tintColor=UIColor.systemGrayColor;view.hidden=NO;}
        else ((UITableViewCell *)cell).accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    }
}
static BOOL douyindisc_insertRootSettingsItem(id controller) {
    if (!NSThread.isMainThread) return NO;
    Class rootClass=NSClassFromString(@"AWESettingsTableViewController"),vmClass=NSClassFromString(@"AWESettingsViewModel");
    Class sectionClass=NSClassFromString(@"AWESettingSectionModel"),itemClass=NSClassFromString(@"AWESettingItemModel");
    if(!rootClass||!vmClass||!sectionClass||!itemClass||![controller isKindOfClass:rootClass])return NO;
    SEL vmSel=NSSelectorFromString(@"viewModel"),sectionsSel=NSSelectorFromString(@"sectionDataArray");
    SEL typeSel=NSSelectorFromString(@"type"),itemsSel=NSSelectorFromString(@"itemArray");
    SEL titleSel=NSSelectorFromString(@"title"),businessSel=NSSelectorFromString(@"businessID"),heightSel=NSSelectorFromString(@"cellHeight");
    if(!douyindisc_encoding(object_getClass(controller),vmSel,"@16@0:8"))return NO;
    id vm=((id(*)(id,SEL))objc_msgSend)(controller,vmSel);
    if(![vm isKindOfClass:vmClass]||!douyindisc_encoding(object_getClass(vm),sectionsSel,"@16@0:8"))return NO;
    id sections=((id(*)(id,SEL))objc_msgSend)(vm,sectionsSel);
    if(![sections isKindOfClass:NSArray.class])return NO;
    NSUInteger existingCount=0,thirdCount=0,fallbackCount=0;
    id targetSection=nil,targetItems=nil,anchorItem=nil;
    NSUInteger targetIndex=NSNotFound,fallbackIndex=NSNotFound;
    id fallbackSection=nil,fallbackItems=nil,fallbackItem=nil;
    for(id section in sections){
        if(![section isKindOfClass:sectionClass]||!douyindisc_encoding(object_getClass(section),itemsSel,"@16@0:8"))continue;
        id items=((id(*)(id,SEL))objc_msgSend)(section,itemsSel);
        if(![items isKindOfClass:NSArray.class])continue;
        BOOL general=[section respondsToSelector:typeSel]&&douyindisc_encoding(object_getClass(section),typeSel,"q16@0:8")&&((NSInteger(*)(id,SEL))objc_msgSend)(section,typeSel)==2;
        for(NSUInteger i=0;i<[items count];i++){
            id candidate=items[i];
            if(douyindisc_rootEntryIdentifier(candidate)){++existingCount;continue;}
            if(!general||![candidate isKindOfClass:itemClass]||!douyindisc_encoding(object_getClass(candidate),titleSel,"@16@0:8"))continue;
            id title=((id(*)(id,SEL))objc_msgSend)(candidate,titleSel);
            if(![title isKindOfClass:NSString.class])continue;
            if([title isEqualToString:@"抖音图层"]){
                ++thirdCount;
                if(thirdCount==1){targetSection=section;targetItems=items;anchorItem=candidate;targetIndex=i+1;}
            }
            if([title isEqualToString:@"通用设置"]&&douyindisc_encoding(object_getClass(candidate),businessSel,"@16@0:8")){
                id business=((id(*)(id,SEL))objc_msgSend)(candidate,businessSel);
                if([business isKindOfClass:NSString.class]&&[business isEqualToString:@"general_setting"]){
                    ++fallbackCount;fallbackSection=section;fallbackItems=items;fallbackItem=candidate;fallbackIndex=i;
                }
            }
        }
    }
    if(existingCount==1)return YES;
    if(existingCount>1)return NO;
    if(thirdCount==1){}
    else if(thirdCount==0&&fallbackCount==1){targetSection=fallbackSection;targetItems=fallbackItems;anchorItem=fallbackItem;targetIndex=fallbackIndex;}
    else return NO;
    SEL setItems=NSSelectorFromString(@"setItemArray:");
    if(!targetSection||!targetItems||!anchorItem||targetIndex==NSNotFound||
       !douyindisc_encoding(object_getClass(anchorItem),typeSel,"q16@0:8")||
       !douyindisc_encoding(object_getClass(targetSection),setItems,"v24@0:8@16"))return NO;
    SEL initializer=NSSelectorFromString(@"initWithIdentifier:");
    if(!douyindisc_encoding(itemClass,initializer,"@24@0:8@16"))return NO;
    id row=[[itemClass alloc]initWithIdentifier:@"com.minis.douyindisc.root-entry"];
    if(!row)return NO;
    NSInteger type=((NSInteger(*)(id,SEL))objc_msgSend)(anchorItem,typeSel);
    UIImage *icon=[[UIImage systemImageNamed:@"square.grid.2x2"] imageWithTintColor:UIColor.blackColor renderingMode:UIImageRenderingModeAlwaysOriginal];
    __weak UIViewController *weakSource=controller;
    dispatch_block_t entryTapped=^{dispatch_block_t open=^{UIViewController *source=weakSource;UINavigationController *nav=source.navigationController;if(nav&&nav.topViewController==source)[nav pushViewController:[DouyinDiscSettingsViewController new] animated:YES];};if(NSThread.isMainThread)open();else dispatch_async(dispatch_get_main_queue(),open);};
    BOOL ready=douyindisc_rootSetObject(row,NSSelectorFromString(@"setBusinessID:"),@"com.minis.douyindisc.root-entry")&&
      douyindisc_rootSetObject(row,NSSelectorFromString(@"setTitle:"),@"DouyinDisc")&&
      douyindisc_rootSetObject(row,NSSelectorFromString(@"setTitleColor:"),UIColor.blackColor)&&
      douyindisc_rootSetObject(row,NSSelectorFromString(@"setIconImageName:"),@"")&&
      douyindisc_rootSetObject(row,NSSelectorFromString(@"setSpecificIconImage:"),icon)&&
      douyindisc_rootSetInteger(row,NSSelectorFromString(@"setType:"),type)&&
      douyindisc_rootSetInteger(row,NSSelectorFromString(@"setCellType:"),4)&&
      douyindisc_rootSetBoolean(row,NSSelectorFromString(@"setUseStandardArrowImage:"),YES)&&
      douyindisc_rootSetBoolean(row,NSSelectorFromString(@"setIsEnable:"),YES)&&
      douyindisc_rootSetBoolean(row,NSSelectorFromString(@"setUserInteractionEnabled:"),YES)&&
      douyindisc_rootSetBoolean(row,NSSelectorFromString(@"setIsForbidChangeColor:"),YES)&&
      douyindisc_rootSetBlock(row,NSSelectorFromString(@"setCellTappedBlock:"),entryTapped);
    if(!ready)return NO;
    SEL setHeight=NSSelectorFromString(@"setCellHeight:");
    if(douyindisc_encoding(object_getClass(anchorItem),heightSel,"d16@0:8")&&douyindisc_encoding(itemClass,setHeight,"v24@0:8d16")){
        double height=((double(*)(id,SEL))objc_msgSend)(anchorItem,heightSel);
        if(height>0&&isfinite(height))((void(*)(id,SEL,double))objc_msgSend)(row,setHeight,height);
    }
    NSMutableArray *updated=[targetItems mutableCopy];
    if(targetIndex>[updated count])return NO;
    [updated insertObject:row atIndex:targetIndex];
    ((void(*)(id,SEL,id))objc_msgSend)(targetSection,setItems,[updated copy]);
    SEL tableSel=NSSelectorFromString(@"tableView");
    if(douyindisc_encoding(object_getClass(controller),tableSel,"@16@0:8")){
        id table=((id(*)(id,SEL))objc_msgSend)(controller,tableSel);
        if([table isKindOfClass:UITableView.class])[table reloadData];
    }
    return YES;
}
static void douyindisc_rootSettingsWillAppear(id object, SEL selector, BOOL animated) {
    douyindisc_visibleRootSettingsController=object;
    if (douyindisc_originalRootSettingsWillAppear) ((void (*)(id, SEL, BOOL))douyindisc_originalRootSettingsWillAppear)(object, selector, animated);
    douyindisc_insertRootSettingsItem(object);
}
static void douyindisc_rootSettingsAppeared(id object, SEL selector, BOOL animated) {
    if (douyindisc_originalRootSettingsAppear) ((void (*)(id, SEL, BOOL))douyindisc_originalRootSettingsAppear)(object, selector, animated);
    douyindisc_visibleRootSettingsController=object;
    douyindisc_insertRootSettingsItem(object);
}
static void douyindisc_settingsViewModelSetSections(id object, SEL selector, id sections) {
    if(douyindisc_originalSettingsViewModelSetSections)((void(*)(id,SEL,id))douyindisc_originalSettingsViewModelSetSections)(object,selector,sections);
    UIViewController *controller=douyindisc_visibleRootSettingsController;
    SEL vmSel=NSSelectorFromString(@"viewModel");
    if(controller&&[controller respondsToSelector:vmSel]&&((id(*)(id,SEL))objc_msgSend)(controller,vmSel)==object)douyindisc_insertRootSettingsItem(controller);
}

void douyindisc_installNavigationHooks(void){if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{douyindisc_installNavigationHooks();});return;}if(!douyindisc_leases){NSPointerFunctionsOptions k=NSPointerFunctionsWeakMemory|NSPointerFunctionsObjectPointerPersonality;douyindisc_leases=[NSMapTable mapTableWithKeyOptions:k valueOptions:NSPointerFunctionsStrongMemory];douyindisc_installedHooks=[NSMutableSet set];}Class top=NSClassFromString(@"AWEHPTopTabItemTextContentView"),bottom=NSClassFromString(@"AWENormalModeTabBarTextView"),icon=NSClassFromString(@"AWENormalModeTabBarIconTextView"),item=NSClassFromString(@"AWEHPTopTabItemView"),root=NSClassFromString(@"AWESettingsTableViewController");
 SEL willAppear=@selector(viewWillAppear:),appear=@selector(viewDidAppear:),select=NSSelectorFromString(@"tableView:didSelectRowAtIndexPath:"),display=NSSelectorFromString(@"tableView:willDisplayCell:forRowAtIndexPath:"),setSections=NSSelectorFromString(@"setSectionDataArray:");
 if(root&&douyindisc_encoding(root,willAppear,"v20@0:8B16")&&douyindisc_encoding(root,appear,"v20@0:8B16")&&douyindisc_encoding(root,select,"v32@0:8@16@24")){
  if(!douyindisc_originalRootDidSelect)douyindisc_hook(root,select,(IMP)douyindisc_rootDidSelect,"v32@0:8@16@24",&douyindisc_originalRootDidSelect);
  if(!douyindisc_originalRootWillDisplay)douyindisc_hook(root,display,(IMP)douyindisc_rootWillDisplay,"v40@0:8@16@24@32",&douyindisc_originalRootWillDisplay);
  if(!douyindisc_originalRootSettingsWillAppear)douyindisc_hook(root,willAppear,(IMP)douyindisc_rootSettingsWillAppear,"v20@0:8B16",&douyindisc_originalRootSettingsWillAppear);
  if(!douyindisc_originalRootSettingsAppear)douyindisc_hook(root,appear,(IMP)douyindisc_rootSettingsAppeared,"v20@0:8B16",&douyindisc_originalRootSettingsAppear);
 }
 Class vmClass=NSClassFromString(@"AWESettingsViewModel");
 if(vmClass&&douyindisc_encoding(vmClass,setSections,"v24@0:8@16")&&!douyindisc_originalSettingsViewModelSetSections)douyindisc_hook(vmClass,setSections,(IMP)douyindisc_settingsViewModelSetSections,"v24@0:8@16",&douyindisc_originalSettingsViewModelSetSections);
 if(!douyindisc_originalTopLayout)douyindisc_hook(top,@selector(layoutSubviews),(IMP)douyindisc_topLayout,"v16@0:8",&douyindisc_originalTopLayout);if(!douyindisc_originalBottomLayout)douyindisc_hook(bottom,@selector(layoutSubviews),(IMP)douyindisc_bottomLayout,"v16@0:8",&douyindisc_originalBottomLayout);if(!douyindisc_originalBottomUpdate)douyindisc_hook(bottom,@selector(updateTitle:),(IMP)douyindisc_bottomUpdate,"v24@0:8@16",&douyindisc_originalBottomUpdate);if(!douyindisc_originalBottomAnimatedUpdate)douyindisc_hook(bottom,@selector(updateTitle:animated:),(IMP)douyindisc_bottomAnimatedUpdate,"v28@0:8@16B24",&douyindisc_originalBottomAnimatedUpdate);if(!douyindisc_originalIconTextUpdate)douyindisc_hook(icon,@selector(updateTitle:),(IMP)douyindisc_iconTextUpdate,"v24@0:8@16",&douyindisc_originalIconTextUpdate);if(!douyindisc_originalTopUpdate)douyindisc_hook(top,@selector(setContentText:),(IMP)douyindisc_topUpdate,"v24@0:8@16",&douyindisc_originalTopUpdate);if(!douyindisc_originalTopSelected)douyindisc_hook(item,@selector(updateSelected:animated:),(IMP)douyindisc_topSelected,"v24@0:8B16B20",&douyindisc_originalTopSelected);if(!douyindisc_originalBottomStatus)douyindisc_hook(bottom,@selector(tabbarStatusDidChanged:animated:),(IMP)douyindisc_bottomStatus,"v28@0:8q16B24",&douyindisc_originalBottomStatus);if(!douyindisc_originalIconStatus)douyindisc_hook(icon,@selector(tabbarStatusDidChanged:animated:),(IMP)douyindisc_iconStatus,"v28@0:8q16B24",&douyindisc_originalIconStatus);if(!douyindisc_observersInstalled){douyindisc_observersInstalled=YES;[NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){(void)n;douyindisc_gifRefresh();douyindisc_reload();}];[NSNotificationCenter.defaultCenter addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){(void)n;douyindisc_stopAnimations();}];[NSNotificationCenter.defaultCenter addObserverForName:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){(void)n;douyindisc_gifRefresh();}];[NSNotificationCenter.defaultCenter addObserverForName:@"com.minis.douyindisc.navigation.changed" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){(void)n;douyindisc_reload();}];[NSNotificationCenter.defaultCenter addObserverForName:@"com.minis.douyindisc.navigation.preview" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){NSString *key=[n.object isKindOfClass:NSString.class]?n.object:nil;for(DouyinDiscTextLease *l in douyindisc_leases.objectEnumerator.allObjects)if(!key||[l.douyindisc_identifier isEqualToString:key])douyindisc_apply(l.douyindisc_textView);}];}douyindisc_reload();}

@implementation DouyinDiscTextLease
@end
