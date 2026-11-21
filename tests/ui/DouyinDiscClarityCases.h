// Behavioral regressions for visible opacity, masks, exact local captions and hits.
static NSUInteger douyindisc_coverage(UIView *view) {
    size_t w = (size_t)ceil(view.bounds.size.width), h = (size_t)ceil(view.bounds.size.height);
    NSMutableData *bytes = [NSMutableData dataWithLength:w*h*4];
    CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(bytes.mutableBytes,w,h,8,w*4,color,kCGImageAlphaPremultipliedLast);
    [view.layer renderInContext:context]; CGContextRelease(context); CGColorSpaceRelease(color);
    NSUInteger total = 0;
    const unsigned char *p = bytes.bytes;
    for (size_t i=0; i<w*h; ++i) total += p[i*4+3];
    return total;
}

static void douyindisc_clarityCases(DouyinDiscDisplay *driver, AWEMusicCoverButton *button,
                                   DouyinDiscSurface *surface, UIWindow *window) {
    DD_CHECK(CGImageGetWidth(driver.douyindisc_image.CGImage) == 512 && CGImageGetHeight(driver.douyindisc_image.CGImage) == 512, "clarity artwork preserves source resolution and shape");
    DD_CHECK(button.layer.mask != nil && surface.douyindisc_overlay.superlayer != button.layer, "native subtree masked while new artwork lives outside its compositing branch");
    CGPoint center = CGPointMake(CGRectGetMidX(button.bounds),CGRectGetMidY(button.bounds));
    DD_CHECK([button hitTest:center withEvent:nil] == button, "real UIKit hit test still resolves the visually masked native button");
    UILabel *fallback = [[UILabel alloc] initWithFrame:CGRectMake(-4,30,52,14)];
    fallback.text = @"拍同款"; fallback.alpha=.8;
    [button addSubview:fallback];
    UILabel *unrelated = [[UILabel alloc] initWithFrame:CGRectMake(0,0,70,20)];
    unrelated.text = @"拍同款"; [surface.douyindisc_canvas addSubview:unrelated];
    [driver douyindisc_refresh:button];
    DD_CHECK(fallback.alpha == 0 && fallback.layer.mask, "local exact UILabel outside named ivars is suppressed again");
    DD_CHECK(unrelated.alpha == 1 && !unrelated.layer.mask, "same caption beyond disc-local geometry remains untouched");
    fallback.text = @"其他文字";
    [driver douyindisc_refresh:button];
    DD_CHECK(fabs(fallback.alpha-.8)<.001 && !fallback.layer.mask, "caption reuse restores owned alpha and mask without changing text");
    [fallback removeFromSuperview]; [unrelated removeFromSuperview];
    NSUInteger before = douyindisc_coverage(surface.douyindisc_canvas);
    CGFloat savedAlpha = button.alpha;
    button.alpha=.25;
    [driver douyindisc_refresh:button];
    DD_CHECK(douyindisc_coverage(surface.douyindisc_canvas) == before, "actual custom artwork raster alpha does not inherit button branch dimming");
    DD_CHECK(fabs(button.alpha-.25)<.001, "native button alpha is never forced brighter");
    DD_CHECK(CGRectEqualToRect(surface.douyindisc_overlay.frame,[button convertRect:button.bounds toView:surface.douyindisc_canvas]), "independent image stays aligned with the original hit target");
    button.alpha=savedAlpha;
    button->_guidanceView.alpha=1;
    button->_guidanceLabel.alpha=1;
    DD_CHECK(douyindisc_coverage(button) == 0, "late native alpha rewrite cannot reveal text or dark plate behind zero mask");
    [driver douyindisc_refresh:button];
    CALayer *nativeMask=[CALayer layer]; nativeMask.backgroundColor=UIColor.whiteColor.CGColor; nativeMask.frame=button.bounds;
    button.layer.mask=nativeMask;
    [driver douyindisc_refresh:button];
    DD_CHECK(button.layer.mask != nativeMask, "a later native mask is temporarily suppressed with ownership recorded");
    [surface douyindisc_restore];
    DD_CHECK(button.layer.mask == nativeMask && button.alpha==savedAlpha, "lease cleanup restores latest native mask and original interactive alpha");
    DD_CHECK(button->_guidanceView.alpha==1 && button->_guidanceView.layer.mask==nil, "cleanup restores native child alpha and mask independently");
    objc_setAssociatedObject(button,&douyindisc_leaseKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    button.layer.mask=nil;
    [driver douyindisc_refresh:button];
    DD_CHECK(objc_getAssociatedObject(button,&douyindisc_leaseKey)!=nil, "strict re-acquisition still works after visual mask cleanup");
    DD_CHECK(button.window==window, "clarity changes never reparent native controls");
}
