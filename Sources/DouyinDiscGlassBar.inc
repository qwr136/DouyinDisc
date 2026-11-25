#import <QuartzCore/QuartzCore.h>
// Included after the verified navigation runtime helpers. No private getter dispatch.
@interface DouyinDiscGlassView : UIView
@property(nonatomic,strong) UIVisualEffectView *douyindisc_blur;
@property(nonatomic,strong) CAGradientLayer *douyindisc_sheen;
@property(nonatomic) BOOL douyindisc_light;
@property(nonatomic) BOOL douyindisc_reduceTransparency;
@property(nonatomic) BOOL douyindisc_styleReady;
- (void)douyindisc_updateLight:(BOOL)light reduced:(BOOL)reduced;
@end
@implementation DouyinDiscGlassView
- (instancetype)initWithFrame:(CGRect)frame {
    self=[super initWithFrame:frame];if(!self)return nil;
    self.userInteractionEnabled=NO;self.isAccessibilityElement=NO;self.accessibilityElementsHidden=YES;
    self.accessibilityIdentifier=@"douyindisc.glass.surface";
    self.douyindisc_blur=[[UIVisualEffectView alloc]initWithEffect:nil];
    self.douyindisc_blur.userInteractionEnabled=NO;self.douyindisc_blur.clipsToBounds=YES;
    [self addSubview:self.douyindisc_blur];
    self.douyindisc_sheen=[CAGradientLayer layer];self.douyindisc_sheen.startPoint=CGPointMake(.1,0);self.douyindisc_sheen.endPoint=CGPointMake(.9,1);
    self.douyindisc_sheen.locations=@[@0,@.42,@1];[self.douyindisc_blur.contentView.layer addSublayer:self.douyindisc_sheen];
    self.layer.shadowOffset=CGSizeMake(0,4);self.layer.shadowRadius=12;
    [self douyindisc_updateLight:NO reduced:UIAccessibilityIsReduceTransparencyEnabled()];return self;
}
- (void)douyindisc_updateLight:(BOOL)light reduced:(BOOL)reduced {
    if(self.douyindisc_styleReady && light==self.douyindisc_light && reduced==self.douyindisc_reduceTransparency)return;
    self.douyindisc_styleReady=YES;self.douyindisc_light=light;self.douyindisc_reduceTransparency=reduced;
    self.douyindisc_blur.effect=reduced?nil:[UIBlurEffect effectWithStyle:light?UIBlurEffectStyleSystemThinMaterialLight:UIBlurEffectStyleSystemThinMaterialDark];
    self.douyindisc_blur.backgroundColor=reduced?[UIColor colorWithWhite:light?.94:.10 alpha:1]:UIColor.clearColor;
    self.douyindisc_blur.contentView.backgroundColor=[UIColor colorWithWhite:light?1:0 alpha:light?.10:.08];
    self.douyindisc_sheen.colors=@[(id)[UIColor colorWithWhite:1 alpha:light?.38:.18].CGColor,(id)[UIColor colorWithWhite:1 alpha:.025].CGColor,(id)[UIColor colorWithWhite:1 alpha:light?.14:.07].CGColor];
    self.douyindisc_blur.layer.borderColor=[UIColor colorWithWhite:1 alpha:light?.7:.28].CGColor;
    self.douyindisc_blur.layer.borderWidth=.5;self.layer.shadowColor=UIColor.blackColor.CGColor;self.layer.shadowOpacity=light?.12:.28;
    [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews];[CATransaction begin];[CATransaction setDisableActions:YES];
    self.douyindisc_blur.frame=self.bounds;self.douyindisc_blur.layer.cornerRadius=self.bounds.size.height/2;
    self.douyindisc_blur.layer.cornerCurve=kCACornerCurveContinuous;
    self.douyindisc_sheen.frame=self.bounds;
    self.layer.shadowPath=[UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.bounds.size.height/2].CGPath;
    [CATransaction commit];
}
@end

