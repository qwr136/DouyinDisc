#import "DouyinDiscNavigation.h"
#import <PhotosUI/PhotosUI.h>
#import <objc/runtime.h>
#import <math.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
static NSString * const douyindisc_utiPNG = @"public.png";
static NSString * const douyindisc_utiJPEG = @"public.jpeg";
static NSString * const douyindisc_utiHEIC = @"public.heic";
static NSString * const douyindisc_utiImage = @"public.image";

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
@property (nonatomic, strong) UIButton *douyindisc_filesButton;
@property (nonatomic, strong) UIButton *douyindisc_clearButton;
@property (nonatomic, strong) UIStackView *douyindisc_actions;
@property (nonatomic, copy) void (^douyindisc_change)(DouyinDiscNavigationRow *, BOOL, CGFloat);
@property (nonatomic, copy) void (^douyindisc_preview)(DouyinDiscNavigationRow *, CGFloat);
@property (nonatomic, copy) void (^douyindisc_changeScale)(DouyinDiscNavigationRow *, CGFloat);
@property (nonatomic, copy) void (^douyindisc_previewScale)(DouyinDiscNavigationRow *, CGFloat);
@property (nonatomic, copy) void (^douyindisc_pick)(DouyinDiscNavigationRow *, BOOL);
@property (nonatomic, copy) void (^douyindisc_clear)(DouyinDiscNavigationRow *);
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
- (void)douyindisc_filesTapped;
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
    self.douyindisc_filesButton=[UIButton buttonWithType:UIButtonTypeSystem];self.douyindisc_filesButton.translatesAutoresizingMaskIntoConstraints=NO;
    [self.douyindisc_filesButton setImage:[UIImage systemImageNamed:@"folder"] forState:UIControlStateNormal];
    self.douyindisc_filesButton.tintColor=douyindisc_color(@"#1557C0");[self.douyindisc_filesButton setTitle:@"文件" forState:UIControlStateNormal];self.douyindisc_filesButton.titleLabel.font=[UIFont systemFontOfSize:12 weight:UIFontWeightMedium];self.douyindisc_filesButton.titleEdgeInsets=UIEdgeInsetsMake(0,4,0,0);
    self.douyindisc_filesButton.accessibilityLabel=@"从文件选择图标";
    self.douyindisc_filesButton.enabled=[entry[@"enabled"] boolValue];
    self.douyindisc_filesButton.accessibilityIdentifier=[@"douyindisc.files." stringByAppendingString:self.douyindisc_identifier];
    [self.douyindisc_filesButton addTarget:self action:@selector(douyindisc_filesTapped) forControlEvents:UIControlEventTouchUpInside];
    self.douyindisc_clearButton=[UIButton buttonWithType:UIButtonTypeSystem]; self.douyindisc_clearButton.translatesAutoresizingMaskIntoConstraints=NO;
    [self.douyindisc_clearButton setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal];
    self.douyindisc_clearButton.accessibilityLabel=@"移除此项自定义图标"; self.douyindisc_clearButton.enabled=image!=nil;
    [self.douyindisc_clearButton addTarget:self action:@selector(douyindisc_clearTapped) forControlEvents:UIControlEventTouchUpInside];
    self.douyindisc_actions=[[UIStackView alloc] initWithArrangedSubviews:@[self.douyindisc_imageButton,self.douyindisc_filesButton,self.douyindisc_clearButton]];
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
    self.douyindisc_sizeTitle=[UILabel new];self.douyindisc_sizeTitle.translatesAutoresizingMaskIntoConstraints=NO;self.douyindisc_sizeTitle.text=@"图标大小";self.douyindisc_sizeTitle.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];self.douyindisc_sizeTitle.textColor=UIColor.secondaryLabelColor;self.douyindisc_sizeTitle.accessibilityIdentifier=@"douyindisc.size.title";[content addSubview:self.douyindisc_sizeTitle];
    self.douyindisc_scale=MAX(.5,MIN(1.5,[entry[@"scale"] respondsToSelector:@selector(doubleValue)]?[entry[@"scale"] doubleValue]:1));
    self.douyindisc_sizeValue=[UITextField new];self.douyindisc_sizeValue.translatesAutoresizingMaskIntoConstraints=NO;self.douyindisc_sizeValue.textAlignment=NSTextAlignmentCenter;self.douyindisc_sizeValue.font=[UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightSemibold];self.douyindisc_sizeValue.textColor=UIColor.labelColor;
    self.douyindisc_sizeValue.keyboardType=UIKeyboardTypeNumberPad;self.douyindisc_sizeValue.accessibilityIdentifier=@"douyindisc.size.value";self.douyindisc_sizeValue.accessibilityLabel=@"图标大小百分比";self.douyindisc_sizeValue.backgroundColor=UIColor.tertiarySystemGroupedBackgroundColor;self.douyindisc_sizeValue.layer.cornerRadius=8;self.douyindisc_sizeValue.layer.masksToBounds=YES;self.douyindisc_sizeValue.text=[NSString stringWithFormat:@"%d%%",(int)lrint(self.douyindisc_scale*100)];
    [self.douyindisc_sizeValue addTarget:self action:@selector(douyindisc_editingSizeInput) forControlEvents:UIControlEventEditingDidBegin];[self.douyindisc_sizeValue addTarget:self action:@selector(douyindisc_commitSizeInput) forControlEvents:UIControlEventEditingDidEnd];[content addSubview:self.douyindisc_sizeValue];
    self.douyindisc_sizeMinus=[UIButton buttonWithType:UIButtonTypeSystem];self.douyindisc_sizeMinus.translatesAutoresizingMaskIntoConstraints=NO;[self.douyindisc_sizeMinus setTitle:@"−" forState:UIControlStateNormal];self.douyindisc_sizeMinus.accessibilityLabel=@"缩小图标";
    self.douyindisc_sizePlus=[UIButton buttonWithType:UIButtonTypeSystem];self.douyindisc_sizePlus.translatesAutoresizingMaskIntoConstraints=NO;[self.douyindisc_sizePlus setTitle:@"＋" forState:UIControlStateNormal];self.douyindisc_sizePlus.accessibilityLabel=@"放大图标";
    for(UIButton *button in @[self.douyindisc_sizeMinus,self.douyindisc_sizePlus]){button.titleLabel.font=[UIFont systemFontOfSize:19 weight:UIFontWeightMedium];button.tintColor=douyindisc_color(item[@"accentColor"]);button.backgroundColor=UIColor.tertiarySystemGroupedBackgroundColor;button.layer.cornerRadius=8;[content addSubview:button];}
    [self.douyindisc_sizeMinus addTarget:self action:@selector(douyindisc_changeSizeByMinus) forControlEvents:UIControlEventTouchUpInside];[self.douyindisc_sizePlus addTarget:self action:@selector(douyindisc_changeSizeByPlus) forControlEvents:UIControlEventTouchUpInside];
    UIToolbar *sizeToolbar=[[UIToolbar alloc]initWithFrame:CGRectMake(0,0,0,44)];UIBarButtonItem *sizeSpace=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];UIBarButtonItem *sizeDone=[[UIBarButtonItem alloc]initWithTitle:@"完成" style:UIBarButtonItemStyleDone target:self action:@selector(douyindisc_inputAccessoryDone)];sizeToolbar.items=@[sizeSpace,sizeDone];self.douyindisc_sizeValue.inputAccessoryView=sizeToolbar;
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14], [content.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
        [content.topAnchor constraintEqualToAnchor:self.topAnchor constant:9], [content.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-9],
        [swatch.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [swatch.topAnchor constraintEqualToAnchor:content.topAnchor], [swatch.widthAnchor constraintEqualToConstant:36], [swatch.heightAnchor constraintEqualToConstant:36],
        [symbol.centerXAnchor constraintEqualToAnchor:swatch.centerXAnchor], [symbol.centerYAnchor constraintEqualToAnchor:swatch.centerYAnchor], [symbol.widthAnchor constraintEqualToConstant:16], [symbol.heightAnchor constraintEqualToConstant:16],
        [title.leadingAnchor constraintEqualToAnchor:swatch.trailingAnchor constant:10], [title.centerYAnchor constraintEqualToAnchor:swatch.centerYAnchor], [title.trailingAnchor constraintLessThanOrEqualToAnchor:self.douyindisc_switch.leadingAnchor constant:-6],
        [self.douyindisc_switch.trailingAnchor constraintEqualToAnchor:content.trailingAnchor], [self.douyindisc_switch.centerYAnchor constraintEqualToAnchor:swatch.centerYAnchor],
        [self.douyindisc_thumbnail.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [self.douyindisc_thumbnail.topAnchor constraintEqualToAnchor:swatch.bottomAnchor constant:8], [self.douyindisc_thumbnail.widthAnchor constraintEqualToConstant:42], [self.douyindisc_thumbnail.heightAnchor constraintEqualToConstant:42],
        [self.douyindisc_actions.leadingAnchor constraintEqualToAnchor:self.douyindisc_thumbnail.trailingAnchor constant:8], [self.douyindisc_actions.centerYAnchor constraintEqualToAnchor:self.douyindisc_thumbnail.centerYAnchor], [self.douyindisc_actions.trailingAnchor constraintLessThanOrEqualToAnchor:content.trailingAnchor],
        [self.douyindisc_imageButton.widthAnchor constraintEqualToConstant:88], [self.douyindisc_imageButton.heightAnchor constraintEqualToConstant:36], [self.douyindisc_filesButton.widthAnchor constraintEqualToConstant:76], [self.douyindisc_filesButton.heightAnchor constraintEqualToConstant:36], [self.douyindisc_clearButton.widthAnchor constraintEqualToConstant:36], [self.douyindisc_clearButton.heightAnchor constraintEqualToConstant:36],
        [self.douyindisc_opacityTitle.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [self.douyindisc_opacityTitle.centerYAnchor constraintEqualToAnchor:self.douyindisc_value.centerYAnchor],
        [self.douyindisc_opacityMinus.leadingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-146], [self.douyindisc_opacityMinus.centerYAnchor constraintEqualToAnchor:self.douyindisc_value.centerYAnchor], [self.douyindisc_opacityMinus.widthAnchor constraintEqualToConstant:34], [self.douyindisc_opacityMinus.heightAnchor constraintEqualToConstant:30],
        [self.douyindisc_value.leadingAnchor constraintEqualToAnchor:self.douyindisc_opacityMinus.trailingAnchor constant:2], [self.douyindisc_value.trailingAnchor constraintEqualToAnchor:self.douyindisc_opacityPlus.leadingAnchor constant:-2], [self.douyindisc_value.widthAnchor constraintEqualToConstant:74], [self.douyindisc_value.heightAnchor constraintEqualToConstant:30], [self.douyindisc_value.topAnchor constraintEqualToAnchor:self.douyindisc_thumbnail.bottomAnchor constant:8],
        [self.douyindisc_opacityPlus.trailingAnchor constraintEqualToAnchor:content.trailingAnchor], [self.douyindisc_opacityPlus.centerYAnchor constraintEqualToAnchor:self.douyindisc_value.centerYAnchor], [self.douyindisc_opacityPlus.widthAnchor constraintEqualToConstant:34], [self.douyindisc_opacityPlus.heightAnchor constraintEqualToConstant:30],
        [self.douyindisc_sizeTitle.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [self.douyindisc_sizeTitle.centerYAnchor constraintEqualToAnchor:self.douyindisc_sizeValue.centerYAnchor],
        [self.douyindisc_sizeMinus.leadingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-146], [self.douyindisc_sizeMinus.topAnchor constraintEqualToAnchor:self.douyindisc_value.bottomAnchor constant:8], [self.douyindisc_sizeMinus.widthAnchor constraintEqualToConstant:34], [self.douyindisc_sizeMinus.heightAnchor constraintEqualToConstant:30],
        [self.douyindisc_sizeValue.leadingAnchor constraintEqualToAnchor:self.douyindisc_sizeMinus.trailingAnchor constant:2], [self.douyindisc_sizeValue.trailingAnchor constraintEqualToAnchor:self.douyindisc_sizePlus.leadingAnchor constant:-2], [self.douyindisc_sizeValue.widthAnchor constraintEqualToConstant:74], [self.douyindisc_sizeValue.heightAnchor constraintEqualToConstant:30],
        [self.douyindisc_sizePlus.trailingAnchor constraintEqualToAnchor:content.trailingAnchor], [self.douyindisc_sizePlus.centerYAnchor constraintEqualToAnchor:self.douyindisc_sizeValue.centerYAnchor], [self.douyindisc_sizePlus.widthAnchor constraintEqualToConstant:34], [self.douyindisc_sizePlus.heightAnchor constraintEqualToConstant:30],
        [self.douyindisc_sizeValue.centerYAnchor constraintEqualToAnchor:self.douyindisc_sizeMinus.centerYAnchor],
        [self.heightAnchor constraintEqualToConstant:198]
    ]];
    return self;
}
- (void)douyindisc_setImagePickingEnabled:(BOOL)enabled { self.douyindisc_imageButton.enabled=enabled;self.douyindisc_filesButton.enabled=enabled; }
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
- (void)douyindisc_adjustSize:(NSInteger)delta {[self.douyindisc_sizeValue resignFirstResponder];NSInteger v=MAX(50,MIN(150,(NSInteger)lrint(self.douyindisc_scale*100)+delta));self.douyindisc_scale=v/100.0;self.douyindisc_sizeValue.text=[NSString stringWithFormat:@"%ld%%",(long)v];if(self.douyindisc_previewScale)self.douyindisc_previewScale(self,self.douyindisc_scale);if(self.douyindisc_changeScale)self.douyindisc_changeScale(self,self.douyindisc_scale);}
- (void)douyindisc_commitOpacityInput {NSString *raw=[self.douyindisc_value.text stringByReplacingOccurrencesOfString:@"%" withString:@""];if(![self douyindisc_validPercentText:raw]){self.douyindisc_value.text=[NSString stringWithFormat:@"%d%%",(int)lrint(self.douyindisc_opacity*100)];return;}double parsed=raw.doubleValue;if(!isfinite(parsed)){self.douyindisc_value.text=[NSString stringWithFormat:@"%d%%",(int)lrint(self.douyindisc_opacity*100)];return;}NSInteger v=(NSInteger)lrint(MIN(100.0,MAX(0.0,parsed)));self.douyindisc_opacity=v/100.0;self.douyindisc_value.text=[NSString stringWithFormat:@"%ld%%",(long)v];if(self.douyindisc_preview)self.douyindisc_preview(self,self.douyindisc_opacity);if(self.douyindisc_change)self.douyindisc_change(self,self.douyindisc_switch.isOn,self.douyindisc_opacity);}
- (void)douyindisc_commitSizeInput {NSString *raw=[self.douyindisc_sizeValue.text stringByReplacingOccurrencesOfString:@"%" withString:@""];if(![self douyindisc_validPercentText:raw]){self.douyindisc_sizeValue.text=[NSString stringWithFormat:@"%d%%",(int)lrint(self.douyindisc_scale*100)];return;}double parsed=raw.doubleValue;if(!isfinite(parsed)){self.douyindisc_sizeValue.text=[NSString stringWithFormat:@"%d%%",(int)lrint(self.douyindisc_scale*100)];return;}NSInteger v=(NSInteger)lrint(MIN(150.0,MAX(50.0,parsed)));self.douyindisc_scale=v/100.0;self.douyindisc_sizeValue.text=[NSString stringWithFormat:@"%ld%%",(long)v];if(self.douyindisc_previewScale)self.douyindisc_previewScale(self,self.douyindisc_scale);if(self.douyindisc_changeScale)self.douyindisc_changeScale(self,self.douyindisc_scale);}
- (void)douyindisc_switchChanged {if(self.douyindisc_change)self.douyindisc_change(self,self.douyindisc_switch.isOn,self.douyindisc_opacity);}
- (void)douyindisc_photoTapped { if(self.douyindisc_imageButton.enabled&&self.douyindisc_pick)self.douyindisc_pick(self,NO); }
- (void)douyindisc_filesTapped { if(self.douyindisc_filesButton.enabled&&self.douyindisc_pick)self.douyindisc_pick(self,YES); }
- (void)douyindisc_setEnabledAfterCommit:(BOOL)enabled { self.douyindisc_switch.on=enabled; [self douyindisc_setImagePickingEnabled:enabled]; }
- (void)douyindisc_clearTapped { if (self.douyindisc_clear) self.douyindisc_clear(self); }
@end

@interface DouyinDiscSettingsViewController (DouyinDiscPickerDismissHandling)
- (void)presentationControllerWillDismiss:(UIPresentationController *)presentationController;
- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController;
- (void)douyindisc_installDismissProxyForPicker:(UIViewController *)picker;
- (void)douyindisc_finishAdaptiveDismissForPicker:(UIViewController *)picker;
@end
@interface DouyinDiscPickerDismissProxy : NSObject <UIAdaptivePresentationControllerDelegate>
@property(nonatomic,strong) id<UIAdaptivePresentationControllerDelegate> next;
@property(nonatomic,weak) DouyinDiscSettingsViewController *owner;
@property(nonatomic,weak) UIViewController *picker;
@end
@implementation DouyinDiscPickerDismissProxy
- (BOOL)presentationControllerShouldDismiss:(UIPresentationController *)pc {
    (void)pc;
    if(self.picker&&self.owner)return NO;
    id<UIAdaptivePresentationControllerDelegate> next=self.next;
    return [next respondsToSelector:_cmd]?[next presentationControllerShouldDismiss:pc]:YES;
}
- (void)presentationControllerWillDismiss:(UIPresentationController *)pc {
    id<UIViewControllerTransitionCoordinator> transition=pc.presentedViewController.transitionCoordinator;
    if(transition){
        __weak UIViewController *picker=self.picker;
        __weak DouyinDiscSettingsViewController *owner=self.owner;
        [transition animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context){
            if(context.isCancelled)[owner douyindisc_installDismissProxyForPicker:picker];
        }];
    }
    id<UIAdaptivePresentationControllerDelegate> next=self.next;
    if([next respondsToSelector:_cmd]&&next!=(id)self)[next presentationControllerWillDismiss:pc];
}
- (void)presentationControllerDidDismiss:(UIPresentationController *)pc {
    UIViewController *picker=self.picker;DouyinDiscSettingsViewController *owner=self.owner;
    id<UIAdaptivePresentationControllerDelegate> next=self.next;
    if(picker&&owner)[owner douyindisc_finishAdaptiveDismissForPicker:picker];
    if([next respondsToSelector:_cmd]&&next!=(id)self)[next presentationControllerDidDismiss:pc];
    self.next=nil;self.picker=nil;self.owner=nil;
}
- (BOOL)respondsToSelector:(SEL)selector{return [super respondsToSelector:selector]||[self.next respondsToSelector:selector];}
- (id)forwardingTargetForSelector:(SEL)selector{return [self.next respondsToSelector:selector]?self.next:[super forwardingTargetForSelector:selector];}
@end
@interface DouyinDiscSettingsViewController () <PHPickerViewControllerDelegate, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate>
@property (nonatomic, strong) UIScrollView *douyindisc_scrollView;
@property (nonatomic, strong) UIStackView *douyindisc_stack;
@property (nonatomic, weak) DouyinDiscNavigationRow *douyindisc_activeRow;
@property (nonatomic, copy) NSString *douyindisc_activeIdentifier;
@property (nonatomic) NSUInteger douyindisc_activePickGeneration;
@property (nonatomic, strong) UIViewController *douyindisc_activePicker;
@property (nonatomic, strong) NSObject<UIAdaptivePresentationControllerDelegate> *douyindisc_activeDismissProxy;
@property (nonatomic, strong) NSTimer *douyindisc_pickerMonitor;
@property (nonatomic) BOOL douyindisc_pickerWasAttached;
@property (nonatomic) BOOL douyindisc_pickerMonitorDismissRequested;
@property (nonatomic) NSUInteger douyindisc_pickerDetachedSamples;
@property (nonatomic) BOOL douyindisc_pickerHasResult;
@property (nonatomic) BOOL douyindisc_pickerHasProvider;
@property (nonatomic) NSUInteger douyindisc_pickerRecoveryGeneration;
@property (nonatomic) NSUInteger douyindisc_pickerRecoveryAttempts;
#if defined(DOUYINDISC_UI_TEST)
@property (nonatomic, copy) void (^douyindisc_uiTestPickerFinished)(BOOL cancelled);
@property (nonatomic, copy) void (^douyindisc_uiTestPickerPresented)(UIViewController *picker);
@property (nonatomic, copy) dispatch_block_t douyindisc_uiTestPickerReady;
#endif
- (void)douyindisc_presentPickerForRow:(DouyinDiscNavigationRow *)row files:(BOOL)files;
- (void)douyindisc_finishPickerUI:(UIViewController *)picker cancelled:(BOOL)cancelled keepImportTicket:(BOOL)keepImportTicket;
- (void)douyindisc_finishImportSessionIdentifier:(NSString *)identifier generation:(NSUInteger)generation;
- (void)douyindisc_dismissPicker:(UIViewController *)picker completion:(dispatch_block_t)completion;
- (void)douyindisc_schedulePickerRecovery:(UIViewController *)picker generation:(NSUInteger)generation;
- (void)douyindisc_startPickerMonitor:(UIViewController *)picker generation:(NSUInteger)generation;
- (void)douyindisc_checkPickerRecovery:(UIViewController *)picker generation:(NSUInteger)generation recovery:(NSUInteger)recovery;
- (void)douyindisc_loadPhotoProvider:(NSItemProvider *)provider types:(NSArray<NSString *> *)types index:(NSUInteger)index identifier:(NSString *)identifier pickingGeneration:(NSUInteger)pickingGeneration error:(NSError *)lastError;
- (void)douyindisc_commitImageData:(NSData *)data identifier:(NSString *)identifier pickingGeneration:(NSUInteger)pickingGeneration;
@end

@implementation DouyinDiscSettingsViewController
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    UIViewController *picker=self.douyindisc_activePicker;
    if(picker){
        if(!self.presentedViewController&&!picker.isBeingPresented&&!picker.isBeingDismissed&&(!picker.isViewLoaded||!picker.view.window)){BOOL hasProvider=self.douyindisc_pickerHasProvider;[self douyindisc_finishPickerUI:picker cancelled:!hasProvider keepImportTicket:hasProvider];}
        else [self douyindisc_schedulePickerRecovery:picker generation:self.douyindisc_activePickGeneration];
    }
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
    UILabel *title=[UILabel new];title.text=@"首页导航图标";title.font=[UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    UILabel *notice=[UILabel new];notice.numberOfLines=0;notice.font=[UIFont systemFontOfSize:12];notice.textColor=UIColor.secondaryLabelColor;notice.text=@"自定义首页分类与底部导航。关闭开关或未选图时保留抖音原样。";
    [intro addArrangedSubview:title];[intro addArrangedSubview:notice];[self.douyindisc_stack addArrangedSubview:intro];
    for (NSDictionary *item in douyindisc_navigationItems()) {
        NSString *group = [item[@"identifier"] hasPrefix:@"top_"] ? @"首页顶部分类" : @"底部导航";
        BOOL needsHeader = self.douyindisc_stack.arrangedSubviews.count == 1 ||
            (([item[@"identifier"] isEqual:@"bottom_home"]));
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
        row.douyindisc_pick = ^(DouyinDiscNavigationRow *selected, BOOL files) { [weakSelf douyindisc_presentPickerForRow:selected files:files]; };
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
- (void)douyindisc_installDismissProxyForPicker:(UIViewController *)picker {
    if (!picker || self.douyindisc_activePicker != picker) return;
    UIPresentationController *presentation=picker.presentationController;if(!presentation)return;
    DouyinDiscPickerDismissProxy *proxy=[self.douyindisc_activeDismissProxy isKindOfClass:DouyinDiscPickerDismissProxy.class]?(DouyinDiscPickerDismissProxy *)self.douyindisc_activeDismissProxy:[DouyinDiscPickerDismissProxy new];
    id<UIAdaptivePresentationControllerDelegate> current=presentation.delegate;
    if(current!=(id)proxy)proxy.next=current;
    proxy.owner=self;proxy.picker=picker;self.douyindisc_activeDismissProxy=proxy;presentation.delegate=proxy;
}
- (void)douyindisc_presentPickerForRow:(DouyinDiscNavigationRow *)row files:(BOOL)files {
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
    UIViewController *picker;
    if (files) {
        UIDocumentPickerViewController *document=[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType typeWithIdentifier:douyindisc_utiImage]] asCopy:YES];
        document.delegate=self; picker=document;
    } else {
        PHPickerConfiguration *config=[PHPickerConfiguration new];
        config.filter=[PHPickerFilter imagesFilter]; config.selectionLimit=1;
        PHPickerViewController *photos=[[PHPickerViewController alloc] initWithConfiguration:config];
        photos.delegate=self; photos.modalInPresentation=YES; picker=photos;
    }
    self.douyindisc_activePicker=picker;
    if([picker isKindOfClass:PHPickerViewController.class])[self douyindisc_installDismissProxyForPicker:picker];
    __weak typeof(self) weakSelf=self;
    [self presentViewController:picker animated:YES completion:^{
        if(weakSelf.douyindisc_activePicker==picker){
            if([picker isKindOfClass:PHPickerViewController.class])[weakSelf douyindisc_installDismissProxyForPicker:picker];
            [weakSelf douyindisc_schedulePickerRecovery:picker generation:weakSelf.douyindisc_activePickGeneration];
            if([picker isKindOfClass:PHPickerViewController.class])[weakSelf douyindisc_startPickerMonitor:picker generation:weakSelf.douyindisc_activePickGeneration];
        }
#if defined(DOUYINDISC_UI_TEST)
        if(weakSelf.douyindisc_uiTestPickerPresented)weakSelf.douyindisc_uiTestPickerPresented(picker);
#endif
    }];
}
- (void)douyindisc_finishPickerUI:(UIViewController *)picker cancelled:(BOOL)cancelled keepImportTicket:(BOOL)keepImportTicket {
    if (!picker || self.douyindisc_activePicker!=picker) return;
    if (cancelled && !keepImportTicket) [DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_finishImagePickingForIdentifier:self.douyindisc_activeIdentifier generation:self.douyindisc_activePickGeneration];
    [self.douyindisc_pickerMonitor invalidate];self.douyindisc_pickerMonitor=nil;self.douyindisc_pickerWasAttached=NO;self.douyindisc_pickerMonitorDismissRequested=NO;self.douyindisc_pickerDetachedSamples=0;
    self.douyindisc_activePicker=nil;
    self.douyindisc_activeDismissProxy=nil;
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
- (void)douyindisc_dismissPicker:(UIViewController *)picker completion:(dispatch_block_t)completion {
    if (!picker.presentingViewController) { if (completion) completion(); return; }
    id<UIViewControllerTransitionCoordinator> transition=picker.transitionCoordinator;
    if (picker.isBeingDismissed && transition) {
        __weak typeof(self) weakSelf=self;
        BOOL registered=[transition animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            if (context.isCancelled) {
                if (weakSelf.douyindisc_activePicker==picker) {
                    weakSelf.douyindisc_pickerHasResult=NO;
                    weakSelf.douyindisc_pickerHasProvider=NO;
                    [weakSelf douyindisc_schedulePickerRecovery:picker generation:weakSelf.douyindisc_activePickGeneration];
                }
            } else if (completion) completion();
        }];
        if (registered) return;
    }
    [picker dismissViewControllerAnimated:YES completion:completion];
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
- (void)douyindisc_finishAdaptiveDismissForPicker:(UIViewController *)picker {
    if(!picker||self.douyindisc_activePicker!=picker)return;
    BOOL hasProvider=self.douyindisc_pickerHasProvider;
    [self douyindisc_finishPickerUI:picker cancelled:!hasProvider keepImportTicket:hasProvider];
}
- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    UIViewController *picker=presentationController.presentedViewController;
    [self douyindisc_finishAdaptiveDismissForPicker:picker];
}
- (void)douyindisc_loadPhotoProvider:(NSItemProvider *)provider types:(NSArray<NSString *> *)types index:(NSUInteger)index identifier:(NSString *)identifier pickingGeneration:(NSUInteger)pickingGeneration error:(NSError *)lastError {
    if(index>=types.count){
        if([provider canLoadObjectOfClass:UIImage.class]){
            __weak typeof(self) weakSelf=self;
            [provider loadObjectOfClass:UIImage.class completionHandler:^(id object,NSError *objectError){
                dispatch_async(dispatch_get_main_queue(),^{NSData *fallback=[object isKindOfClass:UIImage.class]?UIImagePNGRepresentation(object):nil;if(fallback)[weakSelf douyindisc_commitImageData:fallback identifier:identifier pickingGeneration:pickingGeneration];else {[weakSelf douyindisc_finishImportSessionIdentifier:identifier generation:pickingGeneration];[weakSelf douyindisc_showError:objectError?:lastError?:[NSError errorWithDomain:@"com.minis.douyindisc.navigation" code:2 userInfo:@{NSLocalizedDescriptionKey:@"照片无法解码为静态图片。"}]];}});
            }];
        } else dispatch_async(dispatch_get_main_queue(),^{[self douyindisc_finishImportSessionIdentifier:identifier generation:pickingGeneration];[self douyindisc_showError:lastError?:[NSError errorWithDomain:@"com.minis.douyindisc.navigation" code:2 userInfo:@{NSLocalizedDescriptionKey:@"照片提供器没有返回可读取的图片数据。"}]];});
        return;
    }
    NSString *type=types[index];
    if(![provider hasItemConformingToTypeIdentifier:type]){[self douyindisc_loadPhotoProvider:provider types:types index:index+1 identifier:identifier pickingGeneration:pickingGeneration error:lastError];return;}
    __weak typeof(self) weakSelf=self;
    [provider loadDataRepresentationForTypeIdentifier:type completionHandler:^(NSData *data,NSError *error){
        if(data.length&&[DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_decodeImageData:data])dispatch_async(dispatch_get_main_queue(),^{[weakSelf douyindisc_commitImageData:data identifier:identifier pickingGeneration:pickingGeneration];});
        else [weakSelf douyindisc_loadPhotoProvider:provider types:types index:index+1 identifier:identifier pickingGeneration:pickingGeneration error:error?:lastError];
    }];
}
- (void)douyindisc_commitImageData:(NSData *)data identifier:(NSString *)identifier pickingGeneration:(NSUInteger)pickingGeneration {
    __weak typeof(self) weakSelf=self;
    [[DouyinDiscNavigationStore douyindisc_sharedStore] douyindisc_saveImageData:data identifier:identifier pickingGeneration:pickingGeneration completion:^(NSError *error){
        DouyinDiscSettingsViewController *strongSelf=weakSelf;
        if(error){[strongSelf douyindisc_finishImportSessionIdentifier:identifier generation:pickingGeneration];if(strongSelf.isViewLoaded&&strongSelf.view.window)[strongSelf douyindisc_showError:error];return;}
        for(UIView *view in strongSelf.douyindisc_stack.arrangedSubviews){
            if(![view isKindOfClass:DouyinDiscNavigationRow.class])continue;
            DouyinDiscNavigationRow *row=(DouyinDiscNavigationRow *)view;
            if(![row.douyindisc_identifier isEqualToString:identifier])continue;
            row.douyindisc_thumbnail.image=[[DouyinDiscNavigationStore douyindisc_sharedStore] douyindisc_imageForIdentifier:identifier];
            [row douyindisc_setHasImage:YES];break;
        }
    }];
}
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    if (self.douyindisc_activePicker!=picker || self.douyindisc_pickerHasResult) return;
    NSString *identifier=[self.douyindisc_activeIdentifier copy];
    NSUInteger generation=self.douyindisc_activePickGeneration;
    NSItemProvider *provider=results.firstObject.itemProvider;
    self.douyindisc_pickerHasResult=YES;
    self.douyindisc_pickerHasProvider=provider!=nil;
    __weak typeof(self) weakSelf=self;
    [self douyindisc_dismissPicker:picker completion:^{
        [weakSelf douyindisc_finishPickerUI:picker cancelled:!provider keepImportTicket:provider!=nil];
        if (!provider) return;
        NSArray<NSString *> *types=@[douyindisc_utiPNG,douyindisc_utiJPEG,douyindisc_utiHEIC,@"public.heif",@"public.tiff",@"public.gif",douyindisc_utiImage];
        [weakSelf douyindisc_loadPhotoProvider:provider types:types index:0 identifier:identifier pickingGeneration:generation error:nil];
    }];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (self.douyindisc_activePicker!=controller || self.douyindisc_pickerHasResult) return;
    NSURL *url=urls.firstObject;
    NSString *identifier=[self.douyindisc_activeIdentifier copy]; NSUInteger generation=self.douyindisc_activePickGeneration;
    self.douyindisc_pickerHasResult=YES;
    self.douyindisc_pickerHasProvider=url!=nil;
    [self douyindisc_dismissPicker:controller completion:^{
        [self douyindisc_finishPickerUI:controller cancelled:!url keepImportTicket:url!=nil];
        if (!url || !identifier || !generation) return;
        BOOL scoped=[url startAccessingSecurityScopedResource];
    __weak typeof(self) weakSelf=self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
        __block NSData *data=nil; __block NSError *readError=nil;
        NSFileCoordinator *coordinator=[[NSFileCoordinator alloc] initWithFilePresenter:nil];
        [coordinator coordinateReadingItemAtURL:url options:0 error:&readError byAccessor:^(NSURL *readURL){
            NSNumber *size=nil; BOOL hasSize=[readURL getResourceValue:&size forKey:NSURLFileSizeKey error:&readError];
            if(!hasSize||!size||!size.unsignedLongLongValue){readError=readError?:[NSError errorWithDomain:@"com.minis.douyindisc.navigation" code:3 userInfo:@{NSLocalizedDescriptionKey:@"无法读取图片文件信息，请先下载到本机再导入。"}];return;}
            if(size.unsignedLongLongValue>64*1024*1024){readError=[NSError errorWithDomain:@"com.minis.douyindisc.navigation" code:3 userInfo:@{NSLocalizedDescriptionKey:@"图片文件超过 64 MiB。"}];return;}
            data=[NSData dataWithContentsOfURL:readURL options:NSDataReadingMappedIfSafe error:&readError];
        }];
        if(scoped)[url stopAccessingSecurityScopedResource];
        dispatch_async(dispatch_get_main_queue(), ^{if(data)[weakSelf douyindisc_commitImageData:data identifier:identifier pickingGeneration:generation];else {[weakSelf douyindisc_finishImportSessionIdentifier:identifier generation:generation];[weakSelf douyindisc_showError:readError];}});
    });
    }];
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    if (self.douyindisc_activePicker!=controller || self.douyindisc_pickerHasResult) return;
    self.douyindisc_pickerHasResult=YES;
    __weak typeof(self) weakSelf=self;
    [self douyindisc_dismissPicker:controller completion:^{ [weakSelf douyindisc_finishPickerUI:controller cancelled:YES keepImportTicket:NO]; }];
}
@end

