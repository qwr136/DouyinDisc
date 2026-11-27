#import "DouyinDiscNavigation.h"
#import <math.h>
#import <ImageIO/ImageIO.h>
#import <string.h>

static NSString * const douyindisc_utiPNG = @"public.png";
static NSString * const douyindisc_utiGIF = @"com.compuserve.gif";
static const NSUInteger douyindisc_gifByteLimit = 64 * 1024 * 1024;
static const NSUInteger douyindisc_gifFrameLimit = 1024;
static const NSTimeInterval douyindisc_gifDurationLimit = 60.0;
static const NSUInteger douyindisc_gifDecodedByteLimit = 64 * 1024 * 1024;
static const NSUInteger douyindisc_gifCanvasLimit = 4096;
static const NSUInteger douyindisc_gifDecodeEdge = 96;

@interface DouyinDiscGIFAnimation ()
@property(nonatomic,copy,readwrite) NSArray<UIImage *> *frames;
@property(nonatomic,copy,readwrite) NSArray<NSNumber *> *keyTimes;
@property(nonatomic,readwrite) NSTimeInterval duration;
@end
@implementation DouyinDiscGIFAnimation @end

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
            @[@"bottom_me", @"我", @"person.crop.circle", @"#3778D4"], @[@"video_disc", @"视频唱片", @"opticaldisc", @"#8B5CF6"]
        ];
        NSMutableArray *built = [NSMutableArray arrayWithCapacity:raw.count];
        for (NSArray *row in raw) {
            NSString *identifier=row[0];
            [built addObject:@{@"identifier":identifier, @"title":row[1], @"sfIcon":row[2], @"accentColor":row[3], @"adjustmentTitle":[identifier isEqualToString:@"video_disc"]?@"转速":@"图标大小"}];
        }
        items = built.copy;
    });
    return items;
}

NSArray<NSDictionary<NSString *, id> *> *douyindisc_navigationItems(void) { return douyindisc_itemTable(); }

static BOOL douyindisc_validIdentifier(NSString *identifier) {
    for (NSDictionary *item in douyindisc_itemTable()) if ([item[@"identifier"] isEqual:identifier]) return YES;
    return NO;
}

static BOOL douyindisc_isNavigationIconIdentifier(NSString *identifier) {
    return [identifier hasPrefix:@"top_"] || [identifier hasPrefix:@"bottom_"];
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
static NSString *douyindisc_gifNameForImageName(NSString *imageName) {
    if(!douyindisc_validImageName(imageName))return nil;
    return [[imageName stringByDeletingPathExtension] stringByAppendingPathExtension:@"gif"];
}

static BOOL douyindisc_hasGIFSignature(NSData *data) {
    if(data.length<6)return NO;const uint8_t *bytes=data.bytes;
    return !memcmp(bytes,"GIF87a",6)||!memcmp(bytes,"GIF89a",6);
}

static size_t douyindisc_frameCount(NSData *data) {
    CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)data,NULL);
    if(!source)return 0;size_t count=CGImageSourceGetCount(source);CFRelease(source);return count;
}

static BOOL douyindisc_dataIsAnimatedGIF(NSData *data) {
    if(!data.length||data.length>douyindisc_gifByteLimit)return NO;
    CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)data,NULL);
    if(!source)return NO;
    CFStringRef type=CGImageSourceGetType(source);
    BOOL result=type&&CFEqual(type,(__bridge CFStringRef)douyindisc_utiGIF)&&CGImageSourceGetCount(source)>1;
    CFRelease(source);return result;
}

