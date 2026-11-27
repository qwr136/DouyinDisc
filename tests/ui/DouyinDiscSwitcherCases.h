#ifndef DOUYINDISC_SWITCHER_CASES_H
#define DOUYINDISC_SWITCHER_CASES_H
#if !defined(DOUYINDISC_UI_TEST)
#error DOUYINDISC_UI_TEST is required for switcher policy cases.
#endif
// Include after NavigationHooks, Store helpers, makeButton and item.
// Handler policy only: no real App Switcher, system snapshot or card-motion claim.
static void douyindisc_switcherKeeps(CALayer *layer, NSString *key, double epoch, NSString *phase) {
  CAAnimation *animation=[layer animationForKey:key];
  NSString *name=[NSString stringWithFormat:@"%@ %@",phase,key];
  DD_CHECK_NS(animation!=nil,[name stringByAppendingString:@" remains installed"]);
  DD_CHECK_NS(fabs(animation.beginTime-epoch)<.000001,[name stringByAppendingString:@" keeps beginTime"]);
}

static void douyindisc_switcherCases(UIWindow *window) {
  DD_CHECK_NS(NSThread.isMainThread,@"policy runs on main thread");
  if(!NSThread.isMainThread)return;
  DD_CHECK_NS(UIApplication.sharedApplication.applicationState==UIApplicationStateActive,@"fixture starts active");
  DD_CHECK_NS(!UIAccessibilityIsReduceMotionEnabled(),@"positive animation fixture requires Reduce Motion off");
  if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive||UIAccessibilityIsReduceMotionEnabled()||!window.rootViewController||!douyindisc_leases)return;
  DouyinDiscNavigationStore *store=DouyinDiscNavigationStore.douyindisc_sharedStore;
  NSArray *fields=@[@"douyindisc_config",@"douyindisc_images",@"douyindisc_animations",@"douyindisc_previewOpacity",@"douyindisc_previewScale",
    @"douyindisc_imageGeneration",@"douyindisc_pickGeneration",@"douyindisc_activePickGeneration",@"douyindisc_preloadGeneration",
    @"douyindisc_loadFailed",@"douyindisc_testFailNextCommit"];
  NSMutableDictionary *saved=[NSMutableDictionary dictionary];
  for(NSString *field in fields)saved[field]=[store valueForKey:field]?:NSNull.null;
  UIViewController *root=window.rootViewController;
  DouyinDiscDisplay *oldDriver=douyindisc_driver,*driver=[DouyinDiscDisplay new];
  BOOL oldDriverSuspended=oldDriver.douyindisc_refreshSuspended;
  BOOL oldSuspended=douyindisc_animationRefreshSuspended,oldPolling=douyindisc_gifVisibilityTimer.isValid;
  NSMapTable *oldLeases=douyindisc_leases;
  UIScrollView *scroll=nil;AWEMusicCoverButton *disc=nil;AWENormalModeTabBarTextView *inner=nil;
  @try {
    oldDriver.douyindisc_refreshSuspended=YES;
    douyindisc_suspendAnimationRefresh();
    douyindisc_leases=[NSMapTable weakToStrongObjectsMapTable];
    for(NSString *field in fields)if([saved[field] isKindOfClass:NSDictionary.class])[store setValue:[NSMutableDictionary dictionary] forKey:field];
    douyindisc_animationRefreshSuspended=NO;
    douyindisc_driver=driver;driver.douyindisc_image=douyindisc_loadArtwork();
    window.rootViewController=[UIViewController new];window.rootViewController.view.frame=window.bounds;[window makeKeyAndVisible];
    UIView *host=window.rootViewController.view;
    UIImage *icon=[UIImage imageWithData:douyindisc_navCaseImage(UIColor.magentaColor)];
    UIImage *second=[UIImage imageWithData:douyindisc_navCaseImage(UIColor.cyanColor)];
    douyindisc_uiTestSetNavigationImage(@"bottom_home",icon,YES);
    douyindisc_uiTestSetNavigationAnimation(@"bottom_home",@[icon,second],@[@0,@.5],.4);
    NSMutableDictionary *config=[[store valueForKey:@"douyindisc_config"] mutableCopy];
    NSMutableDictionary *entry=[config[@"bottom_home"] mutableCopy];entry[@"rotationEnabled"]=@YES;entry[@"rotationSpeed"]=@1;
    config[@"bottom_home"]=entry;[store setValue:config forKey:@"douyindisc_config"];
    AWENormalModeTabBar *bar=[[AWENormalModeTabBar alloc]initWithFrame:CGRectMake(0,host.bounds.size.height-70,host.bounds.size.width,70)];[host addSubview:bar];
    AWENormalModeTabBarGeneralButton *tab=[[AWENormalModeTabBarGeneralButton alloc]initWithFrame:CGRectMake(16,0,64,49)];[bar addSubview:tab];
    inner=[[AWENormalModeTabBarTextView alloc]initWithFrame:tab.bounds];inner->_label=[[UILabel alloc]initWithFrame:inner.bounds];inner->_label.text=@"首页";
    [inner addSubview:inner->_label];tab->_innerView=inner;[tab addSubview:inner];douyindisc_apply(inner);
    DouyinDiscTextLease *lease=[douyindisc_leases objectForKey:inner->_label];
    scroll=[[UIScrollView alloc]initWithFrame:window.bounds];[host insertSubview:scroll atIndex:0];
    disc=douyindisc_makeButton(icon);douyindisc_item(window,scroll,0,disc,NULL);
    douyindisc_uiTestSetNavigationImage(@"video_disc",icon,YES);douyindisc_uiTestSetDiscSettings(YES,1,1);
    douyindisc_uiTestSetNavigationAnimation(@"video_disc",@[icon,second],@[@0,@.5],.4);
    [driver douyindisc_start];douyindisc_gifRefresh();
    DouyinDiscSurface *surface=objc_getAssociatedObject(disc,&douyindisc_leaseKey);
    DD_CHECK_NS(lease!=nil,@"native bottom-label fixture owns a lease");
    DD_CHECK_NS(surface!=nil,@"paired native disc fixture owns a surface");
    if(!lease||!surface)return;
    NSArray<CALayer *> *layers=@[lease.douyindisc_overlay.layer,lease.douyindisc_overlay.layer,surface.douyindisc_overlay,surface.douyindisc_overlay];
    NSArray<NSString *> *keys=@[@"com.minis.douyindisc.animated-gif",@"com.minis.douyindisc.navigation.rotation",douyindisc_discGIFKey,douyindisc_spinKey];
    NSMutableArray<NSNumber *> *epochs=[NSMutableArray array];
    for(NSUInteger i=0;i<keys.count;i++){
      CAAnimation *animation=[layers[i] animationForKey:keys[i]];
      DD_CHECK_NS(animation!=nil,[@"initial key installed: " stringByAppendingString:keys[i]]);
      [epochs addObject:@(animation.beginTime)];
    }
    for(NSUInteger i=0;i<keys.count;i+=2){
      CAKeyframeAnimation *gif=(CAKeyframeAnimation *)[layers[i] animationForKey:keys[i]];
      DD_CHECK_NS([gif.keyPath isEqualToString:@"contents"],@"GIF animates layer contents");
      DD_CHECK_NS(gif.values.count==2,@"GIF keeps both real frames");
      DD_CHECK_NS(gif.keyTimes.count==3,@"GIF has two boundaries plus terminal hold");
      DD_CHECK_NS([gif.keyTimes.lastObject doubleValue]==1,@"GIF terminal boundary is one");
      DD_CHECK_NS(fabs(gif.duration-.4)<.001,@"GIF duration matches its two-frame model");
      DD_CHECK_NS([gif.calculationMode isEqualToString:kCAAnimationDiscrete],@"GIF uses discrete frame playback");
    }
    NSTimer *navTimer=douyindisc_gifVisibilityTimer,*discTimer=driver.douyindisc_timer;
    DD_CHECK_NS(navTimer.isValid,@"navigation initially polls visibility");
    DD_CHECK_NS(discTimer.isValid,@"disc initially polls known controls");
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    DD_CHECK_NS(douyindisc_animationRefreshSuspended,@"navigation latches before app state changes");
    DD_CHECK_NS(driver.douyindisc_refreshSuspended,@"disc latches before app state changes");
    DD_CHECK_NS(!navTimer.isValid,@"resign invalidates navigation timer");
    DD_CHECK_NS(!discTimer.isValid,@"resign invalidates disc timer");
    for(NSUInteger phase=0;phase<2;phase++){
      if(phase){douyindisc_gifSetVisible(lease,NO);douyindisc_spinSetVisible(lease,NO);douyindisc_gifRefresh();[driver douyindisc_refresh:disc];[driver douyindisc_tick];}
      NSString *label=phase?@"suspended refresh":@"resign";
      for(NSUInteger i=0;i<keys.count;i++)douyindisc_switcherKeeps(layers[i],keys[i],epochs[i].doubleValue,label);
      DD_CHECK_NS(douyindisc_gifVisibilityTimer==nil,[@"navigation timer stays nil: " stringByAppendingString:label]);
      DD_CHECK_NS(driver.douyindisc_timer==nil,[@"disc timer stays nil: " stringByAppendingString:label]);
    }
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    DD_CHECK_NS(!douyindisc_animationRefreshSuspended,@"active clears navigation latch");
    DD_CHECK_NS(!driver.douyindisc_refreshSuspended,@"active clears disc latch");
    DD_CHECK_NS(douyindisc_gifVisibilityTimer.isValid,@"active restarts navigation polling");
    DD_CHECK_NS(driver.douyindisc_timer.isValid,@"active restarts disc polling");
    for(NSUInteger i=0;i<keys.count;i++)douyindisc_switcherKeeps(layers[i],keys[i],epochs[i].doubleValue,@"active");
    DD_CHECK_NS(surface.douyindisc_overlay.contents==(__bridge id)icon.CGImage,@"active disc retains custom first-frame contents");
    DD_CHECK_NS(douyindisc_customDiscRenderedMaxAlpha(surface.douyindisc_artworkGroup)>.9,@"active disc still rasterizes visible pixels");
    // Explicit configuration removal must win even while refresh is suspended.
    douyindisc_suspendAnimationRefresh();
    config=[[store valueForKey:@"douyindisc_config"] mutableCopy];entry=[config[@"bottom_home"] mutableCopy];
    entry[@"rotationEnabled"]=@NO;config[@"bottom_home"]=entry;[store setValue:config forKey:@"douyindisc_config"];douyindisc_apply(inner);
    DD_CHECK_NS([layers[1] animationForKey:keys[1]]==nil,@"rotation off clears its key while suspended");
    DD_CHECK_NS([layers[0] animationForKey:keys[0]]!=nil,@"rotation off does not clear GIF");
    douyindisc_uiTestSetNavigationImage(@"bottom_home",nil,NO);douyindisc_apply(inner);
    DD_CHECK_NS([layers[0] animationForKey:keys[0]]==nil,@"icon removal clears GIF while suspended");
    DD_CHECK_NS([layers[1] animationForKey:keys[1]]==nil,@"icon removal clears spin while suspended");
    [driver douyindisc_resignedActive:nil];
    douyindisc_uiTestSetDiscSettings(NO,1,1);
    DD_CHECK_NS(!objc_getAssociatedObject(disc,&douyindisc_leaseKey)&&![layers[2] animationForKey:keys[2]]&&![layers[3] animationForKey:keys[3]],@"explicit disc disable clears both keys while suspended");
    douyindisc_uiTestSetDiscSettings(YES,1,1);
    [driver douyindisc_refresh:disc];
    DD_CHECK_NS(!objc_getAssociatedObject(disc,&douyindisc_leaseKey)&&!driver.douyindisc_timer,@"inactive enable defers new surface and polling until foreground");
    [driver douyindisc_becameActive:nil];
    DouyinDiscSurface *reopened=objc_getAssociatedObject(disc,&douyindisc_leaseKey);
    DD_CHECK_NS(reopened&&[reopened.douyindisc_overlay animationForKey:douyindisc_discGIFKey],@"foreground restores explicitly re-enabled disc animation");
    [driver douyindisc_resignedActive:nil];[disc removeFromSuperview];
    [driver douyindisc_refresh:disc];
    DD_CHECK_NS(!objc_getAssociatedObject(disc,&douyindisc_leaseKey)&&![reopened.douyindisc_overlay animationForKey:douyindisc_discGIFKey],@"detached disc releases owned animations even while suspended");
  } @catch(NSException *exception) {
    DD_CHECK_NS(NO,[@"policy exception: " stringByAppendingString:exception.name]);
  } @finally {
    douyindisc_suspendAnimationRefresh();[driver douyindisc_resignedActive:nil];
    [NSNotificationCenter.defaultCenter removeObserver:driver];
    if(inner)douyindisc_removeIcon(inner->_label);
    for(UIControl *control in driver.douyindisc_controls.allObjects){
      DouyinDiscSurface *surface=objc_getAssociatedObject(control,&douyindisc_leaseKey);[surface douyindisc_restore];
      objc_setAssociatedObject(control,&douyindisc_leaseKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [scroll removeFromSuperview];
    for(UIView *view in window.rootViewController.view.subviews.copy)[view removeFromSuperview];
    for(NSString *field in fields)[store setValue:saved[field]==NSNull.null?nil:saved[field] forKey:field];
    douyindisc_leases=oldLeases;douyindisc_driver=oldDriver;window.rootViewController=root;
    oldDriver.douyindisc_refreshSuspended=oldDriverSuspended;
    douyindisc_animationRefreshSuspended=oldSuspended;
    if(oldPolling&&!oldSuspended)douyindisc_gifRefresh();
  }
}
#endif