#if defined(DOUYINDISC_UI_TEST)
BOOL douyindisc_uiTestPickerAppearanceStable(UIImage *image) {
 NSDictionary *item=douyindisc_navigationItems().firstObject;DouyinDiscNavigationRow *row=[[DouyinDiscNavigationRow alloc]initWithItem:item entry:@{@"enabled":@NO,@"opacity":@.99,@"scale":@.89} image:nil];row.frame=CGRectMake(0,0,390,198);[row setNeedsLayout];[row layoutIfNeeded];
 BOOL labels=[row.douyindisc_opacityTitle.text isEqualToString:@"透明度"]&&[row.douyindisc_sizeTitle.text isEqualToString:@"图标大小"];
 BOOL controls=[row.douyindisc_value isKindOfClass:UITextField.class]&&[row.douyindisc_sizeValue isKindOfClass:UITextField.class]&&row.douyindisc_opacityMinus&&row.douyindisc_opacityPlus&&row.douyindisc_sizeMinus&&row.douyindisc_sizePlus;
 BOOL rangeControls=row.douyindisc_value.keyboardType==UIKeyboardTypeNumberPad&&row.douyindisc_sizeValue.keyboardType==UIKeyboardTypeNumberPad&&fabs(CGRectGetHeight(row.douyindisc_value.frame)-30)<1&&fabs(CGRectGetHeight(row.douyindisc_sizeValue.frame)-30)<1&&fabs(CGRectGetMidY(row.douyindisc_sizeValue.frame)-CGRectGetMidY(row.douyindisc_sizeMinus.frame))<1;
 __block CGFloat preview=-1,committed=-1;row.douyindisc_previewScale=^(DouyinDiscNavigationRow *r,CGFloat x){(void)r;preview=x;};row.douyindisc_changeScale=^(DouyinDiscNavigationRow *r,CGFloat x){(void)r;committed=x;};row.douyindisc_sizeValue.text=@"125";[row douyindisc_commitSizeInput];BOOL typed=fabs(preview-1.25)<.001&&fabs(committed-1.25)<.001&&[row.douyindisc_sizeValue.text isEqualToString:@"125%"];
 [row.douyindisc_sizePlus sendActionsForControlEvents:UIControlEventTouchUpInside];BOOL plusTapped=fabs(row.douyindisc_scale-1.26)<.001;[row.douyindisc_sizeMinus sendActionsForControlEvents:UIControlEventTouchUpInside];BOOL minusTapped=fabs(row.douyindisc_scale-1.25)<.001;row.douyindisc_sizeValue.text=@"999";[row douyindisc_commitSizeInput];BOOL maxClamp=fabs(row.douyindisc_scale-1.5)<.001;row.douyindisc_sizeValue.text=@"1";[row douyindisc_commitSizeInput];BOOL minClamp=fabs(row.douyindisc_scale-.5)<.001;
 __block CGFloat opacity=-1;row.douyindisc_change=^(DouyinDiscNavigationRow *r,BOOL on,CGFloat x){(void)r;(void)on;opacity=x;};row.douyindisc_value.text=@"120";[row douyindisc_commitOpacityInput];BOOL opacityClamp=fabs(opacity-1)<.001&&[row.douyindisc_value.text isEqualToString:@"100%"];
 BOOL noImage=[[row.douyindisc_imageButton titleForState:UIControlStateNormal] isEqualToString:@"照片"]&&row.douyindisc_imageButton.currentImage!=nil&&row.douyindisc_thumbnail.image==nil&&!row.douyindisc_imageButton.enabled;[row douyindisc_setImagePickingEnabled:YES];__block NSInteger source=-1;row.douyindisc_pick=^(DouyinDiscNavigationRow *r,BOOL files){(void)r;source=files?1:0;};[row.douyindisc_imageButton sendActionsForControlEvents:UIControlEventTouchUpInside];BOOL photo=source==0;source=-1;[row.douyindisc_filesButton sendActionsForControlEvents:UIControlEventTouchUpInside];BOOL files=source==1;
 row.douyindisc_thumbnail.image=image;[row douyindisc_setHasImage:YES];[row douyindisc_setEnabledAfterCommit:NO];
 return labels&&controls&&rangeControls&&typed&&plusTapped&&minusTapped&&maxClamp&&minClamp&&minClamp&&opacityClamp&&noImage&&photo&&files&&row.bounds.size.height==198&&row.douyindisc_actions.arrangedSubviews.count==3&&row.douyindisc_clearButton.enabled&&row.douyindisc_imageButton.bounds.size.width==88;
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
    window.rootViewController=nav;[window makeKeyAndVisible];[panel.view layoutIfNeeded];
    DouyinDiscNavigationRow *row=nil;
    for(UIView *view in panel.douyindisc_stack.arrangedSubviews)
        if([view isKindOfClass:DouyinDiscNavigationRow.class]&&[[(DouyinDiscNavigationRow *)view douyindisc_identifier] isEqualToString:@"top_recommend"]){row=(DouyinDiscNavigationRow *)view;break;}
    if(!row){window.rootViewController=previousRoot;window.hidden=NO;done(@{});return;}
    NSDictionary *before=[store douyindisc_entryForIdentifier:@"top_recommend"];
    NSString *directory=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"DouyinDisc/Navigation"];
    NSString *configPath=[directory stringByAppendingPathComponent:@"settings.plist"];
    NSData *beforeConfig=[NSData dataWithContentsOfFile:configPath];
    double brightness=douyindisc_uiTestWindowBrightness(window);
    __block BOOL completed=NO;
    __block BOOL photoSwipeLocked=NO;
    __block NSInteger source=-1;
    __block NSUInteger generation=0;
    panel.douyindisc_uiTestPickerFinished=^(BOOL cancelled){
        if(completed)return;completed=YES;
        [panel.view layoutIfNeeded];[window layoutIfNeeded];
        CGPoint photoPoint=[row.douyindisc_imageButton convertPoint:CGPointMake(CGRectGetMidX(row.douyindisc_imageButton.bounds),CGRectGetMidY(row.douyindisc_imageButton.bounds)) toView:window];
        CGPoint filePoint=[row.douyindisc_filesButton convertPoint:CGPointMake(CGRectGetMidX(row.douyindisc_filesButton.bounds),CGRectGetMidY(row.douyindisc_filesButton.bounds)) toView:window];
        CGPoint switchPoint=[row.douyindisc_switch convertPoint:CGPointMake(CGRectGetMidX(row.douyindisc_switch.bounds),CGRectGetMidY(row.douyindisc_switch.bounds)) toView:window];
        BOOL touches=[window hitTest:photoPoint withEvent:nil]&&[[window hitTest:photoPoint withEvent:nil] isDescendantOfView:row.douyindisc_imageButton]&&[[window hitTest:filePoint withEvent:nil] isDescendantOfView:row.douyindisc_filesButton]&&[[window hitTest:switchPoint withEvent:nil] isDescendantOfView:row.douyindisc_switch];
        row.douyindisc_pick=^(DouyinDiscNavigationRow *selected,BOOL files){(void)selected;source=files?1:0;};
        [row.douyindisc_imageButton sendActionsForControlEvents:UIControlEventTouchUpInside];BOOL photoDirect=source==0;
        source=-1;[row.douyindisc_filesButton sendActionsForControlEvents:UIControlEventTouchUpInside];BOOL fileDirect=source==1;
        double after=douyindisc_uiTestWindowBrightness(window);
        NSUInteger reopenTicket=[store douyindisc_beginImagePickingForIdentifier:@"top_recommend"];
        BOOL oldTicketRevoked=reopenTicket>generation;
        [store douyindisc_finishImagePickingForIdentifier:@"top_recommend" generation:reopenTicket];
        NSMutableDictionary *results=[@{
            @"swipeRecovery":@(cancelled&&!panel.douyindisc_activePicker&&panel.douyindisc_activePickGeneration==0),
            @"ticketRevoked":@(oldTicketRevoked),
            @"interactive":@(cancelled&&touches&&row.douyindisc_imageButton.enabled&&row.douyindisc_filesButton.enabled&&row.douyindisc_switch.enabled),
            @"brightness":@(brightness>0&&fabs(after-brightness)<3),
            @"photoDirect":@(photoDirect),@"fileDirect":@(fileDirect),
            @"unchanged":@([[store douyindisc_entryForIdentifier:@"top_recommend"] isEqual:before]&&beforeConfig&&[beforeConfig isEqual:[NSData dataWithContentsOfFile:configPath]]),
            @"photoSwipeLocked":@(photoSwipeLocked)
        } mutableCopy];
        panel.douyindisc_uiTestPickerPresented=nil;panel.douyindisc_uiTestPickerFinished=nil;panel.douyindisc_uiTestPickerReady=nil;
        window.rootViewController=previousRoot;[window makeKeyAndVisible];done([results copy]);
    };
    panel.douyindisc_uiTestPickerPresented=^(UIViewController *picker){
        if(![picker isKindOfClass:PHPickerViewController.class])return;
        UIPresentationController *presentation=picker.presentationController;id<UIAdaptivePresentationControllerDelegate> dismissDelegate=(id)panel.douyindisc_activeDismissProxy;photoSwipeLocked=[dismissDelegate respondsToSelector:@selector(presentationControllerShouldDismiss:)]&&! [dismissDelegate presentationControllerShouldDismiss:presentation];
        presentation.delegate=nil;
        PHPickerViewController *photoPicker=(PHPickerViewController *)picker;
        id<PHPickerViewControllerDelegate> delegate=photoPicker.delegate;
        [delegate picker:photoPicker didFinishPicking:@[]];
    };
    [panel.view layoutIfNeeded];
    [row.douyindisc_imageButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,8*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        if(!completed&&panel.douyindisc_activePicker&&panel.douyindisc_activePickGeneration==generation)[panel viewDidAppear:NO];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        if(completed)return;window.rootViewController=previousRoot;window.hidden=NO;done(@{});
    });
}
#endif
