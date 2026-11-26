// Included only by DouyinDiscNavigation.m under DOUYINDISC_UI_TEST.
static CGRect douyindisc_layoutRect(UIView *view, UIView *space) {
    return [view convertRect:view.bounds toView:space];
}
static BOOL douyindisc_layoutWindowHit(UIWindow *window, UIControl *control) {
    CGPoint point=[control convertPoint:CGPointMake(CGRectGetMidX(control.bounds),CGRectGetMidY(control.bounds)) toView:window];
    UIView *hit=[window hitTest:point withEvent:nil];
    BOOL matched=hit&&(hit==control||[hit isDescendantOfView:control]);
    if(!matched)NSLog(@"DD_LAYOUT_HIT target=%@ point=%@ hit=%@",control.accessibilityIdentifier?:NSStringFromClass(control.class),NSStringFromCGPoint(point),hit);
    return matched;
}
static BOOL douyindisc_layoutRowAligned(NSArray<UIView *> *views, UIView *space) {
    CGFloat y=CGRectGetMidY(douyindisc_layoutRect(views.firstObject,space));
    for(UIView *view in views)if(view.hasAmbiguousLayout||fabs(CGRectGetMidY(douyindisc_layoutRect(view,space))-y)>.75)return NO;
    return YES;
}
NSDictionary *douyindisc_uiTestSettingsLayout(UIWindow *window) {
    if(!window||!NSThread.isMainThread)return @{};
    UIViewController *previousRoot=window.rootViewController;
    DouyinDiscSettingsViewController *panel=[DouyinDiscSettingsViewController new];
    UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:panel];
    window.rootViewController=nav;[window makeKeyAndVisible];
    [window layoutIfNeeded];[nav.view layoutIfNeeded];[panel.view layoutIfNeeded];
    [panel.douyindisc_scrollView layoutIfNeeded];[panel.douyindisc_stack layoutIfNeeded];
    BOOL aligned=YES,ordered=YES,bounded=YES,hits=YES,unambiguous=YES,discUnchanged=NO;
    NSUInteger navigationCount=0,controlCount=0;
    for(UIView *view in panel.douyindisc_stack.arrangedSubviews){
        if(![view isKindOfClass:DouyinDiscNavigationRow.class])continue;
        DouyinDiscNavigationRow *row=(DouyinDiscNavigationRow *)view;[row layoutIfNeeded];
        // Enable fixture controls for hit-testing without committing configuration.
        row.douyindisc_imageButton.enabled=YES;row.douyindisc_clearButton.enabled=YES;
        NSMutableArray<UIControl *> *controls=[NSMutableArray arrayWithArray:@[row.douyindisc_switch,row.douyindisc_imageButton,row.douyindisc_clearButton,row.douyindisc_opacityMinus,row.douyindisc_opacityPlus,row.douyindisc_sizeMinus,row.douyindisc_sizePlus,row.douyindisc_value,row.douyindisc_sizeValue]];
        NSMutableArray<NSArray<UIView *> *> *rows=[NSMutableArray arrayWithArray:@[@[row.douyindisc_opacityTitle,row.douyindisc_opacityMinus,row.douyindisc_value,row.douyindisc_opacityPlus],@[row.douyindisc_sizeTitle,row.douyindisc_sizeMinus,row.douyindisc_sizeValue,row.douyindisc_sizePlus]]];
        BOOL disc=[row.douyindisc_identifier isEqual:@"video_disc"];
        if(!disc){
            navigationCount++;
            [rows addObjectsFromArray:@[@[row.douyindisc_angleTitle,row.douyindisc_angleMinus,row.douyindisc_angleValue,row.douyindisc_anglePlus],@[row.douyindisc_cornerTitle,row.douyindisc_cornerMinus,row.douyindisc_cornerValue,row.douyindisc_cornerPlus],@[row.douyindisc_rotationTitle,row.douyindisc_rotationSwitch],@[row.douyindisc_rotationSpeedMinus,row.douyindisc_rotationSpeedValue,row.douyindisc_rotationSpeedPlus]]];
            [controls addObjectsFromArray:@[row.douyindisc_angleMinus,row.douyindisc_anglePlus,row.douyindisc_cornerMinus,row.douyindisc_cornerPlus,row.douyindisc_rotationSwitch,row.douyindisc_rotationSpeedMinus,row.douyindisc_rotationSpeedPlus,row.douyindisc_angleValue,row.douyindisc_cornerValue,row.douyindisc_rotationSpeedValue]];
        }else discUnchanged=fabs(row.bounds.size.height-198)<.75&&!row.douyindisc_rotationSwitch&&!row.douyindisc_angleValue;
        CGFloat previousBottom=CGRectGetMaxY(douyindisc_layoutRect(row.douyindisc_thumbnail,row));
        for(NSArray<UIView *> *line in rows){
            aligned=douyindisc_layoutRowAligned(line,row)&&aligned;
            CGRect unionRect=CGRectNull;
            for(UIView *part in line){CGRect r=douyindisc_layoutRect(part,row);unionRect=CGRectUnion(unionRect,r);unambiguous=!part.hasAmbiguousLayout&&unambiguous;bounded=CGRectContainsRect(row.bounds,r)&&bounded;}
            ordered=CGRectGetMinY(unionRect)>=previousBottom+4&&ordered;
            previousBottom=CGRectGetMaxY(unionRect);
        }
        bounded=previousBottom<=row.bounds.size.height-8&&previousBottom>=row.bounds.size.height-50&&bounded;
        // Put this complete card inside the actual scrolling viewport before testing.
        CGRect card=[row convertRect:row.bounds toView:panel.douyindisc_scrollView];
        CGFloat maximum=MAX(0,panel.douyindisc_scrollView.contentSize.height-panel.douyindisc_scrollView.bounds.size.height);
        [panel.douyindisc_scrollView setContentOffset:CGPointMake(0,MIN(maximum,MAX(0,card.origin.y-8))) animated:NO];
        [window layoutIfNeeded];[panel.douyindisc_scrollView layoutIfNeeded];
        for(UIControl *control in controls){hits=douyindisc_layoutWindowHit(window,control)&&hits;controlCount++;}
    }
    [panel.douyindisc_scrollView setContentOffset:CGPointZero animated:NO];[window layoutIfNeeded];
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc]initWithSize:window.bounds.size];
    UIImage *snapshot=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context){[window.layer renderInContext:context.CGContext];}];
    NSString *directory=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    [UIImagePNGRepresentation(snapshot) writeToFile:[directory stringByAppendingPathComponent:@"settings-layout.png"] atomically:YES];
    NSDictionary *result=@{@"aligned":@(aligned),@"ordered":@(ordered),@"bounded":@(bounded),@"unambiguous":@(unambiguous),@"windowHits":@(hits),@"navigationCount":@(navigationCount),@"controlCount":@(controlCount),@"discUnchanged":@(discUnchanged)};
    window.rootViewController=previousRoot;[window makeKeyAndVisible];return result;
}
