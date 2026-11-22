#ifndef DOUYINDISC_NAVIGATION_STORE_CASES_H
#define DOUYINDISC_NAVIGATION_STORE_CASES_H
#import <UIKit/UIKit.h>
#import <math.h>
#import "../../Sources/DouyinDiscNavigation.h"

#if !defined(DOUYINDISC_UI_TEST)
#error DOUYINDISC_UI_TEST must be enabled when compiling the navigation store UIKit cases.
#endif

extern DouyinDiscNavigationStore *douyindisc_uiTestCreateStore(NSURL *directory);
extern void douyindisc_uiTestFailNextCommit(DouyinDiscNavigationStore *store);
extern BOOL douyindisc_uiTestCanDecodeImageData(NSData *data);

static NSData *douyindisc_navCaseJPEG(UIColor *color) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(24,24),YES,1);
    CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(),color.CGColor);
    CGContextFillRect(UIGraphicsGetCurrentContext(),CGRectMake(0,0,24,24));
    UIImage *image=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();
    return UIImageJPEGRepresentation(image,.9);
}
static NSData *douyindisc_navCaseImage(UIColor *color) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(16, 16), NO, 1);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, CGRectMake(4, 4, 8, 8));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return UIImagePNGRepresentation(image);
}

static BOOL douyindisc_navCaseHasTransparentPixel(UIImage *image) {
    if (!image.CGImage) return NO;
    size_t width = CGImageGetWidth(image.CGImage), height = CGImageGetHeight(image.CGImage);
    NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels.mutableBytes, width, height, 8, width * 4, space,
                                                  kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!context) return NO;
    CGContextClearRect(context, CGRectMake(0, 0, width, height));
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image.CGImage);
    CGContextRelease(context);
    const uint8_t *bytes = pixels.bytes;
    return bytes[3] == 0 && bytes[((height / 2) * width + width / 2) * 4 + 3] > 0;
}

static NSUInteger douyindisc_navCaseUUIDFiles(NSURL *directory) {
    NSArray<NSURL *> *files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:directory
                                                            includingPropertiesForKeys:nil options:0 error:nil];
    NSUInteger count = 0;
    for (NSURL *file in files) {
        NSString *name = file.lastPathComponent;
        if (name.length != 40 || ![name hasSuffix:@".png"]) continue;
        NSString *uuid = [name substringToIndex:36];
        NSUUID *parsed = [[NSUUID alloc] initWithUUIDString:uuid];
        if (parsed && [parsed.UUIDString caseInsensitiveCompare:uuid] == NSOrderedSame) ++count;
    }
    return count;
}

