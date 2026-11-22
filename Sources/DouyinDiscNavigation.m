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
@property (nonatomic, strong) UISlider *douyindisc_sizeSlider;
@property (nonatomic, strong) UILabel *douyindisc_sizeValue;
@property (nonatomic, strong) UIImageView *douyindisc_thumbnail;
@property (nonatomic, strong) UIButton *douyindisc_imageButton;
@property (nonatomic, strong) UIButton *douyindisc_clearButton;
@property (nonatomic, strong) UIStackView *douyindisc_actions;
@property (nonatomic, copy) void (^douyindisc_change)(DouyinDiscNavigationRow *, BOOL, CGFloat);
@property (nonatomic, copy) void (^douyindisc_preview)(DouyinDiscNavigationRow *, CGFloat);
@property (nonatomic, copy) void (^douyindisc_changeScale)(DouyinDiscNavigationRow *, CGFloat);
@property (nonatomic, copy) void (^douyindisc_previewScale)(DouyinDiscNavigationRow *, CGFloat);
@property (nonatomic, copy) void (^douyindisc_pick)(DouyinDiscNavigationRow *);
@property (nonatomic, copy) void (^douyindisc_clear)(DouyinDiscNavigationRow *);
- (void)douyindisc_sliderChanged;
- (void)douyindisc_sizeSliderChanged;
- (void)douyindisc_sizeSliderEnded;
- (void)douyindisc_switchChanged;
- (void)douyindisc_pickTapped;
- (void)douyindisc_clearTapped;
- (void)douyindisc_setHasImage:(BOOL)hasImage;
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
    self.douyindisc_imageButton.titleLabel.lineBreakMode=NSLineBreakByTruncatingTail;
    self.douyindisc_imageButton.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
    self.douyindisc_imageButton.imageView.contentMode=UIViewContentModeScaleAspectFit;
    self.douyindisc_imageButton.titleEdgeInsets=UIEdgeInsetsMake(0,6,0,0);
    self.douyindisc_imageButton.contentVerticalAlignment=UIControlContentVerticalAlignmentCenter;
    [self.douyindisc_imageButton addTarget:self action:@selector(douyindisc_pickTapped) forControlEvents:UIControlEventTouchUpInside];
    self.douyindisc_clearButton=[UIButton buttonWithType:UIButtonTypeSystem]; self.douyindisc_clearButton.translatesAutoresizingMaskIntoConstraints=NO;
    [self.douyindisc_clearButton setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal];
    self.douyindisc_clearButton.accessibilityLabel=@"移除此项自定义图标"; self.douyindisc_clearButton.enabled=image!=nil;
    [self.douyindisc_clearButton addTarget:self action:@selector(douyindisc_clearTapped) forControlEvents:UIControlEventTouchUpInside];
    self.douyindisc_actions=[[UIStackView alloc] initWithArrangedSubviews:@[self.douyindisc_imageButton,self.douyindisc_clearButton]];
    self.douyindisc_actions.translatesAutoresizingMaskIntoConstraints=NO; self.douyindisc_actions.axis=UILayoutConstraintAxisHorizontal; self.douyindisc_actions.spacing=8;
    [content addSubview:self.douyindisc_actions];
    self.douyindisc_thumbnail=[UIImageView new]; self.douyindisc_thumbnail.translatesAutoresizingMaskIntoConstraints=NO;
    self.douyindisc_thumbnail.backgroundColor=UIColor.tertiarySystemFillColor; self.douyindisc_thumbnail.layer.cornerRadius=6;
    self.douyindisc_thumbnail.clipsToBounds=YES; self.douyindisc_thumbnail.contentMode=UIViewContentModeScaleAspectFit;
    self.douyindisc_thumbnail.image=image; [content addSubview:self.douyindisc_thumbnail];
    self.douyindisc_thumbnail.accessibilityIdentifier=[@"douyindisc.preview." stringByAppendingString:self.douyindisc_identifier];
    self.douyindisc_value=[UILabel new]; self.douyindisc_value.translatesAutoresizingMaskIntoConstraints=NO;
    self.douyindisc_value.font=[UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightRegular]; self.douyindisc_value.textColor=UIColor.secondaryLabelColor;
    [content addSubview:self.douyindisc_value];
    self.douyindisc_slider=[UISlider new]; self.douyindisc_slider.translatesAutoresizingMaskIntoConstraints=NO;
    self.douyindisc_slider.minimumValue=0; self.douyindisc_slider.maximumValue=1; self.douyindisc_slider.value=[entry[@"opacity"] floatValue];
    self.douyindisc_slider.minimumTrackTintColor=douyindisc_color(item[@"accentColor"]);
    [self.douyindisc_slider addTarget:self action:@selector(douyindisc_sliderChanged) forControlEvents:UIControlEventValueChanged];
    [self.douyindisc_slider addTarget:self action:@selector(douyindisc_sliderEnded) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventEditingDidEnd];
    [content addSubview:self.douyindisc_slider]; [self douyindisc_updateValue];
    self.douyindisc_sizeValue=[UILabel new]; self.douyindisc_sizeValue.translatesAutoresizingMaskIntoConstraints=NO;
    self.douyindisc_sizeValue.font=[UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightRegular]; self.douyindisc_sizeValue.textColor=UIColor.secondaryLabelColor;
    [content addSubview:self.douyindisc_sizeValue];
    self.douyindisc_sizeSlider=[UISlider new]; self.douyindisc_sizeSlider.translatesAutoresizingMaskIntoConstraints=NO;
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
        [self.douyindisc_imageButton.widthAnchor constraintEqualToConstant:106], [self.douyindisc_imageButton.heightAnchor constraintEqualToConstant:36], [self.douyindisc_clearButton.widthAnchor constraintEqualToConstant:36], [self.douyindisc_clearButton.heightAnchor constraintEqualToConstant:36],
        [self.douyindisc_slider.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [self.douyindisc_slider.trailingAnchor constraintEqualToAnchor:self.douyindisc_value.leadingAnchor constant:-10], [self.douyindisc_slider.topAnchor constraintEqualToAnchor:self.douyindisc_thumbnail.bottomAnchor constant:4],
        [self.douyindisc_value.trailingAnchor constraintEqualToAnchor:content.trailingAnchor], [self.douyindisc_value.centerYAnchor constraintEqualToAnchor:self.douyindisc_slider.centerYAnchor], [self.douyindisc_value.widthAnchor constraintEqualToConstant:44],
        [self.douyindisc_sizeSlider.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [self.douyindisc_sizeSlider.trailingAnchor constraintEqualToAnchor:self.douyindisc_sizeValue.leadingAnchor constant:-10], [self.douyindisc_sizeSlider.topAnchor constraintEqualToAnchor:self.douyindisc_slider.bottomAnchor constant:8],
        [self.douyindisc_sizeValue.trailingAnchor constraintEqualToAnchor:content.trailingAnchor], [self.douyindisc_sizeValue.centerYAnchor constraintEqualToAnchor:self.douyindisc_sizeSlider.centerYAnchor], [self.douyindisc_sizeValue.widthAnchor constraintEqualToConstant:44],
        [self.douyindisc_sizeSlider.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
        [self.heightAnchor constraintEqualToConstant:174]
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
- (void)douyindisc_pickTapped { if (self.douyindisc_pick) self.douyindisc_pick(self); }
- (void)douyindisc_clearTapped { if (self.douyindisc_clear) self.douyindisc_clear(self); }
@end

@interface DouyinDiscSettingsViewController () <PHPickerViewControllerDelegate, UIDocumentPickerDelegate>
#if defined(DOUYINDISC_UI_TEST)
- (DouyinDiscNavigationRow *)douyindisc_uiTestRow;
#endif
@property (nonatomic, strong) UIScrollView *douyindisc_scrollView;
@property (nonatomic, strong) UIStackView *douyindisc_stack;
@property (nonatomic, weak) DouyinDiscNavigationRow *douyindisc_activeRow;
@property (nonatomic, copy) NSString *douyindisc_activeIdentifier;
- (void)douyindisc_loadPhotoProvider:(NSItemProvider *)provider types:(NSArray<NSString *> *)types index:(NSUInteger)index identifier:(NSString *)identifier error:(NSError *)lastError;
@end

@implementation DouyinDiscSettingsViewController
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
            if(![DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_saveEnabled:enabled opacity:opacity scale:[current[@"scale"] doubleValue] identifier:changed.douyindisc_identifier error:&error]){[weakSelf douyindisc_showError:error];return;}
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
        row.douyindisc_pick = ^(DouyinDiscNavigationRow *selected) { [weakSelf douyindisc_presentPickerForRow:selected]; };
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
- (void)douyindisc_presentPickerForRow:(DouyinDiscNavigationRow *)row {
    self.douyindisc_activeRow = row;
    self.douyindisc_activeIdentifier = row.douyindisc_identifier;
    UIAlertController *choice = [UIAlertController alertControllerWithTitle:@"选择自定义图标" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [choice addAction:[UIAlertAction actionWithTitle:@"照片" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action; PHPickerConfiguration *config = [PHPickerConfiguration new]; config.filter = [PHPickerFilter imagesFilter]; config.selectionLimit = 1;
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config]; picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }]];
    [choice addAction:[UIAlertAction actionWithTitle:@"文件" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action; UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType typeWithIdentifier:douyindisc_utiImage]] asCopy:YES];
        picker.delegate = self; [self presentViewController:picker animated:YES completion:nil];
    }]];
    [choice addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = choice.popoverPresentationController;
    popover.sourceView = row.douyindisc_imageButton; popover.sourceRect = row.douyindisc_imageButton.bounds;
    [self presentViewController:choice animated:YES completion:nil];
}
- (void)douyindisc_loadPhotoProvider:(NSItemProvider *)provider types:(NSArray<NSString *> *)types index:(NSUInteger)index identifier:(NSString *)identifier error:(NSError *)lastError {
    if(index>=types.count){
        if([provider canLoadObjectOfClass:UIImage.class]){
            __weak typeof(self) weakSelf=self;
            [provider loadObjectOfClass:UIImage.class completionHandler:^(id object,NSError *objectError){
                dispatch_async(dispatch_get_main_queue(),^{NSData *fallback=[object isKindOfClass:UIImage.class]?UIImagePNGRepresentation(object):nil;if(fallback)[weakSelf douyindisc_commitImageData:fallback identifier:identifier];else [weakSelf douyindisc_showError:objectError?:lastError?:[NSError errorWithDomain:@"com.minis.douyindisc.navigation" code:2 userInfo:@{NSLocalizedDescriptionKey:@"照片无法解码为静态图片。"}]];});
            }];
        } else dispatch_async(dispatch_get_main_queue(),^{[self douyindisc_showError:lastError?:[NSError errorWithDomain:@"com.minis.douyindisc.navigation" code:2 userInfo:@{NSLocalizedDescriptionKey:@"照片提供器没有返回可读取的图片数据。"}]];});
        return;
    }
    NSString *type=types[index];
    if(![provider hasItemConformingToTypeIdentifier:type]){[self douyindisc_loadPhotoProvider:provider types:types index:index+1 identifier:identifier error:lastError];return;}
    __weak typeof(self) weakSelf=self;
    [provider loadDataRepresentationForTypeIdentifier:type completionHandler:^(NSData *data,NSError *error){
        if(data.length&&[DouyinDiscNavigationStore.douyindisc_sharedStore douyindisc_decodeImageData:data])dispatch_async(dispatch_get_main_queue(),^{[weakSelf douyindisc_commitImageData:data identifier:identifier];});
        else [weakSelf douyindisc_loadPhotoProvider:provider types:types index:index+1 identifier:identifier error:error?:lastError];
    }];
}
- (void)douyindisc_commitImageData:(NSData *)data identifier:(NSString *)identifier {
    __weak typeof(self) weakSelf=self;
    [[DouyinDiscNavigationStore douyindisc_sharedStore] douyindisc_saveImageData:data identifier:identifier completion:^(NSError *error){
        DouyinDiscSettingsViewController *strongSelf=weakSelf;
        if(error){if(strongSelf.isViewLoaded&&strongSelf.view.window)[strongSelf douyindisc_showError:error];return;}
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
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSItemProvider *provider = results.firstObject.itemProvider;
    if(!provider)return;
    NSString *identifier=[self.douyindisc_activeIdentifier copy];
    if(!identifier)return;
    NSArray<NSString *> *types=@[douyindisc_utiPNG,douyindisc_utiJPEG,douyindisc_utiHEIC,@"public.heif",@"public.tiff",@"public.gif",douyindisc_utiImage];
    [self douyindisc_loadPhotoProvider:provider types:types index:0 identifier:identifier error:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    (void)controller; NSURL *url=urls.firstObject; if(!url)return;
    NSString *identifier=[self.douyindisc_activeIdentifier copy]; if(!identifier)return;
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
        dispatch_async(dispatch_get_main_queue(), ^{if(data)[weakSelf douyindisc_commitImageData:data identifier:identifier];else [weakSelf douyindisc_showError:readError];});
    });
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller { (void)controller; }
@end

#if defined(DOUYINDISC_UI_TEST)
BOOL douyindisc_uiTestPickerAppearanceStable(UIImage *image) {
    NSDictionary *item=douyindisc_navigationItems().firstObject;
    DouyinDiscNavigationRow *row=[[DouyinDiscNavigationRow alloc] initWithItem:item entry:@{@"enabled":@NO,@"opacity":@1} image:nil];
    BOOL noImage=[[row.douyindisc_imageButton titleForState:UIControlStateNormal] isEqualToString:@"选择图标"] && row.douyindisc_imageButton.currentImage!=nil && row.douyindisc_thumbnail.image==nil;
    row.douyindisc_thumbnail.image=image;
    [row douyindisc_setHasImage:YES];
    return noImage && [[row.douyindisc_imageButton titleForState:UIControlStateNormal] isEqualToString:@"更换图标"] &&
        row.douyindisc_imageButton.currentImage!=nil && row.douyindisc_thumbnail.image==image && row.douyindisc_clearButton.enabled && fabs(row.douyindisc_sizeSlider.minimumValue-.5)<.001 && fabs(row.douyindisc_sizeSlider.maximumValue-1.5)<.001 && fabs(row.douyindisc_sizeSlider.value-1)<.001;
}
#endif
