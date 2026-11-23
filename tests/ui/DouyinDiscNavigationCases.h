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
    DD_CHECK(topLease.douyindisc_overlay.bounds.size.width<=topView->_titleLabel.bounds.size.width && topLease.douyindisc_overlay.bounds.size.height<=topView->_titleLabel.bounds.size.height,"top replacement scales within the original title text slot");
    douyindisc_uiTestSetNavigationImage(@"bottom_home",nil,NO);
    douyindisc_apply(textView);
    DD_CHECK(textLease.douyindisc_overlay.superview==nil && textView->_label.alpha==originalLabelAlpha && [textView->_label.text isEqualToString:@"首页"],"disabling image restores original label visibility and glyph content");
    [feed removeFromSuperview];
    DD_CHECK(douyindisc_uiTestPickerAppearanceStable(testIcon),"selected image shows photo icon and change title while preview remains separate");

    UIImage *rootPlaceholder=[UIImage imageWithData:douyindisc_navCaseImage(UIColor.systemGrayColor)];
    douyindisc_rootPlaceholderFixture=rootPlaceholder;
    AWESettingItemModel *layerItem=[AWESettingItemModel new];layerItem.identifier=@"thirdparty-layer";layerItem.businessID=@"thirdparty-layer";layerItem.title=@"抖音图层";layerItem.type=9;layerItem.cellType=4;layerItem.isEnable=YES;layerItem.isUserInteractionEnabled=YES;layerItem.cellHeight=56;
    AWESettingItemModel *generalItem=[AWESettingItemModel new];generalItem.identifier=@"general_setting";generalItem.businessID=@"general_setting";generalItem.title=@"通用设置";generalItem.type=22;generalItem.cellType=4;generalItem.isEnable=YES;generalItem.isUserInteractionEnabled=YES;generalItem.cellHeight=56;
    AWESettingSectionModel *generalSection=[AWESettingSectionModel new];generalSection.type=2;generalSection.itemArray=@[layerItem,generalItem];
    AWESettingSectionModel *otherSection=[AWESettingSectionModel new];otherSection.type=1;otherSection.itemArray=@[generalItem];
    layerItem.placeholderIconImage=rootPlaceholder;
    generalItem.placeholderIconImage=rootPlaceholder;
    AWESettingsTableViewController *rootSettings=[AWESettingsTableViewController new];rootSettings.viewModel=[AWESettingsViewModel new];rootSettings.viewModel.sectionDataArray=@[generalSection,otherSection];rootSettings.douyindisc_table=[[UITableView alloc]initWithFrame:CGRectMake(0,0,390,600) style:UITableViewStyleGrouped];rootSettings.douyindisc_table.dataSource=rootSettings;rootSettings.douyindisc_table.delegate=rootSettings;
    UINavigationController *rootNav=[[UINavigationController alloc]initWithRootViewController:rootSettings];UIViewController *rootHost=[UIViewController new];[rootHost addChildViewController:rootNav];rootNav.view.frame=rootHost.view.bounds;[rootHost.view addSubview:rootNav.view];(void)rootSettings.view;rootSettings.douyindisc_table.frame=rootSettings.view.bounds;[rootSettings.view addSubview:rootSettings.douyindisc_table];
    [rootSettings viewDidAppear:NO];
    NSArray *updatedItems=generalSection.itemArray;
    AWESettingItemModel *pluginItem=updatedItems.count>1?updatedItems[1]:nil;
    DD_CHECK(updatedItems.count==3&&updatedItems[0]==layerItem&&[[updatedItems[1] title] isEqualToString:@"DouyinDisc"]&&updatedItems[2]==generalItem,"root General section inserts DouyinDisc immediately after the runtime 抖音图层 anchor");
    DD_CHECK(pluginItem.type==layerItem.type&&pluginItem.cellType==4&&[pluginItem.titleColor isEqual:UIColor.blackColor]&&pluginItem.specificIconImage!=nil&&pluginItem.specificIconImage!=rootPlaceholder&&[pluginItem.iconImageName isEqualToString:@""]&&pluginItem.cellTappedBlock!=nil,"native item has resolved icon, black text and direct tap callback");
    AWESettingsTableViewCell *pluginCell=(AWESettingsTableViewCell *)[rootSettings tableView:rootSettings.douyindisc_table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
    DD_CHECK(pluginCell.itemModel==pluginItem&&pluginCell.iconImageView.image==nil&&pluginCell.arrowImageView.image==nil,"IconTitle cell reproduces hidden asynchronous icon and missing chevron before display");
    [rootSettings tableView:rootSettings.douyindisc_table willDisplayCell:pluginCell forRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
    DD_CHECK(pluginCell.iconImageView.image==pluginItem.specificIconImage&&!pluginCell.iconImageView.hidden&&pluginCell.arrowImageView.hidden&&rootSettings.douyindisc_nativeWillDisplayCount==1,"only DouyinDisc root cell receives its icon after one original display callback");
    AWESettingsTableViewCell *nativeLayerCell=(AWESettingsTableViewCell *)[rootSettings tableView:rootSettings.douyindisc_table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    [rootSettings tableView:rootSettings.douyindisc_table willDisplayCell:nativeLayerCell forRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    DD_CHECK(nativeLayerCell.iconImageView.image==nil&&nativeLayerCell.iconImageView.hidden&&nativeLayerCell.arrowImageView.image==nil&&nativeLayerCell.arrowImageView.hidden,"other native IconTitle rows remain untouched");

    DD_CHECK(otherSection.itemArray.count==1&&otherSection.itemArray.firstObject==generalItem,"other root sections stay unchanged");
    [rootSettings viewDidAppear:NO];
    DD_CHECK(generalSection.itemArray.count==3,"returning to root settings never duplicates the DouyinDisc item");
    [rootSettings tableView:rootSettings.douyindisc_table didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    DD_CHECK(rootSettings.douyindisc_nativeSelectCount==1&&rootNav.viewControllers.count==1,"original root row selection forwards exactly once without opening the plugin");
    if(pluginItem.cellTappedBlock)pluginItem.cellTappedBlock();
    DD_CHECK(rootNav.viewControllers.count==2&&[rootNav.topViewController isKindOfClass:DouyinDiscSettingsViewController.class],"native tapped block opens DouyinDisc from the root row");
    [rootNav popViewControllerAnimated:NO];
    [rootSettings tableView:rootSettings.douyindisc_table didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
    DD_CHECK(rootNav.viewControllers.count==2&&[rootNav.topViewController isKindOfClass:DouyinDiscSettingsViewController.class],"root row delegate fallback also preserves the original settings stack");
    AWESettingsTableViewController *withoutAnchor=[AWESettingsTableViewController new];withoutAnchor.viewModel=[AWESettingsViewModel new];withoutAnchor.viewModel.sectionDataArray=@[otherSection];
    DD_CHECK(!douyindisc_insertRootSettingsItem(withoutAnchor)&&otherSection.itemArray.count==1,"missing runtime 抖音图层 anchor never falls back to guessed index");
}

extern void douyindisc_uiTestPickerCancellationInteractive(UIWindow *window, void (^done)(NSDictionary *));
static void douyindisc_pickerCases(UIWindow *window, dispatch_block_t done) {
    douyindisc_uiTestPickerCancellationInteractive(window, ^(NSDictionary *results) {
        DD_CHECK([results[@"empty"] boolValue], "empty photo result dismisses the real picker and revokes its ticket");
        DD_CHECK([results[@"interactive"] boolValue], "picker cancellation leaves the navigation panel visible and interactive");
        DD_CHECK([results[@"brightness"] boolValue], "picker cancellation restores window brightness without removing system views");
        DD_CHECK([results[@"adaptive"] boolValue], "adaptive dismissal closes only its matching photo session");
        DD_CHECK([results[@"stale"] boolValue], "late dismissal from old picker cannot cancel the new photo session");
        DD_CHECK([results[@"unchanged"] boolValue], "cancelled photo sessions preserve image and configuration");
        if(done)done();
    });
}
