static NSUInteger douyindisc_navigationDarkPixels(UIView *view) {
    size_t width=(size_t)ceil(view.bounds.size.width),height=(size_t)ceil(view.bounds.size.height);
    if(!width||!height)return 0;
    NSMutableData *data=[NSMutableData dataWithLength:width*height*4];
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(data.mutableBytes,width,height,8,width*4,space,kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if(!context)return 0;
    CGContextClearRect(context,CGRectMake(0,0,width,height));[view setNeedsLayout];[view layoutIfNeeded];[view.layer displayIfNeeded];[view.layer renderInContext:context];CGContextRelease(context);
    const uint8_t *pixels=data.bytes;NSUInteger dark=0;for(size_t i=0;i<width*height;i++){const uint8_t *p=pixels+i*4;if(p[3]>32&&MAX(p[0],MAX(p[1],p[2]))<p[3]*.35)dark++;}
    return dark;
}

extern BOOL douyindisc_uiTestPickerTitleStable(UIImage *image);

static void douyindisc_navigationCases(UIWindow *window) {
    NSArray<NSDictionary<NSString *,id> *> *items=douyindisc_navigationItems();
    DD_CHECK(items.count==13,"the settings model has exactly thirteen requested text slots");
    NSArray *topTitles=@[@"推荐",@"关注",@"同城",@"精选",@"商城",@"团购",@"直播",@"热点",@"经验"];
    NSArray *bottom=@[@"首页",@"朋友",@"消息",@"我"];
    for(NSUInteger i=0;i<9;i++) DD_CHECK([items[i][@"title"] isEqual:topTitles[i]],"top-channel order matches the screenshot");
    for(NSUInteger i=0;i<4;i++) DD_CHECK([items[i+9][@"title"] isEqual:bottom[i]],"bottom-tab order excludes plus");

    UIView *feed=[UIView new]; feed.frame=CGRectMake(0,0,390,220); [window.rootViewController.view addSubview:feed];
    AWENormalModeTabBar *bar=[AWENormalModeTabBar new]; bar.frame=CGRectMake(0,150,390,70); [feed addSubview:bar];
    AWENormalModeTabBarGeneralButton *tab=[AWENormalModeTabBarGeneralButton new]; tab.frame=CGRectMake(20,0,64,64); [bar addSubview:tab];
    AWENormalModeTabBarTextView *textView=[AWENormalModeTabBarTextView new]; textView.frame=CGRectMake(0,0,64,32);
    textView->_label=[[UILabel alloc] initWithFrame:CGRectMake(7,4,50,24)]; textView->_label.text=@"首页"; [textView addSubview:textView->_label];
    tab->_innerView=textView; [tab addSubview:textView];
    AWEFeedTopBarContainer *container=[AWEFeedTopBarContainer new]; container.frame=CGRectMake(0,0,390,48); [feed addSubview:container];
    UIView *segment=[[UIView alloc] initWithFrame:container.bounds]; [container addSubview:segment]; container->_segmentControlView=segment;
    AWEHPTopTabItemView *itemView=[AWEHPTopTabItemView new]; itemView.frame=CGRectMake(180,0,70,48); itemView->_item=[AWEHPTopTabItemUIModel new]; itemView->_item->_title=@"推荐"; [segment addSubview:itemView];
    AWEHPTopTabItemTextContentView *topView=[AWEHPTopTabItemTextContentView new]; topView.frame=itemView.bounds; topView->_titleLabel=[[UILabel alloc] initWithFrame:CGRectMake(0,10,70,28)]; topView->_titleLabel.text=@"推荐"; [topView addSubview:topView->_titleLabel]; itemView->_textContentView=topView; [itemView addSubview:topView];
    douyindisc_apply(textView); douyindisc_apply(topView);
    DD_CHECK(douyindisc_leases.count==0,"disabled items create no navigation image lease");
    DD_CHECK(textView->_label.alpha==1 && topView->_titleLabel.alpha==1,"no imported image means original text remains visible");
    DD_CHECK(![textView isKindOfClass:UIControl.class] && ![topView isKindOfClass:UIControl.class],"overlays operate on verified text-render views only");
    UIImage *testIcon=[UIImage imageWithData:douyindisc_navCaseImage(UIColor.systemBlueColor)];
    NSUInteger darkBefore=douyindisc_navigationDarkPixels(textView);
    DouyinDiscTextLease *textLease=douyindisc_installTextIcon(textView,textView->_label,@"bottom_home",testIcon,1);
    NSUInteger darkAfter=douyindisc_navigationDarkPixels(textView);
    DD_CHECK(textLease && darkBefore>0,"navigation fixture begins with visible dark original glyphs");
    DD_CHECK(darkAfter<darkBefore,"custom icon fully replaces original glyph pixels");
    CGRect labelTextRect=[textView->_label textRectForBounds:textView->_label.bounds limitedToNumberOfLines:textView->_label.numberOfLines];
    CGPoint expectedCenter=[textView->_label convertPoint:CGPointMake(CGRectGetMidX(labelTextRect),CGRectGetMidY(labelTextRect)) toView:textView];
    CGPoint overlayCenter=CGPointMake(CGRectGetMidX(textLease.douyindisc_overlay.frame),CGRectGetMidY(textLease.douyindisc_overlay.frame));
    DD_CHECK(textLease.douyindisc_overlay.superview==textView && hypot(overlayCenter.x-expectedCenter.x,overlayCenter.y-expectedCenter.y)<.5,"replacement image follows the exact UIKit text-render coordinates");
    DD_CHECK(textLease.douyindisc_overlay.bounds.size.width<=textView->_label.bounds.size.width && textLease.douyindisc_overlay.bounds.size.height<=textView->_label.bounds.size.height,"replacement image fits inside the native label frame");
    douyindisc_removeIcon(textView->_label);
    NSUInteger darkRestored=douyindisc_navigationDarkPixels(textView);
    DD_CHECK(textView->_label.layer.mask==nil && textLease.douyindisc_overlay.superview==nil && darkRestored==darkBefore,"disabling image restores the original label glyph pixels");
    [feed removeFromSuperview];
    DD_CHECK(douyindisc_uiTestPickerTitleStable(testIcon),"selected image keeps the choose-icon title and enables a separate clear action");

    UINavigationController *navigation=[UINavigationController new];
    AWESettingsTableViewController *settings=[AWESettingsTableViewController new]; settings.douyindisc_table=[[UITableView alloc] initWithFrame:CGRectMake(0,0,390,600) style:UITableViewStyleGrouped];
    UIView *root=[[UIView alloc] initWithFrame:window.bounds]; UIViewController *host=[UIViewController new]; host.view=root;
    navigation.viewControllers=@[settings]; [host addChildViewController:navigation]; navigation.view.frame=root.bounds; [root addSubview:navigation.view];
    (void)settings.view;
    douyindisc_settingsAppeared(settings,@selector(viewDidAppear:),NO);
    UIView *header=settings.douyindisc_table.tableHeaderView; UIButton *entry=nil;
    for(UIView *child in header.subviews) if([child isKindOfClass:UIButton.class]) entry=(UIButton *)child;
    DD_CHECK(entry!=nil,"settings page receives a native table-header entry");
    [entry sendActionsForControlEvents:UIControlEventTouchUpInside];
    DD_CHECK(navigation.viewControllers.count==2 && [navigation.topViewController isKindOfClass:DouyinDiscSettingsViewController.class],"settings entry pushes the plugin panel on the existing navigation stack");
    [host removeFromParentViewController];
}
