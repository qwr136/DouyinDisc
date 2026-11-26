#import "DouyinDiscNavigation.h"
#import <objc/runtime.h>
#import <math.h>
#import <ImageIO/ImageIO.h>
#import <Photos/Photos.h>
#if defined(DOUYINDISC_UI_TEST)
#import <dlfcn.h>
#endif
static BOOL douyindisc_navigationIsGIFUTI(NSString *uti) {
    return [uti isEqualToString:@"com.compuserve.gif"]||[uti isEqualToString:@"public.gif"];
}
static BOOL douyindisc_navigationDataHasGIFSignature(NSData *data) {
    if(data.length<6)return NO;const uint8_t *bytes=data.bytes;
    return !memcmp(bytes,"GIF87a",6)||!memcmp(bytes,"GIF89a",6);
}
static NSData *douyindisc_readSelectedPhotoURL(NSURL *url,BOOL declaredGIF,NSError **error) {
    if(!url.isFileURL){if(error)*error=[NSError errorWithDomain:@"com.minis.douyindisc.navigation" code:2 userInfo:@{NSLocalizedDescriptionKey:@"照片库返回了无效的图片地址。"}];return nil;}
    (void)declaredGIF;
    NSFileHandle *handle=[NSFileHandle fileHandleForReadingFromURL:url error:error];if(!handle)return nil;
    NSMutableData *data=[NSMutableData data];
    @try{
        NSData *prefix=[handle readDataOfLength:6];[data appendData:prefix];
        NSUInteger limit=64*1024*1024;
        NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:url.path error:error];NSNumber *size=attributes[NSFileSize];
        if(!size||size.unsignedLongLongValue>limit){if(error&&!*error)*error=[NSError errorWithDomain:@"com.minis.douyindisc.navigation" code:2 userInfo:@{NSLocalizedDescriptionKey:@"GIF或图片文件超过64 MiB安全上限。"}];[handle closeFile];return nil;}
        while(data.length<size.unsignedIntegerValue){NSUInteger remaining=size.unsignedIntegerValue-data.length;NSData *chunk=[handle readDataOfLength:MIN(256*1024,remaining)];if(!chunk.length)break;[data appendData:chunk];}
        [handle closeFile];if(data.length!=size.unsignedIntegerValue){if(error&&!*error)*error=[NSError errorWithDomain:@"com.minis.douyindisc.navigation" code:2 userInfo:@{NSLocalizedDescriptionKey:@"图片读取不完整。"}];return nil;}
    }@catch(NSException *exception){(void)exception;@try{[handle closeFile];}@catch(NSException *ignored){(void)ignored;}if(error&&!*error)*error=[NSError errorWithDomain:@"com.minis.douyindisc.navigation" code:2 userInfo:@{NSLocalizedDescriptionKey:@"照片读取失败。"}];return nil;}
    return data;
}
static UIColor *douyindisc_color(NSString *hex) {
    unsigned value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:[hex stringByReplacingOccurrencesOfString:@"#" withString:@""]];
    if (![scanner scanHexInt:&value]) return UIColor.systemBlueColor;
    return [UIColor colorWithRed:((value >> 16) & 255)/255.0 green:((value >> 8) & 255)/255.0 blue:(value & 255)/255.0 alpha:1];
}

@interface DouyinDiscNavigationRow : UIView
@property (nonatomic, copy) NSString *douyindisc_identifier;
@property (nonatomic, strong) UISwitch *douyindisc_switch;
@property (nonatomic, strong) UITextField *douyindisc_value;
@property (nonatomic, strong) UIButton *douyindisc_opacityMinus;
@property (nonatomic, strong) UIButton *douyindisc_opacityPlus;
@property (nonatomic) CGFloat douyindisc_opacity;
@property (nonatomic, strong) UILabel *douyindisc_opacityTitle;
@property (nonatomic, strong) UITextField *douyindisc_sizeValue;
@property (nonatomic, strong) UIButton *douyindisc_sizeMinus;
@property (nonatomic, strong) UIButton *douyindisc_sizePlus;
@property (nonatomic) CGFloat douyindisc_scale;
@property (nonatomic, strong) UILabel *douyindisc_sizeTitle;
@property (nonatomic, strong) UIImageView *douyindisc_thumbnail;
@property (nonatomic, strong) UIButton *douyindisc_imageButton;
@property (nonatomic, strong) UIButton *douyindisc_clearButton;
@property (nonatomic, strong) UIStackView *douyindisc_actions;
@property(nonatomic) CGFloat douyindisc_angle;
@property(nonatomic) CGFloat douyindisc_cornerRadius;
@property(nonatomic) CGFloat douyindisc_rotationSpeed;
@property(nonatomic) BOOL douyindisc_rotationEnabled;
@property(nonatomic,strong) UILabel *douyindisc_angleTitle,*douyindisc_angleValue,*douyindisc_cornerTitle,*douyindisc_cornerValue,*douyindisc_rotationTitle,*douyindisc_rotationSpeedValue;
@property(nonatomic,strong) UIButton *douyindisc_angleMinus,*douyindisc_anglePlus,*douyindisc_cornerMinus,*douyindisc_cornerPlus,*douyindisc_rotationSpeedMinus,*douyindisc_rotationSpeedPlus;
@property(nonatomic,strong) UISwitch *douyindisc_rotationSwitch;
@property (nonatomic, copy) void (^douyindisc_change)(DouyinDiscNavigationRow *, BOOL, CGFloat);
@property (nonatomic, copy) void (^douyindisc_preview)(DouyinDiscNavigationRow *, CGFloat);
@property (nonatomic, copy) void (^douyindisc_changeScale)(DouyinDiscNavigationRow *, CGFloat);
@property (nonatomic, copy) void (^douyindisc_previewScale)(DouyinDiscNavigationRow *, CGFloat);
@property (nonatomic, copy) void (^douyindisc_pickPhoto)(DouyinDiscNavigationRow *);
@property (nonatomic, copy) void (^douyindisc_clear)(DouyinDiscNavigationRow *);
@property(nonatomic,copy) void (^douyindisc_changeAppearance)(DouyinDiscNavigationRow *);
- (void)douyindisc_changeAngle:(NSInteger)delta;
- (void)douyindisc_changeCorner:(NSInteger)delta;
- (void)douyindisc_changeRotationSpeed:(NSInteger)delta;
- (void)douyindisc_rotationSwitchChanged;
- (void)douyindisc_changeAngleMinus;
- (void)douyindisc_changeAnglePlus;
- (void)douyindisc_changeCornerMinus;
- (void)douyindisc_changeCornerPlus;
- (void)douyindisc_changeRotationSpeedMinus;
- (void)douyindisc_changeRotationSpeedPlus;
- (void)douyindisc_changeOpacityByMinus;
- (void)douyindisc_changeOpacityByPlus;
- (void)douyindisc_changeSizeByMinus;
- (void)douyindisc_changeSizeByPlus;
- (void)douyindisc_editingOpacityInput;
- (void)douyindisc_editingSizeInput;
- (void)douyindisc_commitOpacityInput;
- (void)douyindisc_commitSizeInput;
- (void)douyindisc_inputAccessoryDone;
- (void)douyindisc_adjustOpacity:(NSInteger)delta;
- (void)douyindisc_adjustSize:(NSInteger)delta;
- (void)douyindisc_switchChanged;
- (void)douyindisc_photoTapped;
- (void)douyindisc_clearTapped;
- (void)douyindisc_setHasImage:(BOOL)hasImage;
- (void)douyindisc_setImagePickingEnabled:(BOOL)enabled;
- (void)douyindisc_setEnabledAfterCommit:(BOOL)enabled;
@end

