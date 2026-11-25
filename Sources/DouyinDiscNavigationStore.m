#import "DouyinDiscNavigation.h"
#import <math.h>
#import <ImageIO/ImageIO.h>

static NSString * const douyindisc_utiPNG = @"public.png";

static NSArray<NSDictionary<NSString *, id> *> *douyindisc_itemTable(void) {
    static NSArray *items;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *raw = @[
            @[@"top_recommend", @"推荐", @"sparkles", @"#E94F65"], @[@"top_follow", @"关注", @"heart", @"#E94F65"],
            @[@"top_nearby", @"同城", @"location", @"#E94F65"], @[@"top_featured", @"精选", @"star", @"#E94F65"],
            @[@"top_mall", @"商城", @"bag", @"#E94F65"], @[@"top_groupbuy", @"团购", @"tag", @"#E94F65"],
            @[@"top_live", @"直播", @"dot.radiowaves.left.and.right", @"#E94F65"], @[@"top_hot", @"热点", @"flame", @"#E94F65"],
            @[@"top_experience", @"经验", @"lightbulb", @"#E94F65"], @[@"bottom_home", @"首页", @"house", @"#3778D4"],
            @[@"bottom_friends", @"朋友", @"person.2", @"#3778D4"], @[@"bottom_messages", @"消息", @"bubble.left.and.bubble.right", @"#3778D4"],
            @[@"bottom_me", @"我", @"person.crop.circle", @"#3778D4"]
        ];
        NSMutableArray *built = [NSMutableArray arrayWithCapacity:raw.count];
        for (NSArray *row in raw) [built addObject:@{@"identifier":row[0], @"title":row[1], @"sfIcon":row[2], @"accentColor":row[3]}];
        items = built.copy;
    });
    return items;
}

NSArray<NSDictionary<NSString *, id> *> *douyindisc_navigationItems(void) { return douyindisc_itemTable(); }

static BOOL douyindisc_validIdentifier(NSString *identifier) {
    for (NSDictionary *item in douyindisc_itemTable()) if ([item[@"identifier"] isEqual:identifier]) return YES;
    return NO;
}

static NSError *douyindisc_error(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"com.minis.douyindisc.navigation" code:code userInfo:@{NSLocalizedDescriptionKey:message}];
}

static NSURL *douyindisc_defaultStoreDirectory(void) {
    NSURL *documents = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    return [documents URLByAppendingPathComponent:@"DouyinDisc/Navigation" isDirectory:YES];
}

static BOOL douyindisc_validImageName(NSString *name) {
    if (![name isKindOfClass:NSString.class] || name.length != 40 || ![name hasSuffix:@".png"]) return NO;
    NSString *uuid = [name substringToIndex:36];
    NSUUID *parsed = [[NSUUID alloc] initWithUUIDString:uuid];
    return parsed != nil && [parsed.UUIDString caseInsensitiveCompare:uuid] == NSOrderedSame &&
        [uuid characterAtIndex:8] == '-' && [uuid characterAtIndex:13] == '-' &&
        [uuid characterAtIndex:18] == '-' && [uuid characterAtIndex:23] == '-';
}

static BOOL douyindisc_validConfig(id value) {
    if (![value isKindOfClass:NSDictionary.class]) return NO;
    NSSet *allowed = [NSSet setWithArray:@[@"enabled", @"opacity", @"scale", @"image"]];
    for (id key in (NSDictionary *)value) {
        id entry = value[key];
        if (![key isKindOfClass:NSString.class] || !douyindisc_validIdentifier(key) || ![entry isKindOfClass:NSDictionary.class]) return NO;
        for (id field in (NSDictionary *)entry) if (![field isKindOfClass:NSString.class] || ![allowed containsObject:field]) return NO;
        if (entry[@"enabled"] && ![entry[@"enabled"] isKindOfClass:NSNumber.class]) return NO;
        if (entry[@"opacity"] && ![entry[@"opacity"] isKindOfClass:NSNumber.class]) return NO;
        if (entry[@"scale"] && ![entry[@"scale"] isKindOfClass:NSNumber.class]) return NO;
        if (entry[@"image"] && !douyindisc_validImageName(entry[@"image"])) return NO;
        double opacity = [entry[@"opacity"] respondsToSelector:@selector(doubleValue)] ? [entry[@"opacity"] doubleValue] : 1;
        double scale = [entry[@"scale"] respondsToSelector:@selector(doubleValue)] ? [entry[@"scale"] doubleValue] : 1;
        if (!isfinite(opacity) || opacity < 0 || opacity > 1 || !isfinite(scale) || scale < .5 || scale > 1.5) return NO;
    }
    return YES;
}

