#ifndef DOUYINDISC_STARTUP_CASES_H
#define DOUYINDISC_STARTUP_CASES_H
#import <ImageIO/ImageIO.h>

#if !defined(DOUYINDISC_UI_TEST)
#error DOUYINDISC_UI_TEST is required for startup cases.
#endif

// Include after the native fixtures, Store helpers, makeButton and item helpers.
// Observe the production file-open boundary only during synchronous prepare.
// Forward every call unchanged; never supply images or decoded animation caches.
static NSFileHandle *(*douyindisc_startupOriginalRead)(id, SEL, NSURL *, NSError **);
static NSString *douyindisc_startupReadRoot;
static NSMutableSet<NSString *> *douyindisc_startupReads;
static NSFileHandle *douyindisc_startupRead(id receiver, SEL selector, NSURL *url, NSError **error) {
    if (NSThread.isMainThread && douyindisc_startupReadRoot && [url.path hasPrefix:douyindisc_startupReadRoot])
        [douyindisc_startupReads addObject:url.lastPathComponent];
    return douyindisc_startupOriginalRead(receiver, selector, url, error);
}

static NSSet<NSString *> *douyindisc_startupPrepare(DouyinDiscNavigationStore *store, NSURL *directory) {
    Method method = class_getClassMethod(NSFileHandle.class, @selector(fileHandleForReadingFromURL:error:));
    DD_CHECK_NS(method != NULL, @"startup read probe resolves the production file-open method");
    if (!method) return nil;
    IMP original = method_getImplementation(method);
    douyindisc_startupOriginalRead = (NSFileHandle *(*)(id, SEL, NSURL *, NSError **))original;
    douyindisc_startupReadRoot = [directory.path stringByAppendingString:@"/"];
    douyindisc_startupReads = [NSMutableSet set];
    @try {
        method_setImplementation(method, (IMP)douyindisc_startupRead);
        [store douyindisc_prepareStartupImages];
        return [douyindisc_startupReads copy];
    } @finally {
        method_setImplementation(method, original);
        douyindisc_startupReadRoot = nil;
        douyindisc_startupReads = nil;
    }
}

static NSData *douyindisc_startupGIF(NSData *png) {
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data,
        CFSTR("com.compuserve.gif"), 2, NULL);
    if (!destination) return nil;
    UIImage *first = [UIImage imageWithData:png];
    UIImage *second = [UIImage imageWithData:douyindisc_navCaseImage(UIColor.cyanColor)];
    NSDictionary *properties = @{(__bridge NSString *)kCGImagePropertyGIFDictionary:
        @{(__bridge NSString *)kCGImagePropertyGIFUnclampedDelayTime:@0.1}};
    if (first.CGImage && second.CGImage) {
        CGImageDestinationAddImage(destination, first.CGImage, (__bridge CFDictionaryRef)properties);
        CGImageDestinationAddImage(destination, second.CGImage, (__bridge CFDictionaryRef)properties);
    }
    BOOL valid = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    return valid ? data : nil;
}

static BOOL douyindisc_startupRendersMagenta(CALayer *layer) {
    size_t width = (size_t)ceil(layer.bounds.size.width), height = (size_t)ceil(layer.bounds.size.height);
    if (!width || !height) return NO;
    NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels.mutableBytes, width, height, 8, width * 4, rgb,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(rgb);
    if (!context) return NO;
    [layer displayIfNeeded];
    [layer renderInContext:context];
    CGContextRelease(context);
    const uint8_t *pixel = (const uint8_t *)pixels.bytes + ((height / 2) * width + width / 2) * 4;
    return pixel[0] > 100 && pixel[1] < 20 && pixel[2] > 100 && pixel[3] > 100;
}

