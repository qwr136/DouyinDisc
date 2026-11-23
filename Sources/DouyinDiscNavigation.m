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
@property (nonatomic, strong) UISlider *douyindisc_slider;
@property (nonatomic, strong) UILabel *douyindisc_value;
@property (nonatomic, strong) UILabel *douyindisc_opacityTitle;
@property (nonatomic, strong) UISlider *douyindisc_sizeSlider;
@property (nonatomic, strong) UILabel *douyindisc_sizeValue;
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
- (void)douyindisc_sliderChanged;
- (void)douyindisc_sizeSliderChanged;
- (void)douyindisc_sizeSliderEnded;
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
    self.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.layer.cornerRadius = 10;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.masksToBounds = YES;
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
    [self.douyindisc_imageButton setTitle:@"选择图标" forState:UIControlStateNormal];
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
    self.douyindisc_filesButton.tintColor=douyindisc_color(@"#1557C0");
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
    self.douyindisc_value=[UILabel new]; self.douyindisc_value.translatesAutoresizingMaskIntoConstraints=NO;
    self.douyindisc_value.font=[UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightRegular]; self.douyindisc_value.textColor=UIColor.secondaryLabelColor;
    self.douyindisc_value.accessibilityIdentifier=@"douyindisc.opacity.value";
    [content addSubview:self.douyindisc_value];
    self.douyindisc_opacityTitle=[UILabel new];self.douyindisc_opacityTitle.translatesAutoresizingMaskIntoConstraints=NO;
    self.douyindisc_opacityTitle.text=@"透明度";self.douyindisc_opacityTitle.font=[UIFont systemFontOfSize:12 weight:UIFontWeightMedium];self.douyindisc_opacityTitle.textColor=UIColor.secondaryLabelColor;
    self.douyindisc_opacityTitle.accessibilityIdentifier=@"douyindisc.opacity.title";
    [content addSubview:self.douyindisc_opacityTitle];
    self.douyindisc_slider=[UISlider new]; self.douyindisc_slider.translatesAutoresizingMaskIntoConstraints=NO;
    self.douyindisc_slider.accessibilityLabel=@"图标透明度";
    self.douyindisc_slider.minimumValue=0; self.douyindisc_slider.maximumValue=1; self.douyindisc_slider.value=[entry[@"opacity"] floatValue];
    self.douyindisc_slider.minimumTrackTintColor=douyindisc_color(item[@"accentColor"]);
    [self.douyindisc_slider addTarget:self action:@selector(douyindisc_sliderChanged) forControlEvents:UIControlEventValueChanged];
    [self.douyindisc_slider addTarget:self action:@selector(douyindisc_sliderEnded) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventEditingDidEnd];
    [content addSubview:self.douyindisc_slider]; [self douyindisc_updateValue];
    self.douyindisc_sizeValue=[UILabel new]; self.douyindisc_sizeValue.translatesAutoresizingMaskIntoConstraints=NO;
    self.douyindisc_sizeValue.font=[UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightRegular]; self.douyindisc_sizeValue.textColor=UIColor.secondaryLabelColor;
    self.douyindisc_sizeValue.accessibilityIdentifier=@"douyindisc.size.value";
    [content addSubview:self.douyindisc_sizeValue];
    self.douyindisc_sizeTitle=[UILabel new];self.douyindisc_sizeTitle.translatesAutoresizingMaskIntoConstraints=NO;
    self.douyindisc_sizeTitle.text=@"图标大小";self.douyindisc_sizeTitle.font=[UIFont systemFontOfSize:12 weight:UIFontWeightMedium];self.douyindisc_sizeTitle.textColor=UIColor.secondaryLabelColor;
    self.douyindisc_sizeTitle.accessibilityIdentifier=@"douyindisc.size.title";
    [content addSubview:self.douyindisc_sizeTitle];
    self.douyindisc_sizeSlider=[UISlider new]; self.douyindisc_sizeSlider.translatesAutoresizingMaskIntoConstraints=NO;
    self.douyindisc_sizeSlider.accessibilityLabel=@"图标大小";
    self.douyindisc_sizeSlider.minimumValue=.5; self.douyindisc_sizeSlider.maximumValue=1.5; self.douyindisc_sizeSlider.value=[entry[@"scale"] respondsToSelector:@selector(floatValue)]?[entry[@"scale"] floatValue]:1;
    self.douyindisc_sizeSlider.minimumTrackTintColor=douyindisc_color(item[@"accentColor"]);
    [self.douyindisc_sizeSlider addTarget:self action:@selector(douyindisc_sizeSliderChanged) forControlEvents:UIControlEventValueChanged];
    [self.douyindisc_sizeSlider addTarget:self action:@selector(douyindisc_sizeSliderEnded) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventEditingDidEnd];
    [content addSubview:self.douyindisc_sizeSlider]; [self douyindisc_updateSizeValue];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14], [content.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
        [content.topAnchor constraintEqualToAnchor:self.topAnchor constant:9], [content.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-9],
        [swatch.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [swatch.topAnchor constraintEqualToAnchor:content.topAnchor], [swatch.widthAnchor constraintEqualToConstant:28], [swatch.heightAnchor constraintEqualToConstant:28],
        [symbol.centerXAnchor constraintEqualToAnchor:swatch.centerXAnchor], [symbol.centerYAnchor constraintEqualToAnchor:swatch.centerYAnchor], [symbol.widthAnchor constraintEqualToConstant:16], [symbol.heightAnchor constraintEqualToConstant:16],
        [title.leadingAnchor constraintEqualToAnchor:swatch.trailingAnchor constant:10], [title.centerYAnchor constraintEqualToAnchor:swatch.centerYAnchor], [title.trailingAnchor constraintLessThanOrEqualToAnchor:self.douyindisc_switch.leadingAnchor constant:-6],
        [self.douyindisc_switch.trailingAnchor constraintEqualToAnchor:content.trailingAnchor], [self.douyindisc_switch.centerYAnchor constraintEqualToAnchor:swatch.centerYAnchor],
        [self.douyindisc_thumbnail.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [self.douyindisc_thumbnail.topAnchor constraintEqualToAnchor:swatch.bottomAnchor constant:8], [self.douyindisc_thumbnail.widthAnchor constraintEqualToConstant:38], [self.douyindisc_thumbnail.heightAnchor constraintEqualToConstant:38],
        [self.douyindisc_actions.leadingAnchor constraintEqualToAnchor:self.douyindisc_thumbnail.trailingAnchor constant:8], [self.douyindisc_actions.centerYAnchor constraintEqualToAnchor:self.douyindisc_thumbnail.centerYAnchor], [self.douyindisc_actions.trailingAnchor constraintLessThanOrEqualToAnchor:content.trailingAnchor],
        [self.douyindisc_imageButton.widthAnchor constraintEqualToConstant:92], [self.douyindisc_imageButton.heightAnchor constraintEqualToConstant:36], [self.douyindisc_filesButton.widthAnchor constraintEqualToConstant:36], [self.douyindisc_filesButton.heightAnchor constraintEqualToConstant:36], [self.douyindisc_clearButton.widthAnchor constraintEqualToConstant:36], [self.douyindisc_clearButton.heightAnchor constraintEqualToConstant:36],
        [self.douyindisc_opacityTitle.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [self.douyindisc_opacityTitle.topAnchor constraintEqualToAnchor:self.douyindisc_thumbnail.bottomAnchor constant:4], [self.douyindisc_opacityTitle.heightAnchor constraintEqualToConstant:16],
        [self.douyindisc_slider.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [self.douyindisc_slider.trailingAnchor constraintEqualToAnchor:self.douyindisc_value.leadingAnchor constant:-10], [self.douyindisc_slider.topAnchor constraintEqualToAnchor:self.douyindisc_opacityTitle.bottomAnchor constant:0],
        [self.douyindisc_value.trailingAnchor constraintEqualToAnchor:content.trailingAnchor], [self.douyindisc_value.centerYAnchor constraintEqualToAnchor:self.douyindisc_slider.centerYAnchor], [self.douyindisc_value.widthAnchor constraintEqualToConstant:44],
        [self.douyindisc_sizeTitle.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [self.douyindisc_sizeTitle.topAnchor constraintEqualToAnchor:self.douyindisc_slider.bottomAnchor constant:0], [self.douyindisc_sizeTitle.heightAnchor constraintEqualToConstant:16],
        [self.douyindisc_sizeSlider.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [self.douyindisc_sizeSlider.trailingAnchor constraintEqualToAnchor:self.douyindisc_sizeValue.leadingAnchor constant:-10], [self.douyindisc_sizeSlider.topAnchor constraintEqualToAnchor:self.douyindisc_sizeTitle.bottomAnchor constant:0],
        [self.douyindisc_sizeValue.trailingAnchor constraintEqualToAnchor:content.trailingAnchor], [self.douyindisc_sizeValue.centerYAnchor constraintEqualToAnchor:self.douyindisc_sizeSlider.centerYAnchor], [self.douyindisc_sizeValue.widthAnchor constraintEqualToConstant:44],
        [self.douyindisc_sizeSlider.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
        [self.heightAnchor constraintEqualToConstant:198]
    ]];
    return self;
}
- (void)douyindisc_updateValue { self.douyindisc_value.text = [NSString stringWithFormat:@"%d%%", (int)lrintf(self.douyindisc_slider.value*100)]; }
- (void)douyindisc_updateSizeValue { self.douyindisc_sizeValue.text = [NSString stringWithFormat:@"%d%%", (int)lrintf(self.douyindisc_sizeSlider.value*100)]; }
- (void)douyindisc_sizeSliderChanged {
    [self douyindisc_updateSizeValue];
    if(self.douyindisc_previewScale)self.douyindisc_previewScale(self,self.douyindisc_sizeSlider.value);
}
- (void)douyindisc_sizeSliderEnded { if(self.douyindisc_changeScale)self.douyindisc_changeScale(self,self.douyindisc_sizeSlider.value); }
- (void)douyindisc_setImagePickingEnabled:(BOOL)enabled { self.douyindisc_imageButton.enabled=enabled;self.douyindisc_filesButton.enabled=enabled; }
- (void)douyindisc_setHasImage:(BOOL)hasImage {
    NSString *title=hasImage?@"更换图标":@"选择图标";
    [self.douyindisc_imageButton setTitle:title forState:UIControlStateNormal];
    [self.douyindisc_imageButton setImage:[UIImage systemImageNamed:@"photo"] forState:UIControlStateNormal];
    self.douyindisc_imageButton.tintColor=douyindisc_color(@"#1557C0");
    self.douyindisc_imageButton.accessibilityLabel=title;
    self.douyindisc_clearButton.enabled=hasImage;
}
- (void)douyindisc_sliderChanged {
    [self douyindisc_updateValue];
    if(self.douyindisc_preview)self.douyindisc_preview(self,self.douyindisc_slider.value);
}
- (void)douyindisc_sliderEnded { if (self.douyindisc_change) self.douyindisc_change(self,self.douyindisc_switch.isOn,self.douyindisc_slider.value); }
- (void)douyindisc_switchChanged { if (self.douyindisc_change) self.douyindisc_change(self,self.douyindisc_switch.isOn,self.douyindisc_slider.value); }
- (void)douyindisc_photoTapped { if(self.douyindisc_imageButton.enabled&&self.douyindisc_pick)self.douyindisc_pick(self,NO); }
- (void)douyindisc_filesTapped { if(self.douyindisc_filesButton.enabled&&self.douyindisc_pick)self.douyindisc_pick(self,YES); }
- (void)douyindisc_setEnabledAfterCommit:(BOOL)enabled { self.douyindisc_switch.on=enabled; [self douyindisc_setImagePickingEnabled:enabled]; }
- (void)douyindisc_clearTapped { if (self.douyindisc_clear) self.douyindisc_clear(self); }
@end

@interface DouyinDiscSettingsViewController () <PHPickerViewControllerDelegate, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate>
@property (nonatomic, strong) UIScrollView *douyindisc_scrollView;
@property (nonatomic, strong) UIStackView *douyindisc_stack;
@property (nonatomic, weak) DouyinDiscNavigationRow *douyindisc_activeRow;
@property (nonatomic, copy) NSString *douyindisc_activeIdentifier;
@property (nonatomic) NSUInteger douyindisc_activePickGeneration;
@property (nonatomic, strong) UIViewController *douyindisc_activePicker;
@property (nonatomic) BOOL douyindisc_pickerHasResult;
@property (nonatomic) BOOL douyindisc_pickerHasProvider;
#if defined(DOUYINDISC_UI_TEST)
@property (nonatomic, copy) void (^douyindisc_uiTestPickerFinished)(BOOL cancelled);
@property (nonatomic, copy) void (^douyindisc_uiTestPickerPresented)(UIViewController *picker);
#endif
- (void)douyindisc_presentPickerForRow:(DouyinDiscNavigationRow *)row files:(BOOL)files;
- (void)douyindisc_finishPickerUI:(UIViewController *)picker cancelled:(BOOL)cancelled keepImportTicket:(BOOL)keepImportTicket;
- (void)douyindisc_finishImportSessionIdentifier:(NSString *)identifier generation:(NSUInteger)generation;
- (void)douyindisc_dismissPicker:(UIViewController *)picker completion:(dispatch_block_t)completion;
- (void)douyindisc_loadPhotoProvider:(NSItemProvider *)provider types:(NSArray<NSString *> *)types index:(NSUInteger)index identifier:(NSString *)identifier pickingGeneration:(NSUInteger)pickingGeneration error:(NSError *)lastError;
- (void)douyindisc_commitImageData:(NSData *)data identifier:(NSString *)identifier pickingGeneration:(NSUInteger)pickingGeneration;
@end

@implementation DouyinDiscSettingsViewController
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    UIViewController *picker=self.douyindisc_activePicker;
    if(!picker)return;
    __weak typeof(self) weakSelf=self;
    dispatch_async(dispatch_get_main_queue(),^{
        DouyinDiscSettingsViewController *strongSelf=weakSelf;
        if(!strongSelf||strongSelf.douyindisc_activePicker!=picker||strongSelf.presentedViewController||picker.isBeingDismissed||picker.isBeingPresented)return;
        BOOL hasProvider=strongSelf.douyindisc_pickerHasProvider;
        [strongSelf douyindisc_finishPickerUI:picker cancelled:!hasProvider keepImportTicket:hasProvider];
    });
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
    UILabel *notice = [UILabel new]; notice.numberOfLines = 0; notice.font = [UIFont systemFontOfSize:13]; notice.textColor = UIColor.secondaryLabelColor;
    notice.text = @"每项独立启用图标替换。未选择图片或关闭开关时保留抖音原文字。图片从照片或文件导入，保存于抖音沙盒。";
    [self.douyindisc_stack addArrangedSubview:notice];
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
            if(![DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_saveEnabled:enabled opacity:opacity scale:[current[@"scale"] doubleValue] identifier:changed.douyindisc_identifier error:&error]){[changed douyindisc_setEnabledAfterCommit:[current[@"enabled"] boolValue]];[weakSelf douyindisc_showError:error];return;}
            [changed douyindisc_setEnabledAfterCommit:enabled];
            [DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_clearOpacityPreviewForIdentifier:changed.douyindisc_identifier];
        };
        row.douyindisc_previewScale = ^(DouyinDiscNavigationRow *changed, CGFloat scale) {
            [DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_previewScale:scale identifier:changed.douyindisc_identifier];
        };
        row.douyindisc_changeScale = ^(DouyinDiscNavigationRow *changed, CGFloat scale) {
            NSDictionary *entry=[DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_entryForIdentifier:changed.douyindisc_identifier];NSError *error=nil;
            if(![DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_saveEnabled:[entry[@"enabled"] boolValue] opacity:[entry[@"opacity"] doubleValue] scale:scale identifier:changed.douyindisc_identifier error:&error]){[weakSelf douyindisc_showError:error];return;}
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
        photos.delegate=self; picker=photos;
    }
    self.douyindisc_activePicker=picker;
    picker.presentationController.delegate=self;
    __weak typeof(self) weakSelf=self;
    [self presentViewController:picker animated:YES completion:^{
#if defined(DOUYINDISC_UI_TEST)
        if(weakSelf.douyindisc_uiTestPickerPresented)weakSelf.douyindisc_uiTestPickerPresented(picker);
#endif
        if (weakSelf.douyindisc_activePicker==picker) picker.presentationController.delegate=weakSelf;
    }];
}
- (void)douyindisc_finishPickerUI:(UIViewController *)picker cancelled:(BOOL)cancelled keepImportTicket:(BOOL)keepImportTicket {
    if (!picker || self.douyindisc_activePicker!=picker) return;
    if (cancelled && !keepImportTicket) [DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_finishImagePickingForIdentifier:self.douyindisc_activeIdentifier generation:self.douyindisc_activePickGeneration];
    self.douyindisc_activePicker=nil;
    self.douyindisc_activeRow=nil;
    self.douyindisc_activeIdentifier=nil;
    self.douyindisc_activePickGeneration=0;
    self.douyindisc_pickerHasResult=NO;
    self.douyindisc_pickerHasProvider=NO;
#if defined(DOUYINDISC_UI_TEST)
    if(self.douyindisc_uiTestPickerFinished)self.douyindisc_uiTestPickerFinished(cancelled);
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
                }
            } else if (completion) completion();
        }];
        if (registered) return;
    }
    [picker dismissViewControllerAnimated:YES completion:completion];
}
- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    UIViewController *picker=presentationController.presentedViewController;
    BOOL hasProvider=self.douyindisc_pickerHasProvider;
    [self douyindisc_finishPickerUI:picker cancelled:!hasProvider keepImportTicket:hasProvider];
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
    NSDictionary *item=douyindisc_navigationItems().firstObject;
    DouyinDiscNavigationRow *row=[[DouyinDiscNavigationRow alloc] initWithItem:item entry:@{@"enabled":@NO,@"opacity":@1} image:nil];row.frame=CGRectMake(0,0,390,198);[row setNeedsLayout];[row layoutIfNeeded];
    BOOL opacityTitle=[row.douyindisc_opacityTitle.text isEqualToString:@"透明度"];
    BOOL sizeTitle=[row.douyindisc_sizeTitle.text isEqualToString:@"图标大小"];
    BOOL opacityAccess=[row.douyindisc_slider.accessibilityLabel isEqualToString:@"图标透明度"];
    BOOL sizeAccess=[row.douyindisc_sizeSlider.accessibilityLabel isEqualToString:@"图标大小"];
    BOOL opacityFrame=fabs(CGRectGetMinY(row.douyindisc_slider.frame)-CGRectGetMaxY(row.douyindisc_opacityTitle.frame))<1;
    BOOL sizeFrame=fabs(CGRectGetMinY(row.douyindisc_sizeSlider.frame)-CGRectGetMaxY(row.douyindisc_sizeTitle.frame))<1;
    BOOL sliderLabels=opacityTitle&&sizeTitle&&opacityAccess&&sizeAccess&&opacityFrame&&sizeFrame;
    BOOL noImage=[[row.douyindisc_imageButton titleForState:UIControlStateNormal] isEqualToString:@"选择图标"] && row.douyindisc_imageButton.currentImage!=nil && row.douyindisc_thumbnail.image==nil && !row.douyindisc_imageButton.enabled;
    [row douyindisc_setImagePickingEnabled:YES];
    BOOL opened=row.douyindisc_imageButton.enabled;
    __block NSInteger source=-1;
    row.douyindisc_pick=^(DouyinDiscNavigationRow *selected,BOOL files){(void)selected;source=files?1:0;};
    [row.douyindisc_imageButton sendActionsForControlEvents:UIControlEventTouchUpInside];BOOL photoDirect=source==0;
    source=-1;[row.douyindisc_filesButton sendActionsForControlEvents:UIControlEventTouchUpInside];BOOL filesDirect=source==1;
    [row douyindisc_setEnabledAfterCommit:NO];source=-1;
    [row.douyindisc_imageButton sendActionsForControlEvents:UIControlEventTouchUpInside];[row.douyindisc_filesButton sendActionsForControlEvents:UIControlEventTouchUpInside];BOOL disabledBoth=source==-1&&!row.douyindisc_imageButton.enabled&&!row.douyindisc_filesButton.enabled;
    __block CGFloat previewed=0,committed=0;
    row.douyindisc_previewScale=^(DouyinDiscNavigationRow *changed,CGFloat scale){(void)changed;previewed=scale;};
    row.douyindisc_changeScale=^(DouyinDiscNavigationRow *changed,CGFloat scale){(void)changed;committed=scale;};
    row.douyindisc_sizeSlider.value=1.25;[row.douyindisc_sizeSlider sendActionsForControlEvents:UIControlEventValueChanged];
    BOOL previewWorks=fabs(previewed-1.25)<.001;
    [row.douyindisc_sizeSlider sendActionsForControlEvents:UIControlEventTouchUpInside];
    BOOL saveWorks=fabs(committed-1.25)<.001;
    row.douyindisc_thumbnail.image=image;
    [row douyindisc_setHasImage:YES];
    [row douyindisc_setEnabledAfterCommit:NO];
    return sliderLabels&&photoDirect&&filesDirect&&disabledBoth&&row.bounds.size.height==198&&row.douyindisc_filesButton!=nil&&[row.douyindisc_filesButton.accessibilityLabel isEqualToString:@"从文件选择图标"]&&row.douyindisc_actions.arrangedSubviews.count==3&&noImage && opened && previewWorks && saveWorks && [[row.douyindisc_imageButton titleForState:UIControlStateNormal] isEqualToString:@"更换图标"] &&
        row.douyindisc_imageButton.currentImage!=nil && row.douyindisc_thumbnail.image==image && !row.douyindisc_imageButton.enabled && row.douyindisc_clearButton.enabled && row.douyindisc_actions.spacing<=4 && row.douyindisc_imageButton.bounds.size.width==92 && fabs(row.douyindisc_sizeSlider.minimumValue-.5)<.001 && fabs(row.douyindisc_sizeSlider.maximumValue-1.5)<.001 && fabs(row.douyindisc_sizeSlider.value-1.25)<.001;
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
    DouyinDiscNavigationStore *store=DouyinDiscNavigationStore.douyindisc_sharedStore;
    douyindisc_uiTestSetNavigationImage(@"top_recommend",nil,YES);
    NSError *error=nil;
    if(![store douyindisc_saveEnabled:YES opacity:1 scale:1 identifier:@"top_recommend" error:&error]){done(@{});return;}
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(24,24),NO,1);[UIColor.systemBlueColor setFill];UIRectFill(CGRectMake(0,0,24,24));
    NSData *data=UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext());UIGraphicsEndImageContext();
    [store douyindisc_saveImageData:data identifier:@"top_recommend" completion:^(NSError *importError){
        if(importError){done(@{});return;}
        UIViewController *previousRoot=window.rootViewController;
        DouyinDiscSettingsViewController *panel=[DouyinDiscSettingsViewController new];
        UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:panel];
        window.rootViewController=nav;[window makeKeyAndVisible];[panel.view layoutIfNeeded];
        DouyinDiscNavigationRow *row=nil;
        for(UIView *view in panel.douyindisc_stack.arrangedSubviews)
            if([view isKindOfClass:DouyinDiscNavigationRow.class]&&[[(DouyinDiscNavigationRow *)view douyindisc_identifier] isEqualToString:@"top_recommend"]){row=(DouyinDiscNavigationRow *)view;break;}
        if(!row){window.rootViewController=previousRoot;done(@{});return;}
        NSDictionary *before=[store douyindisc_entryForIdentifier:@"top_recommend"];
        NSString *directory=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"DouyinDisc/Navigation"];
        NSString *configPath=[directory stringByAppendingPathComponent:@"settings.plist"];
        NSData *beforeConfig=[NSData dataWithContentsOfFile:configPath];
        NSMutableDictionary *results=[NSMutableDictionary dictionary];
        __block BOOL completed=NO;__block NSUInteger stage=0,firstTicket=0;
        __block double brightness=0;
        __block PHPickerViewController *oldPicker=nil;
        __block UIPresentationController *oldPresentation=nil;
        void (^finish)(void)=^{
            if(completed)return;completed=YES;
            panel.douyindisc_uiTestPickerPresented=nil;panel.douyindisc_uiTestPickerFinished=nil;
            results[@"unchanged"]=@([[store douyindisc_entryForIdentifier:@"top_recommend"] isEqual:before]&&beforeConfig&&[beforeConfig isEqual:[NSData dataWithContentsOfFile:configPath]]);
            window.rootViewController=previousRoot;[window makeKeyAndVisible];done([results copy]);
        };
        panel.douyindisc_uiTestPickerFinished=^(BOOL cancelled){
            dispatch_async(dispatch_get_main_queue(),^{
                if(completed)return;
                [panel.view layoutIfNeeded];[window layoutIfNeeded];
                CGPoint point=[row.douyindisc_imageButton convertPoint:CGPointMake(CGRectGetMidX(row.douyindisc_imageButton.bounds),CGRectGetMidY(row.douyindisc_imageButton.bounds)) toView:window];
                UIView *hit=[window hitTest:point withEvent:nil];
                CGPoint filePoint=[row.douyindisc_filesButton convertPoint:CGPointMake(CGRectGetMidX(row.douyindisc_filesButton.bounds),CGRectGetMidY(row.douyindisc_filesButton.bounds)) toView:window];
                UIView *fileHit=[window hitTest:filePoint withEvent:nil];
                CGPoint switchPoint=[row.douyindisc_switch convertPoint:CGPointMake(CGRectGetMidX(row.douyindisc_switch.bounds),CGRectGetMidY(row.douyindisc_switch.bounds)) toView:window];
                UIView *switchHit=[window hitTest:switchPoint withEvent:nil];
                BOOL interactive=cancelled&&!nav.presentedViewController&&!panel.douyindisc_activePicker&&row.douyindisc_imageButton.enabled&&row.douyindisc_filesButton.enabled&&[hit isDescendantOfView:row.douyindisc_imageButton]&&[fileHit isDescendantOfView:row.douyindisc_filesButton]&&[switchHit isDescendantOfView:row.douyindisc_switch];
                double after=douyindisc_uiTestWindowBrightness(window);
                results[@"interactive"]=@(interactive&&(stage==0||[results[@"interactive"] boolValue])&&(stage!=0||[results[@"fileHit"] boolValue]));
                results[@"brightness"]=@(brightness>0&&fabs(after-brightness)<3&&(stage==0||[results[@"brightness"] boolValue]));
                if(stage==0){
                    CGPoint filePoint=[row.douyindisc_filesButton convertPoint:CGPointMake(CGRectGetMidX(row.douyindisc_filesButton.bounds),CGRectGetMidY(row.douyindisc_filesButton.bounds)) toView:window];
                    UIView *fileHit=[window hitTest:filePoint withEvent:nil];
                    results[@"fileHit"]=@([fileHit isDescendantOfView:row.douyindisc_filesButton]&&row.douyindisc_filesButton.enabled);
                    [store douyindisc_saveImageData:data identifier:@"top_recommend" pickingGeneration:firstTicket completion:^(NSError *denied){

                        results[@"empty"]=@(cancelled&&denied.code==6&&panel.douyindisc_activePickGeneration==0);
                        stage=1;[row.douyindisc_imageButton sendActionsForControlEvents:UIControlEventTouchUpInside];
                    }];
                }else if(stage==1){
                    results[@"adaptive"]=@(cancelled&&panel.douyindisc_activePickGeneration==0);
                    stage=2;[row.douyindisc_filesButton sendActionsForControlEvents:UIControlEventTouchUpInside];
                }else{results[@"fileCancelled"]=@(cancelled&&!panel.douyindisc_activePicker&&panel.douyindisc_activePickGeneration==0&&row.douyindisc_filesButton.enabled);finish();}
            });
        };
        panel.douyindisc_uiTestPickerPresented=^(UIViewController *controller){
            if(completed)return;
            if(stage==2){
                if(![controller isKindOfClass:UIDocumentPickerViewController.class]){results[@"filePresented"]=@NO;finish();return;}
                results[@"filePresented"]=@YES;
                [panel documentPickerWasCancelled:(UIDocumentPickerViewController *)controller];
                return;
            }
            if(![controller isKindOfClass:PHPickerViewController.class]){finish();return;}
            PHPickerViewController *picker=(PHPickerViewController *)controller;
            if(stage==0){
                oldPicker=picker;oldPresentation=picker.presentationController;firstTicket=panel.douyindisc_activePickGeneration;
                UIPresentationController *presentation=picker.presentationController;
                [picker dismissViewControllerAnimated:NO completion:^{
                    /* Simulate a system down-swipe that returns without the picker delegate callback. */
                    (void)presentation;[panel beginAppearanceTransition:YES animated:NO];[panel endAppearanceTransition];
                }];
            }else{
                NSUInteger active=panel.douyindisc_activePickGeneration;
                [panel picker:oldPicker didFinishPicking:@[]];
                [panel presentationControllerDidDismiss:oldPresentation];
                results[@"stale"]=@(panel.douyindisc_activePicker==picker&&panel.douyindisc_activePickGeneration==active&&active!=0);
                [panel picker:picker didFinishPicking:@[]];
            }
        };
        dispatch_async(dispatch_get_main_queue(),^{
            [window layoutIfNeeded];[panel.view layoutIfNeeded];brightness=douyindisc_uiTestWindowBrightness(window);
            [row.douyindisc_imageButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,20*NSEC_PER_SEC),dispatch_get_main_queue(),^{if(!completed)finish();});
    }];
}

#endif