@interface DouyinDiscGlassMaskLease : NSObject
@property(nonatomic,weak) UIView *douyindisc_view;
@property(nonatomic,strong) CALayer *douyindisc_originalMask;
@property(nonatomic,strong) CALayer *douyindisc_mask;
- (void)douyindisc_restore;
@end
@implementation DouyinDiscGlassMaskLease
- (void)douyindisc_restore {
    UIView *view=self.douyindisc_view;
    if(view.layer.mask==self.douyindisc_mask)view.layer.mask=self.douyindisc_originalMask;
}
@end
@interface DouyinDiscGlassLease : NSObject
@property(nonatomic,weak) UIView *douyindisc_bar;
@property(nonatomic,strong) UIColor *douyindisc_background;
@property(nonatomic,strong) UIColor *douyindisc_ownedClear;
@property(nonatomic,strong) DouyinDiscGlassView *douyindisc_surface;
@property(nonatomic,strong) NSArray<DouyinDiscGlassMaskLease *> *douyindisc_masks;
- (void)douyindisc_restore;
@end
@implementation DouyinDiscGlassLease
- (void)douyindisc_restore {
    for(DouyinDiscGlassMaskLease *mask in self.douyindisc_masks)[mask douyindisc_restore];
    if([self.douyindisc_bar.backgroundColor isEqual:self.douyindisc_ownedClear])self.douyindisc_bar.backgroundColor=self.douyindisc_background;
    [self.douyindisc_surface removeFromSuperview];self.douyindisc_masks=@[];
}
@end
static char douyindisc_glassKey;
static NSHashTable<UIView *> *douyindisc_glassBars;
static IMP douyindisc_glassOriginalLayout,douyindisc_glassOriginalMove;
static BOOL douyindisc_glassHooksReady;
static void douyindisc_glassApply(UIView *bar);