static UIImage *douyindisc_decodeImage(NSData *data, BOOL requirePNG, NSError **error) {
    if (!data.length || data.length > 64 * 1024 * 1024) {
        if (error) *error = douyindisc_error(2, @"图片必须大于 0 字节且不超过 64 MiB。");
        return nil;
    }
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source || CGImageSourceGetCount(source) == 0) {
        if (source) CFRelease(source);
        if (error) *error = douyindisc_error(2, @"系统无法解码该图片文件。");
        return nil;
    }
    CFStringRef type = CGImageSourceGetType(source);
    NSString *typeName = type ? (__bridge NSString *)type : @"";
    if (requirePNG && ![typeName isEqualToString:douyindisc_utiPNG]) {
        CFRelease(source);
        if (error) *error = douyindisc_error(2, @"缓存图片格式无效。");
        return nil;
    }
    NSDictionary *options = @{
        (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways:@YES,
        (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize:@512,
        (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform:@YES,
        (__bridge NSString *)kCGImageSourceShouldCacheImmediately:@YES
    };
    CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    CFRelease(source);
    UIImage *image = thumbnail ? [UIImage imageWithCGImage:thumbnail scale:1 orientation:UIImageOrientationUp] : nil;
    if (thumbnail) CGImageRelease(thumbnail);
    if (!image.CGImage && error) *error = douyindisc_error(2, @"图片解码失败。");
    return image;
}

static NSData *douyindisc_PNGData(CGImageRef image, NSError **error) {
    if (!image) return nil;
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, (__bridge CFStringRef)douyindisc_utiPNG, 1, NULL);
    if (destination) {
        CGImageDestinationAddImage(destination, image, NULL);
        BOOL done = CGImageDestinationFinalize(destination);
        CFRelease(destination);
        if (done && data.length && data.length <= 6 * 1024 * 1024) return data;
    }
    if (error) *error = douyindisc_error(2, @"图片无法转换为合规 PNG。");
    return nil;
}

@interface DouyinDiscNavigationStore ()
@property (nonatomic, copy) NSDictionary<NSString *, NSDictionary<NSString *, id> *> *douyindisc_config;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIImage *> *douyindisc_images;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *douyindisc_previewOpacity;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *douyindisc_previewScale;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *douyindisc_imageGeneration;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *douyindisc_pickGeneration;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *douyindisc_activePickGeneration;
@property (nonatomic, strong) NSURL *douyindisc_storeDirectory;
@property (nonatomic) NSUInteger douyindisc_preloadGeneration;
@property (nonatomic) BOOL douyindisc_loadFailed;
@property (nonatomic) BOOL douyindisc_glassPreference;
@property (nonatomic) BOOL douyindisc_glassLoadFailed;
#if defined(DOUYINDISC_UI_TEST)
@property (nonatomic) BOOL douyindisc_testFailNextCommit;
#endif
- (instancetype)initWithDouyinDiscDirectory:(NSURL *)directory;
- (BOOL)douyindisc_commitLatestConfig:(NSDictionary *)config beforeNotify:(dispatch_block_t)beforeNotify error:(NSError **)error;
@end

@implementation DouyinDiscNavigationStore
+ (instancetype)douyindisc_sharedStore {
    static DouyinDiscNavigationStore *store;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ store = [DouyinDiscNavigationStore new]; });
    return store;
}

- (instancetype)init { return [self initWithDouyinDiscDirectory:douyindisc_defaultStoreDirectory()]; }