@implementation DouyinDiscNavigationRow
- (instancetype)initWithItem:(NSDictionary *)item entry:(NSDictionary *)entry image:(UIImage *)image {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.layer.cornerRadius = 16;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.masksToBounds = YES;self.layer.borderWidth=.5;self.layer.borderColor=UIColor.separatorColor.CGColor;
    self.douyindisc_identifier = item[@"identifier"];

    UIView *content = [UIView new]; content.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:content];
    UIView *swatch = [UIView new]; swatch.translatesAutoresizingMaskIntoConstraints = NO;
    swatch.backgroundColor = douyindisc_color(item[@"accentColor"]); swatch.layer.cornerRadius = 7;
    UIImageView *symbol = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:item[@"sfIcon"]]];
    symbol.translatesAutoresizingMaskIntoConstraints = NO; symbol.tintColor = UIColor.whiteColor; symbol.contentMode = UIViewContentModeScaleAspectFit;
    [swatch addSubview:symbol]; [content addSubview:swatch];
    UILabel *title = [UILabel new]; title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = item[@"title"]; title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [content addSubview:title];
    self.douyindisc_switch = [UISwitch new]; self.douyindisc_switch.translatesAutoresizingMaskIntoConstraints = NO;
    self.douyindisc_switch.onTintColor = douyindisc_color(item[@"accentColor"]);
    self.douyindisc_switch.on=[entry[@"enabled"] boolValue];
    [self.douyindisc_switch addTarget:self action:@selector(douyindisc_switchChanged) forControlEvents:UIControlEventValueChanged];
    [content addSubview:self.douyindisc_switch];

    self.douyindisc_imageButton=[UIButton buttonWithType:UIButtonTypeSystem]; self.douyindisc_imageButton.translatesAutoresizingMaskIntoConstraints=NO;
    [self.douyindisc_imageButton setTitle:@"照片" forState:UIControlStateNormal];
    self.douyindisc_imageButton.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [self.douyindisc_imageButton setImage:[UIImage systemImageNamed:@"photo"] forState:UIControlStateNormal];
    self.douyindisc_imageButton.tintColor=douyindisc_color(@"#1557C0");
    self.douyindisc_imageButton.accessibilityLabel=@"选择图标";
    self.douyindisc_imageButton.accessibilityIdentifier=[@"douyindisc.pick." stringByAppendingString:self.douyindisc_identifier];
    self.douyindisc_imageButton.enabled=[entry[@"enabled"] boolValue];
    self.douyindisc_imageButton.titleLabel.lineBreakMode=NSLineBreakByTruncatingTail;
    self.douyindisc_imageButton.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
    self.douyindisc_imageButton.imageView.contentMode=UIViewContentModeScaleAspectFit;
    self.douyindisc_imageButton.titleEdgeInsets=UIEdgeInsetsMake(0,6,0,0);
    self.douyindisc_imageButton.contentVerticalAlignment=UIControlContentVerticalAlignmentCenter;
    [self.douyindisc_imageButton addTarget:self action:@selector(douyindisc_photoTapped) forControlEvents:UIControlEventTouchUpInside];
    self.douyindisc_clearButton=[UIButton buttonWithType:UIButtonTypeSystem]; self.douyindisc_clearButton.translatesAutoresizingMaskIntoConstraints=NO;
    [self.douyindisc_clearButton setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal];
    self.douyindisc_clearButton.accessibilityLabel=@"移除此项自定义图标"; self.douyindisc_clearButton.enabled=image!=nil;
    [self.douyindisc_clearButton addTarget:self action:@selector(douyindisc_clearTapped) forControlEvents:UIControlEventTouchUpInside];
    self.douyindisc_actions=[[UIStackView alloc] initWithArrangedSubviews:@[self.douyindisc_imageButton,self.douyindisc_clearButton]];
    self.douyindisc_actions.translatesAutoresizingMaskIntoConstraints=NO; self.douyindisc_actions.axis=UILayoutConstraintAxisHorizontal; self.douyindisc_actions.spacing=4;
    [content addSubview:self.douyindisc_actions];
    self.douyindisc_thumbnail=[UIImageView new]; self.douyindisc_thumbnail.translatesAutoresizingMaskIntoConstraints=NO;
    self.douyindisc_thumbnail.backgroundColor=UIColor.tertiarySystemFillColor; self.douyindisc_thumbnail.layer.cornerRadius=6;
    self.douyindisc_thumbnail.clipsToBounds=YES; self.douyindisc_thumbnail.contentMode=UIViewContentModeScaleAspectFit;
    self.douyindisc_thumbnail.image=image; [content addSubview:self.douyindisc_thumbnail];
    self.douyindisc_thumbnail.accessibilityIdentifier=[@"douyindisc.preview." stringByAppendingString:self.douyindisc_identifier];
    self.douyindisc_opacityTitle=[UILabel new];self.douyindisc_opacityTitle.translatesAutoresizingMaskIntoConstraints=NO;
    self.douyindisc_opacityTitle.text=@"透明度";self.douyindisc_opacityTitle.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];self.douyindisc_opacityTitle.textColor=UIColor.secondaryLabelColor;self.douyindisc_opacityTitle.accessibilityIdentifier=@"douyindisc.opacity.title";[content addSubview:self.douyindisc_opacityTitle];
    self.douyindisc_opacity=MAX(0,MIN(1,[entry[@"opacity"] doubleValue]));
    self.douyindisc_value=[UITextField new];self.douyindisc_value.translatesAutoresizingMaskIntoConstraints=NO;self.douyindisc_value.textAlignment=NSTextAlignmentCenter;self.douyindisc_value.font=[UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightSemibold];self.douyindisc_value.textColor=UIColor.labelColor;
    self.douyindisc_value.keyboardType=UIKeyboardTypeNumberPad;self.douyindisc_value.accessibilityIdentifier=@"douyindisc.opacity.value";self.douyindisc_value.accessibilityLabel=@"透明度百分比";self.douyindisc_value.backgroundColor=UIColor.tertiarySystemGroupedBackgroundColor;self.douyindisc_value.layer.cornerRadius=8;self.douyindisc_value.layer.masksToBounds=YES;self.douyindisc_value.text=[NSString stringWithFormat:@"%d%%",(int)lrint(self.douyindisc_opacity*100)];
    [self.douyindisc_value addTarget:self action:@selector(douyindisc_editingOpacityInput) forControlEvents:UIControlEventEditingDidBegin];[self.douyindisc_value addTarget:self action:@selector(douyindisc_commitOpacityInput) forControlEvents:UIControlEventEditingDidEnd];[content addSubview:self.douyindisc_value];
    self.douyindisc_opacityMinus=[UIButton buttonWithType:UIButtonTypeSystem];self.douyindisc_opacityMinus.translatesAutoresizingMaskIntoConstraints=NO;[self.douyindisc_opacityMinus setTitle:@"−" forState:UIControlStateNormal];self.douyindisc_opacityMinus.accessibilityLabel=@"降低透明度";
    self.douyindisc_opacityPlus=[UIButton buttonWithType:UIButtonTypeSystem];self.douyindisc_opacityPlus.translatesAutoresizingMaskIntoConstraints=NO;[self.douyindisc_opacityPlus setTitle:@"＋" forState:UIControlStateNormal];self.douyindisc_opacityPlus.accessibilityLabel=@"提高透明度";
    for(UIButton *button in @[self.douyindisc_opacityMinus,self.douyindisc_opacityPlus]){button.titleLabel.font=[UIFont systemFontOfSize:19 weight:UIFontWeightMedium];button.tintColor=douyindisc_color(item[@"accentColor"]);button.backgroundColor=UIColor.tertiarySystemGroupedBackgroundColor;button.layer.cornerRadius=8;[content addSubview:button];}
    [self.douyindisc_opacityMinus addTarget:self action:@selector(douyindisc_changeOpacityByMinus) forControlEvents:UIControlEventTouchUpInside];[self.douyindisc_opacityPlus addTarget:self action:@selector(douyindisc_changeOpacityByPlus) forControlEvents:UIControlEventTouchUpInside];
    UIToolbar *opacityToolbar=[[UIToolbar alloc]initWithFrame:CGRectMake(0,0,0,44)];UIBarButtonItem *opacitySpace=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];UIBarButtonItem *opacityDone=[[UIBarButtonItem alloc]initWithTitle:@"完成" style:UIBarButtonItemStyleDone target:self action:@selector(douyindisc_inputAccessoryDone)];opacityToolbar.items=@[opacitySpace,opacityDone];self.douyindisc_value.inputAccessoryView=opacityToolbar;
    self.douyindisc_sizeTitle=[UILabel new];self.douyindisc_sizeTitle.translatesAutoresizingMaskIntoConstraints=NO;self.douyindisc_sizeTitle.text=item[@"adjustmentTitle"]?:@"图标大小";self.douyindisc_sizeTitle.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];self.douyindisc_sizeTitle.textColor=UIColor.secondaryLabelColor;self.douyindisc_sizeTitle.accessibilityIdentifier=[self.douyindisc_identifier isEqualToString:@"video_disc"]?@"douyindisc.speed.title":@"douyindisc.size.title";[content addSubview:self.douyindisc_sizeTitle];
    BOOL speedMode=[self.douyindisc_identifier isEqualToString:@"video_disc"];
    CGFloat adjustmentMinimum=speedMode?.25:.5,adjustmentMaximum=speedMode?3:1.5;
    NSNumber *adjustment=entry[speedMode?@"speed":@"scale"]?:@1;
    self.douyindisc_scale=MAX(adjustmentMinimum,MIN(adjustmentMaximum,adjustment.doubleValue));
    self.douyindisc_sizeValue=[UITextField new];self.douyindisc_sizeValue.translatesAutoresizingMaskIntoConstraints=NO;self.douyindisc_sizeValue.textAlignment=NSTextAlignmentCenter;self.douyindisc_sizeValue.font=[UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightSemibold];self.douyindisc_sizeValue.textColor=UIColor.labelColor;
    self.douyindisc_sizeValue.keyboardType=UIKeyboardTypeNumberPad;self.douyindisc_sizeValue.accessibilityIdentifier=speedMode?@"douyindisc.speed.value":@"douyindisc.size.value";self.douyindisc_sizeValue.accessibilityLabel=speedMode?@"唱片转速百分比":@"图标大小百分比";self.douyindisc_sizeValue.backgroundColor=UIColor.tertiarySystemGroupedBackgroundColor;self.douyindisc_sizeValue.layer.cornerRadius=8;self.douyindisc_sizeValue.layer.masksToBounds=YES;self.douyindisc_sizeValue.text=[NSString stringWithFormat:@"%d%%",(int)lrint(self.douyindisc_scale*100)];
    [self.douyindisc_sizeValue addTarget:self action:@selector(douyindisc_editingSizeInput) forControlEvents:UIControlEventEditingDidBegin];[self.douyindisc_sizeValue addTarget:self action:@selector(douyindisc_commitSizeInput) forControlEvents:UIControlEventEditingDidEnd];[content addSubview:self.douyindisc_sizeValue];
    self.douyindisc_sizeMinus=[UIButton buttonWithType:UIButtonTypeSystem];self.douyindisc_sizeMinus.translatesAutoresizingMaskIntoConstraints=NO;[self.douyindisc_sizeMinus setTitle:@"−" forState:UIControlStateNormal];self.douyindisc_sizeMinus.accessibilityLabel=speedMode?@"降低唱片转速":@"缩小图标";
    self.douyindisc_sizePlus=[UIButton buttonWithType:UIButtonTypeSystem];self.douyindisc_sizePlus.translatesAutoresizingMaskIntoConstraints=NO;[self.douyindisc_sizePlus setTitle:@"＋" forState:UIControlStateNormal];self.douyindisc_sizePlus.accessibilityLabel=speedMode?@"提高唱片转速":@"放大图标";
    for(UIButton *button in @[self.douyindisc_sizeMinus,self.douyindisc_sizePlus]){button.titleLabel.font=[UIFont systemFontOfSize:19 weight:UIFontWeightMedium];button.tintColor=douyindisc_color(item[@"accentColor"]);button.backgroundColor=UIColor.tertiarySystemGroupedBackgroundColor;button.layer.cornerRadius=8;[content addSubview:button];}
    [self.douyindisc_sizeMinus addTarget:self action:@selector(douyindisc_changeSizeByMinus) forControlEvents:UIControlEventTouchUpInside];[self.douyindisc_sizePlus addTarget:self action:@selector(douyindisc_changeSizeByPlus) forControlEvents:UIControlEventTouchUpInside];
    UIToolbar *sizeToolbar=[[UIToolbar alloc]initWithFrame:CGRectMake(0,0,0,44)];UIBarButtonItem *sizeSpace=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];UIBarButtonItem *sizeDone=[[UIBarButtonItem alloc]initWithTitle:@"完成" style:UIBarButtonItemStyleDone target:self action:@selector(douyindisc_inputAccessoryDone)];sizeToolbar.items=@[sizeSpace,sizeDone];self.douyindisc_sizeValue.inputAccessoryView=sizeToolbar;
    BOOL navigationIcon=![self.douyindisc_identifier isEqualToString:@"video_disc"];
    if(navigationIcon){
        self.douyindisc_angle=[entry[@"angle"] respondsToSelector:@selector(doubleValue)]?fmod(MAX(0,[entry[@"angle"] doubleValue]),360):0;
        self.douyindisc_cornerRadius=MAX(0,MIN(50,[entry[@"cornerRadius"] doubleValue]));
        self.douyindisc_rotationEnabled=[entry[@"rotationEnabled"] boolValue];
        self.douyindisc_rotationSpeed=MAX(.1,MIN(10,[entry[@"rotationSpeed"] respondsToSelector:@selector(doubleValue)]?[entry[@"rotationSpeed"] doubleValue]:1));
        self.douyindisc_angleTitle=[UILabel new];self.douyindisc_angleTitle.translatesAutoresizingMaskIntoConstraints=NO;self.douyindisc_angleTitle.text=@"静态角度";self.douyindisc_angleTitle.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];self.douyindisc_angleTitle.textColor=UIColor.secondaryLabelColor;self.douyindisc_angleTitle.accessibilityIdentifier=@"douyindisc.angle.title";[content addSubview:self.douyindisc_angleTitle];
        self.douyindisc_angleValue=[UILabel new];self.douyindisc_angleValue.translatesAutoresizingMaskIntoConstraints=NO;self.douyindisc_angleValue.textAlignment=NSTextAlignmentCenter;self.douyindisc_angleValue.font=[UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightSemibold];self.douyindisc_angleValue.text=[NSString stringWithFormat:@"%d°",(int)lrint(self.douyindisc_angle)];self.douyindisc_angleValue.accessibilityIdentifier=@"douyindisc.angle.value";[content addSubview:self.douyindisc_angleValue];
        self.douyindisc_cornerTitle=[UILabel new];self.douyindisc_cornerTitle.translatesAutoresizingMaskIntoConstraints=NO;self.douyindisc_cornerTitle.text=@"圆角";self.douyindisc_cornerTitle.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];self.douyindisc_cornerTitle.textColor=UIColor.secondaryLabelColor;self.douyindisc_cornerTitle.accessibilityIdentifier=@"douyindisc.corner.title";[content addSubview:self.douyindisc_cornerTitle];
        self.douyindisc_cornerValue=[UILabel new];self.douyindisc_cornerValue.translatesAutoresizingMaskIntoConstraints=NO;self.douyindisc_cornerValue.textAlignment=NSTextAlignmentCenter;self.douyindisc_cornerValue.font=[UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightSemibold];self.douyindisc_cornerValue.text=[NSString stringWithFormat:@"%d%%",(int)lrint(self.douyindisc_cornerRadius)];self.douyindisc_cornerValue.accessibilityIdentifier=@"douyindisc.corner.value";[content addSubview:self.douyindisc_cornerValue];
        self.douyindisc_rotationTitle=[UILabel new];self.douyindisc_rotationTitle.translatesAutoresizingMaskIntoConstraints=NO;self.douyindisc_rotationTitle.text=@"持续旋转";self.douyindisc_rotationTitle.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];self.douyindisc_rotationTitle.textColor=UIColor.secondaryLabelColor;self.douyindisc_rotationTitle.accessibilityIdentifier=@"douyindisc.rotation.title";[content addSubview:self.douyindisc_rotationTitle];
        self.douyindisc_rotationSwitch=[UISwitch new];self.douyindisc_rotationSwitch.translatesAutoresizingMaskIntoConstraints=NO;self.douyindisc_rotationSwitch.on=self.douyindisc_rotationEnabled;self.douyindisc_rotationSwitch.onTintColor=douyindisc_color(item[@"accentColor"]);self.douyindisc_rotationSwitch.accessibilityIdentifier=@"douyindisc.rotation.enabled";self.douyindisc_rotationSwitch.accessibilityLabel=@"开启持续旋转";[self.douyindisc_rotationSwitch addTarget:self action:@selector(douyindisc_rotationSwitchChanged) forControlEvents:UIControlEventValueChanged];[content addSubview:self.douyindisc_rotationSwitch];
        self.douyindisc_rotationSpeedValue=[UILabel new];self.douyindisc_rotationSpeedValue.translatesAutoresizingMaskIntoConstraints=NO;self.douyindisc_rotationSpeedValue.textAlignment=NSTextAlignmentCenter;self.douyindisc_rotationSpeedValue.font=[UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightSemibold];self.douyindisc_rotationSpeedValue.text=[NSString stringWithFormat:@"%d%%",(int)lrint(self.douyindisc_rotationSpeed*100)];self.douyindisc_rotationSpeedValue.accessibilityIdentifier=@"douyindisc.rotation.speed";[content addSubview:self.douyindisc_rotationSpeedValue];
        NSArray<NSArray *> *specs=@[@[@"douyindisc_angleMinus",@"douyindisc_anglePlus",@"降低静态角度",@"提高静态角度"],@[@"douyindisc_cornerMinus",@"douyindisc_cornerPlus",@"减小圆角",@"增大圆角"],@[@"douyindisc_rotationSpeedMinus",@"douyindisc_rotationSpeedPlus",@"降低旋转速度",@"提高旋转速度"]];
        NSArray<NSArray<UILabel *> *> *valueRows=@[@[self.douyindisc_angleTitle,self.douyindisc_angleValue],@[self.douyindisc_cornerTitle,self.douyindisc_cornerValue],@[self.douyindisc_rotationTitle,self.douyindisc_rotationSpeedValue]];
        NSMutableArray<UIButton *> *stepperButtons=[NSMutableArray arrayWithCapacity:6];
        for(NSUInteger i=0;i<specs.count;i++)for(NSUInteger side=0;side<2;side++){
            UIButton *step=[UIButton buttonWithType:UIButtonTypeSystem];step.translatesAutoresizingMaskIntoConstraints=NO;[step setTitle:side?@"＋":@"−" forState:UIControlStateNormal];step.accessibilityLabel=specs[i][side+2];step.titleLabel.font=[UIFont systemFontOfSize:19 weight:UIFontWeightMedium];step.tintColor=douyindisc_color(item[@"accentColor"]);step.backgroundColor=UIColor.tertiarySystemGroupedBackgroundColor;step.layer.cornerRadius=8;
            SEL selector=i==0?(side?@selector(douyindisc_changeAnglePlus):@selector(douyindisc_changeAngleMinus)):(i==1?(side?@selector(douyindisc_changeCornerPlus):@selector(douyindisc_changeCornerMinus)):(side?@selector(douyindisc_changeRotationSpeedPlus):@selector(douyindisc_changeRotationSpeedMinus)));
            [step addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];[content addSubview:step];[stepperButtons addObject:step];
            if(i==0){if(side)self.douyindisc_anglePlus=step;else self.douyindisc_angleMinus=step;}else if(i==1){if(side)self.douyindisc_cornerPlus=step;else self.douyindisc_cornerMinus=step;}else{if(side)self.douyindisc_rotationSpeedPlus=step;else self.douyindisc_rotationSpeedMinus=step;}
        }
        (void)valueRows;
    }
    NSMutableArray<NSLayoutConstraint *> *layoutConstraints=[NSMutableArray arrayWithArray:@[
        [content.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14], [content.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
        [content.topAnchor constraintEqualToAnchor:self.topAnchor constant:9], [content.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-9],
        [swatch.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [swatch.topAnchor constraintEqualToAnchor:content.topAnchor], [swatch.widthAnchor constraintEqualToConstant:36], [swatch.heightAnchor constraintEqualToConstant:36],
        [symbol.centerXAnchor constraintEqualToAnchor:swatch.centerXAnchor], [symbol.centerYAnchor constraintEqualToAnchor:swatch.centerYAnchor], [symbol.widthAnchor constraintEqualToConstant:16], [symbol.heightAnchor constraintEqualToConstant:16],
        [title.leadingAnchor constraintEqualToAnchor:swatch.trailingAnchor constant:10], [title.centerYAnchor constraintEqualToAnchor:swatch.centerYAnchor], [title.trailingAnchor constraintLessThanOrEqualToAnchor:self.douyindisc_switch.leadingAnchor constant:-6],
        [self.douyindisc_switch.trailingAnchor constraintEqualToAnchor:content.trailingAnchor], [self.douyindisc_switch.centerYAnchor constraintEqualToAnchor:swatch.centerYAnchor],
        [self.douyindisc_thumbnail.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [self.douyindisc_thumbnail.topAnchor constraintEqualToAnchor:swatch.bottomAnchor constant:8], [self.douyindisc_thumbnail.widthAnchor constraintEqualToConstant:42], [self.douyindisc_thumbnail.heightAnchor constraintEqualToConstant:42],
        [self.douyindisc_actions.leadingAnchor constraintEqualToAnchor:self.douyindisc_thumbnail.trailingAnchor constant:8], [self.douyindisc_actions.centerYAnchor constraintEqualToAnchor:self.douyindisc_thumbnail.centerYAnchor], [self.douyindisc_actions.trailingAnchor constraintLessThanOrEqualToAnchor:content.trailingAnchor],
        [self.douyindisc_imageButton.widthAnchor constraintEqualToConstant:88], [self.douyindisc_imageButton.heightAnchor constraintEqualToConstant:36], [self.douyindisc_clearButton.widthAnchor constraintEqualToConstant:36], [self.douyindisc_clearButton.heightAnchor constraintEqualToConstant:36],
        [self.douyindisc_opacityTitle.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [self.douyindisc_opacityTitle.centerYAnchor constraintEqualToAnchor:self.douyindisc_value.centerYAnchor],
        [self.douyindisc_opacityMinus.leadingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-146], [self.douyindisc_opacityMinus.centerYAnchor constraintEqualToAnchor:self.douyindisc_value.centerYAnchor], [self.douyindisc_opacityMinus.widthAnchor constraintEqualToConstant:34], [self.douyindisc_opacityMinus.heightAnchor constraintEqualToConstant:30],
        [self.douyindisc_value.leadingAnchor constraintEqualToAnchor:self.douyindisc_opacityMinus.trailingAnchor constant:2], [self.douyindisc_value.trailingAnchor constraintEqualToAnchor:self.douyindisc_opacityPlus.leadingAnchor constant:-2], [self.douyindisc_value.widthAnchor constraintEqualToConstant:74], [self.douyindisc_value.heightAnchor constraintEqualToConstant:30], [self.douyindisc_value.topAnchor constraintEqualToAnchor:self.douyindisc_thumbnail.bottomAnchor constant:8],
        [self.douyindisc_opacityPlus.trailingAnchor constraintEqualToAnchor:content.trailingAnchor], [self.douyindisc_opacityPlus.centerYAnchor constraintEqualToAnchor:self.douyindisc_value.centerYAnchor], [self.douyindisc_opacityPlus.widthAnchor constraintEqualToConstant:34], [self.douyindisc_opacityPlus.heightAnchor constraintEqualToConstant:30],
        [self.douyindisc_sizeTitle.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [self.douyindisc_sizeTitle.centerYAnchor constraintEqualToAnchor:self.douyindisc_sizeValue.centerYAnchor],
        [self.douyindisc_sizeMinus.leadingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-146], [self.douyindisc_sizeMinus.topAnchor constraintEqualToAnchor:self.douyindisc_value.bottomAnchor constant:8], [self.douyindisc_sizeMinus.widthAnchor constraintEqualToConstant:34], [self.douyindisc_sizeMinus.heightAnchor constraintEqualToConstant:30],
        [self.douyindisc_sizeValue.leadingAnchor constraintEqualToAnchor:self.douyindisc_sizeMinus.trailingAnchor constant:2], [self.douyindisc_sizeValue.trailingAnchor constraintEqualToAnchor:self.douyindisc_sizePlus.leadingAnchor constant:-2], [self.douyindisc_sizeValue.widthAnchor constraintEqualToConstant:74], [self.douyindisc_sizeValue.heightAnchor constraintEqualToConstant:30],
        [self.douyindisc_sizePlus.trailingAnchor constraintEqualToAnchor:content.trailingAnchor], [self.douyindisc_sizePlus.centerYAnchor constraintEqualToAnchor:self.douyindisc_sizeValue.centerYAnchor], [self.douyindisc_sizePlus.widthAnchor constraintEqualToConstant:34], [self.douyindisc_sizePlus.heightAnchor constraintEqualToConstant:30],
        [self.douyindisc_sizeValue.centerYAnchor constraintEqualToAnchor:self.douyindisc_sizeMinus.centerYAnchor]
    ]];
    if(navigationIcon){
        [layoutConstraints addObjectsFromArray:@[
            [self.douyindisc_angleTitle.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],[self.douyindisc_angleTitle.centerYAnchor constraintEqualToAnchor:self.douyindisc_angleValue.centerYAnchor],
            [self.douyindisc_angleMinus.leadingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-146],[self.douyindisc_angleMinus.topAnchor constraintEqualToAnchor:self.douyindisc_sizeValue.bottomAnchor constant:8],[self.douyindisc_angleMinus.widthAnchor constraintEqualToConstant:34],[self.douyindisc_angleMinus.heightAnchor constraintEqualToConstant:30],
            [self.douyindisc_angleValue.leadingAnchor constraintEqualToAnchor:self.douyindisc_angleMinus.trailingAnchor constant:2],[self.douyindisc_angleValue.trailingAnchor constraintEqualToAnchor:self.douyindisc_anglePlus.leadingAnchor constant:-2],[self.douyindisc_angleValue.widthAnchor constraintEqualToConstant:74],[self.douyindisc_angleValue.heightAnchor constraintEqualToConstant:30],
            [self.douyindisc_anglePlus.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],[self.douyindisc_anglePlus.centerYAnchor constraintEqualToAnchor:self.douyindisc_angleValue.centerYAnchor],[self.douyindisc_anglePlus.widthAnchor constraintEqualToConstant:34],[self.douyindisc_anglePlus.heightAnchor constraintEqualToConstant:30],
            [self.douyindisc_cornerTitle.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],[self.douyindisc_cornerTitle.centerYAnchor constraintEqualToAnchor:self.douyindisc_cornerValue.centerYAnchor],
            [self.douyindisc_cornerMinus.leadingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-146],[self.douyindisc_cornerMinus.topAnchor constraintEqualToAnchor:self.douyindisc_angleValue.bottomAnchor constant:8],[self.douyindisc_cornerMinus.widthAnchor constraintEqualToConstant:34],[self.douyindisc_cornerMinus.heightAnchor constraintEqualToConstant:30],
            [self.douyindisc_cornerValue.leadingAnchor constraintEqualToAnchor:self.douyindisc_cornerMinus.trailingAnchor constant:2],[self.douyindisc_cornerValue.trailingAnchor constraintEqualToAnchor:self.douyindisc_cornerPlus.leadingAnchor constant:-2],[self.douyindisc_cornerValue.widthAnchor constraintEqualToConstant:74],[self.douyindisc_cornerValue.heightAnchor constraintEqualToConstant:30],
            [self.douyindisc_cornerPlus.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],[self.douyindisc_cornerPlus.centerYAnchor constraintEqualToAnchor:self.douyindisc_cornerValue.centerYAnchor],[self.douyindisc_cornerPlus.widthAnchor constraintEqualToConstant:34],[self.douyindisc_cornerPlus.heightAnchor constraintEqualToConstant:30],
            [self.douyindisc_rotationTitle.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],[self.douyindisc_rotationTitle.centerYAnchor constraintEqualToAnchor:self.douyindisc_rotationSwitch.centerYAnchor],
            [self.douyindisc_rotationSwitch.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],[self.douyindisc_rotationSwitch.topAnchor constraintEqualToAnchor:self.douyindisc_cornerValue.bottomAnchor constant:7],
            [self.douyindisc_rotationSpeedMinus.leadingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-146],[self.douyindisc_rotationSpeedMinus.topAnchor constraintEqualToAnchor:self.douyindisc_rotationSwitch.bottomAnchor constant:7],[self.douyindisc_rotationSpeedMinus.widthAnchor constraintEqualToConstant:34],[self.douyindisc_rotationSpeedMinus.heightAnchor constraintEqualToConstant:30],
            [self.douyindisc_rotationSpeedValue.leadingAnchor constraintEqualToAnchor:self.douyindisc_rotationSpeedMinus.trailingAnchor constant:2],[self.douyindisc_rotationSpeedValue.trailingAnchor constraintEqualToAnchor:self.douyindisc_rotationSpeedPlus.leadingAnchor constant:-2],[self.douyindisc_rotationSpeedValue.widthAnchor constraintEqualToConstant:74],[self.douyindisc_rotationSpeedValue.heightAnchor constraintEqualToConstant:30],[self.douyindisc_rotationSpeedValue.centerYAnchor constraintEqualToAnchor:self.douyindisc_rotationSpeedMinus.centerYAnchor],
            [self.douyindisc_rotationSpeedPlus.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],[self.douyindisc_rotationSpeedPlus.centerYAnchor constraintEqualToAnchor:self.douyindisc_rotationSpeedValue.centerYAnchor],[self.douyindisc_rotationSpeedPlus.widthAnchor constraintEqualToConstant:34],[self.douyindisc_rotationSpeedPlus.heightAnchor constraintEqualToConstant:30]
        ]];
    }
    [layoutConstraints addObject:[self.heightAnchor constraintEqualToConstant:navigationIcon?350:198]];
    [NSLayoutConstraint activateConstraints:layoutConstraints];
    return self;
}
- (void)douyindisc_setImagePickingEnabled:(BOOL)enabled { self.douyindisc_imageButton.enabled=enabled; }
- (void)douyindisc_setHasImage:(BOOL)hasImage {
    NSString *title=hasImage?@"更换图标":@"照片";
    [self.douyindisc_imageButton setTitle:title forState:UIControlStateNormal];
    [self.douyindisc_imageButton setImage:[UIImage systemImageNamed:@"photo"] forState:UIControlStateNormal];
    self.douyindisc_imageButton.tintColor=douyindisc_color(@"#1557C0");
    self.douyindisc_imageButton.accessibilityLabel=title;
    self.douyindisc_clearButton.enabled=hasImage;
}
- (void)douyindisc_inputAccessoryDone {if(self.douyindisc_value.isFirstResponder)[self.douyindisc_value resignFirstResponder];else [self.douyindisc_sizeValue resignFirstResponder];}
- (void)douyindisc_changeOpacityByMinus {[self douyindisc_adjustOpacity:-1];}
- (void)douyindisc_changeOpacityByPlus {[self douyindisc_adjustOpacity:1];}
- (void)douyindisc_changeSizeByMinus {[self douyindisc_adjustSize:-1];}
- (void)douyindisc_changeSizeByPlus {[self douyindisc_adjustSize:1];}
- (void)douyindisc_editingOpacityInput {self.douyindisc_value.text=[self.douyindisc_value.text stringByReplacingOccurrencesOfString:@"%" withString:@""];}
- (void)douyindisc_editingSizeInput {self.douyindisc_sizeValue.text=[self.douyindisc_sizeValue.text stringByReplacingOccurrencesOfString:@"%" withString:@""];}
- (BOOL)douyindisc_validPercentText:(NSString *)text {NSString *trim=[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];return trim.length>0&&[trim rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location==NSNotFound;}
- (void)douyindisc_adjustOpacity:(NSInteger)delta {[self.douyindisc_value resignFirstResponder];NSInteger v=MAX(0,MIN(100,(NSInteger)lrint(self.douyindisc_opacity*100)+delta));self.douyindisc_opacity=v/100.0;self.douyindisc_value.text=[NSString stringWithFormat:@"%ld%%",(long)v];if(self.douyindisc_preview)self.douyindisc_preview(self,self.douyindisc_opacity);if(self.douyindisc_change)self.douyindisc_change(self,self.douyindisc_switch.isOn,self.douyindisc_opacity);}
- (void)douyindisc_adjustSize:(NSInteger)delta {[self.douyindisc_sizeValue resignFirstResponder];BOOL speed=[self.douyindisc_identifier isEqualToString:@"video_disc"];NSInteger minimum=speed?25:50,maximum=speed?300:150;NSInteger v=MAX(minimum,MIN(maximum,(NSInteger)lrint(self.douyindisc_scale*100)+delta));self.douyindisc_scale=v/100.0;self.douyindisc_sizeValue.text=[NSString stringWithFormat:@"%ld%%",(long)v];if(self.douyindisc_previewScale)self.douyindisc_previewScale(self,self.douyindisc_scale);if(self.douyindisc_changeScale)self.douyindisc_changeScale(self,self.douyindisc_scale);}
- (void)douyindisc_changeAngle:(NSInteger)delta {NSInteger value=(NSInteger)lrint(self.douyindisc_angle);value=(value+delta)%360;if(value<0)value+=360;self.douyindisc_angle=value;self.douyindisc_angleValue.text=[NSString stringWithFormat:@"%ld°",(long)value];if(self.douyindisc_changeAppearance)self.douyindisc_changeAppearance(self);}
- (void)douyindisc_changeCorner:(NSInteger)delta {NSInteger value=MAX(0,MIN(50,(NSInteger)lrint(self.douyindisc_cornerRadius)+delta));self.douyindisc_cornerRadius=value;self.douyindisc_cornerValue.text=[NSString stringWithFormat:@"%ld%%",(long)value];if(self.douyindisc_changeAppearance)self.douyindisc_changeAppearance(self);}
- (void)douyindisc_changeRotationSpeed:(NSInteger)delta {NSInteger value=MAX(25,MIN(300,(NSInteger)lrint(self.douyindisc_rotationSpeed*100)+delta*5));self.douyindisc_rotationSpeed=value/100.0;self.douyindisc_rotationSpeedValue.text=[NSString stringWithFormat:@"%ld%%",(long)value];if(self.douyindisc_changeAppearance)self.douyindisc_changeAppearance(self);}
- (void)douyindisc_changeAngleMinus {[self douyindisc_changeAngle:-1];}
- (void)douyindisc_changeAnglePlus {[self douyindisc_changeAngle:1];}
- (void)douyindisc_changeCornerMinus {[self douyindisc_changeCorner:-1];}
- (void)douyindisc_changeCornerPlus {[self douyindisc_changeCorner:1];}
- (void)douyindisc_changeRotationSpeedMinus {[self douyindisc_changeRotationSpeed:-1];}
- (void)douyindisc_changeRotationSpeedPlus {[self douyindisc_changeRotationSpeed:1];}
- (void)douyindisc_rotationSwitchChanged {self.douyindisc_rotationEnabled=self.douyindisc_rotationSwitch.isOn;if(self.douyindisc_changeAppearance)self.douyindisc_changeAppearance(self);}
- (void)douyindisc_commitOpacityInput {NSString *raw=[self.douyindisc_value.text stringByReplacingOccurrencesOfString:@"%" withString:@""];if(![self douyindisc_validPercentText:raw]){self.douyindisc_value.text=[NSString stringWithFormat:@"%d%%",(int)lrint(self.douyindisc_opacity*100)];return;}double parsed=raw.doubleValue;if(!isfinite(parsed)){self.douyindisc_value.text=[NSString stringWithFormat:@"%d%%",(int)lrint(self.douyindisc_opacity*100)];return;}NSInteger v=(NSInteger)lrint(MIN(100.0,MAX(0.0,parsed)));self.douyindisc_opacity=v/100.0;self.douyindisc_value.text=[NSString stringWithFormat:@"%ld%%",(long)v];if(self.douyindisc_preview)self.douyindisc_preview(self,self.douyindisc_opacity);if(self.douyindisc_change)self.douyindisc_change(self,self.douyindisc_switch.isOn,self.douyindisc_opacity);}
- (void)douyindisc_commitSizeInput {NSString *raw=[self.douyindisc_sizeValue.text stringByReplacingOccurrencesOfString:@"%" withString:@""];if(![self douyindisc_validPercentText:raw]){self.douyindisc_sizeValue.text=[NSString stringWithFormat:@"%d%%",(int)lrint(self.douyindisc_scale*100)];return;}double parsed=raw.doubleValue;if(!isfinite(parsed)){self.douyindisc_sizeValue.text=[NSString stringWithFormat:@"%d%%",(int)lrint(self.douyindisc_scale*100)];return;}BOOL speed=[self.douyindisc_identifier isEqualToString:@"video_disc"];double minimum=speed?25:50,maximum=speed?300:150;NSInteger v=(NSInteger)lrint(MIN(maximum,MAX(minimum,parsed)));self.douyindisc_scale=v/100.0;self.douyindisc_sizeValue.text=[NSString stringWithFormat:@"%ld%%",(long)v];if(self.douyindisc_previewScale)self.douyindisc_previewScale(self,self.douyindisc_scale);if(self.douyindisc_changeScale)self.douyindisc_changeScale(self,self.douyindisc_scale);}
- (void)douyindisc_switchChanged {if(self.douyindisc_change)self.douyindisc_change(self,self.douyindisc_switch.isOn,self.douyindisc_opacity);}
- (void)douyindisc_photoTapped { if(self.douyindisc_imageButton.enabled&&self.douyindisc_pickPhoto)self.douyindisc_pickPhoto(self); }
- (void)douyindisc_setEnabledAfterCommit:(BOOL)enabled { self.douyindisc_switch.on=enabled; [self douyindisc_setImagePickingEnabled:enabled]; }
- (void)douyindisc_clearTapped { if (self.douyindisc_clear) self.douyindisc_clear(self); }
@end

@interface DouyinDiscSettingsViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) UIScrollView *douyindisc_scrollView;
@property (nonatomic, strong) UIStackView *douyindisc_stack;
@property (nonatomic, weak) DouyinDiscNavigationRow *douyindisc_activeRow;
@property (nonatomic, copy) NSString *douyindisc_activeIdentifier;
@property (nonatomic) NSUInteger douyindisc_activePickGeneration;
@property (nonatomic, strong) UIViewController *douyindisc_activePicker;
@property (nonatomic, strong) NSTimer *douyindisc_pickerMonitor;
@property (nonatomic) BOOL douyindisc_pickerWasAttached;
@property (nonatomic) BOOL douyindisc_pickerMonitorDismissRequested;
@property (nonatomic) NSUInteger douyindisc_pickerDetachedSamples;
@property (nonatomic) BOOL douyindisc_pickerHasResult;
@property (nonatomic) BOOL douyindisc_pickerHasProvider;
@property (nonatomic) NSUInteger douyindisc_pickerRecoveryGeneration;
@property (nonatomic) NSUInteger douyindisc_pickerRecoveryAttempts;
#if defined(DOUYINDISC_UI_TEST)
@property (nonatomic, copy) void (^douyindisc_uiTestImageCommitFinished)(DouyinDiscNavigationRow *, BOOL);
@property (nonatomic, copy) void (^douyindisc_uiTestPickerFinished)(BOOL cancelled);
@property (nonatomic, copy) void (^douyindisc_uiTestPickerPresented)(UIViewController *picker);
@property (nonatomic, copy) dispatch_block_t douyindisc_uiTestPickerReady;
@property (nonatomic) BOOL douyindisc_uiTestPresentationCompleted;
#endif
- (void)douyindisc_presentPhotoPickerForRow:(DouyinDiscNavigationRow *)row;
- (void)douyindisc_finishPickerUI:(UIViewController *)picker cancelled:(BOOL)cancelled keepImportTicket:(BOOL)keepImportTicket;
- (void)douyindisc_finishImportSessionIdentifier:(NSString *)identifier generation:(NSUInteger)generation;
- (void)douyindisc_importGIFResource:(PHAssetResource *)resource identifier:(NSString *)identifier pickingGeneration:(NSUInteger)generation;
- (void)douyindisc_failImagePickingIdentifier:(NSString *)identifier generation:(NSUInteger)generation error:(NSError *)error;
- (void)douyindisc_schedulePickerRecovery:(UIViewController *)picker generation:(NSUInteger)generation;
- (void)douyindisc_startPickerMonitor:(UIViewController *)picker generation:(NSUInteger)generation;
- (void)douyindisc_checkPickerRecovery:(UIViewController *)picker generation:(NSUInteger)generation recovery:(NSUInteger)recovery;
- (void)douyindisc_commitImageData:(NSData *)data identifier:(NSString *)identifier pickingGeneration:(NSUInteger)pickingGeneration;
@end

#if defined(DOUYINDISC_UI_TEST)
static __strong DouyinDiscSettingsViewController *douyindisc_uiTestRetainedPanel;
void douyindisc_uiTestCommitImageAndCheckPanelPreview(NSData *data,NSString *identifier,void(^done)(BOOL)) {
    if(!NSThread.isMainThread||!data.length||!identifier.length||!done){if(done)done(NO);return;}
    DouyinDiscNavigationStore *store=DouyinDiscNavigationStore.douyindisc_sharedStore;
    NSDictionary *old=[store douyindisc_entryForIdentifier:identifier];NSError *saveError=nil;
    if(![store douyindisc_saveEnabled:YES opacity:[old[@"opacity"] doubleValue] scale:[old[@"scale"] doubleValue] identifier:identifier error:&saveError]){done(NO);return;}
    NSUInteger generation=[store douyindisc_beginImagePickingForIdentifier:identifier];
    DouyinDiscSettingsViewController *panel=[DouyinDiscSettingsViewController new];[panel loadViewIfNeeded];
    DouyinDiscNavigationRow *target=nil;
    for(UIView *view in panel.douyindisc_stack.arrangedSubviews)if([view isKindOfClass:DouyinDiscNavigationRow.class]&&[[(DouyinDiscNavigationRow *)view douyindisc_identifier] isEqualToString:identifier]){target=(DouyinDiscNavigationRow *)view;break;}
    if(!target||!generation){if(generation)[store douyindisc_finishImagePickingForIdentifier:identifier generation:generation];[store douyindisc_saveEnabled:[old[@"enabled"] boolValue] opacity:[old[@"opacity"] doubleValue] scale:[old[@"scale"] doubleValue] identifier:identifier error:nil];done(NO);return;}
    douyindisc_uiTestRetainedPanel=panel;
    panel.douyindisc_uiTestImageCommitFinished=^(DouyinDiscNavigationRow *row,BOOL committed){
        BOOL refreshed=committed&&row==target&&row.douyindisc_thumbnail.image==[store douyindisc_imageForIdentifier:identifier]&&row.douyindisc_clearButton.enabled&&[[row.douyindisc_imageButton titleForState:UIControlStateNormal] isEqualToString:@"更换图标"]&&[store douyindisc_entryForIdentifier:identifier][@"hasImage"];
        douyindisc_uiTestRetainedPanel.douyindisc_uiTestImageCommitFinished=nil;
        if(refreshed)[store douyindisc_clearImageForIdentifier:identifier error:nil];
        [store douyindisc_saveEnabled:[old[@"enabled"] boolValue] opacity:[old[@"opacity"] doubleValue] scale:[old[@"scale"] doubleValue] identifier:identifier error:nil];
        douyindisc_uiTestRetainedPanel=nil;if(done)done(refreshed);
    };
    [panel douyindisc_commitImageData:data identifier:identifier pickingGeneration:generation];
}
static void douyindisc_uiTestTracePicker(NSString *event, DouyinDiscSettingsViewController *owner, UIViewController *picker) {
    UIWindow *window=owner.viewIfLoaded.window;
    UINavigationController *nav=owner.navigationController;
    UIViewController *root=window.rootViewController;
    NSLog(@"DD_PICKER %@ picker=%@/%p style=%ld window=%p presenting=%d dismissing=%d presenter=%p owner=%p ownerPresented=%p active=%d completion=%d ownerWindow=%p key=%d root=%@/%p rootPresented=%p nav=%p navPresented=%p navTop=%d ownerTransition=%d rootTransition=%d appState=%ld", event, NSStringFromClass(picker.class), (__bridge void *)picker, (long)picker.modalPresentationStyle, (__bridge void *)picker.viewIfLoaded.window, picker.isBeingPresented, picker.isBeingDismissed, (__bridge void *)picker.presentingViewController, (__bridge void *)owner, (__bridge void *)owner.presentedViewController, owner.douyindisc_activePicker==picker, owner.douyindisc_uiTestPresentationCompleted, (__bridge void *)window, window.isKeyWindow, NSStringFromClass(root.class), (__bridge void *)root, (__bridge void *)root.presentedViewController, (__bridge void *)nav, (__bridge void *)nav.presentedViewController, nav.topViewController==owner, owner.transitionCoordinator!=nil, root.transitionCoordinator!=nil, (long)UIApplication.sharedApplication.applicationState);
    if([event isEqualToString:@"present-before"]){
        for(Class cls in @[UIViewController.class,UINavigationController.class,DouyinDiscSettingsViewController.class]){
            Method method=class_getInstanceMethod(cls,@selector(presentViewController:animated:completion:));
            IMP imp=method_getImplementation(method);Dl_info image={0};dladdr((const void *)imp,&image);
            NSLog(@"DD_PICKER_IMP class=%@ imp=%p encoding=%s image=%s symbol=%s",NSStringFromClass(cls),imp,method_getTypeEncoding(method),image.dli_fname?:"?",image.dli_sname?:"?");
        }
        NSLog(@"DD_PICKER_CLASS image=%s sourceAvailable=%d",class_getImageName(object_getClass(picker))?:"?",[UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]);
    }
}
static void douyindisc_uiTestCapturePickerWindow(UIWindow *window, NSString *name) {
    if(!window)return;
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc]initWithSize:window.bounds.size];
    UIImage *image=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context){(void)context;[window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];}];
    NSString *directory=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    [UIImagePNGRepresentation(image) writeToFile:[directory stringByAppendingPathComponent:name] atomically:YES];
}
static void douyindisc_uiTestObservePicker(DouyinDiscSettingsViewController *owner, UIViewController *picker, NSUInteger remaining) {
    if(owner.douyindisc_activePicker!=picker||!owner.douyindisc_uiTestPickerPresented)return;
    UIWindow *window=picker.viewIfLoaded.window;
    BOOL visible=window&&picker.presentingViewController&&!picker.isBeingPresented&&!picker.isBeingDismissed&&owner.douyindisc_uiTestPresentationCompleted;
    if(visible||remaining==0){
        douyindisc_uiTestTracePicker(visible?@"observe-visible":@"observe-timeout",owner,picker);
        douyindisc_uiTestCapturePickerWindow(window?:owner.viewIfLoaded.window,visible?@"picker-visible.png":@"picker-not-visible.png");
        owner.douyindisc_uiTestPickerPresented(picker);return;
    }
    __weak DouyinDiscSettingsViewController *weakOwner=owner;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.25*NSEC_PER_SEC)),dispatch_get_main_queue(),^{douyindisc_uiTestObservePicker(weakOwner,picker,remaining-1);});
}
#endif