static id douyindisc_glassField(UIView *bar,const char *field,const char *type,BOOL *valid) {
    Class owner=NSClassFromString(@"AWENormalModeTabBar");
    Ivar ivar=owner?class_getInstanceVariable(owner,field):NULL;
    const char *actual=ivar?ivar_getTypeEncoding(ivar):NULL;
    if(!actual||strcmp(actual,type)!=0){*valid=NO;return nil;}
    return object_getIvar(bar,ivar);
}
static BOOL douyindisc_glassRectValid(CGRect r) {
    return isfinite(r.origin.x)&&isfinite(r.origin.y)&&isfinite(r.size.width)&&isfinite(r.size.height)&&r.size.width>0&&r.size.height>0;
}
// Known decoration may be interactive UIView by default; never mask controls or gestures.
static BOOL douyindisc_glassDecoration(UIView *view,UIView *bar,NSArray *buttons) {
    if(![view isKindOfClass:UIView.class]||view==bar||![view isDescendantOfView:bar])return NO;
    for(UIView *button in buttons)if(button==view||[button isDescendantOfView:view]||[view isDescendantOfView:button])return NO;
    NSMutableArray *stack=[NSMutableArray arrayWithObject:view];NSUInteger count=0;
    while(stack.count){if(++count>64)return NO;UIView *v=stack.lastObject;[stack removeLastObject];
        if([v isKindOfClass:UIControl.class]||v.gestureRecognizers.count)return NO;
        if(stack.count+v.subviews.count>64)return NO;[stack addObjectsFromArray:v.subviews];}
    return YES;
}
static BOOL douyindisc_glassResolve(UIView *bar,NSArray **decorations,CGRect *capsule,BOOL *light) {
    Class cls=NSClassFromString(@"AWENormalModeTabBar"),buttonClass=NSClassFromString(@"AWENormalModeTabBarButton");
    if(!cls||!buttonClass||object_getClass(bar)!=cls||!bar.window||!bar.superview||bar.hidden||bar.alpha<=.01||!CGAffineTransformIsIdentity(bar.transform))return NO;
    CGRect bounds=bar.bounds,windowBounds=bar.window.bounds;
    if(!douyindisc_glassRectValid(bounds)||bounds.size.width<280||bounds.size.width>600||bounds.size.height<44||bounds.size.height>120||windowBounds.size.width>windowBounds.size.height)return NO;
    CGRect inWindow=[bar convertRect:bounds toView:bar.window];
    if(CGRectGetMaxY(inWindow)<CGRectGetMaxY(windowBounds)-50||CGRectGetMinY(inWindow)<CGRectGetMaxY(windowBounds)-180)return NO;
    BOOL valid=YES;
    id list=douyindisc_glassField(bar,"_tabBarButtons","@\"NSArray\"",&valid);
    if(!valid||![list isKindOfClass:NSArray.class]||[list count]!=5)return NO;
    NSArray *buttons=list;CGRect unionRect=CGRectNull;CGFloat last=-CGFLOAT_MAX;
    for(id item in buttons){
        if(![item isKindOfClass:buttonClass]||![item isKindOfClass:UIView.class])return NO;
        UIView *button=item;
        if(button.superview!=bar||button.hidden||button.alpha<=.01||!CGAffineTransformIsIdentity(button.transform)||!douyindisc_glassRectValid(button.frame))return NO;
        if(CGRectGetMidX(button.frame)<=last||button.frame.size.height<32||button.frame.size.height>80)return NO;
        last=CGRectGetMidX(button.frame);unionRect=CGRectUnion(unionRect,button.frame);
    }
    if(CGRectGetMinX(unionRect)<CGRectGetMinX(bounds)-1||CGRectGetMaxX(unionRect)>CGRectGetMaxX(bounds)+1||CGRectGetMinY(unionRect)<CGRectGetMinY(bounds)-1||CGRectGetMaxY(unionRect)>CGRectGetMaxY(bounds)+1)return NO;
    // Special campaign covers and extra side controls are left entirely native.
    const char *extras[]={"_customCoverView","_leftElementContainerView","_rightElementContainerView"};
    const char *extraTypes[]={"@\"UIView\"","@\"AWETabBarElementContainerView\"","@\"AWETabBarElementContainerView\""};
    for(NSUInteger i=0;i<3;i++){
        id value=douyindisc_glassField(bar,extras[i],extraTypes[i],&valid);
        if(value&&![value isKindOfClass:UIView.class])return NO;
        UIView *view=value;if(view.superview&& !view.hidden&&view.alpha>.01&&(i==0||view.subviews.count))return NO;
    }
    const char *names[]={"_backgroundView","_darkBackgroundImageView","_lightBackgroundImageView","_separatorLine","_compactModeBackgroundView","_skinContainerView","_awe_blurView"};
    const char *types[]={"@\"UIView\"","@\"UIImageView\"","@\"UIImageView\"","@\"UIView\"","@\"UIView\"","@\"AWETabBarSkinContainerView\"","@\"AWENormalModeTabBarBlurView\""};
    NSMutableArray *views=[NSMutableArray array];
    DouyinDiscGlassLease *existing=objc_getAssociatedObject(bar,&douyindisc_glassKey);
    for(NSUInteger i=0;i<7;i++){
        id view=douyindisc_glassField(bar,names[i],types[i],&valid);
        if(!valid)return NO;
        if(!view){if(i==0)return NO;continue;}
        if(![view isKindOfClass:UIView.class])return NO;
        if(![(UIView *)view superview]){if(i==0)return NO;continue;}
        if(!douyindisc_glassDecoration(view,bar,buttons))return NO;
        if(i>=5 && [(UIView *)view layer].mask){
            BOOL ours=NO;
            for(DouyinDiscGlassMaskLease *m in existing.douyindisc_masks)
                if(m.douyindisc_view==view && [(UIView *)view layer].mask==m.douyindisc_mask){ours=YES;break;}
            if(!ours)return NO; // Never take over a masked skin/blur supplied by another component.
        }
        if(![views containsObject:view])[views addObject:view];
    }
    if(!valid)return NO;
    CGFloat minY=MAX(CGRectGetMinY(bounds)+2,CGRectGetMinY(unionRect)-4);
    CGFloat maxY=MIN(CGRectGetMaxY(bounds)-4,CGRectGetMaxY(unionRect)+5);
    CGRect rect=CGRectMake(CGRectGetMinX(bounds)+12,minY,bounds.size.width-24,maxY-minY);
    if(rect.size.height<40||rect.size.height>76)return NO;
    CGFloat white=0,alpha=0;UIColor *color=((UIView *)views.firstObject).backgroundColor;
    BOOL isLight=bar.traitCollection.userInterfaceStyle==UIUserInterfaceStyleLight;
    if([color getWhite:&white alpha:&alpha]&&alpha>.2)isLight=white>.6;
    else {CGFloat r=0,g=0,b=0;if([color getRed:&r green:&g blue:&b alpha:&alpha]&&alpha>.2)isLight=(r*.2126+g*.7152+b*.0722)>.6;}
    // Mask only outer decoration roots; nested image/blur views inherit their parent's mask.
    NSMutableArray *roots=[NSMutableArray arrayWithCapacity:views.count];
    for(UIView *view in views){BOOL nested=NO;for(UIView *other in views)if(view!=other && [view isDescendantOfView:other]){nested=YES;break;}if(!nested)[roots addObject:view];}
    *decorations=roots;*capsule=rect;*light=isLight;return YES;
}
static void douyindisc_glassRemove(UIView *bar) {
    DouyinDiscGlassLease *lease=objc_getAssociatedObject(bar,&douyindisc_glassKey);
    if(!lease)return;
    [lease douyindisc_restore];objc_setAssociatedObject(bar,&douyindisc_glassKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static void douyindisc_glassApply(UIView *bar) {
    if(!NSThread.isMainThread||!bar||object_getClass(bar)!=NSClassFromString(@"AWENormalModeTabBar"))return;
    if(bar.window)[douyindisc_glassBars addObject:bar];else [douyindisc_glassBars removeObject:bar];
    NSArray *views=nil;CGRect rect=CGRectZero;BOOL light=NO;
    if(!douyindisc_glassHooksReady||!DouyinDiscNavigationStore.douyindisc_sharedStore.douyindisc_glassEnabled||!douyindisc_glassResolve(bar,&views,&rect,&light)){
        douyindisc_glassRemove(bar);return;
    }
    DouyinDiscGlassLease *lease=objc_getAssociatedObject(bar,&douyindisc_glassKey);
    if(!lease){lease=[DouyinDiscGlassLease new];lease.douyindisc_bar=bar;lease.douyindisc_ownedClear=[UIColor colorWithWhite:0 alpha:0];lease.douyindisc_surface=[[DouyinDiscGlassView alloc]initWithFrame:rect];objc_setAssociatedObject(bar,&douyindisc_glassKey,lease,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
    [CATransaction begin];[CATransaction setDisableActions:YES];
    if(![bar.backgroundColor isEqual:lease.douyindisc_ownedClear]){
        lease.douyindisc_background=bar.backgroundColor;bar.backgroundColor=lease.douyindisc_ownedClear;
    }
    NSMutableArray *next=[NSMutableArray array];
    for(DouyinDiscGlassMaskLease *old in lease.douyindisc_masks)if(![views containsObject:old.douyindisc_view])[old douyindisc_restore];
    for(UIView *view in views){
        DouyinDiscGlassMaskLease *mask=nil;
        for(DouyinDiscGlassMaskLease *old in lease.douyindisc_masks)if(old.douyindisc_view==view){mask=old;break;}
        if(!mask){mask=[DouyinDiscGlassMaskLease new];mask.douyindisc_view=view;mask.douyindisc_mask=[CALayer layer];mask.douyindisc_mask.backgroundColor=UIColor.clearColor.CGColor;}
        if(!CGRectEqualToRect(mask.douyindisc_mask.frame,view.bounds))mask.douyindisc_mask.frame=view.bounds;
        if(view.layer.mask!=mask.douyindisc_mask){mask.douyindisc_originalMask=view.layer.mask;view.layer.mask=mask.douyindisc_mask;}
        [next addObject:mask];
    }
    lease.douyindisc_masks=[next copy];
    DouyinDiscGlassView *surface=lease.douyindisc_surface;
    if(surface.superview!=bar)[bar insertSubview:surface atIndex:0];
    if(!CGRectEqualToRect(surface.frame,rect))surface.frame=rect;
    [surface douyindisc_updateLight:light reduced:UIAccessibilityIsReduceTransparencyEnabled()];
    [CATransaction commit];
}
static void douyindisc_glassLayout(id object,SEL selector) {
    ((void(*)(id,SEL))douyindisc_glassOriginalLayout)(object,selector);
    douyindisc_glassApply(object);
}
static void douyindisc_glassMove(id object,SEL selector) {
    ((void(*)(id,SEL))douyindisc_glassOriginalMove)(object,selector);
    douyindisc_glassApply(object);
}
static void douyindisc_glassRefreshKnown(void) {
    if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{douyindisc_glassRefreshKnown();});return;}
    for(UIView *bar in douyindisc_glassBars.allObjects)douyindisc_glassApply(bar);
}
static void douyindisc_installGlassHooks(void) {
    if(!NSThread.isMainThread||douyindisc_glassHooksReady)return;
    Class cls=NSClassFromString(@"AWENormalModeTabBar");
    if(![cls isSubclassOfClass:UIView.class]||!douyindisc_encoding(cls,@selector(layoutSubviews),"v16@0:8")||!douyindisc_encoding(cls,@selector(didMoveToWindow),"v16@0:8"))return;
    if(!douyindisc_glassBars)douyindisc_glassBars=[NSHashTable weakObjectsHashTable];
    if(!douyindisc_glassOriginalLayout&&!douyindisc_hook(cls,@selector(layoutSubviews),(IMP)douyindisc_glassLayout,"v16@0:8",&douyindisc_glassOriginalLayout))return;
    if(!douyindisc_glassOriginalMove&&!douyindisc_hook(cls,@selector(didMoveToWindow),(IMP)douyindisc_glassMove,"v16@0:8",&douyindisc_glassOriginalMove))return;
    douyindisc_glassHooksReady=YES;
    for(NSString *name in @[@"com.minis.douyindisc.glass.changed",UIAccessibilityReduceTransparencyStatusDidChangeNotification])
        [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){(void)n;douyindisc_glassRefreshKnown();}];
}