static void douyindisc_navigationStoreCases(void (^done)(void)) {
    NSAssert(NSThread.isMainThread, @"Store cases must start on main thread");
    NSURL *base = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
        [@"DouyinDiscNavigationStoreCases-" stringByAppendingString:NSUUID.UUID.UUIDString]] isDirectory:YES];
    NSURL *directory = [base URLByAppendingPathComponent:@"main" isDirectory:YES];
    NSURL *badDirectory = [base URLByAppendingPathComponent:@"corrupt" isDirectory:YES];
    NSError *ioError = nil;
    [NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&ioError];
    DouyinDiscNavigationStore *store = douyindisc_uiTestCreateStore(directory);
    NSURL *configURL = [directory URLByAppendingPathComponent:@"settings.plist"];
    DD_CHECK(![NSFileManager.defaultManager fileExistsAtPath:configURL.path], @"fresh initialization reads without writing default configuration");
    NSArray *items = douyindisc_navigationItems();
    for (NSDictionary *item in items) {
        NSDictionary *entry = [store douyindisc_entryForIdentifier:item[@"identifier"]];
        DD_CHECK(![entry[@"enabled"] boolValue] && [entry[@"opacity"] doubleValue] == 1 && ![entry[@"hasImage"] boolValue], @"all thirteen navigation entries have independent defaults");
    }
    NSError *invalidError = nil;
    DD_CHECK(![store douyindisc_saveEnabled:YES opacity:.4 identifier:@"not_a_navigation_item" error:&invalidError] && invalidError != nil,
             @"invalid identifier is rejected synchronously");
    NSData *jpeg=douyindisc_navCaseJPEG(UIColor.systemOrangeColor);
    DD_CHECK(jpeg.length>0 && douyindisc_uiTestCanDecodeImageData(jpeg), @"system ImageIO decoder accepts an ordinary JPEG photo");
    DD_CHECK(!douyindisc_uiTestCanDecodeImageData([@"not an image" dataUsingEncoding:NSUTF8StringEncoding]), @"decoder rejects non-image bytes with a fixed failure");
    [store douyindisc_saveImageData:[@"not an image" dataUsingEncoding:NSUTF8StringEncoding] identifier:@"top_recommend" completion:^(NSError *error) {
        DD_CHECK(NSThread.isMainThread, @"invalid image completion is delivered on main thread");
        DD_CHECK(error != nil, @"invalid image data is rejected");
        DD_CHECK(![NSFileManager.defaultManager fileExistsAtPath:configURL.path], @"invalid image input leaves storage untouched");

        NSData *firstImage = douyindisc_navCaseImage(UIColor.redColor);
        NSData *lastImage = douyindisc_navCaseImage(UIColor.systemGreenColor);
        __block NSUInteger raceCallbacks = 0;
        __block void (^continueAfterRace)(void);
        continueAfterRace = ^{
            if (++raceCallbacks != 2) return;
            DouyinDiscNavigationStore *cold = douyindisc_uiTestCreateStore(directory);
            DD_CHECK([cold douyindisc_imageForIdentifier:@"top_recommend"] == nil, @"cold store begins with an empty image cache");
            [cold douyindisc_preloadImagesWithCompletion:^{
                UIImage *loaded = [cold douyindisc_imageForIdentifier:@"top_recommend"];
                DD_CHECK(loaded.CGImage != NULL, @"preload decodes the persisted PNG from the real store directory");
                DD_CHECK(douyindisc_navCaseHasTransparentPixel(loaded), @"PNG persistence retains actual transparent and opaque pixels");
                NSDictionary *bottom = [cold douyindisc_entryForIdentifier:@"bottom_home"];
                DD_CHECK([bottom[@"enabled"] boolValue] && fabs([bottom[@"opacity"] doubleValue] - .65) < .001,
                         @"cold configuration read preserves a concurrent independent-item update");

                __block BOOL clearObserverSawEmptyCache = NO;
                id clearObserver = [NSNotificationCenter.defaultCenter addObserverForName:@"com.minis.douyindisc.navigation.changed"
                    object:store queue:nil usingBlock:^(NSNotification *note) {
                        (void)note;
                        clearObserverSawEmptyCache = [store douyindisc_imageForIdentifier:@"top_recommend"] == nil &&
                            ![[store douyindisc_entryForIdentifier:@"top_recommend"][@"hasImage"] boolValue];
                    }];
                __block NSError *clearError = nil;
                [store douyindisc_saveImageData:firstImage identifier:@"top_recommend" completion:^(NSError *staleError) {
                    DD_CHECK(staleError != nil, @"an import invalidated by clear reports cancellation");
                    DD_CHECK([store douyindisc_imageForIdentifier:@"top_recommend"] == nil &&
                             ![[store douyindisc_entryForIdentifier:@"top_recommend"][@"hasImage"] boolValue],
                             @"stale import callback cannot restore a cleared image");
                    [store douyindisc_saveImageData:lastImage identifier:@"top_recommend" completion:^(NSError *restoreError) {
                        UIImage *preservedImage = [store douyindisc_imageForIdentifier:@"top_recommend"];
                        NSDictionary *preservedConfig = [NSDictionary dictionaryWithContentsOfURL:configURL];
                        NSString *preservedName = preservedConfig[@"top_recommend"][@"image"];
                        douyindisc_uiTestFailNextCommit(store);
                        NSError *failedClearError = nil;
                        BOOL failedClear = [store douyindisc_clearImageForIdentifier:@"top_recommend" error:&failedClearError];
                        DD_CHECK(restoreError == nil, @"fixture image restores successfully before rollback check");
                        DD_CHECK(!failedClear && failedClearError != nil, @"failed clear commit returns an error");
                        DD_CHECK([store douyindisc_imageForIdentifier:@"top_recommend"] == preservedImage &&
                                 [[store douyindisc_entryForIdentifier:@"top_recommend"][@"hasImage"] boolValue],
                                 @"failed clear preserves the previous config and cached image");
                        NSDictionary *afterFailure = [NSDictionary dictionaryWithContentsOfURL:configURL];
                        DD_CHECK([afterFailure[@"top_recommend"][@"image"] isEqualToString:preservedName],
                                 @"failed clear leaves the previous on-disk image reference intact");

                        [NSFileManager.defaultManager createDirectoryAtURL:badDirectory withIntermediateDirectories:YES attributes:nil error:nil];
                        NSURL *badURL = [badDirectory URLByAppendingPathComponent:@"settings.plist"];
                        NSData *badBytes = [@"not a plist" dataUsingEncoding:NSUTF8StringEncoding];
                        [badBytes writeToURL:badURL atomically:YES];
                        DouyinDiscNavigationStore *corrupt = douyindisc_uiTestCreateStore(badDirectory);
                        NSError *corruptError = nil;
                        BOOL corruptSave = [corrupt douyindisc_saveEnabled:YES opacity:.5 identifier:@"top_follow" error:&corruptError];
                        DD_CHECK(!corruptSave && corruptError != nil, @"corrupt existing config blocks writes");
                        DD_CHECK([[NSData dataWithContentsOfURL:badURL] isEqualToData:badBytes], @"corrupt config bytes are never overwritten");
                        [NSFileManager.defaultManager removeItemAtURL:base error:nil];
                        if (done) done();
                    }];
                }];
                BOOL cleared = [store douyindisc_clearImageForIdentifier:@"top_recommend" error:&clearError];
                DD_CHECK(cleared && clearError == nil, @"clear commits successfully while an older import is pending");
                DD_CHECK([store douyindisc_imageForIdentifier:@"top_recommend"] == nil &&
                         ![[store douyindisc_entryForIdentifier:@"top_recommend"][@"hasImage"] boolValue],
                         @"clear updates image cache and configuration before returning");
                DD_CHECK(clearObserverSawEmptyCache, @"clear notification observes the already-cleared cache");
                [NSNotificationCenter.defaultCenter removeObserver:clearObserver];
            }];
        };
        [store douyindisc_saveImageData:firstImage identifier:@"top_recommend" completion:^(NSError *error) {
            DD_CHECK(NSThread.isMainThread, @"superseded import completion runs on main thread");
            DD_CHECK(error != nil, @"earlier competing import is rejected by per-item generation");
            continueAfterRace();
        }];
        [store douyindisc_saveImageData:lastImage identifier:@"top_recommend" completion:^(NSError *error) {
            UIImage *image = [store douyindisc_imageForIdentifier:@"top_recommend"];
            NSDictionary *saved = [NSDictionary dictionaryWithContentsOfURL:configURL];
            NSDictionary *entry = saved[@"top_recommend"];
            NSDictionary *bottom = [store douyindisc_entryForIdentifier:@"bottom_home"];
            NSString *name = entry[@"image"];
            NSString *uuid = [name isKindOfClass:NSString.class] && name.length == 40 ? [name substringToIndex:36] : @"";
            DD_CHECK(NSThread.isMainThread, @"winning image import completion runs on main thread");
            DD_CHECK(error == nil, @"latest competing image import commits successfully");
            DD_CHECK(image.CGImage != NULL && CGImageGetWidth(image.CGImage) <= 512 && CGImageGetHeight(image.CGImage) <= 512,
                     @"image is decoded and downsampled to a maximum 512-pixel edge");
            DD_CHECK([entry[@"image"] isKindOfClass:NSString.class], @"image reference is committed to persisted configuration");
            DD_CHECK(name.length == 40 && [name hasSuffix:@".png"] &&
                     [[[NSUUID alloc] initWithUUIDString:uuid].UUIDString caseInsensitiveCompare:uuid] == NSOrderedSame,
                     @"stored image uses a UUID-only PNG basename");
            DD_CHECK([bottom[@"enabled"] boolValue] && fabs([bottom[@"opacity"] doubleValue] - .65) < .001,
                     @"image commit merges the latest config without losing another-item toggle");
            DD_CHECK(douyindisc_navCaseUUIDFiles(directory) == 1, @"competing imports retain only the winning unique image file");
            continueAfterRace();
        }];
        NSError *toggleError = nil;
        BOOL toggled = [store douyindisc_saveEnabled:YES opacity:.65 identifier:@"bottom_home" error:&toggleError];
        DD_CHECK(toggled && toggleError == nil, @"unrelated setting commits while image work runs in background");
    }];
}

#endif