@implementation DouyinDiscSettingsViewController
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    UIViewController *picker=self.douyindisc_activePicker;
    if(picker){
        if(!self.presentedViewController&&!picker.isBeingPresented&&!picker.isBeingDismissed&&(!picker.isViewLoaded||!picker.view.window)){BOOL hasProvider=self.douyindisc_pickerHasProvider;[self douyindisc_finishPickerUI:picker cancelled:!hasProvider keepImportTicket:hasProvider];}
        else [self douyindisc_schedulePickerRecovery:picker generation:self.douyindisc_activePickGeneration];
    }
#if defined(DOUYINDISC_UI_TEST)
    if(self.douyindisc_uiTestPickerReady){dispatch_block_t ready=[self.douyindisc_uiTestPickerReady copy];self.douyindisc_uiTestPickerReady=nil;dispatch_async(dispatch_get_main_queue(),ready);}
#endif
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DouyinDisc";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.douyindisc_scrollView = [UIScrollView new]; self.douyindisc_scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.douyindisc_scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.douyindisc_scrollView];
    self.douyindisc_stack = [UIStackView new]; self.douyindisc_stack.translatesAutoresizingMaskIntoConstraints = NO;
    self.douyindisc_stack.axis = UILayoutConstraintAxisVertical; self.douyindisc_stack.spacing = 8;
    [self.douyindisc_scrollView addSubview:self.douyindisc_stack];
    [NSLayoutConstraint activateConstraints:@[
        [self.douyindisc_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [self.douyindisc_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.douyindisc_scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor], [self.douyindisc_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.douyindisc_stack.leadingAnchor constraintEqualToAnchor:self.douyindisc_scrollView.contentLayoutGuide.leadingAnchor constant:16],
        [self.douyindisc_stack.trailingAnchor constraintEqualToAnchor:self.douyindisc_scrollView.contentLayoutGuide.trailingAnchor constant:-16],
        [self.douyindisc_stack.topAnchor constraintEqualToAnchor:self.douyindisc_scrollView.contentLayoutGuide.topAnchor constant:16],
        [self.douyindisc_stack.bottomAnchor constraintEqualToAnchor:self.douyindisc_scrollView.contentLayoutGuide.bottomAnchor constant:-24],
        [self.douyindisc_stack.widthAnchor constraintEqualToAnchor:self.douyindisc_scrollView.frameLayoutGuide.widthAnchor constant:-32]
    ]];
    UIStackView *intro=[UIStackView new];intro.axis=UILayoutConstraintAxisVertical;intro.spacing=4;
    UILabel *title=[UILabel new];title.text=@"抖音图标自定义";title.font=[UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    UILabel *notice=[UILabel new];notice.numberOfLines=0;notice.font=[UIFont systemFontOfSize:12];notice.textColor=UIColor.secondaryLabelColor;notice.text=@"自定义首页分类、底部导航和视频页唱片。关闭对应开关可恢复抖音原样。";
    [intro addArrangedSubview:title];[intro addArrangedSubview:notice];[self.douyindisc_stack addArrangedSubview:intro];
    for (NSDictionary *item in douyindisc_navigationItems()) {
        NSString *identifier=item[@"identifier"];
        NSString *group=[identifier isEqualToString:@"video_disc"]?@"视频页唱片":([identifier hasPrefix:@"top_"]?@"首页顶部分类":@"底部导航");
        BOOL needsHeader = self.douyindisc_stack.arrangedSubviews.count == 1 || [identifier isEqual:@"bottom_home"] || [identifier isEqual:@"video_disc"];
        if (needsHeader) {
            UILabel *header = [UILabel new]; header.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]; header.textColor = UIColor.secondaryLabelColor;
            header.text = group; header.accessibilityLabel = group;
            [self.douyindisc_stack addArrangedSubview:header];
            [header.heightAnchor constraintGreaterThanOrEqualToConstant:22].active = YES;
        }
        NSDictionary *entry = [DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_entryForIdentifier:item[@"identifier"]];
        UIImage *image = [DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_imageForIdentifier:item[@"identifier"]];
        DouyinDiscNavigationRow *row = [[DouyinDiscNavigationRow alloc] initWithItem:item entry:entry image:image];
        __weak typeof(self) weakSelf = self;
        row.douyindisc_preview = ^(DouyinDiscNavigationRow *changed, CGFloat opacity) {
            [DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_previewOpacity:opacity identifier:changed.douyindisc_identifier];
        };
        row.douyindisc_change = ^(DouyinDiscNavigationRow *changed, BOOL enabled, CGFloat opacity) {
            NSDictionary *current=[DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_entryForIdentifier:changed.douyindisc_identifier];NSError *error=nil;
            if(![DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_saveEnabled:enabled opacity:opacity scale:[current[@"scale"] doubleValue] identifier:changed.douyindisc_identifier error:&error]){changed.douyindisc_opacity=[current[@"opacity"] doubleValue];changed.douyindisc_value.text=[NSString stringWithFormat:@"%d%%",(int)lrint(changed.douyindisc_opacity*100)];[DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_clearOpacityPreviewForIdentifier:changed.douyindisc_identifier];[changed douyindisc_setEnabledAfterCommit:[current[@"enabled"] boolValue]];[weakSelf douyindisc_showError:error];return;}
            [changed douyindisc_setEnabledAfterCommit:enabled];
            [DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_clearOpacityPreviewForIdentifier:changed.douyindisc_identifier];
        };
        row.douyindisc_previewScale = ^(DouyinDiscNavigationRow *changed, CGFloat scale) {
            [DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_previewScale:scale identifier:changed.douyindisc_identifier];
        };
        row.douyindisc_changeScale = ^(DouyinDiscNavigationRow *changed, CGFloat scale) {
            NSDictionary *entry=[DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_entryForIdentifier:changed.douyindisc_identifier];NSError *error=nil;
            if(![DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_saveEnabled:[entry[@"enabled"] boolValue] opacity:[entry[@"opacity"] doubleValue] scale:scale identifier:changed.douyindisc_identifier error:&error]){changed.douyindisc_scale=[entry[@"scale"] doubleValue];changed.douyindisc_sizeValue.text=[NSString stringWithFormat:@"%d%%",(int)lrint(changed.douyindisc_scale*100)];[DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_clearScalePreviewForIdentifier:changed.douyindisc_identifier];[weakSelf douyindisc_showError:error];return;}
            [DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_clearScalePreviewForIdentifier:changed.douyindisc_identifier];
        };
        row.douyindisc_changeAppearance=^(DouyinDiscNavigationRow *changed){
            NSError *error=nil;BOOL saved=[DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_saveNavigationAppearanceForIdentifier:changed.douyindisc_identifier angle:changed.douyindisc_angle cornerRadius:changed.douyindisc_cornerRadius rotationEnabled:changed.douyindisc_rotationEnabled rotationSpeed:changed.douyindisc_rotationSpeed error:&error];
            if(!saved){NSDictionary *savedEntry=[DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_entryForIdentifier:changed.douyindisc_identifier];changed.douyindisc_angle=[savedEntry[@"angle"] doubleValue];changed.douyindisc_cornerRadius=[savedEntry[@"cornerRadius"] doubleValue];changed.douyindisc_rotationEnabled=[savedEntry[@"rotationEnabled"] boolValue];changed.douyindisc_rotationSpeed=[savedEntry[@"rotationSpeed"] doubleValue];changed.douyindisc_angleValue.text=[NSString stringWithFormat:@"%d°",(int)lrint(changed.douyindisc_angle)];changed.douyindisc_cornerValue.text=[NSString stringWithFormat:@"%d%%",(int)lrint(changed.douyindisc_cornerRadius)];changed.douyindisc_rotationSpeedValue.text=[NSString stringWithFormat:@"%d%%",(int)lrint(changed.douyindisc_rotationSpeed*100)];changed.douyindisc_rotationSwitch.on=changed.douyindisc_rotationEnabled;[weakSelf douyindisc_showError:error];}
        };
        row.douyindisc_pickPhoto = ^(DouyinDiscNavigationRow *selected) { [weakSelf douyindisc_presentPhotoPickerForRow:selected]; };
        row.douyindisc_clear = ^(DouyinDiscNavigationRow *selected) {
            NSError *error = nil;
            if (![DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_clearImageForIdentifier:selected.douyindisc_identifier error:&error]) { [weakSelf douyindisc_showError:error]; return; }
            [selected douyindisc_setHasImage:NO];
            selected.douyindisc_thumbnail.image=nil;
        };
        [self.douyindisc_stack addArrangedSubview:row];
    }
    __weak typeof(self) weakSelf = self;
    [[DouyinDiscNavigationStore douyindisc_sharedStore] douyindisc_preloadImagesWithCompletion:^{
        if (!weakSelf.isViewLoaded) return;
        for (UIView *view in weakSelf.douyindisc_stack.arrangedSubviews) {
            if (![view isKindOfClass:DouyinDiscNavigationRow.class]) continue;
            DouyinDiscNavigationRow *row=(DouyinDiscNavigationRow *)view;
            UIImage *image=[[DouyinDiscNavigationStore douyindisc_sharedStore] douyindisc_imageForIdentifier:row.douyindisc_identifier];
            row.douyindisc_thumbnail.image=image;
            [row douyindisc_setHasImage:image!=nil];
        }
    }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    for (NSDictionary *item in douyindisc_navigationItems()) {
        [DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_clearOpacityPreviewForIdentifier:item[@"identifier"]];
        [DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_clearScalePreviewForIdentifier:item[@"identifier"]];
    }
}
- (void)douyindisc_showError:(NSError *)error {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"未能保存设置" message:error.localizedDescription ?: @"请重试。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)douyindisc_presentPhotoPickerForRow:(DouyinDiscNavigationRow *)row {
    if (!NSThread.isMainThread || !self.view.window || self.presentedViewController || self.douyindisc_activePicker || self.isBeingDismissed) return;
    DouyinDiscNavigationStore *store=DouyinDiscNavigationStore.douyindisc_sharedStore;
    if (self.douyindisc_activePickGeneration)
        [store douyindisc_finishImagePickingForIdentifier:self.douyindisc_activeIdentifier generation:self.douyindisc_activePickGeneration];
    NSUInteger generation=[store douyindisc_beginImagePickingForIdentifier:row.douyindisc_identifier];
    if (!generation) { [row douyindisc_setImagePickingEnabled:NO]; return; }
    self.douyindisc_activeRow=row;
    self.douyindisc_activeIdentifier=[row.douyindisc_identifier copy];
    self.douyindisc_activePickGeneration=generation;
    self.douyindisc_pickerHasResult=NO;
    self.douyindisc_pickerHasProvider=NO;
    UIImagePickerController *picker=[UIImagePickerController new];
    picker.sourceType=UIImagePickerControllerSourceTypePhotoLibrary;picker.mediaTypes=@[@"public.image"];
    picker.delegate=self;picker.modalPresentationStyle=UIModalPresentationFullScreen;
    self.douyindisc_activePicker=picker;
    __weak typeof(self) weakSelf=self;
#if defined(DOUYINDISC_UI_TEST)
    self.douyindisc_uiTestPresentationCompleted=NO;
    douyindisc_uiTestTracePicker(@"present-before",self,picker);
#endif
    [self presentViewController:picker animated:YES completion:^{
#if defined(DOUYINDISC_UI_TEST)
        weakSelf.douyindisc_uiTestPresentationCompleted=YES;
        douyindisc_uiTestTracePicker(@"present-completion",weakSelf,picker);
#endif
        if(weakSelf.douyindisc_activePicker==picker)[weakSelf douyindisc_schedulePickerRecovery:picker generation:weakSelf.douyindisc_activePickGeneration];
    }];
#if defined(DOUYINDISC_UI_TEST)
    douyindisc_uiTestTracePicker(@"present-returned",self,picker);
    douyindisc_uiTestObservePicker(self,picker,40);
#endif
}
- (void)douyindisc_finishPickerUI:(UIViewController *)picker cancelled:(BOOL)cancelled keepImportTicket:(BOOL)keepImportTicket {
    if (!picker || self.douyindisc_activePicker!=picker) return;
#if defined(DOUYINDISC_UI_TEST)
    douyindisc_uiTestTracePicker(self.douyindisc_pickerHasResult?@"finish-result":@"finish-recovery",self,picker);
#endif
    if (cancelled && !keepImportTicket) [DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_finishImagePickingForIdentifier:self.douyindisc_activeIdentifier generation:self.douyindisc_activePickGeneration];
    [self.douyindisc_pickerMonitor invalidate];self.douyindisc_pickerMonitor=nil;self.douyindisc_pickerWasAttached=NO;self.douyindisc_pickerMonitorDismissRequested=NO;self.douyindisc_pickerDetachedSamples=0;
    self.douyindisc_activePicker=nil;
    self.douyindisc_activeRow=nil;
    self.douyindisc_activeIdentifier=nil;
    self.douyindisc_activePickGeneration=0;
    self.douyindisc_pickerHasResult=NO;
    self.douyindisc_pickerHasProvider=NO;
#if defined(DOUYINDISC_UI_TEST)
    if(self.douyindisc_uiTestPickerFinished)self.douyindisc_uiTestPickerFinished(cancelled);
    if(self.douyindisc_uiTestPickerReady)self.douyindisc_uiTestPickerReady();
#endif
}
- (void)douyindisc_finishImportSessionIdentifier:(NSString *)identifier generation:(NSUInteger)generation {
    [DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_finishImagePickingForIdentifier:identifier generation:generation];
    if ([self.douyindisc_activeIdentifier isEqualToString:identifier] && self.douyindisc_activePickGeneration==generation && !self.douyindisc_activePicker) {
        self.douyindisc_activeIdentifier=nil;self.douyindisc_activePickGeneration=0;self.douyindisc_activeRow=nil;
    }
}
- (void)douyindisc_failImagePickingIdentifier:(NSString *)identifier generation:(NSUInteger)generation error:(NSError *)error {
    [self douyindisc_finishImportSessionIdentifier:identifier generation:generation];
    if(self.isViewLoaded&&self.view.window)[self douyindisc_showError:error?:[NSError errorWithDomain:@"com.minis.douyindisc.navigation" code:2 userInfo:@{NSLocalizedDescriptionKey:@"GIF导入失败，原图保留。"}]];
}
- (void)douyindisc_importGIFResource:(PHAssetResource *)resource identifier:(NSString *)identifier pickingGeneration:(NSUInteger)generation {
    if(!resource||!douyindisc_navigationIsGIFUTI(resource.uniformTypeIdentifier)){[self douyindisc_failImagePickingIdentifier:identifier generation:generation error:nil];return;}
    PHAssetResourceRequestOptions *options=[PHAssetResourceRequestOptions new];options.networkAccessAllowed=YES;
    PHAssetResourceManager *manager=PHAssetResourceManager.defaultManager;NSMutableData *buffer=[NSMutableData data];NSLock *lock=[NSLock new];
    __block PHAssetResourceDataRequestID requestID=PHInvalidAssetResourceDataRequestID;__block BOOL exceeded=NO;
    PHAssetResourceDataRequestID issued=[manager requestDataForAssetResource:resource options:options dataReceivedHandler:^(NSData *chunk){
        [lock lock];BOOL cancel=NO;if(exceeded)cancel=YES;else if(chunk.length>64*1024*1024-buffer.length){exceeded=YES;[buffer setLength:0];cancel=YES;}else [buffer appendData:chunk];PHAssetResourceDataRequestID current=requestID;[lock unlock];if(cancel&&current!=PHInvalidAssetResourceDataRequestID)[manager cancelDataRequest:current];
    } completionHandler:^(NSError *readError){
        [lock lock];BOOL tooLarge=exceeded;NSData *data=tooLarge?nil:[buffer copy];[lock unlock];dispatch_async(dispatch_get_main_queue(),^{
NSError *failure=nil;
            if(tooLarge)failure=[NSError errorWithDomain:@"com.minis.douyindisc.navigation" code:2 userInfo:@{NSLocalizedDescriptionKey:@"GIF文件超过64 MiB限制，原图未更改。"}];
            else if(readError.domain==PHPhotosErrorDomain&&readError.code==PHPhotosErrorUserCancelled)failure=[NSError errorWithDomain:@"com.minis.douyindisc.navigation" code:2 userInfo:@{NSLocalizedDescriptionKey:@"相册已中断GIF资源读取；请确认照片已下载，再重新选择。原图未更改。"}];
            else if(readError)failure=readError;
            else if(!data.length||![[DouyinDiscNavigationStore douyindisc_sharedStore] douyindisc_isAnimatedGIFData:data])failure=[NSError errorWithDomain:@"com.minis.douyindisc.navigation" code:2 userInfo:@{NSLocalizedDescriptionKey:@"无法读取完整GIF动画，原图未更改。"}];
            if(failure){[self douyindisc_failImagePickingIdentifier:identifier generation:generation error:failure];return;}
            [self douyindisc_commitImageData:data identifier:identifier pickingGeneration:generation];
        });
    }];
    [lock lock];requestID=issued;BOOL cancel=exceeded;[lock unlock];if(cancel&&issued!=PHInvalidAssetResourceDataRequestID)[manager cancelDataRequest:issued];
}
- (void)douyindisc_startPickerMonitor:(UIViewController *)picker generation:(NSUInteger)generation {
    if(!NSThread.isMainThread||!picker||self.douyindisc_activePicker!=picker||self.douyindisc_activePickGeneration!=generation)return;
    [self.douyindisc_pickerMonitor invalidate];self.douyindisc_pickerDetachedSamples=0;self.douyindisc_pickerWasAttached=picker.viewIfLoaded.window!=nil;
    __weak typeof(self) weakSelf=self;__weak UIViewController *weakPicker=picker;
    NSTimer *monitor=[NSTimer timerWithTimeInterval:.2 repeats:YES block:^(NSTimer *timer){
        DouyinDiscSettingsViewController *owner=weakSelf;UIViewController *active=weakPicker;
        if(!owner||!active||owner.douyindisc_activePicker!=active||owner.douyindisc_activePickGeneration!=generation){[timer invalidate];return;}
        if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
        if(active.isBeingPresented||active.isBeingDismissed||owner.douyindisc_pickerMonitorDismissRequested)return;
        BOOL attached=active.viewIfLoaded.window!=nil;
        if(attached){owner.douyindisc_pickerWasAttached=YES;owner.douyindisc_pickerDetachedSamples=0;return;}
        if(!owner.douyindisc_pickerWasAttached)return;
        if(++owner.douyindisc_pickerDetachedSamples<3)return;
        BOOL hasProvider=owner.douyindisc_pickerHasProvider;
        if(owner.presentedViewController==active&&active.presentingViewController){owner.douyindisc_pickerMonitorDismissRequested=YES;[active dismissViewControllerAnimated:NO completion:^{[weakSelf douyindisc_finishPickerUI:active cancelled:!hasProvider keepImportTicket:hasProvider];}];}
        else if(owner.presentedViewController!=active||!active.presentingViewController){[owner douyindisc_finishPickerUI:active cancelled:!hasProvider keepImportTicket:hasProvider];}
    }];
    self.douyindisc_pickerMonitor=monitor;[[NSRunLoop mainRunLoop] addTimer:monitor forMode:NSRunLoopCommonModes];
}
- (void)douyindisc_checkPickerRecovery:(UIViewController *)picker generation:(NSUInteger)generation recovery:(NSUInteger)recovery {
    if(self.douyindisc_pickerRecoveryGeneration!=recovery||self.douyindisc_activePicker!=picker||self.douyindisc_activePickGeneration!=generation)return;
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    UIViewController *presented=self.presentedViewController;
    BOOL transitional=picker.isBeingPresented||picker.isBeingDismissed||(presented&&presented!=picker);
    if(transitional){
        if(++self.douyindisc_pickerRecoveryAttempts<=5){__weak typeof(self) weakSelf=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[weakSelf douyindisc_checkPickerRecovery:picker generation:generation recovery:recovery];});}
        return;
    }
    if(presented==picker&&picker.isViewLoaded&&picker.view.window){self.douyindisc_pickerDetachedSamples=0;return;}
    if(presented==picker&&++self.douyindisc_pickerDetachedSamples<3){__weak typeof(self) weakSelf=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[weakSelf douyindisc_checkPickerRecovery:picker generation:generation recovery:recovery];});return;}
    BOOL hasProvider=self.douyindisc_pickerHasProvider;__weak typeof(self) weakSelf=self;
    if(presented==picker){[picker dismissViewControllerAnimated:NO completion:^{[weakSelf douyindisc_finishPickerUI:picker cancelled:!hasProvider keepImportTicket:hasProvider];}];return;}
    if(!presented&&!picker.presentingViewController)[self douyindisc_finishPickerUI:picker cancelled:!hasProvider keepImportTicket:hasProvider];
}
- (void)douyindisc_schedulePickerRecovery:(UIViewController *)picker generation:(NSUInteger)generation {
    if(!NSThread.isMainThread||!picker||self.douyindisc_activePicker!=picker||!generation||self.douyindisc_activePickGeneration!=generation)return;
    NSUInteger recovery=++self.douyindisc_pickerRecoveryGeneration;self.douyindisc_pickerRecoveryAttempts=0;self.douyindisc_pickerDetachedSamples=0;__weak typeof(self) weakSelf=self;
    dispatch_async(dispatch_get_main_queue(),^{[weakSelf douyindisc_checkPickerRecovery:picker generation:generation recovery:recovery];});
}
- (void)douyindisc_commitImageData:(NSData *)data identifier:(NSString *)identifier pickingGeneration:(NSUInteger)pickingGeneration {
    __weak typeof(self) weakSelf=self;
    [[DouyinDiscNavigationStore douyindisc_sharedStore] douyindisc_saveImageData:data identifier:identifier pickingGeneration:pickingGeneration completion:^(NSError *error){
        DouyinDiscSettingsViewController *strongSelf=weakSelf;
        if(error){[strongSelf douyindisc_finishImportSessionIdentifier:identifier generation:pickingGeneration];if(strongSelf.isViewLoaded&&strongSelf.view.window)[strongSelf douyindisc_showError:error];
#if defined(DOUYINDISC_UI_TEST)
            if(strongSelf.douyindisc_uiTestImageCommitFinished){void(^finished)(DouyinDiscNavigationRow *,BOOL)=strongSelf.douyindisc_uiTestImageCommitFinished;strongSelf.douyindisc_uiTestImageCommitFinished=nil;finished(nil,NO);}
#endif
            return;}
        for(UIView *view in strongSelf.douyindisc_stack.arrangedSubviews){
            if(![view isKindOfClass:DouyinDiscNavigationRow.class])continue;
            DouyinDiscNavigationRow *row=(DouyinDiscNavigationRow *)view;
            if(![row.douyindisc_identifier isEqualToString:identifier])continue;
            row.douyindisc_thumbnail.image=[[DouyinDiscNavigationStore douyindisc_sharedStore] douyindisc_imageForIdentifier:identifier];
            [row douyindisc_setHasImage:YES];
#if defined(DOUYINDISC_UI_TEST)
            if(strongSelf.douyindisc_uiTestImageCommitFinished){void(^finished)(DouyinDiscNavigationRow *,BOOL)=strongSelf.douyindisc_uiTestImageCommitFinished;strongSelf.douyindisc_uiTestImageCommitFinished=nil;finished(row,YES);}
#endif
            break;
        }
    }];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    if(self.douyindisc_activePicker!=picker||self.douyindisc_pickerHasResult)return;
    self.douyindisc_pickerHasResult=YES;
    __weak typeof(self) weakSelf=self;
    [picker dismissViewControllerAnimated:YES completion:^{[weakSelf douyindisc_finishPickerUI:picker cancelled:YES keepImportTicket:NO];}];
}
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    if(self.douyindisc_activePicker!=picker||self.douyindisc_pickerHasResult)return;
    NSString *identifier=[self.douyindisc_activeIdentifier copy];NSUInteger generation=self.douyindisc_activePickGeneration;
    NSURL *url=info[UIImagePickerControllerImageURL];UIImage *image=info[UIImagePickerControllerOriginalImage];PHAsset *asset=info[UIImagePickerControllerPHAsset];NSString *mediaType=info[UIImagePickerControllerMediaType];
    PHAssetResource *gifResource=nil;
    if(asset){NSArray<PHAssetResource *> *resources=[PHAssetResource assetResourcesForAsset:asset];for(NSNumber *wanted in @[@(PHAssetResourceTypeFullSizePhoto),@(PHAssetResourceTypePhoto)]){for(PHAssetResource *resource in resources)if(resource.type==wanted.integerValue&&douyindisc_navigationIsGIFUTI(resource.uniformTypeIdentifier)){gifResource=resource;break;}if(gifResource)break;}}
    BOOL declaredGIF=([mediaType isKindOfClass:NSString.class]&&douyindisc_navigationIsGIFUTI(mediaType))||[url.pathExtension caseInsensitiveCompare:@"gif"]==NSOrderedSame;
    BOOL hasProvider=url||image||asset;
    self.douyindisc_pickerHasResult=YES;self.douyindisc_pickerHasProvider=hasProvider;
    __weak typeof(self) weakSelf=self;
    [picker dismissViewControllerAnimated:YES completion:^{
        [weakSelf douyindisc_finishPickerUI:picker cancelled:!hasProvider keepImportTicket:hasProvider];
        if(gifResource){[weakSelf douyindisc_importGIFResource:gifResource identifier:identifier pickingGeneration:generation];return;}
        if(declaredGIF&&!url){[weakSelf douyindisc_failImagePickingIdentifier:identifier generation:generation error:nil];return;}
        if(url){
            NSError *readError=nil;NSData *data=douyindisc_readSelectedPhotoURL(url,declaredGIF,&readError);
            if(data.length&&[DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_decodeImageData:data]){
                if(douyindisc_navigationDataHasGIFSignature(data)&&![[DouyinDiscNavigationStore douyindisc_sharedStore] douyindisc_isAnimatedGIFData:data]){
                    if(image){NSData *still=UIImagePNGRepresentation(image);if(still)[weakSelf douyindisc_commitImageData:still identifier:identifier pickingGeneration:generation];else [weakSelf douyindisc_failImagePickingIdentifier:identifier generation:generation error:nil];}
                    else [weakSelf douyindisc_failImagePickingIdentifier:identifier generation:generation error:nil];
                }else [weakSelf douyindisc_commitImageData:data identifier:identifier pickingGeneration:generation];
            }else if(image&&!declaredGIF){NSData *still=UIImagePNGRepresentation(image);if(still)[weakSelf douyindisc_commitImageData:still identifier:identifier pickingGeneration:generation];else [weakSelf douyindisc_failImagePickingIdentifier:identifier generation:generation error:readError];}
            else [weakSelf douyindisc_failImagePickingIdentifier:identifier generation:generation error:readError];
        }else if(image&&!declaredGIF){NSData *still=UIImagePNGRepresentation(image);if(still)[weakSelf douyindisc_commitImageData:still identifier:identifier pickingGeneration:generation];else [weakSelf douyindisc_failImagePickingIdentifier:identifier generation:generation error:nil];}
        else [weakSelf douyindisc_failImagePickingIdentifier:identifier generation:generation error:nil];
    }];
}
@end