static void douyindisc_startupCases(UIWindow *window) {
    BOOL ready = NSThread.isMainThread && window.rootViewController && !window.hidden &&
        UIApplication.sharedApplication.applicationState == UIApplicationStateActive && douyindisc_leases;
    DD_CHECK_NS(ready, @"startup cases run on the active main thread after navigation hook installation");
    if (!ready) return;
    NSURL *directory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
        [@"DouyinDiscStartup-" stringByAppendingString:NSUUID.UUID.UUIDString]] isDirectory:YES];
    DouyinDiscNavigationStore *shared = DouyinDiscNavigationStore.douyindisc_sharedStore;
    NSArray<NSString *> *keys = @[@"douyindisc_config", @"douyindisc_images", @"douyindisc_animations",
        @"douyindisc_storeDirectory", @"douyindisc_previewOpacity", @"douyindisc_previewScale",
        @"douyindisc_imageGeneration", @"douyindisc_pickGeneration", @"douyindisc_activePickGeneration",
        @"douyindisc_loadFailed", @"douyindisc_testFailNextCommit"];
    NSMutableDictionary *saved = [NSMutableDictionary dictionary];
    for (NSString *key in keys) saved[key] = [shared valueForKey:key] ?: NSNull.null;
    DouyinDiscDisplay *savedDriver = douyindisc_driver;
    UIScrollView *scroll = nil;
    AWEMusicCoverButton *button = nil;
    NSMutableArray<AWENormalModeTabBarTextView *> *inners = [NSMutableArray array];
    BOOL swapped = NO;
    @try {
        BOOL made = [NSFileManager.defaultManager createDirectoryAtURL:directory
            withIntermediateDirectories:YES attributes:nil error:nil];
        DD_CHECK_NS(made, @"startup fixture uses an isolated temporary directory");
        if (!made) return;
        NSMutableArray<NSString *> *names = [NSMutableArray array];
        for (NSUInteger i = 0; i < 6; ++i) [names addObject:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"png"]];
        NSData *png = douyindisc_navCaseImage(UIColor.magentaColor);
        BOOL filesOK = png.length > 0;
        for (NSUInteger i = 0; i < 5; ++i) {
            NSData *bytes = i == 3 ? [@"broken PNG" dataUsingEncoding:NSUTF8StringEncoding] : png;
            filesOK = [bytes writeToURL:[directory URLByAppendingPathComponent:names[i]] atomically:YES] && filesOK;
        }
        NSString *gifName = [[names[0] stringByDeletingPathExtension] stringByAppendingPathExtension:@"gif"];
        NSData *gif = douyindisc_startupGIF(png);
        CGImageSourceRef source = gif ? CGImageSourceCreateWithData((__bridge CFDataRef)gif, NULL) : NULL;
        size_t frames = source ? CGImageSourceGetCount(source) : 0;
        if (source) CFRelease(source);
        filesOK = [gif writeToURL:[directory URLByAppendingPathComponent:gifName] atomically:YES] && filesOK;
        NSString *discGIFName = [[names[1] stringByDeletingPathExtension] stringByAppendingPathExtension:@"gif"];
        filesOK = [gif writeToURL:[directory URLByAppendingPathComponent:discGIFName] atomically:YES] && filesOK;
        DD_CHECK_NS(filesOK && frames == 2, @"startup fixture contains real UUID PNGs and valid two-frame GIF sidecars");
        if (!filesOK || frames != 2) return;
        NSDictionary *config = @{
            @"bottom_home":@{@"enabled":@YES, @"image":names[0], @"opacity":@0.65, @"scale":@1.25},
            @"video_disc":@{@"image":names[1], @"opacity":@0.72, @"speed":@1.5},
            @"bottom_friends":@{@"enabled":@NO, @"image":names[2]},
            @"top_follow":@{@"image":names[2]},
            @"bottom_messages":@{@"enabled":@YES, @"image":names[3]},
            @"bottom_me":@{@"enabled":@YES},
            @"top_recommend":@{@"enabled":@YES, @"image":names[5]}};
        NSURL *configURL = [directory URLByAppendingPathComponent:@"settings.plist"];
        DD_CHECK_NS([config writeToURL:configURL atomically:YES], @"startup legacy configuration is persisted before Store construction");
        NSData *diskBefore = [NSData dataWithContentsOfURL:configURL];
        NSDate *modifiedBefore = [NSFileManager.defaultManager attributesOfItemAtPath:configURL.path error:nil][NSFileModificationDate];
        DouyinDiscNavigationStore *cold = douyindisc_uiTestCreateStore(directory);
        DD_CHECK_NS(cold && [[cold valueForKey:@"douyindisc_images"] count] == 0 &&
            [[cold valueForKey:@"douyindisc_animations"] count] == 0 &&
            [[cold valueForKey:@"douyindisc_config"] isEqual:config], @"real cold Store reads legacy config with zero seeded caches");
        // No dispatch, run-loop pumping or asynchronous preload before these assertions.
        NSSet *reads = douyindisc_startupPrepare(cold, directory);
        DD_CHECK_NS([cold douyindisc_imageForIdentifier:@"bottom_home"].CGImage &&
            [cold douyindisc_imageForIdentifier:@"video_disc"].CGImage,
            @"prepare makes navigation and default-enabled video-disc PNGs available in the same turn");
        DD_CHECK_NS([reads containsObject:names[0]] && [reads containsObject:names[1]] &&
            ![reads containsObject:gifName] && ![reads containsObject:discGIFName] &&
            [cold douyindisc_animationForIdentifier:@"bottom_home"] == nil &&
            [cold douyindisc_animationForIdentifier:@"video_disc"] == nil &&
            [[cold valueForKey:@"douyindisc_animations"] count] == 0,
            @"startup reads the PNG fallback but does not read or decode the GIF sidecar");
        DD_CHECK_NS(![reads containsObject:names[2]] && ![reads containsObject:names[4]] &&
            [cold douyindisc_imageForIdentifier:@"bottom_friends"] == nil &&
            [cold douyindisc_imageForIdentifier:@"top_follow"] == nil &&
            [cold douyindisc_imageForIdentifier:@"bottom_me"] == nil,
            @"disabled, default-off and unreferenced assets are not read or cached");
        DD_CHECK_NS([cold douyindisc_imageForIdentifier:@"bottom_messages"] == nil &&
            [cold douyindisc_imageForIdentifier:@"top_recommend"] == nil,
            @"bad PNG and missing PNG safely remain uncached");
        DD_CHECK_NS([[cold valueForKey:@"douyindisc_config"] isEqual:config] &&
            [diskBefore isEqualToData:[NSData dataWithContentsOfURL:configURL]] &&
            [modifiedBefore isEqual:[NSFileManager.defaultManager attributesOfItemAtPath:configURL.path error:nil][NSFileModificationDate]],
            @"prepare neither migrates legacy fields nor rewrites the settings file");
        NSURL *emptyDirectory = [directory URLByAppendingPathComponent:@"empty" isDirectory:YES];
        DouyinDiscNavigationStore *empty = douyindisc_uiTestCreateStore(emptyDirectory);
        [empty douyindisc_prepareStartupImages];
        NSDictionary *defaultDisc = [empty douyindisc_entryForIdentifier:@"video_disc"];
        DD_CHECK_NS([defaultDisc[@"enabled"] boolValue] && [defaultDisc[@"opacity"] doubleValue] == 1 &&
            [defaultDisc[@"speed"] doubleValue] == 1 && ![defaultDisc[@"hasImage"] boolValue] &&
            ![[empty douyindisc_entryForIdentifier:@"bottom_home"][@"enabled"] boolValue] &&
            [[empty valueForKey:@"douyindisc_images"] count] == 0 &&
            ![NSFileManager.defaultManager fileExistsAtPath:emptyDirectory.path],
            @"code defaults remain distinct from stored values and do not create files");

        // Swap only configuration and fresh empty containers, never the prepared cold caches.
        swapped = YES;
        [shared setValue:@([[shared valueForKey:@"douyindisc_preloadGeneration"] unsignedIntegerValue] + 1)
                  forKey:@"douyindisc_preloadGeneration"];
        [shared setValue:config forKey:@"douyindisc_config"];
        [shared setValue:directory forKey:@"douyindisc_storeDirectory"];
        for (NSString *key in @[@"douyindisc_images", @"douyindisc_animations", @"douyindisc_previewOpacity",
            @"douyindisc_previewScale", @"douyindisc_imageGeneration", @"douyindisc_pickGeneration", @"douyindisc_activePickGeneration"])
            [shared setValue:[NSMutableDictionary dictionary] forKey:key];
        [shared setValue:@NO forKey:@"douyindisc_loadFailed"];
        [shared setValue:@NO forKey:@"douyindisc_testFailNextCommit"];
        DD_CHECK_NS([shared douyindisc_imageForIdentifier:@"bottom_home"] == nil &&
            [shared douyindisc_imageForIdentifier:@"video_disc"] == nil,
            @"render fixture starts with empty shared caches rather than test-injected artwork");
        [shared douyindisc_prepareStartupImages];
        UIImage *navImage = [shared douyindisc_imageForIdentifier:@"bottom_home"];
        UIImage *discImage = [shared douyindisc_imageForIdentifier:@"video_disc"];
        DouyinDiscDisplay *driver = [DouyinDiscDisplay new];
        driver.douyindisc_image = douyindisc_loadArtwork();
        douyindisc_driver = driver;
        DD_CHECK_NS(douyindisc_installLifecycle(douyindisc_changed), @"startup music fixture uses the production lifecycle hook before its first layout");
        scroll = [[UIScrollView alloc] initWithFrame:window.rootViewController.view.bounds];
        scroll.contentSize = scroll.bounds.size;
        scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        [window.rootViewController.view addSubview:scroll];
        button = douyindisc_makeButton(driver.douyindisc_image);
        UIControl *share = nil;
        UIView *item = douyindisc_item(window, scroll, 0, button, &share);
        AWENormalModeTabBar *bar = [[AWENormalModeTabBar alloc] initWithFrame:CGRectMake(0, 80, 288, 64)];
        [item addSubview:bar];
        NSArray *titles = @[@"首页", @"朋友", @"消息", @"我"];
        UIView *tabHit = nil;
        CGPoint tabPoint = CGPointZero;
        for (NSUInteger i = 0; i < titles.count; ++i) {
            AWENormalModeTabBarGeneralButton *tab = [[AWENormalModeTabBarGeneralButton alloc]
                initWithFrame:CGRectMake(i * 70, 0, 64, 64)];
            AWENormalModeTabBarTextView *inner = [[AWENormalModeTabBarTextView alloc] initWithFrame:tab.bounds];
            inner->_label = [[UILabel alloc] initWithFrame:CGRectMake(7, 12, 50, 24)];
            inner->_label.text = titles[i];
            [inner addSubview:inner->_label];
            tab->_innerView = inner;
            [tab addSubview:inner]; [bar addSubview:tab]; [inners addObject:inner];
            if (i == 0) {
                tabPoint = [tab convertPoint:CGPointMake(32, 24) toView:window];
                tabHit = [window hitTest:tabPoint withEvent:nil];
            }
            [inner setNeedsLayout]; [inner layoutIfNeeded]; douyindisc_apply(inner);
        }
        [button setNeedsLayout]; [button layoutIfNeeded]; [driver douyindisc_refresh:button];
        DouyinDiscTextLease *lease = [douyindisc_leases objectForKey:inners[0]->_label];
        DouyinDiscSurface *surface = objc_getAssociatedObject(button, &douyindisc_leaseKey);
        DD_CHECK_NS(navImage.CGImage && lease.douyindisc_overlay.image == navImage &&
            inners[0]->_label.alpha == 0 && [inners[0]->_label.text isEqualToString:@"首页"] &&
            douyindisc_startupRendersMagenta(lease.douyindisc_overlay.layer),
            @"first navigation layout rasterizes the prepared PNG with no native text flash");
        DD_CHECK_NS(surface && discImage.CGImage && surface.douyindisc_overlay.contents == (__bridge id)discImage.CGImage &&
            surface.douyindisc_accentArcs && surface.douyindisc_accentArcs.hidden &&
            surface.douyindisc_centerOverlay && surface.douyindisc_centerOverlay.hidden &&
            ![surface.douyindisc_accentArcs animationForKey:douyindisc_spinKey] &&
            ![surface.douyindisc_centerOverlay animationForKey:douyindisc_spinKey] &&
            button->_imageContentView.alpha == 0 && douyindisc_darkPixels(button) == 0 &&
            douyindisc_startupRendersMagenta(surface.douyindisc_artworkGroup),
            @"first disc layout rasterizes custom pixels without native pixels or bundled decoration");
        DD_CHECK_NS(!lease.douyindisc_animation && !surface.douyindisc_customAnimation &&
            ![lease.douyindisc_overlay.layer animationForKey:@"com.minis.douyindisc.animated-gif"] &&
            ![surface.douyindisc_overlay animationForKey:douyindisc_discGIFKey],
            @"first layout uses static PNGs while multiframe GIF preload remains deferred");
        CGPoint discPoint = [button convertPoint:CGPointMake(22, 22) toView:window];
        CGPoint sharePoint = [share convertPoint:CGPointMake(22, 22) toView:window];
        DD_CHECK_NS(tabHit && [window hitTest:tabPoint withEvent:nil] == tabHit &&
            !lease.douyindisc_overlay.userInteractionEnabled && button.userInteractionEnabled && button.alpha == 1 &&
            [window hitTest:discPoint withEvent:nil] == button && [window hitTest:sharePoint withEvent:nil] == share,
            @"first-frame replacement preserves the original navigation, music and share hit targets");
        for (NSUInteger i = 1; i < inners.count; ++i) {
            UILabel *label = inners[i]->_label;
            DD_CHECK_NS(label.alpha == 1 && [douyindisc_leases objectForKey:label] == nil &&
                [label.text isEqualToString:titles[i]],
                @"disabled, corrupt and unreferenced navigation entries leave native labels visible");
        }
        DD_CHECK_NS(fabs(lease.douyindisc_overlay.alpha - .65) < .001 &&
            fabs(lease.douyindisc_overlay.bounds.size.width - 20) < .01 &&
            fabs(surface.douyindisc_artworkGroup.opacity - .72) < .001 &&
            fabs([[shared douyindisc_entryForIdentifier:@"video_disc"][@"speed"] doubleValue] - 1.5) < .001 &&
            [[shared valueForKey:@"douyindisc_config"] isEqual:config] &&
            [diskBefore isEqualToData:[NSData dataWithContentsOfURL:configURL]],
            @"first layout honors stored opacity, icon scale and disc speed without writing defaults");

        NSError *clearError = nil;
        BOOL clearedNav = [shared douyindisc_clearImageForIdentifier:@"bottom_home" error:&clearError];
        BOOL clearedDisc = [shared douyindisc_clearImageForIdentifier:@"video_disc" error:&clearError];
        douyindisc_apply(inners[0]); [driver douyindisc_refresh:button];
        NSDictionary *clearedConfig = [shared valueForKey:@"douyindisc_config"];
        NSMutableDictionary *expected = [config mutableCopy];
        for (NSString *key in @[@"bottom_home", @"video_disc"]) {
            NSMutableDictionary *entry = [config[key] mutableCopy];
            [entry removeObjectForKey:@"image"]; expected[key] = entry;
        }
        DD_CHECK_NS(clearedNav && clearedDisc && !clearError && [clearedConfig isEqual:expected] &&
            [[NSDictionary dictionaryWithContentsOfURL:configURL] isEqual:expected] &&
            [shared douyindisc_imageForIdentifier:@"bottom_home"] == nil &&
            [shared douyindisc_imageForIdentifier:@"video_disc"] == nil &&
            [shared douyindisc_animationForIdentifier:@"bottom_home"] == nil,
            @"real clear commits only reference removal and preserves all stored customization values");
        DD_CHECK_NS(inners[0]->_label.alpha == 1 && [douyindisc_leases objectForKey:inners[0]->_label] == nil &&
            surface.douyindisc_overlay.contents == (__bridge id)driver.douyindisc_image.CGImage &&
            !surface.douyindisc_accentArcs.hidden && !surface.douyindisc_centerOverlay.hidden &&
            fabs(surface.douyindisc_artworkGroup.opacity - .72) < .001 && surface.douyindisc_overlay.opacity == .5f &&
            [window hitTest:discPoint withEvent:nil] == button,
            @"clear restores native navigation text and bundled disc, not disabled-disc or factory settings");
        BOOL disabled = [shared douyindisc_saveEnabled:NO opacity:.72 scale:1.5 identifier:@"video_disc" error:nil];
        [driver douyindisc_refresh:button];
        DD_CHECK_NS(disabled && objc_getAssociatedObject(button, &douyindisc_leaseKey) == nil &&
            button->_imageContentView.alpha == 1 && !button.layer.mask &&
            [window hitTest:discPoint withEvent:nil] == button,
            @"switch-off separately restores native disc visuals and retains its original hit target");
    } @catch (NSException *exception) {
        DD_CHECK_NS(NO, [@"startup cases must not throw: " stringByAppendingString:exception.name]);
    } @finally {
        for (AWENormalModeTabBarTextView *inner in inners) douyindisc_removeIcon(inner->_label);
        DouyinDiscSurface *surface = objc_getAssociatedObject(button, &douyindisc_leaseKey);
        [surface douyindisc_restore];
        if (button) objc_setAssociatedObject(button, &douyindisc_leaseKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [scroll removeFromSuperview];
        douyindisc_driver = savedDriver;
        if (swapped) {
            // Never roll generation back: old or fixture asynchronous merges must stay invalid.
            [shared setValue:@([[shared valueForKey:@"douyindisc_preloadGeneration"] unsignedIntegerValue] + 1)
                      forKey:@"douyindisc_preloadGeneration"];
            for (NSString *key in keys) [shared setValue:saved[key] == NSNull.null ? nil : saved[key] forKey:key];
            BOOL restored = YES;
            for (NSString *key in keys) {
                id value = [shared valueForKey:key] ?: NSNull.null;
                restored = restored && [value isEqual:saved[key]];
            }
            DD_CHECK_NS(restored, @"startup finally restores shared configuration, cache objects and directory");
            douyindisc_reload();
            [savedDriver douyindisc_tick];
        }
        [NSFileManager.defaultManager removeItemAtURL:directory error:nil];
    }
}
#endif
