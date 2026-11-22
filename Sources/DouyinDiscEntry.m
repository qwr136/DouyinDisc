#import <Foundation/Foundation.h>
#include "DouyinDiscPolicy.h"
#import "DouyinDiscNavigation.h"

void douyindisc_startDisplay(void);

static void douyindisc_initialize(void) {
    id value = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (![value isKindOfClass:NSString.class] || !douyindisc_version_supported([(NSString *)value UTF8String])) return;
    id build = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    if (![build isKindOfClass:NSString.class] || ![(NSString *)build isEqualToString:@"399017"]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        douyindisc_startDisplay();
        douyindisc_installNavigationHooks();
        [[DouyinDiscNavigationStore douyindisc_sharedStore] douyindisc_preloadImagesWithCompletion:nil];
    });
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
