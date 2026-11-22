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
    textView->_label=[[UILabel alloc] initWithFrame:textView.bounds]; textView->_label.text=@"首页"; [textView addSubview:textView->_label];
    tab->_innerView=textView; [tab addSubview:textView];
    AWEFeedTopBarContainer *container=[AWEFeedTopBarContainer new]; container.frame=CGRectMake(0,0,390,48); [feed addSubview:container];
    UIView *segment=[[UIView alloc] initWithFrame:container.bounds]; [container addSubview:segment]; container->_segmentControlView=segment;
    AWEHPTopTabItemView *itemView=[AWEHPTopTabItemView new]; itemView.frame=CGRectMake(180,0,70,48); itemView->_item=[AWEHPTopTabItemUIModel new]; itemView->_item->_title=@"推荐"; [segment addSubview:itemView];
    AWEHPTopTabItemTextContentView *topView=[AWEHPTopTabItemTextContentView new]; topView.frame=itemView.bounds; topView->_titleLabel=[[UILabel alloc] initWithFrame:CGRectMake(0,10,70,28)]; topView->_titleLabel.text=@"推荐"; [topView addSubview:topView->_titleLabel]; itemView->_textContentView=topView; [itemView addSubview:topView];
    douyindisc_applyToTextView(textView); douyindisc_applyToTextView(topView);
    DD_CHECK(!objc_getAssociatedObject(tab,&douyindisc_leaseKey),"tab button does not receive disc-replacement state");
    DD_CHECK(textView->_label.layer.opacity==1 && topView->_titleLabel.layer.opacity==1,"no imported image means original text remains visible");
    DD_CHECK(![textView isKindOfClass:UIControl.class] && ![topView isKindOfClass:UIControl.class],"overlays operate on verified text-render views only");
    [feed removeFromSuperview];

    UINavigationController *navigation=[UINavigationController new];
    AWESettingsTableViewController *settings=[AWESettingsTableViewController new];
    UIView *root=[[UIView alloc] initWithFrame:window.bounds]; UIViewController *host=[UIViewController new]; host.view=root;
    navigation.viewControllers=@[settings]; [host addChildViewController:navigation]; navigation.view.frame=root.bounds; [root addSubview:navigation.view];
    UIButton *entry=[UIButton buttonWithType:UIButtonTypeSystem]; entry.frame=CGRectMake(16,120,300,44); [root addSubview:entry];
    DouyinDiscWeakControllerReference *reference=[DouyinDiscWeakControllerReference new]; reference.controller=settings;
    objc_setAssociatedObject(entry,&douyindisc_settingsOwnerKey,reference,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if(!douyindisc_settingsAction) douyindisc_settingsAction=[DouyinDiscSettingsAction new];
    [entry addTarget:douyindisc_settingsAction action:@selector(douyindisc_open:) forControlEvents:UIControlEventTouchUpInside];
    [entry sendActionsForControlEvents:UIControlEventTouchUpInside];
    DD_CHECK(navigation.viewControllers.count==2 && [navigation.topViewController isKindOfClass:DouyinDiscSettingsViewController.class],"settings entry pushes the plugin panel on the existing navigation stack");
    [host removeFromParentViewController];
}