- (instancetype)initWithDouyinDiscDirectory:(NSURL *)directory {
    self = [super init];
    if (!self) return nil;
    NSAssert(NSThread.isMainThread, @"Navigation store initialization must be on main thread");
    _douyindisc_storeDirectory = directory;
    _douyindisc_images = [NSMutableDictionary dictionary];
    _douyindisc_previewOpacity = [NSMutableDictionary dictionary];
    _douyindisc_previewScale = [NSMutableDictionary dictionary];
    _douyindisc_imageGeneration = [NSMutableDictionary dictionary];
    _douyindisc_pickGeneration = [NSMutableDictionary dictionary];
    _douyindisc_activePickGeneration = [NSMutableDictionary dictionary];
    NSURL *url = [directory URLByAppendingPathComponent:@"settings.plist"];
    if (![NSFileManager.defaultManager fileExistsAtPath:url.path]) {
        _douyindisc_config = @{};
    } else {
        id value = [NSDictionary dictionaryWithContentsOfURL:url];
        if (douyindisc_validConfig(value)) _douyindisc_config = [value copy];
        else { _douyindisc_config = @{}; _douyindisc_loadFailed = YES; }
    }
    NSURL *glassURL=[directory URLByAppendingPathComponent:@"glass.plist"];
    if ([NSFileManager.defaultManager fileExistsAtPath:glassURL.path]) {
        NSDictionary *glass=[NSDictionary dictionaryWithContentsOfURL:glassURL];
        id enabled=glass[@"enabled"];
        if ([glass isKindOfClass:NSDictionary.class] && glass.count==1 && [enabled isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)enabled)==CFBooleanGetTypeID())
            _douyindisc_glassPreference=[enabled boolValue];
        else _douyindisc_glassLoadFailed=YES;
    }
    return self;
}

- (BOOL)douyindisc_glassEnabled {
    NSAssert(NSThread.isMainThread, @"Glass preference read must be on main thread");
    return self.douyindisc_glassPreference && !self.douyindisc_glassLoadFailed;
}

- (BOOL)douyindisc_saveGlassEnabled:(BOOL)enabled error:(NSError **)error {
    NSAssert(NSThread.isMainThread, @"Glass preference commit must be on main thread");
    if(self.douyindisc_glassLoadFailed){if(error)*error=douyindisc_error(1,@"玻璃底栏配置损坏，未覆盖 glass.plist。");return NO;}
#if defined(DOUYINDISC_UI_TEST)
    if(self.douyindisc_testFailNextCommit){self.douyindisc_testFailNextCommit=NO;if(error)*error=douyindisc_error(4,@"UI_TEST injected glass commit failure.");return NO;}
#endif
    NSError *writeError=nil;
    if(![NSFileManager.defaultManager createDirectoryAtURL:self.douyindisc_storeDirectory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&writeError]){if(error)*error=writeError;return NO;}
    NSData *data=[NSPropertyListSerialization dataWithPropertyList:@{@"enabled":@(enabled)} format:NSPropertyListBinaryFormat_v1_0 options:0 error:&writeError];
    NSURL *url=[self.douyindisc_storeDirectory URLByAppendingPathComponent:@"glass.plist"];
    if(!data||![data writeToURL:url options:NSDataWritingAtomic error:&writeError]){if(error)*error=writeError?:douyindisc_error(4,@"玻璃底栏配置保存失败。");return NO;}
    self.douyindisc_glassPreference=enabled;
    [NSNotificationCenter.defaultCenter postNotificationName:@"com.minis.douyindisc.glass.changed" object:self];
    return YES;
}

- (void)douyindisc_previewOpacity:(CGFloat)opacity identifier:(NSString *)identifier {
    NSAssert(NSThread.isMainThread, @"Navigation store access must be on main thread");
    if (!douyindisc_validIdentifier(identifier) || !isfinite(opacity)) return;
    self.douyindisc_previewOpacity[identifier] = @(fmin(1, fmax(0, opacity)));
    [NSNotificationCenter.defaultCenter postNotificationName:@"com.minis.douyindisc.navigation.preview" object:identifier];
}

- (void)douyindisc_clearOpacityPreviewForIdentifier:(NSString *)identifier {
    NSAssert(NSThread.isMainThread, @"Navigation store access must be on main thread");
    if (!douyindisc_validIdentifier(identifier)) return;
    [self.douyindisc_previewOpacity removeObjectForKey:identifier];
    [NSNotificationCenter.defaultCenter postNotificationName:@"com.minis.douyindisc.navigation.preview" object:identifier];
}

- (void)douyindisc_previewScale:(CGFloat)scale identifier:(NSString *)identifier {
    NSAssert(NSThread.isMainThread, @"Navigation store access must be on main thread");
    if (!douyindisc_validIdentifier(identifier) || !isfinite(scale)) return;
    self.douyindisc_previewScale[identifier] = @(fmin(1.5, fmax(.5, scale)));
    [NSNotificationCenter.defaultCenter postNotificationName:@"com.minis.douyindisc.navigation.preview" object:identifier];
}

