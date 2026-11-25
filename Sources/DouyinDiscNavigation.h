#ifndef DOUYINDISC_NAVIGATION_H
#define DOUYINDISC_NAVIGATION_H
#import <UIKit/UIKit.h>

NSArray<NSDictionary<NSString *, id> *> *douyindisc_navigationItems(void);
void douyindisc_installNavigationHooks(void);

@interface DouyinDiscGIFAnimation : NSObject
@property(nonatomic,copy,readonly) NSArray<UIImage *> *frames;
@property(nonatomic,copy,readonly) NSArray<NSNumber *> *keyTimes;
@property(nonatomic,readonly) NSTimeInterval duration;
@end

@interface DouyinDiscNavigationStore : NSObject
+ (instancetype)douyindisc_sharedStore;
- (void)douyindisc_preloadImagesWithCompletion:(void (^)(void))completion;
- (void)douyindisc_previewOpacity:(CGFloat)opacity identifier:(NSString *)identifier;
- (void)douyindisc_clearOpacityPreviewForIdentifier:(NSString *)identifier;
- (void)douyindisc_previewScale:(CGFloat)scale identifier:(NSString *)identifier;
- (void)douyindisc_clearScalePreviewForIdentifier:(NSString *)identifier;
- (NSDictionary<NSString *, id> *)douyindisc_entryForIdentifier:(NSString *)identifier;
- (UIImage *)douyindisc_imageForIdentifier:(NSString *)identifier;
- (DouyinDiscGIFAnimation *)douyindisc_animationForIdentifier:(NSString *)identifier;
- (UIImage *)douyindisc_decodeImageData:(NSData *)data;
- (BOOL)douyindisc_isAnimatedGIFData:(NSData *)data;
- (BOOL)douyindisc_imagePickingEnabledForIdentifier:(NSString *)identifier;
- (NSUInteger)douyindisc_beginImagePickingForIdentifier:(NSString *)identifier;
- (void)douyindisc_finishImagePickingForIdentifier:(NSString *)identifier generation:(NSUInteger)generation;
- (void)douyindisc_cancelImagePickingForIdentifier:(NSString *)identifier;
- (void)douyindisc_saveImageData:(NSData *)data identifier:(NSString *)identifier pickingGeneration:(NSUInteger)pickingGeneration completion:(void (^)(NSError *error))completion;
- (BOOL)douyindisc_saveEnabled:(BOOL)enabled opacity:(CGFloat)opacity scale:(CGFloat)scale identifier:(NSString *)identifier error:(NSError **)error;
- (void)douyindisc_saveImageData:(NSData *)data identifier:(NSString *)identifier completion:(void (^)(NSError *error))completion;
- (BOOL)douyindisc_clearImageForIdentifier:(NSString *)identifier error:(NSError **)error;
@end

@interface DouyinDiscSettingsViewController : UIViewController
@end

#endif