#if defined(DOUYINDISC_UI_TEST)
BOOL douyindisc_uiTestPickerAppearanceStable(UIImage *image) {
 NSDictionary *item=douyindisc_navigationItems().firstObject;DouyinDiscNavigationRow *row=[[DouyinDiscNavigationRow alloc]initWithItem:item entry:@{@"enabled":@NO,@"opacity":@.99,@"scale":@.89} image:nil];row.frame=CGRectMake(0,0,390,350);[row setNeedsLayout];[row layoutIfNeeded];
 BOOL labels=[row.douyindisc_opacityTitle.text isEqualToString:@"透明度"]&&[row.douyindisc_sizeTitle.text isEqualToString:@"图标大小"];
 BOOL controls=[row.douyindisc_value isKindOfClass:UITextField.class]&&[row.douyindisc_sizeValue isKindOfClass:UITextField.class]&&row.douyindisc_opacityMinus&&row.douyindisc_opacityPlus&&row.douyindisc_sizeMinus&&row.douyindisc_sizePlus;
 BOOL rangeControls=row.douyindisc_value.keyboardType==UIKeyboardTypeNumberPad&&row.douyindisc_sizeValue.keyboardType==UIKeyboardTypeNumberPad&&fabs(CGRectGetHeight(row.douyindisc_value.frame)-30)<1&&fabs(CGRectGetHeight(row.douyindisc_sizeValue.frame)-30)<1&&fabs(CGRectGetMidY(row.douyindisc_sizeValue.frame)-CGRectGetMidY(row.douyindisc_sizeMinus.frame))<1;
 __block CGFloat preview=-1,committed=-1;row.douyindisc_previewScale=^(DouyinDiscNavigationRow *r,CGFloat x){(void)r;preview=x;};row.douyindisc_changeScale=^(DouyinDiscNavigationRow *r,CGFloat x){(void)r;committed=x;};row.douyindisc_sizeValue.text=@"125";[row douyindisc_commitSizeInput];BOOL typed=fabs(preview-1.25)<.001&&fabs(committed-1.25)<.001&&[row.douyindisc_sizeValue.text isEqualToString:@"125%"];
 [row.douyindisc_sizePlus sendActionsForControlEvents:UIControlEventTouchUpInside];BOOL plusTapped=fabs(row.douyindisc_scale-1.26)<.001;[row.douyindisc_sizeMinus sendActionsForControlEvents:UIControlEventTouchUpInside];BOOL minusTapped=fabs(row.douyindisc_scale-1.25)<.001;row.douyindisc_sizeValue.text=@"999";[row douyindisc_commitSizeInput];BOOL maxClamp=fabs(row.douyindisc_scale-1.5)<.001;row.douyindisc_sizeValue.text=@"1";[row douyindisc_commitSizeInput];BOOL minClamp=fabs(row.douyindisc_scale-.5)<.001;
 __block CGFloat opacity=-1;row.douyindisc_change=^(DouyinDiscNavigationRow *r,BOOL on,CGFloat x){(void)r;(void)on;opacity=x;};row.douyindisc_value.text=@"120";[row douyindisc_commitOpacityInput];BOOL opacityClamp=fabs(opacity-1)<.001&&[row.douyindisc_value.text isEqualToString:@"100%"];
 BOOL appearanceControls=row.douyindisc_angleTitle&&row.douyindisc_angleValue&&row.douyindisc_cornerTitle&&row.douyindisc_cornerValue&&row.douyindisc_rotationTitle&&row.douyindisc_rotationSwitch&&row.douyindisc_rotationSpeedValue&&[row.douyindisc_angleTitle.text isEqualToString:@"静态角度"]&&[row.douyindisc_cornerTitle.text isEqualToString:@"圆角"]&&[row.douyindisc_rotationTitle.text isEqualToString:@"持续旋转"]&&fabs(row.douyindisc_angle)<.001&&fabs(row.douyindisc_cornerRadius)<.001&&!row.douyindisc_rotationEnabled&&fabs(row.douyindisc_rotationSpeed-1)<.001;
 __block CGFloat appearanceAngle=-1,appearanceCorner=-1,appearanceSpeed=-1;__block BOOL appearanceRotation=NO;row.douyindisc_changeAppearance=^(DouyinDiscNavigationRow *r){appearanceAngle=r.douyindisc_angle;appearanceCorner=r.douyindisc_cornerRadius;appearanceSpeed=r.douyindisc_rotationSpeed;appearanceRotation=r.douyindisc_rotationEnabled;};
 [row.douyindisc_anglePlus sendActionsForControlEvents:UIControlEventTouchUpInside];[row.douyindisc_cornerPlus sendActionsForControlEvents:UIControlEventTouchUpInside];[row.douyindisc_rotationSwitch setOn:YES animated:NO];[row.douyindisc_rotationSwitch sendActionsForControlEvents:UIControlEventValueChanged];[row.douyindisc_rotationSpeedPlus sendActionsForControlEvents:UIControlEventTouchUpInside];
 BOOL appearanceAdjustments=fabs(appearanceAngle-1)<.001&&fabs(appearanceCorner-1)<.001&&appearanceRotation&&fabs(appearanceSpeed-1.05)<.001&&[row.douyindisc_angleValue.text isEqualToString:@"1°"]&&[row.douyindisc_cornerValue.text isEqualToString:@"1%"]&&[row.douyindisc_rotationSpeedValue.text isEqualToString:@"105%"];
 BOOL noImage=[[row.douyindisc_imageButton titleForState:UIControlStateNormal] isEqualToString:@"照片"]&&row.douyindisc_imageButton.currentImage!=nil&&row.douyindisc_thumbnail.image==nil&&!row.douyindisc_imageButton.enabled;[row douyindisc_setImagePickingEnabled:YES];__block BOOL photo=NO;row.douyindisc_pickPhoto=^(DouyinDiscNavigationRow *r){(void)r;photo=YES;};[row.douyindisc_imageButton sendActionsForControlEvents:UIControlEventTouchUpInside];
 row.douyindisc_thumbnail.image=image;[row douyindisc_setHasImage:YES];[row douyindisc_setEnabledAfterCommit:NO];
 NSDictionary *discItem=douyindisc_navigationItems().lastObject;DouyinDiscNavigationRow *discRow=[[DouyinDiscNavigationRow alloc]initWithItem:discItem entry:@{@"enabled":@YES,@"opacity":@.7,@"speed":@1} image:image];discRow.frame=CGRectMake(0,0,390,198);[discRow layoutIfNeeded];
 BOOL discControls=[discItem[@"identifier"] isEqual:@"video_disc"]&&[discRow.douyindisc_sizeTitle.text isEqualToString:@"转速"]&&[discRow.douyindisc_sizeValue.accessibilityLabel isEqualToString:@"唱片转速百分比"]&&discRow.douyindisc_switch.isOn&&discRow.douyindisc_imageButton.enabled;
 __block CGFloat speedCommit=-1;discRow.douyindisc_changeScale=^(DouyinDiscNavigationRow *r,CGFloat value){(void)r;speedCommit=value;};[discRow.douyindisc_sizePlus sendActionsForControlEvents:UIControlEventTouchUpInside];BOOL speedStepper=fabs(discRow.douyindisc_scale-1.01)<.001&&fabs(speedCommit-1.01)<.001;
 discRow.douyindisc_sizeValue.text=@"999";[discRow douyindisc_commitSizeInput];BOOL speedMaximum=fabs(discRow.douyindisc_scale-3)<.001&&[discRow.douyindisc_sizeValue.text isEqualToString:@"300%"];
 discRow.douyindisc_sizeValue.text=@"1";[discRow douyindisc_commitSizeInput];BOOL speedMinimum=fabs(discRow.douyindisc_scale-.25)<.001&&[discRow.douyindisc_sizeValue.text isEqualToString:@"25%"];
 return labels&&controls&&rangeControls&&typed&&plusTapped&&minusTapped&&maxClamp&&minClamp&&opacityClamp&&appearanceControls&&appearanceAdjustments&&noImage&&photo&&row.bounds.size.height==350&&row.douyindisc_actions.arrangedSubviews.count==2&&row.douyindisc_clearButton.enabled&&row.douyindisc_imageButton.bounds.size.width==88&&discControls&&speedStepper&&speedMaximum&&speedMinimum;
}