static DouyinDiscGIFAnimation *douyindisc_decodeGIF(NSData *data,NSError **error) {
    if(!data.length||data.length>douyindisc_gifByteLimit){if(error)*error=douyindisc_error(2,@"GIF动画超过64 MiB安全上限。");return nil;}
    CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)data,NULL);
    if(!source){if(error)*error=douyindisc_error(2,@"GIF动画数据损坏。");return nil;}
    CFStringRef type=CGImageSourceGetType(source);size_t count=CGImageSourceGetCount(source);
    if(!type||!CFEqual(type,(__bridge CFStringRef)douyindisc_utiGIF)||count<2||count>douyindisc_gifFrameLimit||CGImageSourceGetStatus(source)!=kCGImageStatusComplete){CFRelease(source);if(error)*error=douyindisc_error(2,count>douyindisc_gifFrameLimit?@"GIF帧数超过1024帧安全上限。":@"GIF动画数据不完整或不是多帧GIF。");return nil;}
    NSMutableArray<UIImage *> *frames=[NSMutableArray arrayWithCapacity:count];NSMutableArray<NSNumber *> *keyTimes=[NSMutableArray arrayWithCapacity:count];NSTimeInterval duration=0;
    NSDictionary *options=@{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways:@YES,(__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize:@(douyindisc_gifDecodeEdge),(__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform:@YES,(__bridge NSString *)kCGImageSourceShouldCacheImmediately:@YES};
    for(size_t i=0;i<count;i++){
        if(CGImageSourceGetStatusAtIndex(source,i)!=kCGImageStatusComplete){CFRelease(source);if(error)*error=douyindisc_error(2,@"GIF存在不完整帧。");return nil;}
        NSDictionary *props=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,i,NULL));
        NSNumber *w=props[(__bridge NSString *)kCGImagePropertyPixelWidth],*h=props[(__bridge NSString *)kCGImagePropertyPixelHeight];
        if(!w||!h||!w.unsignedIntegerValue||!h.unsignedIntegerValue||w.unsignedIntegerValue>douyindisc_gifCanvasLimit||h.unsignedIntegerValue>douyindisc_gifCanvasLimit){CFRelease(source);if(error)*error=douyindisc_error(2,@"GIF画布超过4096像素限制。");return nil;}
        NSDictionary *gif=props[(__bridge NSString *)kCGImagePropertyGIFDictionary];
        NSNumber *n=gif[(__bridge NSString *)kCGImagePropertyGIFUnclampedDelayTime]?:gif[(__bridge NSString *)kCGImagePropertyGIFDelayTime];
        double delay=n?[n doubleValue]:.1;if(!isfinite(delay))delay=.1;delay=fmin(.5,fmax(.04,delay));
        if(duration+delay>douyindisc_gifDurationLimit){CFRelease(source);if(error)*error=douyindisc_error(2,@"GIF动画时长超过60秒安全上限。");return nil;}
        CGImageRef frame=CGImageSourceCreateThumbnailAtIndex(source,i,(__bridge CFDictionaryRef)options);
        if(!frame){CFRelease(source);if(error)*error=douyindisc_error(2,@"GIF帧解码失败。");return nil;}
        [frames addObject:[UIImage imageWithCGImage:frame scale:1 orientation:UIImageOrientationUp]];CGImageRelease(frame);
        [keyTimes addObject:@(duration)];duration+=delay;
    }
    CFRelease(source);for(NSUInteger i=0;i<keyTimes.count;i++)keyTimes[i]=@([keyTimes[i] doubleValue]/duration);
    DouyinDiscGIFAnimation *animation=[DouyinDiscGIFAnimation new];animation.frames=frames.copy;animation.keyTimes=keyTimes.copy;animation.duration=duration;return animation;
}

