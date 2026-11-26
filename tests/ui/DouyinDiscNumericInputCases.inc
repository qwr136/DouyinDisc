// Included at file scope by DouyinDiscNavigation.m under DOUYINDISC_UI_TEST.
// Main-thread, synchronous UIKit test. Does NOT claim a keyboard notification or
// an on-screen software keyboard: textInputMode + first responder are observed.
#if !defined(DOUYINDISC_UI_TEST)
#error Numeric input cases must only be included in the UIKit test host.
#endif
extern void douyindisc_uiTestFailNextCommit(DouyinDiscNavigationStore *store);
extern DouyinDiscNavigationStore *douyindisc_uiTestCreateStore(NSURL *directory);

@interface DouyinDiscNumericInputEvents : NSObject
@property(nonatomic) NSUInteger begins, ends;
- (void)douyindisc_numericBegan:(UITextField *)field;
- (void)douyindisc_numericEnded:(UITextField *)field;
@end
@implementation DouyinDiscNumericInputEvents
- (void)douyindisc_numericBegan:(UITextField *)field {(void)field;self.begins++;}
- (void)douyindisc_numericEnded:(UITextField *)field {(void)field;self.ends++;}
@end

// Only the error presentation is intercepted: inherited layout, field actions,
// the production appearance callback, Store writes and rollback all run unchanged.
@interface DouyinDiscNumericInputPanel : DouyinDiscSettingsViewController
@property(nonatomic,strong) NSError *douyindisc_numericError;
@end
@implementation DouyinDiscNumericInputPanel
- (void)douyindisc_showError:(NSError *)error {self.douyindisc_numericError=error;}
@end

static DouyinDiscNavigationRow *douyindisc_numericRow(DouyinDiscSettingsViewController *panel, NSString *identifier) {
    for(UIView *view in panel.douyindisc_stack.arrangedSubviews)
        if([view isKindOfClass:DouyinDiscNavigationRow.class]&&[[(DouyinDiscNavigationRow *)view douyindisc_identifier] isEqual:identifier])return (DouyinDiscNavigationRow *)view;
    return nil;
}
static BOOL douyindisc_numericWindowHit(UIWindow *window, DouyinDiscSettingsViewController *panel, UIControl *control) {
    if(!control||control.window!=window||!control.enabled)return NO;
    UIScrollView *scroll=panel.douyindisc_scrollView;
    CGRect rect=[control convertRect:control.bounds toView:scroll];
    [scroll scrollRectToVisible:CGRectInset(rect,-8,-8) animated:NO];
    [window layoutIfNeeded];[scroll layoutIfNeeded];
    CGPoint point=[control convertPoint:CGPointMake(CGRectGetMidX(control.bounds),CGRectGetMidY(control.bounds)) toView:window];
    UIView *hit=[window hitTest:point withEvent:nil];
    BOOL matched=hit&&(hit==control||[hit isDescendantOfView:control]);
    if(!matched)NSLog(@"DD_NUMERIC_HIT target=%@ point=%@ hit=%@",control.accessibilityIdentifier,NSStringFromCGPoint(point),hit);
    return matched; // Never accept a card, ancestor, or row-local fallback hit.
}
static UIBarButtonItem *douyindisc_numericDone(UITextField *field, DouyinDiscNavigationRow *row) {
    if(![field.inputAccessoryView isKindOfClass:UIToolbar.class])return nil;
    for(UIBarButtonItem *item in ((UIToolbar *)field.inputAccessoryView).items)
        if(item.enabled&&item.target==row&&item.action==@selector(douyindisc_inputAccessoryDone))return item;
    return nil;
}
static CGFloat douyindisc_numericValue(DouyinDiscNavigationRow *row, NSUInteger index) {
    return index==0?row.douyindisc_angle:(index==1?row.douyindisc_cornerRadius:row.douyindisc_rotationSpeed);
}
static NSString *douyindisc_numericText(CGFloat value, NSUInteger index, BOOL unit) {
    return [NSString stringWithFormat:@"%ld%@",(long)lrint(value*(index==2?100:1)),unit?(index==0?@"°":@"%"):@""];
}