extern void douyindisc_uiTestSetNavigationImage(NSString *, UIImage *, BOOL);
static double douyindisc_uiTestWindowBrightness(UIWindow *window) {
    UIGraphicsBeginImageContextWithOptions(window.bounds.size, YES, 1);
    [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];
    UIImage *image=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();
    size_t width=CGImageGetWidth(image.CGImage),height=CGImageGetHeight(image.CGImage);
    if(!width||!height)return -1000;
    NSMutableData *pixels=[NSMutableData dataWithLength:width*height*4];
    CGColorSpaceRef rgb=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(pixels.mutableBytes,width,height,8,width*4,rgb,kCGBitmapByteOrder32Big|kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(rgb);if(!context)return -1000;
    CGContextDrawImage(context,CGRectMake(0,0,width,height),image.CGImage);CGContextRelease(context);
    const uint8_t *p=pixels.bytes;double total=0;
    for(size_t i=0;i<width*height;i++)total+=p[4*i]+p[4*i+1]+p[4*i+2];
    return total/(width*height*3);
}
void douyindisc_uiTestPickerCancellationInteractive(UIWindow *window, void (^done)(NSDictionary *)) {
    if(!NSThread.isMainThread||!window||!done)return;
    DouyinDiscNavigationStore *store=DouyinDiscNavigationStore.douyindisc_sharedStore;
    douyindisc_uiTestSetNavigationImage(@"top_recommend",nil,YES);
    NSError *error=nil;
    if(![store douyindisc_saveEnabled:YES opacity:1 scale:1 identifier:@"top_recommend" error:&error]){done(@{});return;}
    UIViewController *previousRoot=window.rootViewController;
    DouyinDiscSettingsViewController *panel=[DouyinDiscSettingsViewController new];
    UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:panel];
    [panel loadViewIfNeeded];
    DouyinDiscNavigationRow *row=nil;
    for(UIView *view in panel.douyindisc_stack.arrangedSubviews)
        if([view isKindOfClass:DouyinDiscNavigationRow.class]&&[[(DouyinDiscNavigationRow *)view douyindisc_identifier] isEqualToString:@"top_recommend"]){row=(DouyinDiscNavigationRow *)view;break;}
    if(!row){window.rootViewController=previousRoot;window.hidden=NO;done(@{});return;}
    NSDictionary *before=[store douyindisc_entryForIdentifier:@"top_recommend"];
    NSString *directory=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"DouyinDisc/Navigation"];
    NSString *configPath=[directory stringByAppendingPathComponent:@"settings.plist"];
    NSData *beforeConfig=[NSData dataWithContentsOfFile:configPath];
    __block double brightness=-1000;
    __block BOOL completed=NO;
    __block BOOL photoFullScreen=NO;
    __block BOOL photoVisible=NO;
    __block BOOL cancelSent=NO;
    __block BOOL photoDirect=NO;
    __block NSUInteger generation=0;
    panel.douyindisc_uiTestPickerFinished=^(BOOL cancelled){
        if(completed)return;completed=YES;
        [panel.view layoutIfNeeded];[panel.douyindisc_scrollView layoutIfNeeded];[panel.douyindisc_stack layoutIfNeeded];[row layoutIfNeeded];[window layoutIfNeeded];
        CGPoint photoPoint=[row.douyindisc_imageButton convertPoint:CGPointMake(CGRectGetMidX(row.douyindisc_imageButton.bounds),CGRectGetMidY(row.douyindisc_imageButton.bounds)) toView:window];
        CGPoint switchPoint=[row.douyindisc_switch convertPoint:CGPointMake(CGRectGetMidX(row.douyindisc_switch.bounds),CGRectGetMidY(row.douyindisc_switch.bounds)) toView:window];
        UIView *photoHit=[window hitTest:photoPoint withEvent:nil],*switchHit=[window hitTest:switchPoint withEvent:nil];
        BOOL photoTouchable=photoHit&&(photoHit==row.douyindisc_imageButton||[photoHit isDescendantOfView:row.douyindisc_imageButton]);
        BOOL switchTouchable=switchHit&&(switchHit==row.douyindisc_switch||[switchHit isDescendantOfView:row.douyindisc_switch]);
        NSLog(@"DD_PICKER_TOUCH rowFrame=%@ scrollFrame=%@ contentOffset=%@ photoPoint=%@ photoHit=%@ photoInside=%d switchPoint=%@ switchHit=%@ switchInside=%d enabled=%d/%d",NSStringFromCGRect(row.frame),NSStringFromCGRect(panel.douyindisc_scrollView.frame),NSStringFromCGPoint(panel.douyindisc_scrollView.contentOffset),NSStringFromCGPoint(photoPoint),NSStringFromClass(photoHit.class),photoTouchable,NSStringFromCGPoint(switchPoint),NSStringFromClass(switchHit.class),switchTouchable,row.douyindisc_imageButton.enabled,row.douyindisc_switch.enabled);
        BOOL touches=photoTouchable&&switchTouchable;
        row.douyindisc_pickPhoto=^(DouyinDiscNavigationRow *selected){(void)selected;photoDirect=YES;};
        [row.douyindisc_imageButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        double after=douyindisc_uiTestWindowBrightness(window);
        NSUInteger reopenTicket=[store douyindisc_beginImagePickingForIdentifier:@"top_recommend"];
        BOOL oldTicketRevoked=reopenTicket>generation;
        [store douyindisc_finishImagePickingForIdentifier:@"top_recommend" generation:reopenTicket];
        NSMutableDictionary *results=[@{
            @"swipeRecovery":@(cancelled&&!panel.douyindisc_activePicker&&panel.douyindisc_activePickGeneration==0),
            @"ticketRevoked":@(oldTicketRevoked),
            @"interactive":@(cancelled&&touches&&row.douyindisc_imageButton.enabled&&row.douyindisc_switch.enabled),
            @"brightness":@(brightness>0&&fabs(after-brightness)<3),
            @"photoDirect":@(photoDirect),
            @"unchanged":@([[store douyindisc_entryForIdentifier:@"top_recommend"] isEqual:before]&&beforeConfig&&[beforeConfig isEqual:[NSData dataWithContentsOfFile:configPath]]),
            @"photoFullScreen":@(photoFullScreen),@"photoVisible":@(photoVisible),@"cancelSent":@(cancelSent)
        } mutableCopy];
        panel.douyindisc_uiTestPickerPresented=nil;panel.douyindisc_uiTestPickerFinished=nil;panel.douyindisc_uiTestPickerReady=nil;
        window.rootViewController=previousRoot;[window makeKeyAndVisible];done([results copy]);
    };
    panel.douyindisc_uiTestPickerPresented=^(UIViewController *picker){
        if(![picker isKindOfClass:UIImagePickerController.class])return;
        UIImagePickerController *photoPicker=(UIImagePickerController *)picker;
        douyindisc_uiTestTracePicker(@"test-observed",panel,picker);
        photoFullScreen=photoPicker.modalPresentationStyle==UIModalPresentationFullScreen;
        photoVisible=photoPicker.viewIfLoaded.window==window&&photoPicker.presentingViewController!=nil&&!photoPicker.isBeingPresented&&!photoPicker.isBeingDismissed;
        if(!photoVisible||!panel.douyindisc_uiTestPresentationCompleted)return;
        id<UIImagePickerControllerDelegate> delegate=photoPicker.delegate;
        if(delegate!=panel||![delegate respondsToSelector:@selector(imagePickerControllerDidCancel:)])return;
        cancelSent=YES;
        [delegate imagePickerControllerDidCancel:photoPicker];
    };
    __weak DouyinDiscSettingsViewController *weakPanel=panel;
    panel.douyindisc_uiTestPickerReady=^{
        DouyinDiscSettingsViewController *visiblePanel=weakPanel;
        if(!visiblePanel||completed)return;
        [visiblePanel.view layoutIfNeeded];
        brightness=douyindisc_uiTestWindowBrightness(window);
        [row.douyindisc_imageButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        generation=visiblePanel.douyindisc_activePickGeneration;
        douyindisc_uiTestTracePicker(@"test-open",visiblePanel,visiblePanel.douyindisc_activePicker);
    };
    window.rootViewController=nav;[window makeKeyAndVisible];[panel.view layoutIfNeeded];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        if(completed)return;
        completed=YES;
        douyindisc_uiTestTracePicker(@"test-timeout",panel,panel.douyindisc_activePicker);
        douyindisc_uiTestCapturePickerWindow(window,@"picker-timeout.png");
        NSDictionary *failure=@{@"photoFullScreen":@(photoFullScreen),@"photoVisible":@(photoVisible),@"cancelSent":@(cancelSent)};
        panel.douyindisc_uiTestPickerPresented=nil;panel.douyindisc_uiTestPickerFinished=nil;panel.douyindisc_uiTestPickerReady=nil;
        window.rootViewController=previousRoot;[window makeKeyAndVisible];done(failure);
    });
}
#endif