static NSUInteger douyindisc_gifDecodedCost(DouyinDiscGIFAnimation *animation) {
    NSUInteger total=0;if(!animation)return 0;
    for(UIImage *image in animation.frames){CGImageRef cg=image.CGImage;if(!cg)return NSUIntegerMax;size_t row=CGImageGetBytesPerRow(cg),height=CGImageGetHeight(cg);if(row>NSUIntegerMax/height||total>NSUIntegerMax-row*height)return NSUIntegerMax;total+=row*height;}
    return total;
}
static BOOL douyindisc_validConfig(id value) {
    if (![value isKindOfClass:NSDictionary.class]) return NO;
    NSSet *allowed = [NSSet setWithArray:@[@"enabled", @"opacity", @"scale", @"speed", @"image", @"angle", @"cornerRadius", @"rotationEnabled", @"rotationSpeed"]];
    for (id key in (NSDictionary *)value) {
        id entry = value[key];
        if (![key isKindOfClass:NSString.class] || !douyindisc_validIdentifier(key) || ![entry isKindOfClass:NSDictionary.class]) return NO;
        for (id field in (NSDictionary *)entry) if (![field isKindOfClass:NSString.class] || ![allowed containsObject:field]) return NO;
        if (entry[@"enabled"] && ![entry[@"enabled"] isKindOfClass:NSNumber.class]) return NO;
        if (entry[@"opacity"] && ![entry[@"opacity"] isKindOfClass:NSNumber.class]) return NO;
        if (entry[@"scale"] && ![entry[@"scale"] isKindOfClass:NSNumber.class]) return NO;
        if (entry[@"speed"] && (![key isEqualToString:@"video_disc"] || ![entry[@"speed"] isKindOfClass:NSNumber.class])) return NO;
        if(entry[@"angle"]&&(!douyindisc_isNavigationIconIdentifier(key)||![entry[@"angle"] isKindOfClass:NSNumber.class]))return NO;
        if(entry[@"cornerRadius"]&&(!douyindisc_isNavigationIconIdentifier(key)||![entry[@"cornerRadius"] isKindOfClass:NSNumber.class]))return NO;
        if(entry[@"rotationEnabled"]&&(!douyindisc_isNavigationIconIdentifier(key)||![entry[@"rotationEnabled"] isKindOfClass:NSNumber.class]))return NO;
        if(entry[@"rotationSpeed"]&&(!douyindisc_isNavigationIconIdentifier(key)||![entry[@"rotationSpeed"] isKindOfClass:NSNumber.class]))return NO;
        if (entry[@"image"] && !douyindisc_validImageName(entry[@"image"])) return NO;
        double opacity = [entry[@"opacity"] respondsToSelector:@selector(doubleValue)] ? [entry[@"opacity"] doubleValue] : 1;
        double scale = [entry[@"scale"] respondsToSelector:@selector(doubleValue)] ? [entry[@"scale"] doubleValue] : 1;
        double speed = [entry[@"speed"] respondsToSelector:@selector(doubleValue)] ? [entry[@"speed"] doubleValue] : 1;
        double angle=[entry[@"angle"] respondsToSelector:@selector(doubleValue)]?[entry[@"angle"] doubleValue]:0;
        double corner=[entry[@"cornerRadius"] respondsToSelector:@selector(doubleValue)]?[entry[@"cornerRadius"] doubleValue]:0;
        double rotationSpeed=[entry[@"rotationSpeed"] respondsToSelector:@selector(doubleValue)]?[entry[@"rotationSpeed"] doubleValue]:1;
        if (!isfinite(opacity) || opacity < 0 || opacity > 1 || !isfinite(scale) || scale < .5 || scale > 1.5 || !isfinite(speed) || speed < .25 || speed > 3 || !isfinite(angle) || angle < 0 || angle > 360 || !isfinite(corner) || corner < 0 || corner > 50 || !isfinite(rotationSpeed) || rotationSpeed < .25 || rotationSpeed > 3) return NO;
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
@property (nonatomic, strong) NSMutableDictionary<NSString *, DouyinDiscGIFAnimation *> *douyindisc_animations;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *douyindisc_previewOpacity;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *douyindisc_previewScale;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *douyindisc_imageGeneration;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *douyindisc_pickGeneration;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *douyindisc_activePickGeneration;
@property (nonatomic, strong) NSURL *douyindisc_storeDirectory;
@property (nonatomic) NSUInteger douyindisc_preloadGeneration;
@property (nonatomic) BOOL douyindisc_loadFailed;
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
    _douyindisc_animations = [NSMutableDictionary dictionary];
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
    return self;
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
    CGFloat minimum=[identifier isEqualToString:@"video_disc"]?.25:.5,maximum=[identifier isEqualToString:@"video_disc"]?3:1.5;
    self.douyindisc_previewScale[identifier] = @(fmin(maximum, fmax(minimum, scale)));
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
    BOOL videoDisc=[identifier isEqualToString:@"video_disc"];
    NSNumber *opacity = self.douyindisc_previewOpacity[identifier] ?: stored[@"opacity"] ?: @1;
    NSNumber *adjustment=self.douyindisc_previewScale[identifier] ?: (videoDisc?(stored[@"speed"]?:@1):(stored[@"scale"]?:@1));
    NSNumber *enabled=stored[@"enabled"] ?: @(videoDisc);
    BOOL navigationIcon=douyindisc_isNavigationIconIdentifier(identifier);
    return @{@"enabled":enabled, @"opacity":opacity, @"scale":adjustment, @"speed":adjustment, @"hasImage":@(stored[@"image"] != nil), @"angle":navigationIcon?(stored[@"angle"]?:@0):@0, @"cornerRadius":navigationIcon?(stored[@"cornerRadius"]?:@0):@0, @"rotationEnabled":navigationIcon?(stored[@"rotationEnabled"]?:@NO):@NO, @"rotationSpeed":navigationIcon?(stored[@"rotationSpeed"]?:@1):@1};
}

- (BOOL)douyindisc_imagePickingEnabledForIdentifier:(NSString *)identifier {
    NSAssert(NSThread.isMainThread, @"Navigation store access must be on main thread");
    if(!douyindisc_validIdentifier(identifier))return NO;
    NSNumber *enabled=self.douyindisc_config[identifier][@"enabled"];
    return enabled?[enabled boolValue]:[identifier isEqualToString:@"video_disc"];
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

- (BOOL)douyindisc_isAnimatedGIFData:(NSData *)data {
    return douyindisc_dataIsAnimatedGIF(data);
}

- (UIImage *)douyindisc_imageForIdentifier:(NSString *)identifier {
    NSAssert(NSThread.isMainThread, @"Navigation store access must be on main thread");
    return douyindisc_validIdentifier(identifier) ? self.douyindisc_images[identifier] : nil;
}

- (DouyinDiscGIFAnimation *)douyindisc_animationForIdentifier:(NSString *)identifier {
    NSAssert(NSThread.isMainThread, @"Navigation animation access must be on main thread");
    return douyindisc_validIdentifier(identifier)?self.douyindisc_animations[identifier]:nil;
}

- (void)douyindisc_prepareStartupImages {
    NSAssert(NSThread.isMainThread, @"Startup images must be prepared on main thread");
    if (!NSThread.isMainThread || self.douyindisc_loadFailed) return;
    // Import already persists a bounded PNG first frame even for GIFs. Prepare
    // only that file before renderers run; never synchronously open the GIF.
    for (NSDictionary *item in douyindisc_itemTable()) {
        @autoreleasepool {
            NSString *key=item[@"identifier"];
            if (![self douyindisc_imagePickingEnabledForIdentifier:key] || self.douyindisc_images[key].CGImage) continue;
            NSString *name=self.douyindisc_config[key][@"image"];
            if (!douyindisc_validImageName(name)) continue;
            NSURL *url=[self.douyindisc_storeDirectory URLByAppendingPathComponent:name];
            NSNumber *size=nil,*regular=nil;
            if (![url getResourceValue:&size forKey:NSURLFileSizeKey error:nil] || !size.unsignedLongLongValue || size.unsignedLongLongValue>6*1024*1024 ||
                ![url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil] || !regular.boolValue) continue;
            NSData *data=nil;NSFileHandle *file=[NSFileHandle fileHandleForReadingFromURL:url error:nil];
            if (!file) continue;
            @try { data=[file readDataOfLength:6*1024*1024+1]; }
            @catch (NSException *exception) { (void)exception;data=nil; }
            @finally { @try { [file closeFile]; } @catch(NSException *exception) { (void)exception; } }
            if (!data.length || data.length>6*1024*1024) continue;
            CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)data,NULL);
            if (!source) continue;
            CFStringRef type=CGImageSourceGetType(source);
            BOOL png=type&&CFEqual(type,(__bridge CFStringRef)douyindisc_utiPNG)&&CGImageSourceGetCount(source)==1&&CGImageSourceGetStatus(source)==kCGImageStatusComplete;
            NSDictionary *properties=png?CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,NULL)):nil;
            NSUInteger width=[properties[(__bridge NSString *)kCGImagePropertyPixelWidth] unsignedIntegerValue];
            NSUInteger height=[properties[(__bridge NSString *)kCGImagePropertyPixelHeight] unsignedIntegerValue];
            CFRelease(source);
            // These files are generated by our 512px importer, not arbitrary originals.
            if (!png || width==0 || height==0 || width>512 || height>512) continue;
            UIImage *image=douyindisc_decodeImage(data,YES,nil);
            if (image.CGImage) self.douyindisc_images[key]=image;
        }
    }
}

