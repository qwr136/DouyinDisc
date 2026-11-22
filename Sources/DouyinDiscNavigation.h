#ifndef DOUYINDISC_NAVIGATION_H
#define DOUYINDISC_NAVIGATION_H
#import <UIKit/UIKit.h>

NSArray<NSDictionary<NSString *, id> *> *douyindisc_navigationItems(void);
void douyindisc_installNavigationHooks(void);

@interface DouyinDiscNavigationStore : NSObject
+ (instancetype)douyindisc_sharedStore;
- (void)douyindisc_preloadImagesWithCompletion:(void (^)(void))completion;
- (void)douyindisc_previewOpacity:(CGFloat)opacity identifier:(NSString *)identifier;
- (void)douyindisc_clearOpacityPreviewForIdentifier:(NSString *)identifier;
- (NSDictionary<NSString *, id> *)douyindisc_entryForIdentifier:(NSString *)identifier;
- (UIImage *)douyindisc_imageForIdentifier:(NSString *)identifier;
- (UIImage *)douyindisc_decodeImageData:(NSData *)data;
- (BOOL)douyindisc_saveEnabled:(BOOL)enabled opacity:(CGFloat)opacity identifier:(NSString *)identifier error:(NSError **)error;
- (void)douyindisc_saveImageData:(NSData *)data identifier:(NSString *)identifier completion:(void (^)(NSError *error))completion;
- (BOOL)douyindisc_clearImageForIdentifier:(NSString *)identifier error:(NSError **)error;
@end

@interface DouyinDiscSettingsViewController : UIViewController
@end

#endif
