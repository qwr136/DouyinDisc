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
        BOOL uuidImage=name.length==40&&[name hasSuffix:@".png"];
        BOOL uuidGIF=name.length==40&&[name hasSuffix:@".gif"];
        if(!uuidImage&&!uuidGIF)continue;
        NSString *uuid=[name substringToIndex:36];
        NSUUID *parsed = [[NSUUID alloc] initWithUUIDString:uuid];
        if (parsed && [parsed.UUIDString caseInsensitiveCompare:uuid] == NSOrderedSame) ++count;
    }
    return count;
}

static void douyindisc_navCaseVerifyDisabledImportRollback(DouyinDiscNavigationStore *store, NSURL *directory, dispatch_block_t done) {
    UIImage *oldImage=[store douyindisc_imageForIdentifier:@"top_recommend"];
    NSDictionary *disk=[NSDictionary dictionaryWithContentsOfURL:[directory URLByAppendingPathComponent:@"settings.plist"]];
    NSString *oldName=disk[@"top_recommend"][@"image"];
    NSUInteger oldFileCount=douyindisc_navCaseUUIDFiles(directory);
    NSUInteger ticket=[store douyindisc_beginImagePickingForIdentifier:@"top_recommend"];
    DD_CHECK_NS(ticket>0 && oldImage.CGImage!=NULL && oldName.length>0,@"enabled item grants photo import authorization while existing image is present");
    [store douyindisc_saveImageData:douyindisc_navCaseImage(UIColor.purpleColor) identifier:@"top_recommend" pickingGeneration:ticket completion:^(NSError *error){
        NSDictionary *after=[NSDictionary dictionaryWithContentsOfURL:[directory URLByAppendingPathComponent:@"settings.plist"]];
        DD_CHECK_NS(error!=nil,@"photo result completing after switch-off is rejected");
        DD_CHECK_NS([store douyindisc_imageForIdentifier:@"top_recommend"]==oldImage && [after[@"top_recommend"][@"image"] isEqualToString:oldName],@"late denied image leaves previous preview and stored reference intact");
        DD_CHECK_NS(douyindisc_navCaseUUIDFiles(directory)==oldFileCount,@"late denied image temp PNG is removed");
        NSDictionary *entry=[store douyindisc_entryForIdentifier:@"top_recommend"];NSError *enableError=nil;
        BOOL reenabled=[store douyindisc_saveEnabled:YES opacity:[entry[@"opacity"] doubleValue] scale:[entry[@"scale"] doubleValue] identifier:@"top_recommend" error:&enableError];
        DD_CHECK_NS(reenabled && enableError==nil,@"test re-enables image selection without touching the retained image");
        if(done)done();
    }];
    NSDictionary *current=[store douyindisc_entryForIdentifier:@"top_recommend"];NSError *disableError=nil;
    BOOL disabled=[store douyindisc_saveEnabled:NO opacity:[current[@"opacity"] doubleValue] scale:[current[@"scale"] doubleValue] identifier:@"top_recommend" error:&disableError];
    DD_CHECK_NS(disabled && disableError==nil && ![store douyindisc_imagePickingEnabledForIdentifier:@"top_recommend"] && [store douyindisc_beginImagePickingForIdentifier:@"top_recommend"]==0,@"committed switch-off immediately revokes new picker authorization");
}