- (void)douyindisc_preloadImagesWithCompletion:(void (^)(void))completion {
    NSAssert(NSThread.isMainThread, @"Navigation store access must be on main thread");
    NSDictionary *configSnapshot = self.douyindisc_config ?: @{};
    NSMutableDictionary *generations = [NSMutableDictionary dictionaryWithCapacity:14];
    for (NSDictionary *item in douyindisc_itemTable()) {
        NSString *key = item[@"identifier"];
        generations[key] = self.douyindisc_imageGeneration[key] ?: @0;
    }
    NSUInteger preloadGeneration = ++self.douyindisc_preloadGeneration;
    NSDictionary<NSString *,DouyinDiscGIFAnimation *> *animationSnapshot=[self.douyindisc_animations copy];
    NSUInteger reservedAnimationBytes=0;for(DouyinDiscGIFAnimation *animation in animationSnapshot.allValues){NSUInteger cost=douyindisc_gifDecodedCost(animation);reservedAnimationBytes=cost>NSUIntegerMax-reservedAnimationBytes?NSUIntegerMax:reservedAnimationBytes+cost;}
    NSURL *directory = self.douyindisc_storeDirectory;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableDictionary<NSString *, UIImage *> *images = [NSMutableDictionary dictionary];
        NSMutableDictionary<NSString *, DouyinDiscGIFAnimation *> *animations = [NSMutableDictionary dictionary];
        NSMutableSet<NSString *> *animationCandidates=[NSMutableSet set];
        NSUInteger decodedAnimationBytes=reservedAnimationBytes;
        for (NSDictionary *item in douyindisc_itemTable()) {
            NSString *key = item[@"identifier"];
            NSString *name = configSnapshot[key][@"image"];
            if (!douyindisc_validImageName(name)) continue;
            NSURL *url = [directory URLByAppendingPathComponent:name];
            NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
            if (!data.length || data.length > 6 * 1024 * 1024) continue;
            UIImage *image = douyindisc_decodeImage(data, YES, nil);
            if (image.CGImage) images[key] = image;
            BOOL enabled=configSnapshot[key][@"enabled"]?[configSnapshot[key][@"enabled"] boolValue]:[key isEqualToString:@"video_disc"];
            if(!enabled)continue;
            [animationCandidates addObject:key];
            NSString *gifName=douyindisc_gifNameForImageName(name);
            NSURL *gifURL=gifName?[directory URLByAppendingPathComponent:gifName]:nil;
            DouyinDiscGIFAnimation *cached=animationSnapshot[key];
            if(cached&&gifURL&&[NSFileManager.defaultManager fileExistsAtPath:gifURL.path]){animations[key]=cached;continue;}
            NSNumber *gifSize=nil;if(gifURL)[gifURL getResourceValue:&gifSize forKey:NSURLFileSizeKey error:nil];
            NSData *gif=(gifSize&&gifSize.unsignedLongLongValue>0&&gifSize.unsignedLongLongValue<=douyindisc_gifByteLimit)?[NSData dataWithContentsOfURL:gifURL options:NSDataReadingMappedIfSafe error:nil]:nil;
            if(gif.length<=douyindisc_gifByteLimit){DouyinDiscGIFAnimation *animation=douyindisc_decodeGIF(gif,nil);NSUInteger cost=douyindisc_gifDecodedCost(animation);if(animation&&decodedAnimationBytes<=douyindisc_gifDecodedByteLimit&&cost<=douyindisc_gifDecodedByteLimit-decodedAnimationBytes){animations[key]=animation;decodedAnimationBytes+=cost;}}
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAssert(NSThread.isMainThread, @"Navigation store merge must be on main thread");
            BOOL changed = NO;
            if (self.douyindisc_preloadGeneration == preloadGeneration) {
                for(NSDictionary *item in douyindisc_itemTable()){
                    NSString *key=item[@"identifier"],*name=configSnapshot[key][@"image"];
                    if(![self.douyindisc_config[key][@"image"] isEqualToString:name]||[self.douyindisc_imageGeneration[key] unsignedIntegerValue]!=[generations[key] unsignedIntegerValue])continue;
                    UIImage *image=images[key];if(image&&self.douyindisc_images[key]!=image){self.douyindisc_images[key]=image;changed=YES;}
                }
                for(NSString *key in animationCandidates){
                    NSString *name=configSnapshot[key][@"image"];
                    if(![self.douyindisc_config[key][@"image"] isEqualToString:name]||[self.douyindisc_imageGeneration[key] unsignedIntegerValue]!=[generations[key] unsignedIntegerValue])continue;
                    DouyinDiscGIFAnimation *animation=animations[key];
                    if(self.douyindisc_animations[key]!=animation){if(animation)self.douyindisc_animations[key]=animation;else [self.douyindisc_animations removeObjectForKey:key];changed=YES;}
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
    CGFloat minimum=[identifier isEqualToString:@"video_disc"]?.25:.5,maximum=[identifier isEqualToString:@"video_disc"]?3:1.5;
    if (!douyindisc_validIdentifier(identifier) || !isfinite(opacity) || !isfinite(scale) || scale<minimum || scale>maximum) {
        if (error) *error = douyindisc_error(3, @"导航项、不透明度或大小/转速无效。");
        return NO;
    }
    opacity = fmin(1, fmax(0, opacity));
    scale = fmin(maximum, fmax(minimum, scale));
    BOOL wasEnabled=[self.douyindisc_config[identifier][@"enabled"] boolValue];
    NSMutableDictionary *config = [self.douyindisc_config mutableCopy];
    NSMutableDictionary *entry = [config[identifier] mutableCopy] ?: [NSMutableDictionary dictionary];
    entry[@"enabled"] = @(enabled);
    entry[@"opacity"] = @(opacity);
    if([identifier isEqualToString:@"video_disc"])entry[@"speed"]=@(scale);else entry[@"scale"]=@(scale);
    config[identifier] = entry;
    BOOL committed=[self douyindisc_commitLatestConfig:config beforeNotify:nil error:error];
    if(committed&&!enabled){[self douyindisc_cancelImagePickingForIdentifier:identifier];self.douyindisc_preloadGeneration++;[self.douyindisc_animations removeObjectForKey:identifier];}
    else if(committed&&enabled&&!wasEnabled){NSString *name=self.douyindisc_config[identifier][@"image"];NSString *gifName=douyindisc_gifNameForImageName(name);if(gifName&&[NSFileManager.defaultManager fileExistsAtPath:[self.douyindisc_storeDirectory URLByAppendingPathComponent:gifName].path])[self douyindisc_preloadImagesWithCompletion:nil];}
    return committed;
}

- (BOOL)douyindisc_saveNavigationAppearanceForIdentifier:(NSString *)identifier angle:(CGFloat)angle cornerRadius:(CGFloat)cornerRadius rotationEnabled:(BOOL)rotationEnabled rotationSpeed:(CGFloat)rotationSpeed error:(NSError **)error {
    NSAssert(NSThread.isMainThread,@"Navigation store access must be on main thread");
    if(!douyindisc_validIdentifier(identifier)||!douyindisc_isNavigationIconIdentifier(identifier)||!isfinite(angle)||angle<0||angle>=360||!isfinite(cornerRadius)||cornerRadius<0||cornerRadius>50||!isfinite(rotationSpeed)||rotationSpeed<.25||rotationSpeed>3){if(error)*error=douyindisc_error(3,@"导航图标角度、圆角或旋转速度无效。");return NO;}
    NSMutableDictionary *config=[self.douyindisc_config mutableCopy]?:[NSMutableDictionary dictionary];
    NSMutableDictionary *entry=[config[identifier] mutableCopy]?:[NSMutableDictionary dictionary];
    entry[@"angle"]=@(angle);entry[@"cornerRadius"]=@(cornerRadius);entry[@"rotationEnabled"]=@(rotationEnabled);entry[@"rotationSpeed"]=@(rotationSpeed);
    config[identifier]=entry;
    return [self douyindisc_commitLatestConfig:config beforeNotify:nil error:error];
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
        BOOL gifSignature=douyindisc_hasGIFSignature(snapshot);
        size_t sourceFrames=gifSignature&&snapshot.length<=douyindisc_gifByteLimit?douyindisc_frameCount(snapshot):0;
        DouyinDiscGIFAnimation *animation=nil;
        if(gifSignature&&(!sourceFrames||snapshot.length>douyindisc_gifByteLimit))error=douyindisc_error(2,@"GIF动画数据损坏或超过64 MiB安全上限。");
        else if(gifSignature&&sourceFrames>1)animation=douyindisc_decodeGIF(snapshot,&error);
        UIImage *image=error?nil:douyindisc_decodeImage(snapshot,NO,&error);
        NSData *png = image.CGImage ? douyindisc_PNGData(image.CGImage, &error) : nil;
        NSString *name = nil;NSURL *newURL = nil;NSURL *newGIFURL=nil;
        if (png.length && (!gifSignature||sourceFrames<=1||animation)) {
            NSError *writeError = nil;
            if (![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&writeError]) {
                error = writeError;
            } else {
                name = [NSString stringWithFormat:@"%@.png", NSUUID.UUID.UUIDString];
                newURL = [directory URLByAppendingPathComponent:name];
                if (![png writeToURL:newURL options:NSDataWritingAtomic error:&writeError]) { error = writeError; name = nil; newURL = nil; }
                if(name&&animation){newGIFURL=[directory URLByAppendingPathComponent:douyindisc_gifNameForImageName(name)];if(![snapshot writeToURL:newGIFURL options:NSDataWritingAtomic error:&writeError]){[NSFileManager.defaultManager removeItemAtURL:newURL error:nil];error=writeError;name=nil;newURL=nil;newGIFURL=nil;}}
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAssert(NSThread.isMainThread, @"Navigation store merge must be on main thread");
            if (!name || !image.CGImage || (animation&&!newGIFURL)) {
                if(newURL)[NSFileManager.defaultManager removeItemAtURL:newURL error:nil];
                if(newGIFURL)[NSFileManager.defaultManager removeItemAtURL:newGIFURL error:nil];
                [self douyindisc_finishImagePickingForIdentifier:key generation:authorizedGeneration];
                if (completion) completion(error ?: douyindisc_error(2, @"图片无法读取或保存。"));
                return;
            }
            if ([self.douyindisc_imageGeneration[key] unsignedIntegerValue] != generation) {
                [NSFileManager.defaultManager removeItemAtURL:newURL error:nil];
                if(newGIFURL)[NSFileManager.defaultManager removeItemAtURL:newGIFURL error:nil];
                if([self.douyindisc_activePickGeneration[key] isEqualToNumber:@(authorizedGeneration)])[self douyindisc_finishImagePickingForIdentifier:key generation:authorizedGeneration];
                if (completion) completion(douyindisc_error(5, @"该图片导入已被更新操作取消。"));
                return;
            }
            if (![self.douyindisc_activePickGeneration[key] isEqualToNumber:@(authorizedGeneration)] || ![self douyindisc_imagePickingEnabledForIdentifier:key]) {
                [NSFileManager.defaultManager removeItemAtURL:newURL error:nil];
                if(newGIFURL)[NSFileManager.defaultManager removeItemAtURL:newGIFURL error:nil];
                [self douyindisc_finishImagePickingForIdentifier:key generation:authorizedGeneration];
                if (completion) completion(douyindisc_error(6, @"此项图标替换已关闭，导入已取消，原图保留。"));
                return;
            }
            NSString *oldName = self.douyindisc_config[key][@"image"];
            if(animation){
                NSUInteger total=douyindisc_gifDecodedCost(animation);
                for(NSString *cachedKey in self.douyindisc_animations)if(![cachedKey isEqualToString:key]){NSUInteger cost=douyindisc_gifDecodedCost(self.douyindisc_animations[cachedKey]);total=cost>NSUIntegerMax-total?NSUIntegerMax:total+cost;}
                if(total>douyindisc_gifDecodedByteLimit){[NSFileManager.defaultManager removeItemAtURL:newURL error:nil];if(newGIFURL)[NSFileManager.defaultManager removeItemAtURL:newGIFURL error:nil];[self douyindisc_finishImagePickingForIdentifier:key generation:authorizedGeneration];if(completion)completion(douyindisc_error(2,@"GIF动画缓存超过64 MiB安全上限，原图未更改。"));return;}
            }
            NSMutableDictionary *config = [self.douyindisc_config mutableCopy];
            NSMutableDictionary *entry = [config[key] mutableCopy] ?: [NSMutableDictionary dictionary];
            entry[@"image"] = name;
            config[key] = entry;
            __block NSError *commitError = nil;
            BOOL saved = [self douyindisc_commitLatestConfig:config beforeNotify:^{
                self.douyindisc_images[key]=image;
                if(animation)self.douyindisc_animations[key]=animation;else [self.douyindisc_animations removeObjectForKey:key];
            } error:&commitError];
            [self douyindisc_finishImagePickingForIdentifier:key generation:authorizedGeneration];
            if (!saved) { [NSFileManager.defaultManager removeItemAtURL:newURL error:nil];if(newGIFURL)[NSFileManager.defaultManager removeItemAtURL:newGIFURL error:nil]; }
            else if(douyindisc_validImageName(oldName)&&![oldName isEqualToString:name]){
                [NSFileManager.defaultManager removeItemAtURL:[directory URLByAppendingPathComponent:oldName] error:nil];
                NSString *oldGIF=douyindisc_gifNameForImageName(oldName);if(oldGIF)[NSFileManager.defaultManager removeItemAtURL:[directory URLByAppendingPathComponent:oldGIF] error:nil];
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
    BOOL cleared = [self douyindisc_commitLatestConfig:config beforeNotify:^{ [self.douyindisc_images removeObjectForKey:identifier];[self.douyindisc_animations removeObjectForKey:identifier]; } error:error];
    if (!cleared) return NO;
    if (douyindisc_validImageName(oldName)) {
        [NSFileManager.defaultManager removeItemAtURL:[self.douyindisc_storeDirectory URLByAppendingPathComponent:oldName] error:nil];
        NSString *gifName=douyindisc_gifNameForImageName(oldName);if(gifName)[NSFileManager.defaultManager removeItemAtURL:[self.douyindisc_storeDirectory URLByAppendingPathComponent:gifName] error:nil];
    }
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
    if([identifier isEqualToString:@"video_disc"]&&!entry[@"speed"])entry[@"speed"]=@1;
    if(image){entry[@"image"]=@"fixture.png";store.douyindisc_images[identifier]=image;}
    else { [entry removeObjectForKey:@"image"];[store.douyindisc_images removeObjectForKey:identifier];[store.douyindisc_animations removeObjectForKey:identifier]; }
    config[identifier]=entry;
    store.douyindisc_config=[config copy];
    [NSNotificationCenter.defaultCenter postNotificationName:@"com.minis.douyindisc.navigation.changed" object:store];
}

void douyindisc_uiTestSetNavigationScale(NSString *identifier, CGFloat scale) {
    if (!NSThread.isMainThread || !douyindisc_validIdentifier(identifier) || !isfinite(scale)) return;
    DouyinDiscNavigationStore *store=[DouyinDiscNavigationStore douyindisc_sharedStore];
    NSMutableDictionary *config=[store.douyindisc_config mutableCopy] ?: [NSMutableDictionary dictionary];
    NSMutableDictionary *entry=[config[identifier] mutableCopy] ?: [NSMutableDictionary dictionary];
    CGFloat minimum=[identifier isEqualToString:@"video_disc"]?.25:.5,maximum=[identifier isEqualToString:@"video_disc"]?3:1.5;
    if([identifier isEqualToString:@"video_disc"])entry[@"speed"]=@(fmin(maximum,fmax(minimum,scale)));else entry[@"scale"]=@(fmin(maximum,fmax(minimum,scale)));
    config[identifier]=entry;
    store.douyindisc_config=[config copy];
    [NSNotificationCenter.defaultCenter postNotificationName:@"com.minis.douyindisc.navigation.changed" object:store];
}

void douyindisc_uiTestSetDiscSettings(BOOL enabled, CGFloat opacity, CGFloat speed) {
    if(!NSThread.isMainThread||!isfinite(opacity)||!isfinite(speed))return;
    DouyinDiscNavigationStore *store=[DouyinDiscNavigationStore douyindisc_sharedStore];
    NSMutableDictionary *config=[store.douyindisc_config mutableCopy]?:[NSMutableDictionary dictionary];
    NSMutableDictionary *entry=[config[@"video_disc"] mutableCopy]?:[NSMutableDictionary dictionary];
    entry[@"enabled"]=@(enabled);entry[@"opacity"]=@(fmin(1,fmax(0,opacity)));entry[@"speed"]=@(fmin(3,fmax(.25,speed)));
    config[@"video_disc"]=entry;store.douyindisc_config=[config copy];
    [NSNotificationCenter.defaultCenter postNotificationName:@"com.minis.douyindisc.navigation.changed" object:store];
}

void douyindisc_uiTestSetNavigationAnimation(NSString *identifier, NSArray<UIImage *> *frames, NSArray<NSNumber *> *keyTimes, NSTimeInterval duration) {
    if(!NSThread.isMainThread||!douyindisc_validIdentifier(identifier)||frames.count<2||frames.count!=keyTimes.count||!isfinite(duration)||duration<=0)return;
    DouyinDiscGIFAnimation *animation=[DouyinDiscGIFAnimation new];animation.frames=frames.copy;animation.keyTimes=keyTimes.copy;animation.duration=duration;
    DouyinDiscNavigationStore *store=[DouyinDiscNavigationStore douyindisc_sharedStore];store.douyindisc_animations[identifier]=animation;
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