NSDictionary *douyindisc_uiTestNumericInput(UIWindow *window) {
    NSArray<NSString *> *keys=@[@"fixtureReady",@"textFields",@"windowHits",@"numberPadAndDone",@"eventBindings",@"firstResponder",@"inputModeAvailable",@"beginRemovesUnit",@"editingEvents",@"doneEndsEditing",@"angleCommit",@"cornerCommit",@"speedCommit",@"unitsAccepted",@"emptyRejected",@"invalidRejected",@"lowerBounds",@"upperBounds",@"overflowClamped",@"steppersUnchanged",@"otherItemUnchanged",@"videoDiscUnchanged",@"unrelatedSettingsUnchanged",@"coldStorePersistence",@"reopenPersistence",@"saveFailureRollback",@"restored"];
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    for(NSString *key in keys)result[key]=@NO;
    if(!window||!NSThread.isMainThread)return result;
    DouyinDiscNavigationStore *store=DouyinDiscNavigationStore.douyindisc_sharedStore;
    UIViewController *previousRoot=window.rootViewController;
    BOOL wasHidden=window.hidden;
    UIWindow *previousKey=nil;
    for(UIWindow *candidate in window.windowScene.windows)if(candidate.isKeyWindow){previousKey=candidate;break;}
    // Snapshot exact memory AND file state: previous UIKit cases may have an
    // intentionally memory-only fixture. Saving old effective values is not enough.
    NSDictionary *oldConfig=[[store valueForKey:@"douyindisc_config"] copy];
    NSDictionary *oldOpacity=[[store valueForKey:@"douyindisc_previewOpacity"] copy];
    NSDictionary *oldScale=[[store valueForKey:@"douyindisc_previewScale"] copy];
    id oldFailure=[store valueForKey:@"douyindisc_testFailNextCommit"];
    NSURL *directory=[store valueForKey:@"douyindisc_storeDirectory"];
    NSURL *settings=[directory URLByAppendingPathComponent:@"settings.plist"];
    NSFileManager *fm=NSFileManager.defaultManager;
    BOOL hadDirectory=[fm fileExistsAtPath:directory.path],hadFile=[fm fileExistsAtPath:settings.path];
    NSData *oldData=hadFile?[NSData dataWithContentsOfURL:settings]:nil;
    if(!directory||!oldConfig||(hadFile&&!oldData)||[oldFailure boolValue])return result;
    NSDictionary *oldEntry=[[store douyindisc_entryForIdentifier:@"top_recommend"] copy];
    NSDictionary *otherEntry=[[store douyindisc_entryForIdentifier:@"bottom_home"] copy];
    NSDictionary *discEntry=[[store douyindisc_entryForIdentifier:@"video_disc"] copy];
    DouyinDiscNumericInputPanel *panel=[DouyinDiscNumericInputPanel new];
    DouyinDiscNavigationRow *row=nil;
    void (^productionChange)(DouyinDiscNavigationRow *)=nil;
    @try {
        UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:panel];
        window.rootViewController=nav;[window makeKeyAndVisible];
        [window layoutIfNeeded];[nav.view layoutIfNeeded];[panel.view layoutIfNeeded];
        [panel.douyindisc_scrollView layoutIfNeeded];[panel.douyindisc_stack layoutIfNeeded];
        row=douyindisc_numericRow(panel,@"top_recommend");
        DouyinDiscNavigationRow *disc=douyindisc_numericRow(panel,@"video_disc");
        result[@"fixtureReady"]=@(row&&disc&&panel.view.window==window);
        // Use id for the guard so the regression fails cleanly against old UILabels.
        NSArray *candidates=@[row.douyindisc_angleValue?:NSNull.null,row.douyindisc_cornerValue?:NSNull.null,row.douyindisc_rotationSpeedValue?:NSNull.null];
        BOOL textFields=row!=nil;
        for(id candidate in candidates)textFields=textFields&&[candidate isKindOfClass:UITextField.class];
        result[@"textFields"]=@(textFields);
        if(!textFields)return result; // @finally still restores the fixture.
        NSArray<UITextField *> *fields=candidates;
        NSArray<NSString *> *storeKeys=@[@"angle",@"cornerRadius",@"rotationSpeed"];
        DouyinDiscNumericInputEvents *events=[DouyinDiscNumericInputEvents new];
        BOOL hits=YES,traits=YES,bindings=YES;
        for(UITextField *field in fields){
            hits=douyindisc_numericWindowHit(window,panel,field)&&hits;
            traits=(field.keyboardType==UIKeyboardTypeNumberPad&&douyindisc_numericDone(field,row)!=nil)&&traits;
            bindings=[[field actionsForTarget:row forControlEvent:UIControlEventEditingDidBegin] containsObject:NSStringFromSelector(@selector(douyindisc_editingAppearanceInput:))]&&bindings;
            bindings=[[field actionsForTarget:row forControlEvent:UIControlEventEditingDidEnd] containsObject:NSStringFromSelector(@selector(douyindisc_commitAppearanceInput:))]&&bindings;
            [field addTarget:events action:@selector(douyindisc_numericBegan:) forControlEvents:UIControlEventEditingDidBegin];
            [field addTarget:events action:@selector(douyindisc_numericEnded:) forControlEvents:UIControlEventEditingDidEnd];
        }
        result[@"windowHits"]=@(hits);result[@"numberPadAndDone"]=@(traits);result[@"eventBindings"]=@(bindings);
        productionChange=[row.douyindisc_changeAppearance copy];
        __block NSUInteger callbacks=0;
        row.douyindisc_changeAppearance=^(DouyinDiscNavigationRow *changed){callbacks++;if(productionChange)productionChange(changed);};
        __block BOOL responders=YES,modes=YES,begins=YES,eventDelivery=YES,ends=YES;
        BOOL (^edit)(NSUInteger,NSString *,CGFloat,BOOL)=^BOOL(NSUInteger index,NSString *input,CGFloat expected,BOOL save){
            UITextField *field=fields[index];
            NSDictionary *before=[[store douyindisc_entryForIdentifier:@"top_recommend"] copy];
            NSData *beforeData=save?nil:[NSData dataWithContentsOfURL:settings];
            NSUInteger count=callbacks,beginCount=events.begins,endCount=events.ends;
            BOOL hit=douyindisc_numericWindowHit(window,panel,field);
            BOOL became=[field becomeFirstResponder]&&field.isFirstResponder;
            responders=became&&responders;modes=(field.textInputMode!=nil)&&modes;
            begins=[field.text isEqual:douyindisc_numericText(douyindisc_numericValue(row,index),index,NO)]&&begins;
            if(!became)return NO;
            // Assigning the replacement text models typing/paste. Never call the
            // production commit selector or synthesize EditingDidBegin/DidEnd.
            field.text=input;[field sendActionsForControlEvents:UIControlEventEditingChanged];
            BOOL noEarlySave=callbacks==count;
            UIBarButtonItem *done=douyindisc_numericDone(field,row);
            BOOL dispatched=done&&[UIApplication.sharedApplication sendAction:done.action to:done.target from:done forEvent:nil];
            BOOL ended=dispatched&&!field.isFirstResponder;ends=ended&&ends;
            BOOL delivered=events.begins==beginCount+1&&events.ends==endCount+1;
            eventDelivery=delivered&&eventDelivery;
            NSDictionary *after=[store douyindisc_entryForIdentifier:@"top_recommend"];
            BOOL value=fabs(douyindisc_numericValue(row,index)-expected)<.0001&&fabs([after[storeKeys[index]] doubleValue]-expected)<.0001&&[field.text isEqual:douyindisc_numericText(expected,index,YES)];
            BOOL countOK=callbacks==count+(save?1:0);
            BOOL untouched=YES;
            for(NSUInteger other=0;other<3;other++)if(other!=index)untouched=[before[storeKeys[other]] isEqual:after[storeKeys[other]]]&&untouched;
            if(!save){NSData *afterData=[NSData dataWithContentsOfURL:settings];untouched=[before isEqual:after]&&((!beforeData&&!afterData)||[beforeData isEqual:afterData])&&untouched;}
            BOOL passed=hit&&became&&noEarlySave&&ended&&delivered&&productionChange&&countOK&&value&&untouched;
            if(!passed)NSLog(@"DD_NUMERIC_EDIT index=%lu input=%@ expected=%g callbacks=%lu hit=%d responder=%d ended=%d events=%d value=%d untouched=%d",(unsigned long)index,input,(double)expected,(unsigned long)(callbacks-count),hit,became,ended,delivered,value,untouched);
            return passed;
        };
        CGFloat angle=fabs(row.douyindisc_angle-137)<.0001?138:137;
        CGFloat corner=fabs(row.douyindisc_cornerRadius-19)<.0001?20:19;
        CGFloat speed=fabs(row.douyindisc_rotationSpeed-1.75)<.0001?1.76:1.75;
        result[@"angleCommit"]=@(edit(0,douyindisc_numericText(angle,0,NO),angle,YES));
        result[@"cornerCommit"]=@(edit(1,douyindisc_numericText(corner,1,NO),corner,YES));
        result[@"speedCommit"]=@(edit(2,douyindisc_numericText(speed,2,NO),speed,YES));
        BOOL units=edit(0,@"248°",248,YES);
        units=edit(1,@"31%",31,YES)&&units;units=edit(2,@"220%",2.2,YES)&&units;
        result[@"unitsAccepted"]=@(units);
        DouyinDiscNavigationStore *fractionCold=douyindisc_uiTestCreateStore(directory);
        NSDictionary *fractionEntry=[fractionCold douyindisc_entryForIdentifier:@"top_recommend"];
        BOOL fractionPersisted=fabs([fractionEntry[@"angle"] doubleValue]-248)<.0001&&fabs([fractionEntry[@"cornerRadius"] doubleValue]-31)<.0001&&fabs([fractionEntry[@"rotationSpeed"] doubleValue]-2.2)<.0001;
        BOOL empty=YES,invalid=YES;
        for(NSUInteger i=0;i<3;i++){
            for(NSString *text in @[@"",@" \t\n"])
                empty=edit(i,text,douyindisc_numericValue(row,i),NO)&&empty;
            NSMutableArray<NSString *> *bad=[@[@"abc",@"12x",@"1.5",@"+1",@"-1",@"1e2",@"１２",@"١٢",@"1 2",@"\u200B12"] mutableCopy];
            [bad addObjectsFromArray:i==0?@[@"12%",@"12°°"]:@[@"12°",@"12%%"]];
            for(NSString *text in bad)invalid=edit(i,text,douyindisc_numericValue(row,i),NO)&&invalid;
        }
        result[@"emptyRejected"]=@(empty);result[@"invalidRejected"]=@(invalid);
        // Negative values above are invalid, NOT a request to clamp. Zero is a
        // legal lower bound for angle/corner and below the legal speed range.
        BOOL lower=YES,upper=YES,overflow=YES;
        NSArray<NSNumber *> *minimums=@[@0,@0,@.25],*maximums=@[@359,@50,@3];
        NSArray<NSString *> *maximumText=@[@"359",@"50",@"300"],*overText=@[@"360",@"51",@"301"];
        for(NSUInteger i=0;i<3;i++){
            lower=edit(i,@"0",[minimums[i] doubleValue],YES)&&lower;
            upper=edit(i,maximumText[i],[maximums[i] doubleValue],YES)&&upper;
            lower=edit(i,i==2?@"25%":(i==0?@"0°":@"0%"),[minimums[i] doubleValue],YES)&&lower;
            upper=edit(i,overText[i],[maximums[i] doubleValue],YES)&&upper;
            lower=edit(i,i==2?@"24":@"1",i==2?.25:1,YES)&&lower;
            overflow=edit(i,@"99999999999999999999999999999999999999999999999999",[maximums[i] doubleValue],YES)&&overflow;
        }
        result[@"lowerBounds"]=@(lower);result[@"upperBounds"]=@(upper);result[@"overflowClamped"]=@(overflow);
        // Existing buttons must retain angle wrap, corner saturation and 5% speed
        // increments, with the same production callback and Store persistence.
        NSArray<NSArray<UIButton *> *> *steps=@[@[row.douyindisc_anglePlus,row.douyindisc_angleMinus],@[row.douyindisc_cornerMinus,row.douyindisc_cornerPlus],@[row.douyindisc_rotationSpeedMinus,row.douyindisc_rotationSpeedPlus]];
        NSArray<NSArray<NSNumber *> *> *stepValues=@[@[@0,@359],@[@49,@50],@[@2.95,@3]];
        BOOL steppers=YES;
        for(NSUInteger i=0;i<3;i++)for(NSUInteger j=0;j<2;j++){
            UIButton *button=steps[i][j];CGFloat expected=[stepValues[i][j] doubleValue];NSUInteger count=callbacks;
            BOOL hit=douyindisc_numericWindowHit(window,panel,button);
            [button sendActionsForControlEvents:UIControlEventTouchUpInside];
            steppers=hit&&callbacks==count+1&&fabs(douyindisc_numericValue(row,i)-expected)<.0001&&fabs([[store douyindisc_entryForIdentifier:@"top_recommend"][storeKeys[i]] doubleValue]-expected)<.0001&&[fields[i].text isEqual:douyindisc_numericText(expected,i,YES)]&&steppers;
        }
        result[@"steppersUnchanged"]=@(steppers);
        result[@"firstResponder"]=@(responders);result[@"inputModeAvailable"]=@(modes);
        result[@"beginRemovesUnit"]=@(begins);result[@"editingEvents"]=@(eventDelivery);result[@"doneEndsEditing"]=@(ends);
        NSDictionary *committed=[[store douyindisc_entryForIdentifier:@"top_recommend"] copy];
        DouyinDiscNavigationStore *cold=douyindisc_uiTestCreateStore(directory);
        NSDictionary *coldEntry=[cold douyindisc_entryForIdentifier:@"top_recommend"];
        BOOL persisted=YES;
        for(NSString *key in storeKeys)persisted=[committed[key] isEqual:coldEntry[key]]&&persisted;
        result[@"coldStorePersistence"]=@(fractionPersisted&&persisted);
        DouyinDiscSettingsViewController *reopened=[DouyinDiscSettingsViewController new];
        [nav setViewControllers:@[reopened] animated:NO];[window layoutIfNeeded];[reopened.view layoutIfNeeded];
        DouyinDiscNavigationRow *reopenedRow=douyindisc_numericRow(reopened,@"top_recommend");
        NSArray *reopenedFields=@[reopenedRow.douyindisc_angleValue?:NSNull.null,reopenedRow.douyindisc_cornerValue?:NSNull.null,reopenedRow.douyindisc_rotationSpeedValue?:NSNull.null];
        BOOL reopenedOK=reopenedRow&&reopened.view.window==window;
        for(NSUInteger i=0;i<3;i++){
            UITextField *field=reopenedFields[i];CGFloat expected=[committed[storeKeys[i]] doubleValue];
            reopenedOK=[field isKindOfClass:UITextField.class]&&fabs(douyindisc_numericValue(reopenedRow,i)-expected)<.0001&&[field.text isEqual:douyindisc_numericText(expected,i,YES)]&&reopenedOK;
        }
        result[@"reopenPersistence"]=@(reopenedOK);
        // Reattach the original panel; inject failures into the real Store, not
        // a replacement callback. Its inherited rollback must restore all fields.
        [nav setViewControllers:@[panel] animated:NO];[window layoutIfNeeded];[panel.view layoutIfNeeded];
        BOOL rollback=YES;
        NSArray<NSString *> *failedInputs=@[@"123",@"17",@"155"];
        for(NSUInteger i=0;i<3;i++){
            NSData *beforeData=[NSData dataWithContentsOfURL:settings];
            NSDictionary *before=[[store douyindisc_entryForIdentifier:@"top_recommend"] copy];
            panel.douyindisc_numericError=nil;douyindisc_uiTestFailNextCommit(store);
            BOOL tested=edit(i,failedInputs[i],douyindisc_numericValue(row,i),YES);
            rollback=tested&&panel.douyindisc_numericError!=nil&&![[store valueForKey:@"douyindisc_testFailNextCommit"] boolValue]&&[before isEqual:[store douyindisc_entryForIdentifier:@"top_recommend"]]&&[beforeData isEqual:[NSData dataWithContentsOfURL:settings]]&&rollback;
        }
        result[@"saveFailureRollback"]=@(rollback);
        result[@"firstResponder"]=@(responders);result[@"inputModeAvailable"]=@(modes);
        result[@"beginRemovesUnit"]=@(begins);result[@"editingEvents"]=@(eventDelivery);result[@"doneEndsEditing"]=@(ends);
        result[@"otherItemUnchanged"]=@([otherEntry isEqual:[store douyindisc_entryForIdentifier:@"bottom_home"]]);
        result[@"videoDiscUnchanged"]=@([discEntry isEqual:[store douyindisc_entryForIdentifier:@"video_disc"]]&&disc&&!disc.douyindisc_angleValue&&!disc.douyindisc_cornerValue&&!disc.douyindisc_rotationSpeedValue&&!disc.douyindisc_rotationSwitch&&fabs(disc.bounds.size.height-198)<.75&&fabs(disc.douyindisc_scale-[discEntry[@"speed"] doubleValue])<.0001);
        NSMutableDictionary *oldOther=[oldConfig mutableCopy],*newOther=[[store valueForKey:@"douyindisc_config"] mutableCopy];
        [oldOther removeObjectForKey:@"top_recommend"];[newOther removeObjectForKey:@"top_recommend"];
        NSMutableDictionary *oldSettings=[oldEntry mutableCopy],*newSettings=[[store douyindisc_entryForIdentifier:@"top_recommend"] mutableCopy];
        for(NSString *key in storeKeys){[oldSettings removeObjectForKey:key];[newSettings removeObjectForKey:key];}
        result[@"unrelatedSettingsUnchanged"]=@([oldOther isEqual:newOther]&&[oldSettings isEqual:newSettings]);
    } @catch(NSException *exception) {
        NSLog(@"DD_NUMERIC_EXCEPTION %@",exception);
        result[@"fixtureReady"]=@NO;
    } @finally {
        [window endEditing:YES];
        if(row&&productionChange)row.douyindisc_changeAppearance=productionChange;
        window.rootViewController=previousRoot;
        window.hidden=wasHidden;if(previousKey)[previousKey makeKeyWindow];
        // Panel creation queues image preload work. Invalidate only the queued
        // generations; do not clear/replace images, GIF animations or pick tickets.
        NSUInteger generation=[[store valueForKey:@"douyindisc_preloadGeneration"] unsignedIntegerValue];
        [store setValue:@(generation+1) forKey:@"douyindisc_preloadGeneration"];
        [store setValue:oldConfig forKey:@"douyindisc_config"];
        [store setValue:[oldOpacity mutableCopy] forKey:@"douyindisc_previewOpacity"];
        [store setValue:[oldScale mutableCopy] forKey:@"douyindisc_previewScale"];
        [store setValue:oldFailure forKey:@"douyindisc_testFailNextCommit"];
        BOOL restoredFile=hadFile?[oldData writeToURL:settings options:NSDataWritingAtomic error:nil]:(![fm fileExistsAtPath:settings.path]||[fm removeItemAtURL:settings error:nil]);
        if(!hadDirectory&&[fm fileExistsAtPath:directory.path]&&[fm contentsOfDirectoryAtPath:directory.path error:nil].count==0)[fm removeItemAtURL:directory error:nil];
        [NSNotificationCenter.defaultCenter postNotificationName:@"com.minis.douyindisc.navigation.changed" object:store];
        BOOL bytesMatch=hadFile?[oldData isEqual:[NSData dataWithContentsOfURL:settings]]:![fm fileExistsAtPath:settings.path];
        result[@"restored"]=@(restoredFile&&bytesMatch&&[[store valueForKey:@"douyindisc_config"] isEqual:oldConfig]&&[[store douyindisc_entryForIdentifier:@"top_recommend"] isEqual:oldEntry]&&[[store douyindisc_entryForIdentifier:@"bottom_home"] isEqual:otherEntry]&&[[store douyindisc_entryForIdentifier:@"video_disc"] isEqual:discEntry]&&window.rootViewController==previousRoot&&window.hidden==wasHidden);
    }
    return result;
}