- (void)douyindisc_clearScalePreviewForIdentifier:(NSString *)identifier {
    NSAssert(NSThread.isMainThread, @"Navigation store access must be on main thread");
    if (!douyindisc_validIdentifier(identifier)) return;
    [self.douyindisc_previewScale removeObjectForKey:identifier];
    [NSNotificationCenter.defaultCenter postNotificationName:@"com.minis.douyindisc.navigation.preview" object:identifier];
}

- (NSDictionary<NSString *, id> *)douyindisc_entryForIdentifier:(NSString *)identifier {
    NSAssert(NSThread.isMainThread, @"Navigation store access must be on main thread");
    if (!douyindisc_validIdentifier(identifier)) return @{@"enabled":@NO, @"opacity":@1, @"hasImage":@NO};
    NSDictionary *stored = self.douyindisc_config[identifier];
    NSNumber *opacity = self.douyindisc_previewOpacity[identifier] ?: stored[@"opacity"] ?: @1;
    NSNumber *scale=self.douyindisc_previewScale[identifier] ?: stored[@"scale"] ?: @1;
    return @{@"enabled":stored[@"enabled"] ?: @NO, @"opacity":opacity, @"scale":scale, @"hasImage":@(stored[@"image"] != nil)};
}

- (BOOL)douyindisc_imagePickingEnabledForIdentifier:(NSString *)identifier {
    NSAssert(NSThread.isMainThread, @"Navigation store access must be on main thread");
    return douyindisc_validIdentifier(identifier) && [self.douyindisc_config[identifier][@"enabled"] boolValue];
}

- (NSUInteger)douyindisc_beginImagePickingForIdentifier:(NSString *)identifier {
    NSAssert(NSThread.isMainThread, @"Navigation store access must be on main thread");
    if (![self douyindisc_imagePickingEnabledForIdentifier:identifier]) return 0;
    NSUInteger generation=[self.douyindisc_pickGeneration[identifier] unsignedIntegerValue]+1;
    self.douyindisc_pickGeneration[identifier]=@(generation);
    self.douyindisc_activePickGeneration[identifier]=@(generation);
    return generation;
}

- (void)douyindisc_finishImagePickingForIdentifier:(NSString *)identifier generation:(NSUInteger)generation {
    NSAssert(NSThread.isMainThread, @"Navigation store access must be on main thread");
    if (!douyindisc_validIdentifier(identifier) || !generation) return;
    if (![self.douyindisc_activePickGeneration[identifier] isEqualToNumber:@(generation)]) return;
    [self.douyindisc_activePickGeneration removeObjectForKey:identifier];
}

- (void)douyindisc_cancelImagePickingForIdentifier:(NSString *)identifier {
    NSAssert(NSThread.isMainThread, @"Navigation store access must be on main thread");
    if (!douyindisc_validIdentifier(identifier)) return;
    self.douyindisc_pickGeneration[identifier]=@([self.douyindisc_pickGeneration[identifier] unsignedIntegerValue]+1);
    [self.douyindisc_activePickGeneration removeObjectForKey:identifier];
}

- (UIImage *)douyindisc_decodeImageData:(NSData *)data {
    NSError *error=nil;
    return douyindisc_decodeImage(data,NO,&error);
}

- (UIImage *)douyindisc_imageForIdentifier:(NSString *)identifier {
    NSAssert(NSThread.isMainThread, @"Navigation store access must be on main thread");
    return douyindisc_validIdentifier(identifier) ? self.douyindisc_images[identifier] : nil;
}

