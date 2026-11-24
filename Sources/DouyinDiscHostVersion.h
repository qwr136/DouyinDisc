#import <Foundation/Foundation.h>
#include <string.h>
#include "DouyinDiscPolicy.h"

static inline BOOL douyindisc_hostVersionAllowed(void) {
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (![version isKindOfClass:NSString.class]) return NO;
    const char *bytes = version.UTF8String;
    // A plist string can contain NUL; don't accept only its C-string prefix.
    return bytes && strlen(bytes) == [version lengthOfBytesUsingEncoding:NSUTF8StringEncoding] &&
           douyindisc_version_supported(bytes);
}
