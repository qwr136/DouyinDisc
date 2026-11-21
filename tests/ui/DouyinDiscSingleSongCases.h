// Device trace _1 confirms SingleSongStyle host 275 owns circle 279 and plate 281;
// UIImageView 281 outside button 283. Verify only the identity-bound plate hides.
static void douyindisc_singleSongCases(DouyinDiscDisplay *driver,AWEMusicCoverButton *button) {
    UIView *oldParent=button.superview; CGRect oldFrame=button.frame;
    DouyinDiscSurface *old=objc_getAssociatedObject(button,&douyindisc_leaseKey); [old douyindisc_restore];
    objc_setAssociatedObject(button,&douyindisc_leaseKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    AWEPlayInteractionSingleSongMusicStyleView *host=[[AWEPlayInteractionSingleSongMusicStyleView alloc] initWithFrame:oldFrame];
    host->_playInteractionCircleMaskView=[[UIView alloc] initWithFrame:CGRectMake(0,0,44,44)];
    host->_playInteractionCircleMaskView.clipsToBounds=YES;host->_playInteractionCircleMaskView.layer.cornerRadius=22;
    host->_playInteractionCircleMaskView.userInteractionEnabled=NO;
    host->_playInteractionMaskView=[[UIImageView alloc] initWithFrame:CGRectMake(0,29.6667,44,14.3333)];
    host->_playInteractionMaskView.backgroundColor=[UIColor colorWithWhite:0 alpha:.6];
    host->_playInteractionCircleMaskView.backgroundColor=UIColor.clearColor;
    [host->_playInteractionCircleMaskView addSubview:host->_playInteractionMaskView];
    host->_playInteractionLabel=[[UILabel alloc] initWithFrame:CGRectMake(0,29.6667,44,14.3333)];host->_playInteractionLabel.text=@"拍同款";
    [host addSubview:host->_playInteractionCircleMaskView];[oldParent addSubview:host];
    button.frame=host.bounds;host->_musicButton=button;[host insertSubview:button atIndex:0];[host addSubview:host->_playInteractionLabel];
    [driver douyindisc_refresh:button];
    DouyinDiscSurface *surface=objc_getAssociatedObject(button,&douyindisc_leaseKey);
    DD_CHECK(host->_playInteractionMaskView.alpha==0 && host->_playInteractionMaskView.layer.mask, "trace-proven SingleSongStyle plate is hidden by its own exact host rule");
    DD_CHECK(douyindisc_darkPixels(host)==0, "SingleSongStyle raster contains no isolated black plate pixels");
    DD_CHECK(!host.hidden && !host->_playInteractionCircleMaskView.hidden && host.alpha==1 && host->_playInteractionCircleMaskView.alpha==1 && button.alpha==1, "SingleSong repair leaves host clip and native click target visible");
    DD_CHECK(host->_playInteractionLabel.alpha==0 && [host->_playInteractionLabel.text isEqualToString:@"拍同款"], "SingleSong exact caption disappears without rewriting its content");
    DD_CHECK([host hitTest:CGPointMake(22,22) withEvent:nil]==button, "SingleSong ancestor hit testing still selects the native button");
    host->_playInteractionCircleMaskView.userInteractionEnabled=YES;[driver douyindisc_refresh:button];
    DD_CHECK(host->_playInteractionMaskView.alpha==1 && !host->_playInteractionMaskView.layer.mask, "interactive SingleSong clip fails closed without hiding its plate");
    DouyinDiscDerivedSingleSongMusicStyleView *derived=[DouyinDiscDerivedSingleSongMusicStyleView new];
    derived.frame=host.frame; derived->_musicButton=button;
    derived->_playInteractionCircleMaskView=[[UIView alloc] initWithFrame:host->_playInteractionCircleMaskView.frame];
    derived->_playInteractionCircleMaskView.clipsToBounds=YES; derived->_playInteractionCircleMaskView.layer.cornerRadius=22;
    derived->_playInteractionMaskView=[[UIImageView alloc] initWithFrame:host->_playInteractionMaskView.frame];
    derived->_playInteractionMaskView.backgroundColor=[UIColor colorWithWhite:0 alpha:.6];
    host->_playInteractionCircleMaskView.userInteractionEnabled=NO;
    [host->_playInteractionMaskView removeFromSuperview]; [host removeFromSuperview];
    [oldParent addSubview:derived]; [derived insertSubview:button atIndex:0];
    [derived addSubview:derived->_playInteractionCircleMaskView];
    [derived->_playInteractionCircleMaskView addSubview:derived->_playInteractionMaskView];
    button.frame=derived.bounds;
    [driver douyindisc_refresh:button];
    DD_CHECK(object_getClass(derived)!=NSClassFromString(@"AWEPlayInteractionSingleSongMusicStyleView") &&
        derived->_playInteractionMaskView.alpha==1 && !derived->_playInteractionMaskView.layer.mask,
        "unverified subclass is never authorized by exact SingleSong host predicate");
    [derived removeFromSuperview];
    [host->_playInteractionMaskView removeFromSuperview];
    [host->_playInteractionCircleMaskView addSubview:host->_playInteractionMaskView];
    [oldParent addSubview:host]; [host insertSubview:button atIndex:0]; button.frame=host.bounds;
    host->_playInteractionCircleMaskView.userInteractionEnabled=NO;[driver douyindisc_refresh:button];
    surface=objc_getAssociatedObject(button,&douyindisc_leaseKey);
    DD_CHECK(host->_playInteractionMaskView.alpha==0 && host->_playInteractionMaskView.layer.mask, "restoring exact noninteractive SingleSong clip reinstates its owned lease");
    DD_CHECK(surface.douyindisc_overlay.opacity==.5f && surface.douyindisc_centerOverlay.opacity==.9f, "SingleSong style keeps outer half-opacity and inner ninety percent");
    DD_CHECK([button hitTest:CGPointMake(22,22) withEvent:nil]==button, "SingleSong visual-only repair retains exact original button hit testing");

    UIView *foreign=[[UIView alloc] initWithFrame:host->_playInteractionCircleMaskView.frame];
    UIImageView *foreignPlate=[[UIImageView alloc] initWithFrame:host->_playInteractionMaskView.frame];
    foreignPlate.backgroundColor=[UIColor colorWithWhite:0 alpha:.6];[foreign addSubview:foreignPlate];[host insertSubview:foreign atIndex:0];
    [driver douyindisc_refresh:button];
    DD_CHECK(foreignPlate.alpha==1 && !foreignPlate.layer.mask, "unlisted duplicate plate outside the exact StyleOne/SingleSong host fields is untouched");
    [foreign removeFromSuperview];
    host->_playInteractionLabel.text=@"其他文案";[driver douyindisc_refresh:button];
    DD_CHECK(host->_playInteractionLabel.alpha==1, "reused SingleSong caption restores when its exact text changes");
    [surface douyindisc_restore];objc_setAssociatedObject(button,&douyindisc_leaseKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    DD_CHECK(host->_playInteractionMaskView.alpha==1 && !host->_playInteractionMaskView.layer.mask, "SingleSong plate lease restores the exact original state");
    objc_setAssociatedObject(button,&douyindisc_leaseKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [oldParent addSubview:button];button.frame=oldFrame;[button layoutSubviews];[host removeFromSuperview];[driver douyindisc_refresh:button];
    DD_CHECK(objc_getAssociatedObject(button,&douyindisc_leaseKey)!=nil, "style change returns to normal music without stale plate binding");
}
