#ifndef DOUYINDISC_GIF_CASES_H
#define DOUYINDISC_GIF_CASES_H
#import <ImageIO/ImageIO.h>

static NSData *douyindisc_gifCaseFixture(void) {
    NSMutableData *data=[NSMutableData data];
    NSUInteger frameCount=130;
    CGImageDestinationRef destination=CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data,(__bridge CFStringRef)@"com.compuserve.gif",frameCount,NULL);
    if(!destination)return nil;
    NSDictionary *global=@{(__bridge NSString *)kCGImagePropertyGIFDictionary:@{(__bridge NSString *)kCGImagePropertyGIFLoopCount:@0}};
    CGImageDestinationSetProperties(destination,(__bridge CFDictionaryRef)global);
    NSArray<UIColor *> *colors=@[UIColor.redColor,UIColor.blueColor];NSArray<NSNumber *> *delays=@[@.04,@.04];
    for(NSUInteger i=0;i<frameCount;i++){
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(24,24),NO,1);
        CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(),colors[i%colors.count].CGColor);CGContextFillRect(UIGraphicsGetCurrentContext(),CGRectMake(0,0,24,24));
        UIImage *image=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();
        NSDictionary *properties=@{(__bridge NSString *)kCGImagePropertyGIFDictionary:@{(__bridge NSString *)kCGImagePropertyGIFUnclampedDelayTime:delays[i%delays.count]}};
        CGImageDestinationAddImage(destination,image.CGImage,(__bridge CFDictionaryRef)properties);
    }
    BOOL ok=CGImageDestinationFinalize(destination);CFRelease(destination);if(!ok||data.length<2)return nil;
    // Add valid GIF comment sub-blocks, so the fixture reproduces the old >8 MiB rejection.
    uint8_t trailer=((const uint8_t *)data.bytes)[data.length-1];[data setLength:data.length-1];uint8_t extension[2]={0x21,0xfe};[data appendBytes:extension length:2];
    NSUInteger target=8*1024*1024+4096;
    while(data.length+1<target){NSUInteger count=MIN((NSUInteger)255,target-data.length-1);uint8_t block=(uint8_t)count;[data appendBytes:&block length:1];NSMutableData *payload=[NSMutableData dataWithLength:count];[data appendData:payload];}
    uint8_t end=0;[data appendBytes:&end length:1];[data appendBytes:&trailer length:1];return data;
}
static NSData *douyindisc_gifCasePixel(CGImageRef image) {
    if(!image)return nil;NSMutableData *data=[NSMutableData dataWithLength:24*24*4];CGColorSpaceRef color=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(data.mutableBytes,24,24,8,24*4,color,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);CGColorSpaceRelease(color);if(!context)return nil;
    CGContextDrawImage(context,CGRectMake(0,0,24,24),image);CGContextRelease(context);const uint8_t *bytes=data.bytes;
    return [NSData dataWithBytes:bytes+(12*24+12)*4 length:3];
}
static void douyindisc_gifStoreAndPlaybackCases(UIWindow *window,dispatch_block_t done) {
    DouyinDiscNavigationStore *store=DouyinDiscNavigationStore.douyindisc_sharedStore;NSString *identifier=@"bottom_home";NSError *error=nil;
    if(![store douyindisc_saveEnabled:YES opacity:1 scale:1 identifier:identifier error:&error]){DD_CHECK_NS(NO,@"GIF test enables the bottom navigation item");if(done)done();return;}
    NSData *gif=douyindisc_gifCaseFixture();size_t sourceFrames=0;CGImageSourceRef source=gif?CGImageSourceCreateWithData((__bridge CFDataRef)gif,NULL):NULL;if(source){sourceFrames=CGImageSourceGetCount(source);CFRelease(source);}
    DD_CHECK_NS(sourceFrames==130&&gif.length>8*1024*1024&&gif.length<64*1024*1024,@"fixture is a valid 130-frame GIF larger than the former 8 MiB file cap");
    [store douyindisc_saveImageData:gif identifier:identifier completion:^(NSError *saveError){
        UIImage *first=[store douyindisc_imageForIdentifier:identifier];DouyinDiscGIFAnimation *animation=[store douyindisc_animationForIdentifier:identifier];
        DD_CHECK_NS(saveError==nil&&first.CGImage!=NULL,@"GIF import stores a static PNG fallback");
        DD_CHECK_NS(animation.frames.count==130&&animation.keyTimes.count==130&&animation.duration>=5.0&&animation.duration<=5.5&&CGImageGetWidth(animation.frames[0].CGImage)<=96,@"130 GIF frames survive decoding within the bounded memory and frame-size safeguards");
        NSString *directory=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"DouyinDisc/Navigation"];
        NSDictionary *disk=[NSDictionary dictionaryWithContentsOfFile:[directory stringByAppendingPathComponent:@"settings.plist"]];NSString *pngName=disk[identifier][@"image"];
        NSString *gifName=[[pngName stringByDeletingPathExtension]stringByAppendingPathExtension:@"gif"];NSURL *gifURL=[NSURL fileURLWithPath:[directory stringByAppendingPathComponent:gifName]];
        NSData *sidecar=[NSData dataWithContentsOfURL:gifURL];DD_CHECK_NS(sidecar.length==gif.length&&[sidecar isEqualToData:gif],@"original GIF bytes are stored beside the legacy PNG reference");
        DouyinDiscNavigationStore *cold=douyindisc_uiTestCreateStore([NSURL fileURLWithPath:directory isDirectory:YES]);
        [cold douyindisc_preloadImagesWithCompletion:^{
            DouyinDiscGIFAnimation *coldAnimation=[cold douyindisc_animationForIdentifier:identifier];
            NSData *decodedFirst=UIImagePNGRepresentation(coldAnimation.frames.firstObject),*decodedSecond=UIImagePNGRepresentation(coldAnimation.frames.lastObject);
            DD_CHECK_NS(coldAnimation.frames.count==130&&decodedFirst.length&&decodedSecond.length&&![decodedFirst isEqualToData:decodedSecond]&&[cold douyindisc_imageForIdentifier:identifier].CGImage,@"cold launch restores all 130 GIF frames and the PNG fallback");
            AWENormalModeTabBarGeneralButton *button=[[AWENormalModeTabBarGeneralButton alloc]initWithFrame:CGRectMake(0,0,64,49)];
            AWENormalModeTabBarTextView *inner=[[AWENormalModeTabBarTextView alloc]initWithFrame:button.bounds];UILabel *label=[[UILabel alloc]initWithFrame:inner.bounds];label.text=@"首页";inner->_label=label;[inner addSubview:label];button->_innerView=inner;[button addSubview:inner];[window.rootViewController.view addSubview:button];
            douyindisc_apply(inner);DouyinDiscTextLease *lease=[douyindisc_leases objectForKey:label];CAKeyframeAnimation *play=(CAKeyframeAnimation *)[lease.douyindisc_overlay.layer animationForKey:@"com.minis.douyindisc.animated-gif"];
            DD_CHECK_NS(lease!=nil,@"GIF fixture resolves to a native navigation icon lease");DD_CHECK_NS(lease.douyindisc_animation.frames.count==coldAnimation.frames.count&&fabs(lease.douyindisc_animation.duration-coldAnimation.duration)<.001,@"GIF lease owns the restored cold-load animation");DD_CHECK_NS(play!=nil,@"visible GIF layer has a Core Animation playback entry");DD_CHECK_NS(play.values.count==coldAnimation.frames.count&&play.keyTimes.count==coldAnimation.frames.count+1&&[play.keyTimes.firstObject doubleValue]==0.0&&[play.keyTimes.lastObject doubleValue]==1.0,@"GIF timeline holds the final frame explicitly");DD_CHECK_NS(play.calculationMode==kCAAnimationDiscrete&&lease.douyindisc_animationVisible,@"visible icon schedules discrete GIF frame playback");DD_CHECK_NS(!lease.douyindisc_overlay.userInteractionEnabled,@"animated overlay preserves native navigation taps");
            lease.douyindisc_overlay.hidden=YES;douyindisc_gifRefresh();DD_CHECK_NS(![lease.douyindisc_overlay.layer animationForKey:@"com.minis.douyindisc.animated-gif"],@"hidden icon stops GIF playback");lease.douyindisc_overlay.hidden=NO;douyindisc_gifRefresh();
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.14*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                CALayer *presentation=(CALayer *)lease.douyindisc_overlay.layer.presentationLayer;NSData *presentedPixel=douyindisc_gifCasePixel((__bridge CGImageRef)presentation.contents);NSData *firstPixel=douyindisc_gifCasePixel(coldAnimation.frames.firstObject.CGImage);BOOL matchedNonInitialFrame=NO;
                for(NSUInteger i=1;i<coldAnimation.frames.count;i++){NSData *framePixel=douyindisc_gifCasePixel(coldAnimation.frames[i].CGImage);if([presentedPixel isEqualToData:framePixel]){matchedNonInitialFrame=YES;break;}}
                DD_CHECK_NS(presentedPixel.length==3&&firstPixel.length==3&&matchedNonInitialFrame&&! [presentedPixel isEqualToData:firstPixel],@"rendered presentation advances beyond the first GIF frame");
                NSData *invalid=[@"GIF89a broken" dataUsingEncoding:NSASCIIStringEncoding];NSUInteger ticket=[store douyindisc_beginImagePickingForIdentifier:identifier];
                [store douyindisc_saveImageData:invalid identifier:identifier pickingGeneration:ticket completion:^(NSError *badError){
                    DD_CHECK_NS(badError!=nil&&[store douyindisc_imageForIdentifier:identifier]==first,@"malformed GIF keeps previous icon untouched");
                [store douyindisc_clearImageForIdentifier:identifier error:nil];
                BOOL clearedReference=![[store douyindisc_entryForIdentifier:identifier][@"hasImage"] boolValue];
                BOOL clearedAnimation=[store douyindisc_animationForIdentifier:identifier]==nil;
                BOOL removedSidecar=![NSFileManager.defaultManager fileExistsAtPath:gifURL.path];
                [store douyindisc_saveEnabled:NO opacity:1 scale:1 identifier:identifier error:nil];douyindisc_apply(inner);[button removeFromSuperview];
                DD_CHECK_NS(clearedReference,@"clearing GIF icon clears the stored image reference");
                DD_CHECK_NS(clearedAnimation,@"clearing GIF icon releases decoded frames");
                DD_CHECK_NS(removedSidecar,@"clearing GIF icon removes its paired resource");
                if(done)done();
                }];
            });
        }];
    }];
}
extern void douyindisc_uiTestCommitImageAndCheckPanelPreview(NSData *,NSString *,void(^)(BOOL));
static void douyindisc_gifCases(UIWindow *window,dispatch_block_t done) {
    NSData *fixture=douyindisc_gifCaseFixture();
    douyindisc_uiTestCommitImageAndCheckPanelPreview(fixture,@"top_recommend",^(BOOL refreshed){
        DD_CHECK_NS(refreshed,@"after GIF save the existing settings row immediately shows the thumbnail, change title and clear action");
        douyindisc_gifStoreAndPlaybackCases(window,done);
    });
}
#endif
