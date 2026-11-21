#ifndef DOUYINDISC_NATIVE_H
#define DOUYINDISC_NATIVE_H
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <string.h>

static id douyindisc_nativeObject(id object, const char *ownerName, const char *field, const char *type) {
    Class owner = NSClassFromString([NSString stringWithUTF8String:ownerName]);
    if (!owner || ![object isKindOfClass:owner]) return nil;
    Ivar ivar = class_getInstanceVariable(owner, field);
    const char *actual = ivar ? ivar_getTypeEncoding(ivar) : NULL;
    return actual && !strcmp(actual, type) ? object_getIvar(object, ivar) : nil;
}

// Classes/ivar types are verified against AwemeCore 39.9.0 build 399017.
static UIView *douyindisc_nativeSubview(UIControl *control, const char *ownerName,
                                      const char *ivarName, const char *expectedType) {
    Class owner = NSClassFromString([NSString stringWithUTF8String:ownerName]);
    if (!owner || ![control isKindOfClass:owner]) return nil;
    Ivar ivar = class_getInstanceVariable(owner, ivarName);
    const char *actual = ivar ? ivar_getTypeEncoding(ivar) : NULL;
    if (!actual || strcmp(actual, expectedType)) return nil;
    id value = object_getIvar(control, ivar);
    if (![value isKindOfClass:UIView.class] || value == control ||
        ![(UIView *)value isDescendantOfView:control] ||
        [value isKindOfClass:UIControl.class] || ((UIView *)value).userInteractionEnabled) return nil;
    return value;
}

static BOOL douyindisc_nativeMusic(UIControl *control) {
    Class cls = NSClassFromString(@"AWEMusicCoverButton");
    return cls && [control isKindOfClass:cls];
}

static UIView *douyindisc_nativeListenHost(UIControl *control) {
    Class cls = NSClassFromString(@"AWEPlayInteractionListenFeedView");
    UIView *ancestor = control.superview;
    for (unsigned int depth = 0; ancestor && depth < 6; ancestor = ancestor.superview, ++depth) {
        if (cls && [ancestor isKindOfClass:cls] &&
            douyindisc_nativeObject(ancestor, "AWEPlayInteractionListenFeedView", "_musicButton", "@\"AWEMusicCoverButton\"") == control) return ancestor;
    }
    return nil;
}

static NSArray<UIView *> *douyindisc_nativeVisuals(UIControl *control) {
    if (!douyindisc_nativeMusic(control)) return @[];
    NSMutableArray<UIView *> *views = [NSMutableArray array];
    const char *owners[] = {"AWEButton", "AWEMusicCoverButton", "AWEMusicCoverButton", "AWEMusicCoverButton", "AWEMusicCoverButton", "AWEMusicCoverButton"};
    const char *fields[] = {"_imageContentView", "_imageBgView", "_ownerImageView", "_guidanceLabel", "_guidanceView", "_topCoverNoteImgV"};
    const char *types[] = {"@\"UIImageView\"", "@\"UIView\"", "@\"UIImageView\"", "@\"UILabel\"", "@\"UIView\"", "@\"UIImageView\""};
    for (unsigned int i = 0; i < sizeof(fields)/sizeof(fields[0]); ++i) {
        UIView *view = douyindisc_nativeSubview(control, owners[i], fields[i], types[i]);
        if (view && ![views containsObject:view]) [views addObject:view];
    }
    UIView *listenHost = douyindisc_nativeListenHost(control);
    if (listenHost) {
        const char *names[] = {"_listenIconView", "_listenTitleLabel", "_backgroundView"};
        const char *kinds[] = {"@\"UIImageView\"", "@\"UILabel\"", "@\"AWEGradientView\""};
        for (unsigned int i = 0; i < 3; ++i) {
            id value = douyindisc_nativeObject(listenHost, "AWEPlayInteractionListenFeedView", names[i], kinds[i]);
            if ([value isKindOfClass:UIView.class] && value != control &&
                [(UIView *)value isDescendantOfView:listenHost] &&
                ![value isKindOfClass:UIControl.class] && ![(UIView *)value isUserInteractionEnabled] &&
                ![views containsObject:value]) [views addObject:value];
        }
    }
    return views;
}
#endif
