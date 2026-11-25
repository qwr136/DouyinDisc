#ifndef DOUYINDISC_GIF_CASES_H
#define DOUYINDISC_GIF_CASES_H
#import <ImageIO/ImageIO.h>

static NSData *douyindisc_gifCaseFixture(void) {
    NSMutableData *data=[NSMutableData data];
    CGImageDestinationRef destination=CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data,(__bridge CFStringRef)@"com.compuserve.gif",2,NULL);
    if(!destination)return nil;
    NSDictionary *global=@{(__bridge NSString *)kCGImagePropertyGIFDictionary:@{(__bridge NSString *)kCGImagePropertyGIFLoopCount:@0}};
    CGImageDestinationSetProperties(destination,(__bridge CFDictionaryRef)global);
    NSArray<UIColor *> *colors=@[UIColor.redColor,UIColor.blueColor];NSArray<NSNumber *> *delays=@[@.08,@.17];
    for(NSUInteger i=0;i<colors.count;i++){
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(24,24),NO,1);
        CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(),colors[i].CGColor);CGContextFillRect(UIGraphicsGetCurrentContext(),CGRectMake(0,0,24,24));
        UIImage *image=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();
        NSDictionary *properties=@{(__bridge NSString *)kCGImagePropertyGIFDictionary:@{(__bridge NSString *)kCGImagePropertyGIFUnclampedDelayTime:delays[i]}};
        CGImageDestinationAddImage(destination,image.CGImage,(__bridge CFDictionaryRef)properties);
    }
    BOOL ok=CGImageDestinationFinalize(destination);CFRelease(destination);return ok?data:nil;
}

