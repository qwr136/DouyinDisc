static NSUInteger douyindisc_navigationDarkPixels(UIView *view) {
    size_t width=(size_t)ceil(view.bounds.size.width),height=(size_t)ceil(view.bounds.size.height);
    if(!width||!height)return 0;
    NSMutableData *data=[NSMutableData dataWithLength:width*height*4];
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(data.mutableBytes,width,height,8,width*4,space,kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if(!context)return 0;
    CGContextClearRect(context,CGRectMake(0,0,width,height));[view.layer displayIfNeeded];[view.layer renderInContext:context];CGContextRelease(context);
    const uint8_t *pixels=data.bytes;NSUInteger dark=0;for(size_t i=0;i<width*height;i++){const uint8_t *p=pixels+i*4;if(p[3]>32&&MAX(p[0],MAX(p[1],p[2]))<p[3]*.35)dark++;}
    return dark;
}

extern BOOL douyindisc_uiTestPickerAppearanceStable(UIImage *image);
extern void douyindisc_uiTestSetNavigationImage(NSString *identifier, UIImage *image, BOOL enabled);
extern void douyindisc_uiTestSetNavigationScale(NSString *identifier, CGFloat scale);

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
    textView->_label=[[UILabel alloc] initWithFrame:CGRectMake(7,4,50,24)]; textView->_label.text=@"首页"; textView->_label.textAlignment=NSTextAlignmentCenter; [textView addSubview:textView->_label];
    tab->_innerView=textView; [tab addSubview:textView];
    AWEFeedTopBarContainer *container=[AWEFeedTopBarContainer new]; container.frame=CGRectMake(0,0,390,48); [feed addSubview:container];
    UIView *segment=[[UIView alloc] initWithFrame:container.bounds]; [container addSubview:segment]; container->_segmentControlView=segment;
    AWEHPTopTabItemView *itemView=[AWEHPTopTabItemView new]; itemView.frame=CGRectMake(180,0,70,48); itemView->_item=[AWEHPTopTabItemUIModel new]; itemView->_item->_title=@"推荐"; [segment addSubview:itemView];
    AWEHPTopTabItemTextContentView *topView=[AWEHPTopTabItemTextContentView new]; topView.frame=itemView.bounds; topView->_titleLabel=[[UILabel alloc] initWithFrame:CGRectMake(0,10,70,28)]; topView->_titleLabel.text=@"推荐"; [topView addSubview:topView->_titleLabel]; itemView->_textContentView=topView; [itemView addSubview:topView];
    douyindisc_apply(textView); douyindisc_apply(topView);
    DD_CHECK(douyindisc_leases.count==0,"disabled items create no navigation image lease");
    CGFloat originalLabelAlpha=textView->_label.alpha;
    DD_CHECK(originalLabelAlpha>0 && topView->_titleLabel.alpha==1,"no imported image means original text remains visible");
    DD_CHECK(![textView isKindOfClass:UIControl.class] && ![topView isKindOfClass:UIControl.class],"overlays operate on verified text-render views only");
    UIImage *testIcon=[UIImage imageWithData:douyindisc_navCaseImage(UIColor.systemBlueColor)];
    douyindisc_uiTestSetNavigationImage(@"bottom_home",testIcon,YES);
    douyindisc_apply(textView);
    NSDictionary *defaultEntry=[[DouyinDiscNavigationStore douyindisc_sharedStore] douyindisc_entryForIdentifier:@"bottom_home"];
    DD_CHECK(fabs([defaultEntry[@"scale"] doubleValue]-1)<.001,"legacy navigation entry defaults icon size to one hundred percent");
    DouyinDiscTextLease *textLease=[douyindisc_leases objectForKey:textView->_label];
    CGSize originalIconSize=textLease.douyindisc_overlay.bounds.size;
    douyindisc_uiTestSetNavigationScale(@"bottom_home",1.25);
    douyindisc_apply(textView);
    DD_CHECK(fabs(textLease.douyindisc_overlay.bounds.size.width-originalIconSize.width*1.25)<.5 && fabs(textLease.douyindisc_overlay.bounds.size.height-originalIconSize.height*1.25)<.5,"size setting scales the replacement around the original tab label center");
    douyindisc_uiTestSetNavigationScale(@"bottom_home",1);
    DD_CHECK(textLease!=nil,"enabled configuration creates a navigation image lease");
    DD_CHECK(textView->_label.alpha==0 && [textView->_label.text isEqualToString:@"首页"],"replacement hides rendered text without changing native label content");
    CGRect labelRect=[textView->_label convertRect:textView->_label.bounds toView:textView];
    CGPoint expectedCenter=CGPointMake(CGRectGetMidX(labelRect),CGRectGetMidY(labelRect));
    CGRect overlayFrame=textLease.douyindisc_overlay.frame;
    CGPoint overlayCenter=CGPointMake(CGRectGetMidX(overlayFrame),CGRectGetMidY(overlayFrame));
    DD_CHECK(textLease.douyindisc_overlay.superview==textView && hypot(overlayCenter.x-expectedCenter.x,overlayCenter.y-expectedCenter.y)<1.0,"replacement image follows the exact UIKit text-render coordinates");
    DD_CHECK(textLease.douyindisc_overlay.bounds.size.width<=textView->_label.bounds.size.width && textLease.douyindisc_overlay.bounds.size.height<=textView->_label.bounds.size.height,"replacement image fits inside the native label frame");
    douyindisc_uiTestSetNavigationImage(@"top_recommend",testIcon,YES);douyindisc_apply(topView);
    DouyinDiscTextLease *topLease=[douyindisc_leases objectForKey:topView->_titleLabel];
    CGRect topItemRect=[itemView convertRect:itemView.bounds toView:topView];
    DD_CHECK(topLease && fabs(CGRectGetMidX(topLease.douyindisc_overlay.frame)-CGRectGetMidX(topItemRect))<.5 && fabs(CGRectGetMidY(topLease.douyindisc_overlay.frame)-CGRectGetMidY(topItemRect))<.5,"top replacement aligns to the native tab item center not its offset text child");
    douyindisc_uiTestSetNavigationImage(@"bottom_home",nil,NO);
    douyindisc_apply(textView);
    DD_CHECK(textLease.douyindisc_overlay.superview==nil && textView->_label.alpha==originalLabelAlpha && [textView->_label.text isEqualToString:@"首页"],"disabling image restores original label visibility and glyph content");
    [feed removeFromSuperview];
    DD_CHECK(douyindisc_uiTestPickerAppearanceStable(testIcon),"selected image shows photo icon and change title while preview remains separate");

    AWESettingsTableViewController *otherSettings=[AWESettingsTableViewController new];
    DD_CHECK(objc_getAssociatedObject(otherSettings,&douyindisc_generalRowKey)==nil,"non-General settings pages do not receive the DouyinDisc row");
    AWEGeneralSettingViewController *general=[AWEGeneralSettingViewController new]; general.douyindisc_table=[[UITableView alloc] initWithFrame:CGRectMake(0,0,390,600) style:UITableViewStyleGrouped];
    UINavigationController *generalNav=[[UINavigationController alloc] initWithRootViewController:general]; UIViewController *generalHost=[UIViewController new]; [generalHost addChildViewController:generalNav]; generalNav.view.frame=generalHost.view.bounds; [generalHost.view addSubview:generalNav.view]; (void)general.view;general.douyindisc_table.frame=general.view.bounds;[general.view addSubview:general.douyindisc_table];
    douyindisc_generalSettingsAppeared(general,@selector(viewDidAppear:),NO);
    UIButton *entry=objc_getAssociatedObject(general,&douyindisc_generalRowKey);
    DD_CHECK(entry!=nil && [[entry titleForState:UIControlStateNormal] isEqualToString:@"DouyinDisc"],"General settings page receives one DouyinDisc row");
    DD_CHECK(entry.titleLabel.textColor==UIColor.blackColor && entry.frame.size.height==56 && general.douyindisc_table.frame.origin.y>=56,"General entry uses black text and pushes its table below the row");
    [entry sendActionsForControlEvents:UIControlEventTouchUpInside];
    DD_CHECK(generalNav.viewControllers.count==2 && [generalNav.topViewController isKindOfClass:DouyinDiscSettingsViewController.class],"General settings row opens the plugin panel on its original navigation stack");
}
