#import <Foundation/Foundation.h>
#include "DouyinDiscPolicy.h"

void douyindisc_startDisplay(void);

static void douyindisc_initialize(void) {
    id value = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (![value isKindOfClass:NSString.class] || !douyindisc_version_supported([(NSString *)value UTF8String])) return;
    dispatch_async(dispatch_get_main_queue(), ^{ douyindisc_startDisplay(); });
}

__attribute__((constructor))
static void douyindisc_entry(void) {
    @autoreleasepool {
        NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
        if (![bundleIdentifier isEqualToString:@"com.ss.iphone.ugc.Aweme"]) {
            return;
        }
        douyindisc_initialize();
    }
}
