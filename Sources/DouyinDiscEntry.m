#import <Foundation/Foundation.h>
#import "DouyinDiscHostVersion.h"
#import "DouyinDiscNavigation.h"

void douyindisc_startDisplay(void);

static void douyindisc_initialize(void) {
    if (!douyindisc_hostVersionAllowed()) return;
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