- (void)douyindisc_preloadImagesWithCompletion:(void (^)(void))completion {
    NSAssert(NSThread.isMainThread, @"Navigation store access must be on main thread");
    NSDictionary *configSnapshot = self.douyindisc_config ?: @{};
    NSMutableDictionary *generations = [NSMutableDictionary dictionaryWithCapacity:13];
    for (NSDictionary *item in douyindisc_itemTable()) {
        NSString *key = item[@"identifier"];
        generations[key] = self.douyindisc_imageGeneration[key] ?: @0;
    }
    NSUInteger preloadGeneration = ++self.douyindisc_preloadGeneration;
    NSURL *directory = self.douyindisc_storeDirectory;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableDictionary<NSString *, UIImage *> *images = [NSMutableDictionary dictionary];
        for (NSDictionary *item in douyindisc_itemTable()) {
            NSString *key = item[@"identifier"];
            NSString *name = configSnapshot[key][@"image"];
            if (!douyindisc_validImageName(name)) continue;
            NSURL *url = [directory URLByAppendingPathComponent:name];
            NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
            if (!data.length || data.length > 6 * 1024 * 1024) continue;
            UIImage *image = douyindisc_decodeImage(data, YES, nil);
            if (image.CGImage) images[key] = image;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAssert(NSThread.isMainThread, @"Navigation store merge must be on main thread");
            BOOL changed = NO;
            if (self.douyindisc_preloadGeneration == preloadGeneration) {
                for (NSString *key in images) {
                    NSString *name = configSnapshot[key][@"image"];
                    if ([self.douyindisc_config[key][@"image"] isEqualToString:name] &&
                        [self.douyindisc_imageGeneration[key] unsignedIntegerValue] == [generations[key] unsignedIntegerValue]) {
                        self.douyindisc_images[key] = images[key];
                        changed = YES;
                    }
                }
            }
            if (changed) [NSNotificationCenter.defaultCenter postNotificationName:@"com.minis.douyindisc.navigation.changed" object:self];
            if (completion) completion();
        });
    });
}

- (BOOL)douyindisc_commitLatestConfig:(NSDictionary *)config beforeNotify:(dispatch_block_t)beforeNotify error:(NSError **)error {
    NSAssert(NSThread.isMainThread, @"Navigation store commit must be on main thread");
    if (self.douyindisc_loadFailed) {
        if (error) *error = douyindisc_error(1, @"配置文件格式错误，未覆盖原文件。请先备份 settings.plist。");
        return NO;
    }
#if defined(DOUYINDISC_UI_TEST)
    if (self.douyindisc_testFailNextCommit) {
        self.douyindisc_testFailNextCommit = NO;
        if (error) *error = douyindisc_error(4, @"UI_TEST injected config commit failure.");
        return NO;
    }
#endif
    NSError *writeError = nil;
    if (![NSFileManager.defaultManager createDirectoryAtURL:self.douyindisc_storeDirectory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&writeError]) {
        if (error) *error = writeError;
        return NO;
    }
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:config format:NSPropertyListBinaryFormat_v1_0 options:0 error:&writeError];
    NSURL *configURL = [self.douyindisc_storeDirectory URLByAppendingPathComponent:@"settings.plist"];
    if (!data || ![data writeToURL:configURL options:NSDataWritingAtomic error:&writeError]) {
        if (error) *error = writeError ?: douyindisc_error(4, @"配置文件写入失败。");
        return NO;
    }
    self.douyindisc_config = [config copy];
    if (beforeNotify) beforeNotify();
    [NSNotificationCenter.defaultCenter postNotificationName:@"com.minis.douyindisc.navigation.changed" object:self];
    return YES;
}

- (BOOL)douyindisc_saveEnabled:(BOOL)enabled opacity:(CGFloat)opacity scale:(CGFloat)scale identifier:(NSString *)identifier error:(NSError **)error {
    NSAssert(NSThread.isMainThread, @"Navigation store access must be on main thread");
    if (!douyindisc_validIdentifier(identifier) || !isfinite(opacity) || !isfinite(scale)) {
        if (error) *error = douyindisc_error(3, @"导航项、不透明度或图标大小无效。");
        return NO;
    }
    opacity = fmin(1, fmax(0, opacity));
    scale = fmin(1.5, fmax(.5, scale));
    NSMutableDictionary *config = [self.douyindisc_config mutableCopy];
    NSMutableDictionary *entry = [config[identifier] mutableCopy] ?: [NSMutableDictionary dictionary];
    entry[@"enabled"] = @(enabled);
    entry[@"opacity"] = @(opacity);
    entry[@"scale"] = @(scale);
    config[identifier] = entry;
    BOOL committed=[self douyindisc_commitLatestConfig:config beforeNotify:nil error:error];
    if(committed&&!enabled)[self douyindisc_cancelImagePickingForIdentifier:identifier];
    return committed;
}