static void douyindisc_navigationStoreCases(void (^done)(void)) {
    NSURL *base = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
        [@"DouyinDiscNavigationStoreCases-" stringByAppendingString:NSUUID.UUID.UUIDString]] isDirectory:YES];
    NSURL *directory = [base URLByAppendingPathComponent:@"main" isDirectory:YES];
    NSURL *badDirectory = [base URLByAppendingPathComponent:@"corrupt" isDirectory:YES];
    NSError *ioError = nil;
    [NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&ioError];
    DouyinDiscNavigationStore *store = douyindisc_uiTestCreateStore(directory);
    NSURL *configURL = [directory URLByAppendingPathComponent:@"settings.plist"];
    DD_CHECK_NS(![NSFileManager.defaultManager fileExistsAtPath:configURL.path], @"fresh initialization reads without writing default configuration");
    DD_CHECK_NS(![store douyindisc_imagePickingEnabledForIdentifier:@"bottom_home"] && [store douyindisc_beginImagePickingForIdentifier:@"bottom_home"]==0,@"disabled item cannot obtain a photo or file import authorization");
    NSArray *items = douyindisc_navigationItems();
    for (NSDictionary *item in items) {
        NSDictionary *entry = [store douyindisc_entryForIdentifier:item[@"identifier"]];
        BOOL videoDisc=[item[@"identifier"] isEqual:@"video_disc"];
        DD_CHECK_NS([entry[@"enabled"] boolValue]==videoDisc && [entry[@"opacity"] doubleValue]==1 && [entry[@"scale"] doubleValue]==1 && [entry[@"speed"] doubleValue]==1 && ![entry[@"hasImage"] boolValue]&&[entry[@"angle"] doubleValue]==0&&[entry[@"cornerRadius"] doubleValue]==0&&![entry[@"rotationEnabled"] boolValue]&&[entry[@"rotationSpeed"] doubleValue]==1, @"entries preserve legacy off/default values, zero angle/corners, and disabled rotation");
    }
    NSUInteger discTicket=[store douyindisc_beginImagePickingForIdentifier:@"video_disc"];
    DD_CHECK_NS(discTicket>0&&[store douyindisc_imagePickingEnabledForIdentifier:@"video_disc"],@"legacy built-in disc remains enabled and can start a custom-image picker without configuration migration");
    [store douyindisc_finishImagePickingForIdentifier:@"video_disc" generation:discTicket];
    NSURL *speedDirectory=[base URLByAppendingPathComponent:@"speed" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:speedDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    DouyinDiscNavigationStore *speedStore=douyindisc_uiTestCreateStore(speedDirectory);NSError *speedError=nil;
    DD_CHECK_NS([speedStore douyindisc_saveEnabled:YES opacity:.72 scale:3 identifier:@"video_disc" error:&speedError] && [speedStore douyindisc_entryForIdentifier:@"video_disc"][@"speed"] && fabs([[speedStore douyindisc_entryForIdentifier:@"video_disc"][@"speed"] doubleValue]-3)<.001, @"video disc accepts the maximum 300 percent speed and persists it as speed");
    NSError *invalidSpeedError=nil;
    DD_CHECK_NS(![speedStore douyindisc_saveEnabled:YES opacity:.72 scale:3.01 identifier:@"video_disc" error:&invalidSpeedError] && invalidSpeedError!=nil, @"video disc rejects speeds above the explicit three-times ceiling");
    NSURL *appearanceDirectory=[base URLByAppendingPathComponent:@"appearance" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:appearanceDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    DouyinDiscNavigationStore *appearanceStore=douyindisc_uiTestCreateStore(appearanceDirectory);NSError *appearanceSaveError=nil;
    BOOL appearanceSaved=[appearanceStore douyindisc_saveNavigationAppearanceForIdentifier:@"bottom_home" angle:123 cornerRadius:25 rotationEnabled:YES rotationSpeed:1.75 error:&appearanceSaveError];
    NSDictionary *appearanceEntry=[appearanceStore douyindisc_entryForIdentifier:@"bottom_home"];
    DD_CHECK_NS(appearanceSaved&&appearanceSaveError==nil&&fabs([appearanceEntry[@"angle"] doubleValue]-123)<.001&&fabs([appearanceEntry[@"cornerRadius"] doubleValue]-25)<.001&&[appearanceEntry[@"rotationEnabled"] boolValue]&&fabs([appearanceEntry[@"rotationSpeed"] doubleValue]-1.75)<.001,@"static angle, corner radius, rotation switch and speed persist independently for a navigation icon");
    NSError *invalidAppearanceError=nil;
    DD_CHECK_NS(![appearanceStore douyindisc_saveNavigationAppearanceForIdentifier:@"video_disc" angle:45 cornerRadius:10 rotationEnabled:YES rotationSpeed:1 error:&invalidAppearanceError]&&invalidAppearanceError!=nil,@"video-disc settings cannot consume navigation-only appearance controls");
    NSError *invalidError = nil;
    DD_CHECK_NS(![store douyindisc_saveEnabled:YES opacity:.4 scale:1 identifier:@"not_a_navigation_item" error:&invalidError] && invalidError != nil,
             @"invalid identifier is rejected synchronously");
    NSData *jpeg=douyindisc_navCaseJPEG(UIColor.systemOrangeColor);
    DD_CHECK_NS(jpeg.length>0 && douyindisc_uiTestCanDecodeImageData(jpeg), @"system ImageIO decoder accepts an ordinary JPEG photo");
    DD_CHECK_NS(!douyindisc_uiTestCanDecodeImageData([@"not an image" dataUsingEncoding:NSUTF8StringEncoding]), @"decoder rejects non-image bytes with a fixed failure");
    [store douyindisc_saveImageData:douyindisc_navCaseImage(UIColor.redColor) identifier:@"top_recommend" completion:^(NSError *error) {
        DD_CHECK_NS(NSThread.isMainThread, @"disabled image-import rejection is delivered on main thread");
        DD_CHECK_NS(error.code==6, @"a valid image cannot be imported while the item switch is off");
        DD_CHECK_NS(![NSFileManager.defaultManager fileExistsAtPath:configURL.path] && douyindisc_navCaseUUIDFiles(directory)==0, @"disabled image import creates no config or orphan file");

        NSError *enableError=nil;
        DD_CHECK_NS([store douyindisc_saveEnabled:YES opacity:1 scale:1 identifier:@"top_recommend" error:&enableError] && enableError==nil,@"image fixture enables the target item before import");
        NSData *firstImage = douyindisc_navCaseImage(UIColor.redColor);
        NSData *lastImage = douyindisc_navCaseImage(UIColor.systemGreenColor);
        __block NSUInteger raceCallbacks = 0;
        __block void (^continueAfterRace)(void);
        continueAfterRace = ^{
            if (++raceCallbacks != 2) return;
            DD_CHECK_NS(douyindisc_navCaseUUIDFiles(directory) == 1, @"competing imports retain only the winning unique image file after both callbacks");
            douyindisc_navCaseVerifyDisabledImportRollback(store,directory,^{
            DouyinDiscNavigationStore *cold = douyindisc_uiTestCreateStore(directory);
            DD_CHECK_NS([cold douyindisc_imageForIdentifier:@"top_recommend"] == nil, @"cold store begins with an empty image cache");
            [cold douyindisc_preloadImagesWithCompletion:^{
                UIImage *loaded = [cold douyindisc_imageForIdentifier:@"top_recommend"];
                DD_CHECK_NS(loaded.CGImage != NULL, @"preload decodes the persisted PNG from the real store directory");
                DD_CHECK_NS(douyindisc_navCaseHasTransparentPixel(loaded), @"PNG persistence retains actual transparent and opaque pixels");
                NSDictionary *bottom = [cold douyindisc_entryForIdentifier:@"bottom_home"];
                DD_CHECK_NS([bottom[@"enabled"] boolValue] && fabs([bottom[@"opacity"] doubleValue] - .65) < .001 && fabs([bottom[@"scale"] doubleValue]-1.25)<.001,
                         @"cold configuration read preserves size, opacity and another-item toggle");

                __block BOOL clearObserverSawEmptyCache = NO;
                id clearObserver = [NSNotificationCenter.defaultCenter addObserverForName:@"com.minis.douyindisc.navigation.changed"
                    object:store queue:nil usingBlock:^(NSNotification *note) {
                        (void)note;
                        clearObserverSawEmptyCache = [store douyindisc_imageForIdentifier:@"top_recommend"] == nil &&
                            ![[store douyindisc_entryForIdentifier:@"top_recommend"][@"hasImage"] boolValue];
                    }];
                __block NSError *clearError = nil;
                [store douyindisc_saveImageData:firstImage identifier:@"top_recommend" completion:^(NSError *staleError) {
                    DD_CHECK_NS(staleError != nil, @"an import invalidated by clear reports cancellation");
                    DD_CHECK_NS([store douyindisc_imageForIdentifier:@"top_recommend"] == nil &&
                             ![[store douyindisc_entryForIdentifier:@"top_recommend"][@"hasImage"] boolValue],
                             @"stale import callback cannot restore a cleared image");
                    [store douyindisc_saveImageData:lastImage identifier:@"top_recommend" completion:^(NSError *restoreError) {
                        UIImage *preservedImage = [store douyindisc_imageForIdentifier:@"top_recommend"];
                        NSDictionary *preservedConfig = [NSDictionary dictionaryWithContentsOfURL:configURL];
                        NSString *preservedName = preservedConfig[@"top_recommend"][@"image"];
                        douyindisc_uiTestFailNextCommit(store);
                        NSError *failedClearError = nil;
                        BOOL failedClear = [store douyindisc_clearImageForIdentifier:@"top_recommend" error:&failedClearError];
                        DD_CHECK_NS(restoreError == nil, @"fixture image restores successfully before rollback check");
                        DD_CHECK_NS(!failedClear && failedClearError != nil, @"failed clear commit returns an error");
                        DD_CHECK_NS([store douyindisc_imageForIdentifier:@"top_recommend"] == preservedImage &&
                                 [[store douyindisc_entryForIdentifier:@"top_recommend"][@"hasImage"] boolValue],
                                 @"failed clear preserves the previous config and cached image");
                        NSDictionary *afterFailure = [NSDictionary dictionaryWithContentsOfURL:configURL];
                        DD_CHECK_NS([afterFailure[@"top_recommend"][@"image"] isEqualToString:preservedName],
                                 @"failed clear leaves the previous on-disk image reference intact");

                        [NSFileManager.defaultManager createDirectoryAtURL:badDirectory withIntermediateDirectories:YES attributes:nil error:nil];
                        NSURL *badURL = [badDirectory URLByAppendingPathComponent:@"settings.plist"];
                        NSData *badBytes = [@"not a plist" dataUsingEncoding:NSUTF8StringEncoding];
                        [badBytes writeToURL:badURL atomically:YES];
                        DouyinDiscNavigationStore *corrupt = douyindisc_uiTestCreateStore(badDirectory);
                        NSError *corruptError = nil;
                        BOOL corruptSave = [corrupt douyindisc_saveEnabled:YES opacity:.5 scale:1 identifier:@"top_follow" error:&corruptError];
                        DD_CHECK_NS(!corruptSave && corruptError != nil, @"corrupt existing config blocks writes");
                        DD_CHECK_NS([[NSData dataWithContentsOfURL:badURL] isEqualToData:badBytes], @"corrupt config bytes are never overwritten");
                        [NSFileManager.defaultManager removeItemAtURL:base error:nil];
                        if (done) done();
                    }];
                }];
                BOOL cleared = [store douyindisc_clearImageForIdentifier:@"top_recommend" error:&clearError];
                DD_CHECK_NS(cleared && clearError == nil, @"clear commits successfully while an older import is pending");
                DD_CHECK_NS([store douyindisc_imageForIdentifier:@"top_recommend"] == nil &&
                         ![[store douyindisc_entryForIdentifier:@"top_recommend"][@"hasImage"] boolValue],
                         @"clear updates image cache and configuration before returning");
                DD_CHECK_NS(clearObserverSawEmptyCache, @"clear notification observes the already-cleared cache");
                [NSNotificationCenter.defaultCenter removeObserver:clearObserver];
            }];
            });
        };
        [store douyindisc_saveImageData:firstImage identifier:@"top_recommend" completion:^(NSError *error) {
            DD_CHECK_NS(NSThread.isMainThread, @"superseded import completion runs on main thread");
            DD_CHECK_NS(error != nil, @"earlier competing import is rejected by per-item generation");
            continueAfterRace();
        }];
        [store douyindisc_saveImageData:lastImage identifier:@"top_recommend" completion:^(NSError *error) {
            UIImage *image = [store douyindisc_imageForIdentifier:@"top_recommend"];
            NSDictionary *saved = [NSDictionary dictionaryWithContentsOfURL:configURL];
            NSDictionary *entry = saved[@"top_recommend"];
            NSDictionary *bottom = [store douyindisc_entryForIdentifier:@"bottom_home"];
            NSString *name = entry[@"image"];
            NSString *uuid = [name isKindOfClass:NSString.class] && name.length == 40 ? [name substringToIndex:36] : @"";
            DD_CHECK_NS(NSThread.isMainThread, @"winning image import completion runs on main thread");
            DD_CHECK_NS(error == nil, @"latest competing image import commits successfully");
            DD_CHECK_NS(image.CGImage != NULL && CGImageGetWidth(image.CGImage) <= 512 && CGImageGetHeight(image.CGImage) <= 512,
                     @"image is decoded and downsampled to a maximum 512-pixel edge");
            DD_CHECK_NS([entry[@"image"] isKindOfClass:NSString.class], @"image reference is committed to persisted configuration");
            DD_CHECK_NS(name.length == 40 && [name hasSuffix:@".png"] &&
                     [[[NSUUID alloc] initWithUUIDString:uuid].UUIDString caseInsensitiveCompare:uuid] == NSOrderedSame,
                     @"stored image uses a UUID-only PNG basename");
            DD_CHECK_NS([bottom[@"enabled"] boolValue] && fabs([bottom[@"opacity"] doubleValue] - .65) < .001,
                     @"image commit merges the latest config without losing another-item toggle");
            continueAfterRace();
        }];
        NSError *toggleError = nil;
        BOOL toggled = [store douyindisc_saveEnabled:YES opacity:.65 scale:1.25 identifier:@"bottom_home" error:&toggleError];
        DD_CHECK_NS(toggled && toggleError == nil, @"unrelated setting commits while image work runs in background");
        DD_CHECK_NS(fabs([[store douyindisc_entryForIdentifier:@"bottom_home"][@"scale"] doubleValue]-1.25)<.001, @"icon size persists independently for each navigation item");
    }];
}

#endif
