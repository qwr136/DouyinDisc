#ifndef DOUYINDISC_GLASS_STORE_CASES_H
#define DOUYINDISC_GLASS_STORE_CASES_H
static void douyindisc_glassStoreCases(void) {
    NSURL *directory=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[@"DouyinDiscGlass-" stringByAppendingString:NSUUID.UUID.UUIDString]] isDirectory:YES];
    DouyinDiscNavigationStore *store=douyindisc_uiTestCreateStore(directory);
    NSURL *url=[directory URLByAppendingPathComponent:@"glass.plist"];
    NSURL *oldURL=[directory URLByAppendingPathComponent:@"settings.plist"];
    DD_CHECK(!store.douyindisc_glassEnabled&&![NSFileManager.defaultManager fileExistsAtPath:directory.path],"glass is off by default without creating configuration files");
    NSError *error=nil;
    DD_CHECK([store douyindisc_saveEnabled:YES opacity:.73 scale:1.25 identifier:@"bottom_home" error:&error],"legacy navigation entry can be saved before enabling glass");
    NSData *legacy=[NSData dataWithContentsOfURL:oldURL];
    __block BOOL notificationSeesCommit=NO;
    id observer=[NSNotificationCenter.defaultCenter addObserverForName:@"com.minis.douyindisc.glass.changed" object:store queue:nil usingBlock:^(NSNotification *n){(void)n;notificationSeesCommit=store.douyindisc_glassEnabled&&[[NSDictionary dictionaryWithContentsOfURL:url][@"enabled"] boolValue];}];
    error=nil;
    DD_CHECK([store douyindisc_saveGlassEnabled:YES error:&error]&&error==nil&&notificationSeesCommit,"glass enabled notification observes both persisted and in-memory commit");
    [NSNotificationCenter.defaultCenter removeObserver:observer];
    DD_CHECK([legacy isEqual:[NSData dataWithContentsOfURL:oldURL]],"glass preference never rewrites legacy navigation settings");
    DouyinDiscNavigationStore *cold=douyindisc_uiTestCreateStore(directory);
    DD_CHECK(cold.douyindisc_glassEnabled&&fabs([[cold douyindisc_entryForIdentifier:@"bottom_home"][@"scale"] doubleValue]-1.25)<.001,"cold launch loads glass and legacy icon scale independently");
    NSData *before=[NSData dataWithContentsOfURL:url];
    douyindisc_uiTestFailNextCommit(store);error=nil;
    DD_CHECK(![store douyindisc_saveGlassEnabled:NO error:&error]&&error&&store.douyindisc_glassEnabled&&[before isEqual:[NSData dataWithContentsOfURL:url]],"failed glass save keeps prior value and original bytes");
    error=nil;
    DD_CHECK([store douyindisc_saveGlassEnabled:NO error:&error]&&!store.douyindisc_glassEnabled,"glass can be switched off independently of icon replacement");
    [@{@"enabled":@"bad"} writeToURL:url atomically:YES];
    NSData *corrupt=[NSData dataWithContentsOfURL:url];
    DouyinDiscNavigationStore *invalid=douyindisc_uiTestCreateStore(directory);error=nil;
    DD_CHECK(!invalid.douyindisc_glassEnabled&&![invalid douyindisc_saveGlassEnabled:YES error:&error]&&error&&[corrupt isEqual:[NSData dataWithContentsOfURL:url]],"corrupt glass preferences fail closed without overwriting user data");
    DD_CHECK([[invalid douyindisc_entryForIdentifier:@"bottom_home"][@"enabled"] boolValue],"corrupt glass configuration does not disable valid custom icons");
    [NSFileManager.defaultManager removeItemAtURL:directory error:nil];
}
#endif
