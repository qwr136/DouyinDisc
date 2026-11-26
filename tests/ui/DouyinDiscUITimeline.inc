// Test-host only. Marker identity binds startup/progress to one runner launch.
void douyindisc_uiTraceEvent(NSString *event, NSString *detail) {
    NSString *directory=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    NSString *nonce=NSProcessInfo.processInfo.environment[@"DOUYINDISC_TEST_NONCE"]?:@"local";
    NSDictionary *record=@{@"nonce":nonce,@"event":event?:@"unknown",@"detail":detail?:@"",@"timeUTC":@([NSDate date].timeIntervalSince1970),@"uptime":@(CACurrentMediaTime()),@"checks":@(douyindisc_checks)};
    NSData *json=[NSJSONSerialization dataWithJSONObject:record options:0 error:nil];
    if(!directory||!json)return;
    NSString *marker=[event isEqual:@"APP_STARTED"]?@"uikit-start.json":([event isEqual:@"TEST_BEGIN"]?@"uikit-begin.json":([event isEqual:@"TEST_DONE"]?@"uikit-complete.json":nil));
    if(marker)[json writeToFile:[directory stringByAppendingPathComponent:marker] atomically:YES];
    NSString *path=[directory stringByAppendingPathComponent:@"uikit-timeline.jsonl"];
    if(![NSFileManager.defaultManager fileExistsAtPath:path])[NSFileManager.defaultManager createFileAtPath:path contents:nil attributes:nil];
    @try {
        NSFileHandle *file=[NSFileHandle fileHandleForWritingAtPath:path];
        [file seekToEndOfFile];[file writeData:json];[file writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];[file closeFile];
    } @catch(NSException *exception) {NSLog(@"DD_TRACE_ERROR %@",exception.name);}
}