- (void)douyindisc_saveImageData:(NSData *)data identifier:(NSString *)identifier completion:(void (^)(NSError *))completion {
    NSUInteger generation=[self douyindisc_beginImagePickingForIdentifier:identifier];
    if(!generation){dispatch_async(dispatch_get_main_queue(),^{if(completion)completion(douyindisc_error(6,@"请先开启此项的图标替换开关。"));});return;}
    [self douyindisc_saveImageData:data identifier:identifier pickingGeneration:generation completion:completion];
}

- (void)douyindisc_saveImageData:(NSData *)data identifier:(NSString *)identifier pickingGeneration:(NSUInteger)pickingGeneration completion:(void (^)(NSError *))completion {
    NSAssert(NSThread.isMainThread, @"Navigation store access must be on main thread");
    NSData *snapshot = [data copy];
    NSString *key = [identifier copy];
    NSUInteger authorizedGeneration=pickingGeneration;
    if (!douyindisc_validIdentifier(key) || !authorizedGeneration || ![self.douyindisc_activePickGeneration[key] isEqualToNumber:@(authorizedGeneration)] || ![self douyindisc_imagePickingEnabledForIdentifier:key]) {
        dispatch_async(dispatch_get_main_queue(), ^{ if(completion)completion(douyindisc_error(6,@"请先开启此项的图标替换开关，再选择图标。")); });
        return;
    }
    NSUInteger generation = [self.douyindisc_imageGeneration[key] unsignedIntegerValue] + 1;
    self.douyindisc_imageGeneration[key] = @(generation);
    NSURL *directory = self.douyindisc_storeDirectory;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        UIImage *image = douyindisc_decodeImage(snapshot, NO, &error);
        NSData *png = image.CGImage ? douyindisc_PNGData(image.CGImage, &error) : nil;
        NSString *name = nil;
        NSURL *newURL = nil;
        if (png.length) {
            NSError *writeError = nil;
            if (![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&writeError]) {
                error = writeError;
            } else {
                name = [NSString stringWithFormat:@"%@.png", NSUUID.UUID.UUIDString];
                newURL = [directory URLByAppendingPathComponent:name];
                if (![png writeToURL:newURL options:NSDataWritingAtomic error:&writeError]) { error = writeError; name = nil; newURL = nil; }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAssert(NSThread.isMainThread, @"Navigation store merge must be on main thread");
            if (!name || !image.CGImage) {
                [self douyindisc_finishImagePickingForIdentifier:key generation:authorizedGeneration];
                if (completion) completion(error ?: douyindisc_error(2, @"图片无法读取或保存。"));
                return;
            }
            if ([self.douyindisc_imageGeneration[key] unsignedIntegerValue] != generation) {
                [NSFileManager.defaultManager removeItemAtURL:newURL error:nil];
                if([self.douyindisc_activePickGeneration[key] isEqualToNumber:@(authorizedGeneration)])[self douyindisc_finishImagePickingForIdentifier:key generation:authorizedGeneration];
                if (completion) completion(douyindisc_error(5, @"该图片导入已被更新操作取消。"));
                return;
            }
            if (![self.douyindisc_activePickGeneration[key] isEqualToNumber:@(authorizedGeneration)] || ![self douyindisc_imagePickingEnabledForIdentifier:key]) {
                [NSFileManager.defaultManager removeItemAtURL:newURL error:nil];
                [self douyindisc_finishImagePickingForIdentifier:key generation:authorizedGeneration];
                if (completion) completion(douyindisc_error(6, @"此项图标替换已关闭，导入已取消，原图保留。"));
                return;
            }
            NSString *oldName = self.douyindisc_config[key][@"image"];
            NSMutableDictionary *config = [self.douyindisc_config mutableCopy];
            NSMutableDictionary *entry = [config[key] mutableCopy] ?: [NSMutableDictionary dictionary];
            entry[@"image"] = name;
            config[key] = entry;
            __block NSError *commitError = nil;
            BOOL saved = [self douyindisc_commitLatestConfig:config beforeNotify:^{ self.douyindisc_images[key] = image; } error:&commitError];
            [self douyindisc_finishImagePickingForIdentifier:key generation:authorizedGeneration];
            if (!saved) [NSFileManager.defaultManager removeItemAtURL:newURL error:nil];
            else {
                if (douyindisc_validImageName(oldName) && ![oldName isEqualToString:name])
                    [NSFileManager.defaultManager removeItemAtURL:[directory URLByAppendingPathComponent:oldName] error:nil];
            }
            if (completion) completion(saved ? nil : (error ?: douyindisc_error(4, @"图片配置提交失败。")));
        });
    });
}