static void douyindisc_gifCases(UIWindow *window,dispatch_block_t done) {
    DouyinDiscNavigationStore *store=DouyinDiscNavigationStore.douyindisc_sharedStore;NSString *identifier=@"bottom_home";NSError *error=nil;
    if(![store douyindisc_saveEnabled:YES opacity:1 scale:1 identifier:identifier error:&error]){DD_CHECK_NS(NO,@"GIF test enables the bottom navigation item");if(done)done();return;}
    NSData *gif=douyindisc_gifCaseFixture();size_t sourceFrames=0;CGImageSourceRef source=gif?CGImageSourceCreateWithData((__bridge CFDataRef)gif,NULL):NULL;if(source){sourceFrames=CGImageSourceGetCount(source);CFRelease(source);}
    DD_CHECK_NS(sourceFrames==2,@"ImageIO creates a valid two-frame animated GIF fixture");
    [store douyindisc_saveImageData:gif identifier:identifier completion:^(NSError *saveError){
        UIImage *first=[store douyindisc_imageForIdentifier:identifier];DouyinDiscGIFAnimation *animation=[store douyindisc_animationForIdentifier:identifier];
        DD_CHECK_NS(saveError==nil&&first.CGImage!=NULL,@"GIF import stores a static PNG fallback");
        DD_CHECK_NS(animation.frames.count==2&&animation.keyTimes.count==2&&animation.duration>=.24&&animation.duration<=.26&&CGImageGetWidth(animation.frames[0].CGImage)<=96,@"GIF frames, delays and downsample budget are retained");
        NSString *directory=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"DouyinDisc/Navigation"];
        NSDictionary *disk=[NSDictionary dictionaryWithContentsOfFile:[directory stringByAppendingPathComponent:@"settings.plist"]];NSString *pngName=disk[identifier][@"image"];
        NSString *gifName=[[pngName stringByDeletingPathExtension]stringByAppendingPathExtension:@"gif"];NSURL *gifURL=[NSURL fileURLWithPath:[directory stringByAppendingPathComponent:gifName]];
        NSData *sidecar=[NSData dataWithContentsOfURL:gifURL];
        DD_CHECK_NS(sidecar.length==gif.length&&[sidecar isEqualToData:gif],@"original GIF bytes are stored beside the legacy PNG reference");
        DouyinDiscNavigationStore *cold=douyindisc_uiTestCreateStore([NSURL fileURLWithPath:directory isDirectory:YES]);
        [cold douyindisc_preloadImagesWithCompletion:^{
        DouyinDiscGIFAnimation *coldAnimation=[cold douyindisc_animationForIdentifier:identifier];
        DD_CHECK_NS(coldAnimation.frames.count==2&&[cold douyindisc_imageForIdentifier:identifier].CGImage,@"cold launch restores both the PNG fallback and GIF frames");
        AWENormalModeTabBarGeneralButton *button=[[AWENormalModeTabBarGeneralButton alloc]initWithFrame:CGRectMake(0,0,64,49)];
        AWENormalModeTabBarTextView *inner=[[AWENormalModeTabBarTextView alloc]initWithFrame:button.bounds];UILabel *label=[[UILabel alloc]initWithFrame:inner.bounds];label.text=@"首页";inner->_label=label;[inner addSubview:label];button->_innerView=inner;[button addSubview:inner];[window.rootViewController.view addSubview:button];
        douyindisc_apply(inner);DouyinDiscTextLease *lease=[douyindisc_leases objectForKey:label];CAKeyframeAnimation *play=(CAKeyframeAnimation *)[lease.douyindisc_overlay.layer animationForKey:@"com.minis.douyindisc.animated-gif"];
        DD_CHECK_NS(lease.douyindisc_animation==coldAnimation&&play.values.count==2&&play.keyTimes.count==2&&play.calculationMode==kCAAnimationDiscrete,@"visible icon runs true GIF frames with per-frame timing");
        DD_CHECK_NS(!lease.douyindisc_overlay.userInteractionEnabled,@"animated icon layer preserves native button interaction");
        lease.douyindisc_overlay.hidden=YES;douyindisc_gifRefresh();
        DD_CHECK_NS([lease.douyindisc_overlay.layer animationForKey:@"com.minis.douyindisc.animated-gif"]==nil,@"hidden navigation icon stops advancing GIF frames");
        lease.douyindisc_overlay.hidden=NO;douyindisc_gifRefresh();
        DD_CHECK_NS([lease.douyindisc_overlay.layer animationForKey:@"com.minis.douyindisc.animated-gif"]!=nil,@"visible navigation icon resumes its GIF animation");
        NSData *invalid=[@"GIF89a broken" dataUsingEncoding:NSASCIIStringEncoding];NSUInteger ticket=[store douyindisc_beginImagePickingForIdentifier:identifier];
        [store douyindisc_saveImageData:invalid identifier:identifier pickingGeneration:ticket completion:^(NSError *badError){
            DD_CHECK_NS(badError!=nil&&[store douyindisc_imageForIdentifier:identifier]==first,@"malformed GIF keeps previous icon untouched");
            NSData *tooLarge=[NSMutableData dataWithLength:2*1024*1024+1];memcpy((void *)tooLarge.bytes,"GIF89a",6);
            NSUInteger largeTicket=[store douyindisc_beginImagePickingForIdentifier:identifier];
            [store douyindisc_saveImageData:tooLarge identifier:identifier pickingGeneration:largeTicket completion:^(NSError *largeError){
                NSDictionary *after=[NSDictionary dictionaryWithContentsOfFile:[directory stringByAppendingPathComponent:@"settings.plist"]];
                DD_CHECK_NS(largeError!=nil&&[after[identifier][@"image"] isEqual:pngName]&&[store douyindisc_imageForIdentifier:identifier]==first,@"over-limit GIF does not replace the prior PNG icon");
                BOOL cleared=[store douyindisc_clearImageForIdentifier:identifier error:nil];
                [store douyindisc_saveEnabled:NO opacity:1 scale:1 identifier:identifier error:nil];douyindisc_apply(inner);[button removeFromSuperview];
                DD_CHECK_NS(cleared&&![NSFileManager.defaultManager fileExistsAtPath:gifURL.path]&&[store douyindisc_animationForIdentifier:identifier]==nil,@"clearing the icon deletes its paired GIF and frees decoded frames");
                DouyinDiscNavigationStore *cold=nil;(void)cold;
                if(done)done();
            }];
        }];
        }];
    }];
}
#endif
