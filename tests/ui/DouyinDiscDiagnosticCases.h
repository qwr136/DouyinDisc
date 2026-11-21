// All diagnostics tests use the real bounded writer and actual UIKit objects.
static void douyindisc_diagnosticCases(DouyinDiscDisplay *driver, AWEMusicCoverButton *control) {
    UILabel *variant=[[UILabel alloc] initWithFrame:CGRectMake(-4,30,52,14)];
    variant.text=@"玩同款"; variant.alpha=.6; [control addSubview:variant];
    [driver douyindisc_refresh:control];
    DD_CHECK(variant.alpha==0 && variant.layer.mask, "exact 玩同款 variant is suppressed within the matched disc");
    variant.attributedText=[[NSAttributedString alloc] initWithString:@"玩同款"];
    [driver douyindisc_refresh:control];
    DD_CHECK(variant.alpha==0, "attributed 玩同款 variant is also suppressed");
    variant.text=@"试试玩同款";
    [driver douyindisc_refresh:control];
    DD_CHECK(fabs(variant.alpha-.6)<.001 && !variant.layer.mask, "containing text is not broadened into an exact variant match");
    [variant removeFromSuperview];

    douyindisc_diag_install(driver);
    DouyinDiscDiagnostics *diagnostics=douyindisc_diagnostics;
    DD_CHECK(!douyindisc_diag_enabled && diagnostics.douyindisc_fd==-1 && diagnostics.douyindisc_events==0, "diagnostic entry installs with capture off by default");
    DD_CHECK(diagnostics.douyindisc_button.superview==control.window, "visible opt-in button uses the existing window rather than a new window");
    [driver douyindisc_refresh:control];
    DD_CHECK(!diagnostics.douyindisc_ids && !diagnostics.douyindisc_file && diagnostics.douyindisc_events==0, "capture off does not prepare strings, object maps or a log file during refresh");
    DouyinDiscDiagnostics *failedWriter=[DouyinDiscDiagnostics new];
    failedWriter.douyindisc_driver=driver; failedWriter.douyindisc_button=diagnostics.douyindisc_button; failedWriter.douyindisc_window=diagnostics.douyindisc_window;
    failedWriter.douyindisc_writeOverride=^ssize_t(const void *bytes,NSUInteger length) { (void)bytes; (void)length; return -1; };
    douyindisc_diagnostics=failedWriter;
    [failedWriter douyindisc_begin];
    DD_CHECK(!douyindisc_diag_enabled && failedWriter.douyindisc_fd==-1 && !failedWriter.douyindisc_completed && !failedWriter.douyindisc_timer, "failed initial trace write leaves no empty export and no running timer");
    failedWriter.douyindisc_writeOverride=nil;
    [failedWriter douyindisc_begin];
    DD_CHECK(douyindisc_diag_enabled && failedWriter.douyindisc_wroteCaptureStart && failedWriter.douyindisc_timer.isValid, "retry after initial write failure starts a complete trace");
    [failedWriter douyindisc_stop:@"test-write-retry"];
    douyindisc_diagnostics=diagnostics;

    DouyinDiscSurface *surface=objc_getAssociatedObject(control,&douyindisc_leaseKey);
    CAShapeLayer *plate=[CAShapeLayer layer];
    plate.frame=[control convertRect:control.bounds toView:surface.douyindisc_canvas];
    plate.shadowOpacity=.4; plate.shadowRadius=3;
    CGPathRef path=CGPathCreateWithEllipseInRect(plate.bounds,NULL); plate.shadowPath=path; CGPathRelease(path);
    [surface.douyindisc_canvas.layer addSublayer:plate];
    UILabel *privateLabel=[[UILabel alloc] initWithFrame:CGRectMake(1,30,42,14)];
    privateLabel.text=@"PRIVATE_DIAG_SENTINEL_TEXT";
    privateLabel.accessibilityLabel=@"PRIVATE_DIAG_SENTINEL_ACCESS";
    privateLabel.accessibilityIdentifier=@"PRIVATE_DIAG_SENTINEL_ID";
    [control addSubview:privateLabel];
    [diagnostics douyindisc_active:nil];
    [driver douyindisc_tick];
    DD_CHECK(!douyindisc_diag_enabled && diagnostics.douyindisc_fd==-1, "diagnostic stays OFF after startup and automatic display refreshes");
    [diagnostics douyindisc_begin];
    __weak CALayer *freedLayer;
    NSNumber *oldID;
    @autoreleasepool {
        CALayer *temporary=[CALayer layer]; freedLayer=temporary;
        oldID=[diagnostics douyindisc_id:temporary];
        DD_CHECK([[diagnostics douyindisc_id:temporary] isEqual:oldID], "same live object keeps one anonymous ID");
    }
    DD_CHECK(freedLayer==nil, "diagnostic identity map does not retain view or layer owners");
    CALayer *replacement=[CALayer layer];
    DD_CHECK([[diagnostics douyindisc_id:replacement] unsignedIntegerValue]>oldID.unsignedIntegerValue, "replacement objects receive monotonically new IDs after deallocation");
    DD_CHECK([[diagnostics douyindisc_id:(__bridge id)driver.douyindisc_image.CGImage] isEqual:@0], "diagnostic identity map never retains or weak-registers image resources");
    DD_CHECK(douyindisc_diag_enabled && diagnostics.douyindisc_timer.isValid, "user-started capture creates only its own bounded timer");
    DD_CHECK([diagnostics douyindisc_exportController]==nil, "active capture cannot export an unfinished open file");
    [driver douyindisc_refresh:control];
    [diagnostics douyindisc_sample];
    [diagnostics douyindisc_stop:@"test-user-stop"];
    DD_CHECK(!douyindisc_diag_enabled && !diagnostics.douyindisc_timer && diagnostics.douyindisc_fd==-1, "explicit capture stop closes file and invalidates capture timer");
    NSData *data=[NSData dataWithContentsOfURL:diagnostics.douyindisc_file];
    NSString *text=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    DD_CHECK(data.length>0 && data.length<=douyindisc_diag_byteLimit, "actual trace file respects the declared byte limit");
    DD_CHECK(![text containsString:@"PRIVATE_DIAG_SENTINEL"] && ![text containsString:@"0x"], "text, accessibility contents and raw pointers never enter the trace");
    BOOL start=NO,end=NO,shadow=NO,mask=NO,before=NO,after=NO,anonymous=NO;
    NSUInteger lines=0;
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        if (!line.length) continue;
        NSDictionary *event=[NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
        if (!event) continue;
        ++lines;
        if ([event[@"event"] isEqual:@"capture-start"] && [event[@"schema"] isEqual:@"douyindisc-visual-v1"]) start=YES;
        if ([event[@"event"] isEqual:@"capture-end"]) end=YES;
        if ([event[@"shadowPathPresent"] boolValue] && [event[@"shadowOpacity"] doubleValue]>.39) shadow=YES;
        if ([event[@"maskContentsPresent"] isEqual:@NO] && [event[@"mask"] unsignedIntegerValue]>0) mask=YES;
        if ([event[@"event"] isEqual:@"refresh-before"]) before=YES;
        if ([event[@"event"] isEqual:@"refresh-after"]) after=YES;
        if ([event[@"id"] isKindOfClass:NSNumber.class] && [event[@"parent"] isKindOfClass:NSNumber.class]) anonymous=YES;
    }
    DD_CHECK(start && end && lines==diagnostics.douyindisc_events, "trace has parseable session start and completion with exact event count");
    DD_CHECK(shadow, "local sibling shadow-path state is captured without changing it");
    DD_CHECK(mask, "trace includes the actual transparent mask state");
    DD_CHECK(before && after, "same production refresh records both native input and applied output");
    DD_CHECK(anonymous, "exported object relations use numeric capture-local IDs");
    struct stat info; lstat(diagnostics.douyindisc_file.fileSystemRepresentation,&info);
    DD_CHECK((info.st_mode & 0777)==0600, "trace is a private app-sandbox 0600 file");
    NSUInteger bytes=diagnostics.douyindisc_bytes;
    [driver douyindisc_refresh:control]; [diagnostics douyindisc_sample];
    DD_CHECK(diagnostics.douyindisc_bytes==bytes, "stopped diagnostics leaves the file unchanged across refresh and sample");
    [plate removeFromSuperlayer]; [privateLabel removeFromSuperview];

    [diagnostics douyindisc_begin];
    diagnostics.douyindisc_deadline=CACurrentMediaTime()-1;
    [diagnostics douyindisc_sample];
    DD_CHECK(!douyindisc_diag_enabled && !diagnostics.douyindisc_timer, "monotonic deadline automatically stops the bounded capture");
    [diagnostics douyindisc_begin];
    diagnostics.douyindisc_events=douyindisc_diag_eventLimit-1;
    [diagnostics douyindisc_append:@{@"event":@"test-budget"}];
    DD_CHECK(!douyindisc_diag_enabled && diagnostics.douyindisc_events<=douyindisc_diag_eventLimit, "event cap stops capture instead of unbounded logging");
    [diagnostics douyindisc_begin];
    [diagnostics douyindisc_inactive:nil];
    DD_CHECK(!douyindisc_diag_enabled && diagnostics.douyindisc_fd==-1, "real inactive callback stops capture and closes its file");
    DD_CHECK(objc_getAssociatedObject(control,&douyindisc_leaseKey)==surface && surface.douyindisc_overlay.superlayer!=nil, "capture and stop never remove the existing visual repair");
}