- (BOOL)douyindisc_clearImageForIdentifier:(NSString *)identifier error:(NSError **)error {
    NSAssert(NSThread.isMainThread, @"Navigation store access must be on main thread");
    if (!douyindisc_validIdentifier(identifier)) {
        if (error) *error = douyindisc_error(3, @"导航项无效。");
        return NO;
    }
    self.douyindisc_imageGeneration[identifier] = @([self.douyindisc_imageGeneration[identifier] unsignedIntegerValue] + 1);
    NSString *oldName = self.douyindisc_config[identifier][@"image"];
    NSMutableDictionary *config = [self.douyindisc_config mutableCopy];
    NSMutableDictionary *entry = [config[identifier] mutableCopy] ?: [NSMutableDictionary dictionary];
    [entry removeObjectForKey:@"image"];
    config[identifier] = entry;
    BOOL cleared = [self douyindisc_commitLatestConfig:config beforeNotify:^{ [self.douyindisc_images removeObjectForKey:identifier]; } error:error];
    if (!cleared) return NO;
    if (douyindisc_validImageName(oldName))
        [NSFileManager.defaultManager removeItemAtURL:[self.douyindisc_storeDirectory URLByAppendingPathComponent:oldName] error:nil];
    return YES;
}
@end

#if defined(DOUYINDISC_UI_TEST)
DouyinDiscNavigationStore *douyindisc_uiTestCreateStore(NSURL *directory) {
    if (!NSThread.isMainThread || !directory.isFileURL) return nil;
    return [[DouyinDiscNavigationStore alloc] initWithDouyinDiscDirectory:directory];
}

void douyindisc_uiTestPreviewNavigationScale(NSString *identifier, CGFloat scale) {
    if (!NSThread.isMainThread || !douyindisc_validIdentifier(identifier) || !isfinite(scale)) return;
    DouyinDiscNavigationStore *store=[DouyinDiscNavigationStore douyindisc_sharedStore];
    [store douyindisc_previewScale:scale identifier:identifier];
}

void douyindisc_uiTestSetNavigationImage(NSString *identifier, UIImage *image, BOOL enabled) {
    if (!NSThread.isMainThread || !douyindisc_validIdentifier(identifier)) return;
    DouyinDiscNavigationStore *store=[DouyinDiscNavigationStore douyindisc_sharedStore];
    NSMutableDictionary *config=[store.douyindisc_config mutableCopy] ?: [NSMutableDictionary dictionary];
    NSMutableDictionary *entry=[config[identifier] mutableCopy] ?: [NSMutableDictionary dictionary];
    entry[@"enabled"]=@(enabled);
    entry[@"opacity"]=@1;
    if(image){entry[@"image"]=@"fixture.png";store.douyindisc_images[identifier]=image;}
    else { [entry removeObjectForKey:@"image"];[store.douyindisc_images removeObjectForKey:identifier]; }
    config[identifier]=entry;
    store.douyindisc_config=[config copy];
    [NSNotificationCenter.defaultCenter postNotificationName:@"com.minis.douyindisc.navigation.changed" object:store];
}

void douyindisc_uiTestSetNavigationScale(NSString *identifier, CGFloat scale) {
    if (!NSThread.isMainThread || !douyindisc_validIdentifier(identifier) || !isfinite(scale)) return;
    DouyinDiscNavigationStore *store=[DouyinDiscNavigationStore douyindisc_sharedStore];
    NSMutableDictionary *config=[store.douyindisc_config mutableCopy] ?: [NSMutableDictionary dictionary];
    NSMutableDictionary *entry=[config[identifier] mutableCopy] ?: [NSMutableDictionary dictionary];
    entry[@"scale"]=@(fmin(1.5,fmax(.5,scale)));
    config[identifier]=entry;
    store.douyindisc_config=[config copy];
    [NSNotificationCenter.defaultCenter postNotificationName:@"com.minis.douyindisc.navigation.changed" object:store];
}

BOOL douyindisc_uiTestCanDecodeImageData(NSData *data) {
    return douyindisc_decodeImage(data, NO, NULL).CGImage != NULL;
}

void douyindisc_uiTestFailNextCommit(DouyinDiscNavigationStore *store) {
    if (!NSThread.isMainThread || !store) return;
    store.douyindisc_testFailNextCommit = YES;
}
#endif