// Independent asynchronous software-keyboard proof. Call serially on the main
// thread, before starting any other UIKit fixture. Completion is exactly once.
// The panel PNG excludes the system keyboard; the JSON marker asks the runner
// for a real simctl screenshot while the keyboard is held for another second.
void douyindisc_uiTestKeyboardVisible(UIWindow *window, void(^done)(BOOL)) {
    static BOOL running=NO;
    if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{if(done)done(NO);});return;}
    if(!window||!done||running){if(done)done(NO);return;}running=YES;
    DouyinDiscNavigationStore *store=DouyinDiscNavigationStore.douyindisc_sharedStore;
    UIViewController *previousRoot=window.rootViewController;
    BOOL wasHidden=window.hidden;UIWindow *previousKey=nil;
    for(UIWindow *candidate in window.windowScene.windows)if(candidate.isKeyWindow){previousKey=candidate;break;}
    NSDictionary *config=[[store valueForKey:@"douyindisc_config"] copy];
    NSDictionary *opacity=[[store valueForKey:@"douyindisc_previewOpacity"] copy];
    NSDictionary *scale=[[store valueForKey:@"douyindisc_previewScale"] copy];
    NSURL *directory=[store valueForKey:@"douyindisc_storeDirectory"];
    NSURL *settings=[directory URLByAppendingPathComponent:@"settings.plist"];
    NSFileManager *fm=NSFileManager.defaultManager;
    BOOL hadDirectory=[fm fileExistsAtPath:directory.path],hadFile=[fm fileExistsAtPath:settings.path];
    NSData *bytes=hadFile?[NSData dataWithContentsOfURL:settings]:nil;
    if(!config||!directory||(hadFile&&!bytes)){running=NO;done(NO);return;}
    NSString *documents=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    NSString *marker=[documents stringByAppendingPathComponent:@"numeric-keyboard-visible.json"];
    NSString *png=[documents stringByAppendingPathComponent:@"numeric-keyboard-panel.png"];
    [fm removeItemAtPath:marker error:nil];[fm removeItemAtPath:png error:nil];
    DouyinDiscSettingsViewController *panel=[DouyinDiscSettingsViewController new];
    UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:panel];
    __block DouyinDiscNavigationRow *row=nil;
    __block UITextField *field=nil;
    __block BOOL finished=NO,shown=NO,captureScheduled=NO;
    __block CGRect keyboardFrame=CGRectZero;
    NSMutableArray *observers=[NSMutableArray array];
    NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
    BOOL (^visible)(void)=^BOOL{
        CGRect intersection=CGRectIntersection(window.bounds,keyboardFrame);
        return shown&&field.isFirstResponder&&field.window==window&&window.rootViewController==nav&&!CGRectIsNull(intersection)&&CGRectGetWidth(intersection)>0&&CGRectGetHeight(intersection)>100;
    };
    void (^finish)(BOOL)=^(BOOL passed){
        if(finished)return;finished=YES;
        for(id token in observers)[center removeObserver:token];[observers removeAllObjects];
        // Empty text is invalid by contract: focus-only probing must not save.
        field.text=@"";
        UIBarButtonItem *button=douyindisc_numericDone(field,row);
        BOOL sent=button&&[UIApplication.sharedApplication sendAction:button.action to:button.target from:button forEvent:nil];
        BOOL ended=sent&&!field.isFirstResponder;
        [panel.view endEditing:YES];
        BOOL unchanged=[[store valueForKey:@"douyindisc_config"] isEqual:config];
        NSData *after=[NSData dataWithContentsOfURL:settings];
        unchanged=((hadFile&&[bytes isEqual:after])||(!hadFile&&!after))&&unchanged;
        window.rootViewController=previousRoot;window.hidden=wasHidden;if(previousKey)[previousKey makeKeyWindow];
        NSUInteger generation=[[store valueForKey:@"douyindisc_preloadGeneration"] unsignedIntegerValue];
        [store setValue:@(generation+1) forKey:@"douyindisc_preloadGeneration"];
        [store setValue:config forKey:@"douyindisc_config"];
        [store setValue:[opacity mutableCopy] forKey:@"douyindisc_previewOpacity"];
        [store setValue:[scale mutableCopy] forKey:@"douyindisc_previewScale"];
        BOOL restored=YES;
        if(!unchanged)restored=hadFile?[bytes writeToURL:settings options:NSDataWritingAtomic error:nil]:(![fm fileExistsAtPath:settings.path]||[fm removeItemAtURL:settings error:nil]);
        if(!hadDirectory&&[fm fileExistsAtPath:directory.path]&&[fm contentsOfDirectoryAtPath:directory.path error:nil].count==0)[fm removeItemAtURL:directory error:nil];
        [center postNotificationName:@"com.minis.douyindisc.navigation.changed" object:store];
        BOOL success=passed&&ended&&unchanged&&restored&&window.rootViewController==previousRoot;
        NSLog(@"DD_NUMERIC_KEYBOARD_FINISHED pass=%d didShow=%d doneEnded=%d configUnchanged=%d",success,shown,ended,unchanged);
        if(!success)[fm removeItemAtPath:marker error:nil];
        running=NO;done(success);
    };
    // The deadline includes panel mounting, notification wait and screenshot hold.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(5.8*NSEC_PER_SEC)),dispatch_get_main_queue(),^{finish(NO);});
    @try {
        window.rootViewController=nav;[window makeKeyAndVisible];
        [window layoutIfNeeded];[nav.view layoutIfNeeded];[panel.view layoutIfNeeded];
        [panel.douyindisc_scrollView layoutIfNeeded];[panel.douyindisc_stack layoutIfNeeded];
        // Do not let this asynchronous probe change prior GIF/image fixtures.
        NSUInteger generation=[[store valueForKey:@"douyindisc_preloadGeneration"] unsignedIntegerValue];
        [store setValue:@(generation+1) forKey:@"douyindisc_preloadGeneration"];
        row=douyindisc_numericRow(panel,@"top_recommend");
        if(![row.douyindisc_angleValue isKindOfClass:UITextField.class]){finish(NO);return;}
        field=row.douyindisc_angleValue;
        if(!douyindisc_numericWindowHit(window,panel,field)||field.keyboardType!=UIKeyboardTypeNumberPad||!douyindisc_numericDone(field,row)){finish(NO);return;}
        void (^updateFrame)(NSNotification *)=^(NSNotification *note){
            NSValue *value=note.userInfo[UIKeyboardFrameEndUserInfoKey];
            keyboardFrame=value?[window convertRect:value.CGRectValue fromCoordinateSpace:window.screen.coordinateSpace]:CGRectZero;
        };
        [observers addObject:[center addObserverForName:UIKeyboardDidHideNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){(void)note;shown=NO;keyboardFrame=CGRectZero;}]];
        [observers addObject:[center addObserverForName:UIKeyboardDidChangeFrameNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){if(!finished)updateFrame(note);}]];
        [observers addObject:[center addObserverForName:UIKeyboardDidShowNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){
            if(finished||!field.isFirstResponder)return;updateFrame(note);shown=YES;
            if(!visible()||captureScheduled)return;captureScheduled=YES;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                if(finished)return;if(!visible()){finish(NO);return;}
                NSDictionary *evidence=@{@"event":@"UIKeyboardDidShowNotification",@"firstResponder":@YES,@"windowIntersection":NSStringFromCGRect(CGRectIntersection(window.bounds,keyboardFrame)),@"timestamp":@([NSDate date].timeIntervalSince1970),@"screenshotHoldSeconds":@1};
                NSData *json=[NSJSONSerialization dataWithJSONObject:evidence options:0 error:nil];
                BOOL marked=[json writeToFile:marker atomically:YES];
                UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc]initWithSize:window.bounds.size];
                UIImage *image=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context){(void)context;[window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];}];
                BOOL captured=[UIImagePNGRepresentation(image) writeToFile:png atomically:YES];
                NSLog(@"DD_NUMERIC_KEYBOARD_VISIBLE marker=%@ frame=%@",marker,NSStringFromCGRect(keyboardFrame));
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{if(!finished)finish(marked&&captured&&visible());});
            });
        }]];
        // Yield once so panel/window appearance reaches UIKit before asking focus.
        dispatch_async(dispatch_get_main_queue(),^{if(!finished&&(![field becomeFirstResponder]||!field.isFirstResponder))finish(NO);});
    } @catch(NSException *exception) {NSLog(@"DD_NUMERIC_KEYBOARD_EXCEPTION %@",exception);finish(NO);}
}
