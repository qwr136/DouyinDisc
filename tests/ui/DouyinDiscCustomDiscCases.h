extern void douyindisc_uiTestSetDiscSettings(BOOL enabled, CGFloat opacity, CGFloat speed);
extern void douyindisc_uiTestSetNavigationImage(NSString *identifier, UIImage *image, BOOL enabled);
extern void douyindisc_uiTestSetNavigationAnimation(NSString *identifier, NSArray<UIImage *> *frames, NSArray<NSNumber *> *keyTimes, NSTimeInterval duration);

static CGFloat douyindisc_customDiscRenderedMaxAlpha(CALayer *layer) {
    size_t width=(size_t)ceil(layer.bounds.size.width),height=(size_t)ceil(layer.bounds.size.height);
    NSMutableData *pixels=[NSMutableData dataWithLength:width*height*4];CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(pixels.mutableBytes,width,height,8,width*4,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);CGColorSpaceRelease(space);
    if(!context)return 0;CGContextClearRect(context,CGRectMake(0,0,width,height));[layer renderInContext:context];CGContextRelease(context);
    const uint8_t *bytes=pixels.bytes;uint8_t maximum=0;for(size_t i=0;i<width*height;i++)maximum=MAX(maximum,bytes[i*4+3]);return maximum/255.0;
}

static void douyindisc_customDiscCases(DouyinDiscDisplay *driver, AWEMusicCoverButton *button) {
    UIImage *icon=[[[UIGraphicsImageRenderer alloc]initWithSize:CGSizeMake(44,44)] imageWithActions:^(UIGraphicsImageRendererContext *context){(void)context;[[UIColor.systemPurpleColor colorWithAlphaComponent:1] setFill];UIBezierPath *path=[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0,0,44,44)];[path fill];}];
    douyindisc_uiTestSetNavigationImage(@"video_disc",icon,YES);
    douyindisc_uiTestSetDiscSettings(YES,.72,1.5);
    [driver douyindisc_refresh:button];
    DouyinDiscSurface *surface=objc_getAssociatedObject(button,&douyindisc_leaseKey);
    DD_CHECK_NS(surface&&surface.douyindisc_overlay.contents==(__bridge id)icon.CGImage,@"video-page disc displays the user-selected icon rather than embedded artwork");
    DD_CHECK_NS(surface.douyindisc_overlay.masksToBounds&&fabs(surface.douyindisc_overlay.cornerRadius-22)<.5&&surface.douyindisc_overlay.contentsGravity==kCAGravityResizeAspectFill,@"custom photo is aspect-filled and clipped to a circular icon");
    DD_CHECK_NS(fabs(surface.douyindisc_artworkGroup.opacity-.72)<.001&&fabs(surface.douyindisc_overlay.opacity-1)<.001&&fabs(surface.douyindisc_accentArcs.opacity-1)<.001&&fabs(surface.douyindisc_centerOverlay.opacity-.9)<.001,@"one parent opacity applies to the fully composited disc without layered over-opacity");
    CGFloat renderedAlpha=douyindisc_customDiscRenderedMaxAlpha(surface.douyindisc_artworkGroup);
    DD_CHECK_NS(renderedAlpha>=.70&&renderedAlpha<=.74,@"rasterized composite alpha matches the requested seventy-two percent opacity");
    UIImage *secondFrame=[[[UIGraphicsImageRenderer alloc]initWithSize:CGSizeMake(44,44)] imageWithActions:^(UIGraphicsImageRendererContext *context){(void)context;[UIColor.systemOrangeColor setFill];[[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0,0,44,44)] fill];}];
    douyindisc_uiTestSetNavigationAnimation(@"video_disc",@[icon,secondFrame],@[@0,@.5],.2);[driver douyindisc_refresh:button];
    CAKeyframeAnimation *gif=(CAKeyframeAnimation *)[surface.douyindisc_overlay animationForKey:douyindisc_discGIFKey];
    DD_CHECK_NS(gif&&gif.values.count==3&&gif.keyTimes.count==3&&fabs(gif.duration-.2)<.001&&gif.calculationMode==kCAAnimationDiscrete&&[gif.keyTimes.lastObject doubleValue]==1&&[gif.values[1] isEqual:gif.values[2]]&&[surface.douyindisc_overlay animationForKey:douyindisc_spinKey],@"custom GIF includes terminal-frame hold and animates independently from disc rotation");
    CABasicAnimation *spin=(CABasicAnimation *)[surface.douyindisc_overlay animationForKey:douyindisc_spinKey];
    DD_CHECK_NS(spin&&fabs(spin.duration-(7.0/1.5))<.001,@"150 percent speed shortens one rotation period from seven to under five seconds");
    AWEMusicCoverButton *twin=[[AWEMusicCoverButton alloc]initWithFrame:button.frame];
    twin->_imageContentView=[[UIImageView alloc]initWithImage:button->_imageContentView.image];twin->_imageContentView.frame=twin.bounds;[twin addSubview:twin->_imageContentView];
    twin->_imageBgView=[[UIView alloc]initWithFrame:twin.bounds];twin->_imageBgView.userInteractionEnabled=NO;[twin insertSubview:twin->_imageBgView atIndex:0];
    [button.superview addSubview:twin];[driver douyindisc_refresh:twin];
    DouyinDiscSurface *twinSurface=objc_getAssociatedObject(twin,&douyindisc_leaseKey);CABasicAnimation *twinSpin=(CABasicAnimation *)[twinSurface.douyindisc_overlay animationForKey:douyindisc_spinKey];
    DD_CHECK_NS(twinSurface&&twinSpin&&fabs(twinSpin.duration-spin.duration)<.001&&fabs(twinSpin.beginTime-spin.beginTime)<.001,@"new feed controls join the same adjusted rotation phase after speed changes");
    [twinSurface douyindisc_restore];objc_setAssociatedObject(twin,&douyindisc_leaseKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[twin removeFromSuperview];
    douyindisc_uiTestSetDiscSettings(NO,.72,1.5);[driver douyindisc_refresh:button];
    DD_CHECK_NS(objc_getAssociatedObject(button,&douyindisc_leaseKey)==nil&&button->_imageContentView.alpha==1&&button.userInteractionEnabled,@"switch-off restores original pixels and preserves the native clickable control");
    douyindisc_uiTestSetNavigationImage(@"video_disc",nil,YES);douyindisc_uiTestSetDiscSettings(YES,1,1);[driver douyindisc_refresh:button];
    DD_CHECK_NS(objc_getAssociatedObject(button,&douyindisc_leaseKey)!=nil,@"clearing the custom image returns to the built-in rotating artwork");
}
