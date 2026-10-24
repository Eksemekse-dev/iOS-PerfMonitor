#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#include <unistd.h>
#include <dlfcn.h>

// Color resolution helper for PiP presets
static inline UIColor *getPerfColorForIndex(NSInteger idx, CGFloat alpha) {
    switch (idx) {
        case 1: return [[UIColor colorWithRed:0.06 green:0.09 blue:0.18 alpha:1.0] colorWithAlphaComponent:alpha]; // Dark Slate
        case 2: return [[UIColor colorWithRed:0.03 green:0.20 blue:0.27 alpha:1.0] colorWithAlphaComponent:alpha]; // Cyber Cyan
        case 3: return [[UIColor colorWithRed:0.18 green:0.06 blue:0.38 alpha:1.0] colorWithAlphaComponent:alpha]; // Neon Purple
        case 4: return [[UIColor colorWithRed:0.02 green:0.28 blue:0.20 alpha:1.0] colorWithAlphaComponent:alpha]; // Emerald
        case 5: return [[UIColor colorWithRed:0.28 green:0.04 blue:0.04 alpha:1.0] colorWithAlphaComponent:alpha]; // Crimson
        default: return [[UIColor blackColor] colorWithAlphaComponent:alpha]; // OLED Black
    }
}

// Dynamic Hardware GPU Usage percentage detector on iOS
static float getGPUUsagePercentage(void) {
    static float s_lastGpu = 0.0f;
    @try {
        typedef mach_port_t (*IOServiceMatching_t)(const char *name);
        typedef mach_port_t (*IOServiceGetMatchingService_t)(mach_port_t, CFDictionaryRef);
        typedef kern_return_t (*IORegistryEntryCreateCFProperties_t)(mach_port_t, CFMutableDictionaryRef *, CFAllocatorRef, uint32_t);
        typedef kern_return_t (*IOObjectRelease_t)(mach_port_t);

        static IOServiceMatching_t p_IOServiceMatching = NULL;
        static IOServiceGetMatchingService_t p_IOServiceGetMatchingService = NULL;
        static IORegistryEntryCreateCFProperties_t p_IORegistryEntryCreateCFProperties = NULL;
        static IOObjectRelease_t p_IOObjectRelease = NULL;
        static BOOL p_inited = NO;

        if (!p_inited) {
            p_inited = YES;
            p_IOServiceMatching = (IOServiceMatching_t)dlsym(RTLD_DEFAULT, "IOServiceMatching");
            p_IOServiceGetMatchingService = (IOServiceGetMatchingService_t)dlsym(RTLD_DEFAULT, "IOServiceGetMatchingService");
            p_IORegistryEntryCreateCFProperties = (IORegistryEntryCreateCFProperties_t)dlsym(RTLD_DEFAULT, "IORegistryEntryCreateCFProperties");
            p_IOObjectRelease = (IOObjectRelease_t)dlsym(RTLD_DEFAULT, "IOObjectRelease");
        }

        if (p_IOServiceMatching && p_IOServiceGetMatchingService && p_IORegistryEntryCreateCFProperties) {
            CFMutableDictionaryRef matching = (CFMutableDictionaryRef)p_IOServiceMatching("IOAccelerator");
            if (matching) {
                mach_port_t service = p_IOServiceGetMatchingService(0, matching);
                if (service) {
                    CFMutableDictionaryRef props = NULL;
                    if (p_IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == 0 && props) {
                        NSDictionary *dict = (__bridge_transfer NSDictionary *)props;
                        NSDictionary *perfStats = dict[@"PerformanceStatistics"];
                        if (perfStats && [perfStats isKindOfClass:[NSDictionary class]]) {
                            NSNumber *util = perfStats[@"Device Utilization %"] ?: perfStats[@"GPU Core Utilization %"] ?: perfStats[@"GpuCoreUtilization"];
                            if (util) {
                                s_lastGpu = [util floatValue];
                                if (p_IOObjectRelease) p_IOObjectRelease(service);
                                return s_lastGpu;
                            }
                        }
                    }
                    if (p_IOObjectRelease) p_IOObjectRelease(service);
                }
            }
        }
    } @catch (NSException *ex) {}
    return s_lastGpu;
}

// ===== TUTORIAL OVERLAY =====
@interface PerfTutorialView : UIView
@property (nonatomic, copy) void (^onCompleted)(void);
- (void)clearDots;
@end

@implementation PerfTutorialView {
    UIVisualEffectView *_bgBlur;
    UIView *_guideCard;
    UILabel *_headerInstructionLabel;
    UILabel *_touchCountLabel;
    UIButton *_skipButton;
    BOOL _isTriggered;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
        self.multipleTouchEnabled = YES;
        _isTriggered = NO;

        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        _bgBlur = [[UIVisualEffectView alloc] initWithEffect:blur];
        _bgBlur.frame = self.bounds;
        _bgBlur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_bgBlur];

        UIEdgeInsets safeInsets = UIEdgeInsetsZero;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindow *window = scene.windows.firstObject;
                    if (window) { safeInsets = window.safeAreaInsets; break; }
                }
            }
        }
        CGFloat topY = safeInsets.top > 0 ? safeInsets.top + 10 : 40;

        _headerInstructionLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, topY, frame.size.width - 48, 44)];
        _headerInstructionLabel.backgroundColor = [[UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:0.25] colorWithAlphaComponent:0.3];
        _headerInstructionLabel.textColor = [UIColor whiteColor];
        _headerInstructionLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        _headerInstructionLabel.textAlignment = NSTextAlignmentCenter;
        _headerInstructionLabel.layer.cornerRadius = 22;
        _headerInstructionLabel.layer.masksToBounds = YES;
        _headerInstructionLabel.layer.borderWidth = 1.0;
        _headerInstructionLabel.layer.borderColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:0.5].CGColor;
        _headerInstructionLabel.text = @"Touch with 4 fingers to test gesture";
        [self addSubview:_headerInstructionLabel];

        CGFloat cardW = frame.size.width - 48;
        CGFloat cardH = 260;
        _guideCard = [[UIView alloc] initWithFrame:CGRectMake(24, (frame.size.height - cardH) / 2.0 - 20, cardW, cardH)];
        _guideCard.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:0.95];
        _guideCard.layer.cornerRadius = 24;
        _guideCard.layer.borderWidth = 0.5;
        _guideCard.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.18].CGColor;
        _guideCard.userInteractionEnabled = NO;
        [self addSubview:_guideCard];

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, cardW - 40, 26)];
        title.text = @"iOS PerfMonitor Gestures";
        title.textColor = [UIColor systemBlueColor];
        title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
        title.textAlignment = NSTextAlignmentCenter;
        [_guideCard addSubview:title];

        UILabel *steps = [[UILabel alloc] initWithFrame:CGRectMake(20, 56, cardW - 40, 130)];
        steps.textColor = [UIColor whiteColor];
        steps.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        steps.numberOfLines = 0;
        steps.text = @"• 4-Finger Tap: Toggle floating PiP monitor\n\n• 4-Finger Hold (0.6s): Open Secret Menu & Settings\n\n• Drag anywhere: Freely reposition PiP on screen";
        [_guideCard addSubview:steps];

        _touchCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, cardH - 52, cardW - 40, 34)];
        _touchCountLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        _touchCountLabel.textColor = [UIColor lightGrayColor];
        _touchCountLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        _touchCountLabel.textAlignment = NSTextAlignmentCenter;
        _touchCountLabel.layer.cornerRadius = 17;
        _touchCountLabel.layer.masksToBounds = YES;
        _touchCountLabel.text = @"Touches detected: 0 / 4";
        [_guideCard addSubview:_touchCountLabel];

        _skipButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _skipButton.frame = CGRectMake((frame.size.width - 150) / 2.0, CGRectGetMaxY(_guideCard.frame) + 30, 150, 44);
        _skipButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        [_skipButton setTitle:@"Skip Tutorial" forState:UIControlStateNormal];
        [_skipButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _skipButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
        _skipButton.layer.cornerRadius = 22;
        _skipButton.layer.borderWidth = 0.5;
        _skipButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
        [_skipButton addTarget:self action:@selector(skipTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_skipButton];
    }
    return self;
}

- (void)skipTapped {
    if (self.onCompleted) self.onCompleted();
}

- (void)clearDots {
    for (UIView *subview in [self.subviews copy]) {
        if (subview.tag == 7777) [subview removeFromSuperview];
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self renderTouches:event]; }
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self renderTouches:event]; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self renderTouches:event]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self clearDots]; }

- (void)renderTouches:(UIEvent *)event {
    [self clearDots];
    NSSet<UITouch *> *allTouches = event.allTouches;
    BOOL isFourFingers = (allTouches.count >= 4);
    UIColor *dotColor = isFourFingers ? [UIColor systemGreenColor] : [UIColor systemBlueColor];

    _touchCountLabel.text = [NSString stringWithFormat:@"Touches detected: %lu / 4", (unsigned long)allTouches.count];
    _touchCountLabel.textColor = isFourFingers ? [UIColor systemGreenColor] : [UIColor lightGrayColor];

    for (UITouch *touch in allTouches) {
        if (touch.phase == UITouchPhaseBegan || touch.phase == UITouchPhaseMoved || touch.phase == UITouchPhaseStationary) {
            CGPoint loc = [touch locationInView:self];
            UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 52, 52)];
            dot.center = loc;
            dot.tag = 7777;
            dot.backgroundColor = [dotColor colorWithAlphaComponent:0.8];
            dot.layer.cornerRadius = 26;
            dot.layer.borderWidth = 2.5;
            dot.layer.borderColor = [UIColor whiteColor].CGColor;
            dot.userInteractionEnabled = NO;
            [self addSubview:dot];
        }
    }

    if (isFourFingers && !_isTriggered) {
        _isTriggered = YES;
        @try {
            UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            [gen impactOccurred];
        } @catch (NSException *e) {}

        [UIView animateWithDuration:0.25 animations:^{
            self->_headerInstructionLabel.backgroundColor = [[UIColor systemGreenColor] colorWithAlphaComponent:0.35];
            self->_headerInstructionLabel.layer.borderColor = [UIColor systemGreenColor].CGColor;
            self->_headerInstructionLabel.textColor = [UIColor systemGreenColor];
            self->_headerInstructionLabel.text = @"✓ 4-Finger gesture detected! Launching...";
        }];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.onCompleted) self.onCompleted();
        });
    }
}

@end

// ===== FLOATING PIP MONITOR =====
@interface PerfMonitorView : UIView
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) NSTimer *timer;
- (void)applySettings;
@end

@interface PerfMonitorWindow : UIWindow
@end

@implementation PerfMonitorWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = [super hitTest:point withEvent:event];
    return (view == self) ? nil : view;
}
@end

static PerfMonitorWindow *sharedMonitorWindow = nil;
static PerfMonitorView *sharedMonitorView = nil;
static UIWindow *fullScreenMenuWindow = nil;
static UIWindow *tutorialWindow = nil;

@implementation PerfMonitorView {
    CGPoint _initialCenter;
    id _fpsDisplayLink;
    NSInteger _fpsFrameCount;
    NSTimeInterval _fpsLastTimestamp;
    NSInteger _currentFps;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.layer.cornerRadius = 14;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
        self.userInteractionEnabled = YES;

        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:panGesture];

        _infoLabel = [[UILabel alloc] initWithFrame:self.bounds];
        _infoLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _infoLabel.textColor = [UIColor whiteColor];
        _infoLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        _infoLabel.numberOfLines = 0;
        _infoLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_infoLabel];

        _fpsFrameCount = 0;
        _fpsLastTimestamp = 0;
        _currentFps = 60;
        Class dlClass = NSClassFromString(@"CADisplayLink");
        if (dlClass && [dlClass respondsToSelector:@selector(displayLinkWithTarget:selector:)]) {
            _fpsDisplayLink = [dlClass displayLinkWithTarget:self selector:@selector(displayLinkTick:)];
            [_fpsDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        }

        [self applySettings];
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateStats) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)displayLinkTick:(id)link {
    NSTimeInterval linkTimestamp = 0;
    if ([link respondsToSelector:@selector(timestamp)]) {
        NSMethodSignature *sig = [link methodSignatureForSelector:@selector(timestamp)];
        if (sig) {
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setSelector:@selector(timestamp)];
            [inv setTarget:link];
            [inv invoke];
            [inv getReturnValue:&linkTimestamp];
        }
    }
    if (linkTimestamp <= 0) linkTimestamp = [[NSDate date] timeIntervalSince1970];
    if (_fpsLastTimestamp == 0) { _fpsLastTimestamp = linkTimestamp; return; }
    _fpsFrameCount++;
    NSTimeInterval delta = linkTimestamp - _fpsLastTimestamp;
    if (delta >= 1.0) {
        _currentFps = (NSInteger)round(_fpsFrameCount / delta);
        _fpsFrameCount = 0;
        _fpsLastTimestamp = linkTimestamp;
    }
}

- (void)applySettings {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    float opacity = [defs floatForKey:@"perf_pip_opacity"];
    if (opacity <= 0.05f) opacity = 0.85f;
    NSInteger colorIdx = [defs integerForKey:@"perf_pip_color_idx"];
    self.backgroundColor = getPerfColorForIndex(colorIdx, opacity);

    float scale = [defs floatForKey:@"perf_pip_scale"];
    if (scale < 0.6f || scale > 1.6f) scale = 1.0f;

    BOOL showCpu = [defs objectForKey:@"perf_show_cpu"] ? [defs boolForKey:@"perf_show_cpu"] : YES;
    BOOL showGpu = [defs objectForKey:@"perf_show_gpu"] ? [defs boolForKey:@"perf_show_gpu"] : YES;
    BOOL showRam = [defs objectForKey:@"perf_show_ram"] ? [defs boolForKey:@"perf_show_ram"] : YES;
    BOOL showTemp = [defs objectForKey:@"perf_show_temp"] ? [defs boolForKey:@"perf_show_temp"] : YES;
    BOOL showFps = [defs boolForKey:@"perf_show_fps"];

    int activeCount = (showCpu ? 1 : 0) + (showGpu ? 1 : 0) + (showRam ? 1 : 0) + (showTemp ? 1 : 0) + (showFps ? 1 : 0);
    if (activeCount == 0) activeCount = 1;

    CGFloat baseH = 24 + activeCount * 17;
    CGFloat baseW = (showFps || showGpu) ? 152 : 142;
    CGFloat newW = round(baseW * scale);
    CGFloat newH = round(baseH * scale);

    self.layer.cornerRadius = 14.0f * scale;
    self.infoLabel.font = [UIFont systemFontOfSize:MAX(8.5f, 11.0f * scale) weight:UIFontWeightSemibold];

    if (sharedMonitorWindow) {
        CGPoint center = sharedMonitorWindow.center;
        sharedMonitorWindow.bounds = CGRectMake(0, 0, newW, newH);
        sharedMonitorWindow.center = center;
        self.frame = sharedMonitorWindow.bounds;
    }

    [self updateStats];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIWindow *window = self.window;
    if (!window) return;
    if (gesture.state == UIGestureRecognizerStateBegan) {
        _initialCenter = window.center;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [gesture translationInView:window];
        window.center = CGPointMake(_initialCenter.x + translation.x, _initialCenter.y + translation.y);
    }
}

- (void)updateStats {
    struct task_basic_info info;
    mach_msg_type_number_t size = TASK_BASIC_INFO_COUNT;
    task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    double ramMB = info.resident_size / (1024.0 * 1024.0);

    thread_array_t thread_list;
    mach_msg_type_number_t thread_count;
    float cpuUsage = 0;
    if (task_threads(mach_task_self(), &thread_list, &thread_count) == KERN_SUCCESS) {
        for (int i = 0; i < thread_count; i++) {
            thread_basic_info_data_t t_info;
            mach_msg_type_number_t t_info_count = THREAD_BASIC_INFO_COUNT;
            if (thread_info(thread_list[i], THREAD_BASIC_INFO, (thread_info_t)&t_info, &t_info_count) == KERN_SUCCESS) {
                if (!(t_info.flags & TH_FLAGS_IDLE)) {
                    cpuUsage += (t_info.cpu_usage / (float)TH_USAGE_SCALE) * 100.0;
                }
            }
        }
        vm_deallocate(mach_task_self(), (vm_address_t)thread_list, thread_count * sizeof(thread_t));
    }

    float gpuUsage = getGPUUsagePercentage();

    NSProcessInfoThermalState thermal = [[NSProcessInfo processInfo] thermalState];
    NSString *thermalStr = @"Normal";
    if (thermal == NSProcessInfoThermalStateFair) thermalStr = @"Warm";
    else if (thermal == NSProcessInfoThermalStateSerious) thermalStr = @"Hot";
    else if (thermal == NSProcessInfoThermalStateCritical) thermalStr = @"Critical!";

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    BOOL showCpu = [defs objectForKey:@"perf_show_cpu"] ? [defs boolForKey:@"perf_show_cpu"] : YES;
    BOOL showGpu = [defs objectForKey:@"perf_show_gpu"] ? [defs boolForKey:@"perf_show_gpu"] : YES;
    BOOL showRam = [defs objectForKey:@"perf_show_ram"] ? [defs boolForKey:@"perf_show_ram"] : YES;
    BOOL showTemp = [defs objectForKey:@"perf_show_temp"] ? [defs boolForKey:@"perf_show_temp"] : YES;
    BOOL showFps = [defs boolForKey:@"perf_show_fps"];

    NSMutableArray *lines = [NSMutableArray array];
    if (showCpu) [lines addObject:[NSString stringWithFormat:@"CPU: %.1f%%", cpuUsage]];
    if (showGpu) [lines addObject:[NSString stringWithFormat:@"GPU: %.1f%%", gpuUsage]];
    if (showRam) [lines addObject:[NSString stringWithFormat:@"RAM: %.1f MB", ramMB]];
    if (showTemp) [lines addObject:[NSString stringWithFormat:@"Temp: %@", thermalStr]];
    if (showFps) [lines addObject:[NSString stringWithFormat:@"FPS: %ld", (long)_currentFps]];

    self.infoLabel.text = (lines.count == 0) ? @"PiP Active" : [lines componentsJoinedByString:@"\n"];
}

@end

// ===== NATIVE IOS SETTINGS STYLE MENU WITH NON-ROOT FILE MANAGER =====
@interface PerfFullScreenMenuView : UIView
@property (nonatomic, copy) void (^onClose)(void);
@property (nonatomic, copy) void (^onRunTest)(void);
@property (nonatomic, copy) NSString *shareSummaryText;
@end

@implementation PerfFullScreenMenuView {
    UISegmentedControl *_segmentedControl;
    UIScrollView *_diagScrollView;
    UIView *_settingsContainerView;
    UIView *_filesContainerView;

    // PiP Settings Controls
    UIView *_previewPipView;
    UILabel *_previewInfoLabel;
    UILabel *_sizeValueLabel;
    UISlider *_sizeSlider;
    UILabel *_opacityValueLabel;
    UISlider *_opacitySlider;

    // File Manager Controls
    NSString *_currentPath;
    UILabel *_currentPathLabel;
    UIScrollView *_filesScrollView;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        // iOS Settings Grouped Background (Deep rich dark in dark mode)
        self.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.08 alpha:0.96];

        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.frame = self.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:blurView];

        UIEdgeInsets safeInsets = UIEdgeInsetsZero;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindow *window = scene.windows.firstObject;
                    if (window) { safeInsets = window.safeAreaInsets; break; }
                }
            }
        }
        CGFloat topY = safeInsets.top > 0 ? safeInsets.top + 6 : 38;
        CGFloat navH = 44;

        // --- 1. iOS Standard Navigation Bar ---
        UIView *navBar = [[UIView alloc] initWithFrame:CGRectMake(0, topY, frame.size.width, navH)];
        [self addSubview:navBar];

        // Share button on left
        UIButton *shareButton = [UIButton buttonWithType:UIButtonTypeSystem];
        shareButton.frame = CGRectMake(16, 6, 36, 32);
        [shareButton setImage:[UIImage systemImageNamed:@"square.and.arrow.up"] forState:UIControlStateNormal];
        shareButton.tintColor = [UIColor systemBlueColor];
        [shareButton addTarget:self action:@selector(shareTapped) forControlEvents:UIControlEventTouchUpInside];
        [navBar addSubview:shareButton];

        // Center Title
        UILabel *navTitle = [[UILabel alloc] initWithFrame:CGRectMake(60, 6, frame.size.width - 120, 32)];
        navTitle.text = @"Secret Menu";
        navTitle.textColor = [UIColor whiteColor];
        navTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
        navTitle.textAlignment = NSTextAlignmentCenter;
        [navBar addSubview:navTitle];

        // Done button on right (standard iOS Settings)
        UIButton *doneButton = [UIButton buttonWithType:UIButtonTypeSystem];
        doneButton.frame = CGRectMake(frame.size.width - 70, 6, 56, 32);
        [doneButton setTitle:@"Done" forState:UIControlStateNormal];
        doneButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
        doneButton.tintColor = [UIColor systemBlueColor];
        [doneButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
        [navBar addSubview:doneButton];

        // --- 2. iOS Native Segmented Control ---
        _segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Diagnostics", @"PiP Settings", @"Files"]];
        _segmentedControl.frame = CGRectMake(18, CGRectGetMaxY(navBar.frame) + 8, frame.size.width - 36, 32);
        _segmentedControl.selectedSegmentIndex = 0;
        [_segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_segmentedControl];

        CGFloat contentY = CGRectGetMaxY(_segmentedControl.frame) + 12;
        CGFloat footerH = 46;
        CGFloat bottomY = frame.size.height - (safeInsets.bottom > 0 ? safeInsets.bottom + 6 : 16);
        CGFloat contentH = (bottomY - footerH) - contentY;
        CGFloat contentW = frame.size.width - 36;

        // --- TAB 1: DIAGNOSTICS (iOS Inset Grouped) ---
        [self setupDiagnosticsTabAtY:contentY width:contentW height:contentH];

        // --- TAB 2: PIP SETTINGS (iOS Inset Grouped) ---
        [self setupSettingsTabAtY:contentY width:contentW height:contentH];

        // --- TAB 3: NON-ROOT FILE MANAGER ---
        [self setupFilesTabAtY:contentY width:contentW height:contentH];

        // --- Footer with GitHub button ---
        UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(18, bottomY - footerH + 4, contentW, footerH)];
        [self addSubview:footer];

        UILabel *credit = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, contentW - 95, footerH)];
        credit.text = @"Created by Eksemekse-dev with AI • v3.0";
        credit.textColor = [UIColor secondaryLabelColor];
        credit.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        [footer addSubview:credit];

        UIButton *githubBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        githubBtn.frame = CGRectMake(contentW - 90, 8, 90, 32);
        [githubBtn setImage:[UIImage systemImageNamed:@"globe"] forState:UIControlStateNormal];
        [githubBtn setTitle:@" GitHub" forState:UIControlStateNormal];
        githubBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        githubBtn.tintColor = [UIColor systemBlueColor];
        githubBtn.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.15];
        githubBtn.layer.cornerRadius = 16;
        [githubBtn addTarget:self action:@selector(openGithubTapped) forControlEvents:UIControlEventTouchUpInside];
        [footer addSubview:githubBtn];
    }
    return self;
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    _diagScrollView.hidden = (sender.selectedSegmentIndex != 0);
    _settingsContainerView.hidden = (sender.selectedSegmentIndex != 1);
    _filesContainerView.hidden = (sender.selectedSegmentIndex != 2);
    if (sender.selectedSegmentIndex == 1) [self updateLivePreview];
    if (sender.selectedSegmentIndex == 2) [self reloadFilesList];
}

// Helper: creates iOS Settings-style Grouped Section Container
- (UIView *)createSettingsGroupWithHeader:(NSString *)header width:(CGFloat)w rows:(NSArray<UIView *> *)rows {
    CGFloat rowH = 46.0;
    CGFloat groupH = rows.count * rowH;

    UIView *wrapper = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 22 + groupH)];
    UILabel *headerLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, w - 24, 18)];
    headerLbl.text = header.uppercaseString;
    headerLbl.textColor = [UIColor secondaryLabelColor];
    headerLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [wrapper addSubview:headerLbl];

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, 22, w, groupH)];
    card.backgroundColor = [UIColor colorWithRed:0.16 green:0.16 blue:0.18 alpha:0.85];
    card.layer.cornerRadius = 14;
    card.layer.borderWidth = 0.5;
    card.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    card.clipsToBounds = YES;
    [wrapper addSubview:card];

    for (int i = 0; i < rows.count; i++) {
        UIView *r = rows[i];
        r.frame = CGRectMake(0, i * rowH, w, rowH);
        [card addSubview:r];
        if (i < rows.count - 1) {
            UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(48, (i + 1) * rowH - 0.5, w - 48, 0.5)];
            sep.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.1];
            [card addSubview:sep];
        }
    }
    return wrapper;
}

// Helper: creates a single row with iOS Settings colored square icon
- (UIView *)createSettingRowWithIcon:(NSString *)iconName color:(UIColor *)color title:(NSString *)title value:(NSString *)val width:(CGFloat)w {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 46)];
    row.userInteractionEnabled = YES;

    // Left Icon Badge (like Settings.app)
    UIView *badge = [[UIView alloc] initWithFrame:CGRectMake(12, 8, 28, 28)];
    badge.backgroundColor = color;
    badge.layer.cornerRadius = 6.5;
    badge.layer.masksToBounds = YES;
    [row addSubview:badge];

    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(4, 4, 20, 20)];
    iv.image = [UIImage systemImageNamed:iconName];
    iv.tintColor = [UIColor whiteColor];
    iv.contentMode = UIViewContentModeScaleAspectFit;
    [badge addSubview:iv];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(48, 0, w * 0.45, 46)];
    t.text = title;
    t.textColor = [UIColor whiteColor];
    t.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [row addSubview:t];

    UILabel *v = [[UILabel alloc] initWithFrame:CGRectMake(48 + w * 0.45, 0, w - (48 + w * 0.45) - 14, 46)];
    v.text = val;
    v.textColor = [UIColor secondaryLabelColor];
    v.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    v.textAlignment = NSTextAlignmentRight;
    v.adjustsFontSizeToFitWidth = YES;
    v.minimumScaleFactor = 0.65;
    v.tag = 999;
    [row addSubview:v];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(rowTapped:)];
    [row addGestureRecognizer:tap];
    return row;
}

// --- SETUP DIAGNOSTICS TAB ---
- (void)setupDiagnosticsTabAtY:(CGFloat)y width:(CGFloat)w height:(CGFloat)h {
    _diagScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(18, y, w, h)];
    _diagScrollView.showsVerticalScrollIndicator = NO;
    [self addSubview:_diagScrollView];

    size_t modelSize;
    sysctlbyname("hw.machine", NULL, &modelSize, NULL, 0);
    char *machine = malloc(modelSize);
    sysctlbyname("hw.machine", machine, &modelSize, NULL, 0);
    NSString *deviceModel = [NSString stringWithUTF8String:machine];
    free(machine);

    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    struct kinfo_proc kinfo;
    size_t ksize = sizeof(kinfo);
    BOOL debuggerAttached = NO;
    if (sysctl(mib, 4, &kinfo, &ksize, NULL, 0) == 0) debuggerAttached = ((kinfo.kp_proc.p_flag & P_TRACED) != 0);

    struct task_basic_info taskInfo;
    mach_msg_type_number_t tSize = TASK_BASIC_INFO_COUNT;
    task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&taskInfo, &tSize);
    double appRamMB = taskInfo.resident_size / (1024.0 * 1024.0);
    unsigned long long totalDeviceRam = [[NSProcessInfo processInfo] physicalMemory] / (1024 * 1024);
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"Unknown";
    NSString *iosVersion = [[UIDevice currentDevice] systemVersion];
    float gpuVal = getGPUUsagePercentage();

    BOOL jitEnabled = debuggerAttached;
    typedef int (*csops_t)(pid_t, unsigned int, void*, size_t);
    csops_t csops_ptr = (csops_t)dlsym(RTLD_DEFAULT, "csops");
    if (csops_ptr) {
        uint32_t csFlags = 0;
        if (csops_ptr(getpid(), 0, &csFlags, sizeof(csFlags)) == 0) jitEnabled = ((csFlags & 0x10000000) != 0);
    }

    self.shareSummaryText = [NSString stringWithFormat:
        @"📊 PerfMonitor Diagnostics\n------------------------\nDevice: %@\niOS: %@\nBundle: %@\nDebugger: %@\nJIT: %@\nApp RAM: %.1f MB\nTotal RAM: %llu MB\nGPU: %.1f%%",
        deviceModel, iosVersion, bundleId, debuggerAttached ? @"Yes" : @"No", jitEnabled ? @"Active" : @"Disabled", appRamMB, totalDeviceRam, gpuVal];

    CGFloat cY = 0;

    // Group 1: Device Information
    NSArray *g1 = @[
        [self createSettingRowWithIcon:@"iphone" color:[UIColor systemBlueColor] title:@"Device Model" value:deviceModel width:w],
        [self createSettingRowWithIcon:@"gearshape.fill" color:[UIColor systemGrayColor] title:@"iOS Version" value:iosVersion width:w],
        [self createSettingRowWithIcon:@"app.badge.fill" color:[UIColor systemOrangeColor] title:@"Bundle ID" value:bundleId width:w],
        [self createSettingRowWithIcon:@"bolt.fill" color:[UIColor systemIndigoColor] title:@"JIT Compilation" value:jitEnabled ? @"Enabled" : @"Disabled" width:w]
    ];
    UIView *sec1 = [self createSettingsGroupWithHeader:@"Device & Runtime" width:w rows:g1];
    sec1.frame = CGRectMake(0, cY, w, sec1.frame.size.height);
    [_diagScrollView addSubview:sec1];
    cY += sec1.frame.size.height + 16;

    // Group 2: Performance Vitals (CPU, GPU, RAM)
    NSArray *g2 = @[
        [self createSettingRowWithIcon:@"cpu" color:[UIColor systemTealColor] title:@"Memory+ Kernel" value:@"Active" width:w],
        [self createSettingRowWithIcon:@"speedometer" color:[UIColor systemYellowColor] title:@"GPU Utilization" value:[NSString stringWithFormat:@"%.1f%%", gpuVal] width:w],
        [self createSettingRowWithIcon:@"memorychip" color:[UIColor systemPurpleColor] title:@"App RAM Usage" value:[NSString stringWithFormat:@"%.1f MB", appRamMB] width:w],
        [self createSettingRowWithIcon:@"internaldrive" color:[UIColor systemGreenColor] title:@"Total Physical RAM" value:[NSString stringWithFormat:@"%llu MB", totalDeviceRam] width:w]
    ];
    UIView *sec2 = [self createSettingsGroupWithHeader:@"Performance & Memory" width:w rows:g2];
    sec2.frame = CGRectMake(0, cY, w, sec2.frame.size.height);
    [_diagScrollView addSubview:sec2];
    cY += sec2.frame.size.height + 16;

    // Stress test action button (iOS Destructive Style)
    UIButton *testBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    testBtn.frame = CGRectMake(0, cY, w, 48);
    testBtn.backgroundColor = [UIColor colorWithRed:0.95 green:0.20 blue:0.20 alpha:0.9];
    testBtn.layer.cornerRadius = 14;
    [testBtn setTitle:@"Run RAM Stress Test (OOM)" forState:UIControlStateNormal];
    [testBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    testBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    [testBtn addTarget:self action:@selector(runStressTestTapped) forControlEvents:UIControlEventTouchUpInside];
    [_diagScrollView addSubview:testBtn];
    cY += 58;

    _diagScrollView.contentSize = CGSizeMake(w, cY);
}

// --- SETUP PIP SETTINGS TAB ---
- (void)setupSettingsTabAtY:(CGFloat)y width:(CGFloat)w height:(CGFloat)h {
    _settingsContainerView = [[UIView alloc] initWithFrame:CGRectMake(18, y, w, h)];
    _settingsContainerView.hidden = YES;
    [self addSubview:_settingsContainerView];

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:_settingsContainerView.bounds];
    scroll.showsVerticalScrollIndicator = NO;
    [_settingsContainerView addSubview:scroll];

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    float curOpacity = [defs floatForKey:@"perf_pip_opacity"];
    if (curOpacity <= 0.05f) curOpacity = 0.85f;
    NSInteger curColorIdx = [defs integerForKey:@"perf_pip_color_idx"];
    float curScale = [defs floatForKey:@"perf_pip_scale"];
    if (curScale < 0.6f || curScale > 1.6f) curScale = 1.0f;

    CGFloat sY = 0;

    // 0. Live Preview Box (iOS grouped card)
    UILabel *prevHdr = [[UILabel alloc] initWithFrame:CGRectMake(12, sY, w - 24, 18)];
    prevHdr.text = @"LIVE PIP PREVIEW";
    prevHdr.textColor = [UIColor secondaryLabelColor];
    prevHdr.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [scroll addSubview:prevHdr];
    sY += 22;

    UIView *previewCard = [[UIView alloc] initWithFrame:CGRectMake(0, sY, w, 110)];
    previewCard.backgroundColor = [UIColor colorWithRed:0.16 green:0.16 blue:0.18 alpha:0.85];
    previewCard.layer.cornerRadius = 14;
    previewCard.layer.borderWidth = 0.5;
    previewCard.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    previewCard.clipsToBounds = YES;
    [scroll addSubview:previewCard];

    _previewPipView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 142, 62)];
    _previewPipView.center = CGPointMake(w / 2.0, 55);
    _previewPipView.layer.cornerRadius = 12;
    _previewPipView.layer.masksToBounds = YES;
    _previewPipView.layer.borderWidth = 1.0;
    _previewPipView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
    _previewPipView.backgroundColor = getPerfColorForIndex(curColorIdx, curOpacity);
    _previewPipView.transform = CGAffineTransformMakeScale(curScale, curScale);
    [previewCard addSubview:_previewPipView];

    _previewInfoLabel = [[UILabel alloc] initWithFrame:_previewPipView.bounds];
    _previewInfoLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _previewInfoLabel.textColor = [UIColor whiteColor];
    _previewInfoLabel.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightSemibold];
    _previewInfoLabel.numberOfLines = 0;
    _previewInfoLabel.textAlignment = NSTextAlignmentCenter;
    _previewInfoLabel.text = @"CPU: 14.8%\nGPU: 28.5%\nRAM: 52.4 MB\nTemp: Normal";
    [_previewPipView addSubview:_previewInfoLabel];
    sY += 122;

    // 1. Group: Dimensions & Opacity
    UILabel *dimHdr = [[UILabel alloc] initWithFrame:CGRectMake(12, sY, w - 24, 18)];
    dimHdr.text = @"PIP DIMENSIONS & OPACITY";
    dimHdr.textColor = [UIColor secondaryLabelColor];
    dimHdr.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [scroll addSubview:dimHdr];
    sY += 22;

    UIView *dimCard = [[UIView alloc] initWithFrame:CGRectMake(0, sY, w, 134)];
    dimCard.backgroundColor = [UIColor colorWithRed:0.16 green:0.16 blue:0.18 alpha:0.85];
    dimCard.layer.cornerRadius = 14;
    dimCard.layer.borderWidth = 0.5;
    dimCard.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    [scroll addSubview:dimCard];

    // Size Slider
    UILabel *szLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 10, w * 0.5, 20)];
    szLbl.text = @"Scale Size";
    szLbl.textColor = [UIColor whiteColor];
    szLbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [dimCard addSubview:szLbl];

    _sizeValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(w - 74, 10, 60, 20)];
    _sizeValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)(curScale * 100)];
    _sizeValueLabel.textColor = [UIColor systemBlueColor];
    _sizeValueLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    _sizeValueLabel.textAlignment = NSTextAlignmentRight;
    [dimCard addSubview:_sizeValueLabel];

    _sizeSlider = [[UISlider alloc] initWithFrame:CGRectMake(14, 34, w - 28, 28)];
    _sizeSlider.minimumValue = 0.65f;
    _sizeSlider.maximumValue = 1.35f;
    _sizeSlider.value = curScale;
    [_sizeSlider addTarget:self action:@selector(sizeSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [dimCard addSubview:_sizeSlider];

    // Opacity Slider
    UILabel *opLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 72, w * 0.5, 20)];
    opLbl.text = @"Overlay Opacity";
    opLbl.textColor = [UIColor whiteColor];
    opLbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [dimCard addSubview:opLbl];

    _opacityValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(w - 74, 72, 60, 20)];
    _opacityValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)(curOpacity * 100)];
    _opacityValueLabel.textColor = [UIColor systemBlueColor];
    _opacityValueLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    _opacityValueLabel.textAlignment = NSTextAlignmentRight;
    [dimCard addSubview:_opacityValueLabel];

    _opacitySlider = [[UISlider alloc] initWithFrame:CGRectMake(14, 96, w - 28, 28)];
    _opacitySlider.minimumValue = 0.2f;
    _opacitySlider.maximumValue = 1.0f;
    _opacitySlider.value = curOpacity;
    [_opacitySlider addTarget:self action:@selector(opacitySliderChanged:) forControlEvents:UIControlEventValueChanged];
    [dimCard addSubview:_opacitySlider];
    sY += 146;

    // 2. Color Themes Palette
    UILabel *colHdr = [[UILabel alloc] initWithFrame:CGRectMake(12, sY, w - 24, 18)];
    colHdr.text = @"THEME PALETTE";
    colHdr.textColor = [UIColor secondaryLabelColor];
    colHdr.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [scroll addSubview:colHdr];
    sY += 22;

    UIView *colCard = [[UIView alloc] initWithFrame:CGRectMake(0, sY, w, 90)];
    colCard.backgroundColor = [UIColor colorWithRed:0.16 green:0.16 blue:0.18 alpha:0.85];
    colCard.layer.cornerRadius = 14;
    colCard.layer.borderWidth = 0.5;
    colCard.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    [scroll addSubview:colCard];

    NSArray *cNames = @[@"Black", @"Navy", @"Cyan", @"Purple", @"Emerald", @"Crimson"];
    CGFloat bW = (w - 32) / 3.0;
    CGFloat bH = 32;
    for (int i = 0; i < 6; i++) {
        CGFloat bx = 8 + (i % 3) * (bW + 8);
        CGFloat by = 8 + (i / 3) * (bH + 8);
        UIButton *cBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        cBtn.frame = CGRectMake(bx, by, bW, bH);
        cBtn.backgroundColor = getPerfColorForIndex(i, 0.95);
        cBtn.layer.cornerRadius = 8;
        cBtn.layer.borderWidth = (i == curColorIdx) ? 2.5 : 1.0;
        cBtn.layer.borderColor = (i == curColorIdx) ? [UIColor systemBlueColor].CGColor : [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
        [cBtn setTitle:cNames[i] forState:UIControlStateNormal];
        cBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        cBtn.tag = 100 + i;
        [cBtn addTarget:self action:@selector(colorSelected:) forControlEvents:UIControlEventTouchUpInside];
        [colCard addSubview:cBtn];
    }
    sY += 102;

    // 3. Visible Metrics Toggles (CPU, GPU, RAM, Temp, FPS)
    UILabel *swHdr = [[UILabel alloc] initWithFrame:CGRectMake(12, sY, w - 24, 18)];
    swHdr.text = @"VISIBLE METRICS IN PIP";
    swHdr.textColor = [UIColor secondaryLabelColor];
    swHdr.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [scroll addSubview:swHdr];
    sY += 22;

    NSArray *configs = @[
        @{@"key": @"perf_show_cpu",  @"title": @"Show CPU Usage",     @"def": @YES},
        @{@"key": @"perf_show_gpu",  @"title": @"Show GPU Usage",     @"def": @YES},
        @{@"key": @"perf_show_ram",  @"title": @"Show RAM Usage",     @"def": @YES},
        @{@"key": @"perf_show_temp", @"title": @"Show Thermal State", @"def": @YES},
        @{@"key": @"perf_show_fps",  @"title": @"Show Render FPS",    @"def": @NO}
    ];

    UIView *swCard = [[UIView alloc] initWithFrame:CGRectMake(0, sY, w, configs.count * 46)];
    swCard.backgroundColor = [UIColor colorWithRed:0.16 green:0.16 blue:0.18 alpha:0.85];
    swCard.layer.cornerRadius = 14;
    swCard.layer.borderWidth = 0.5;
    swCard.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    swCard.clipsToBounds = YES;
    [scroll addSubview:swCard];

    for (int i = 0; i < configs.count; i++) {
        NSDictionary *c = configs[i];
        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, i * 46, w, 46)];
        [swCard addSubview:row];

        UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, w - 80, 46)];
        t.text = c[@"title"];
        t.textColor = [UIColor whiteColor];
        t.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [row addSubview:t];

        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(w - 62, 7.5, 51, 31)];
        BOOL val = [defs objectForKey:c[@"key"]] ? [defs boolForKey:c[@"key"]] : [c[@"def"] boolValue];
        sw.on = val;
        sw.accessibilityIdentifier = c[@"key"];
        [sw addTarget:self action:@selector(metricSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        [row addSubview:sw];

        if (i < configs.count - 1) {
            UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(14, 45.5, w - 14, 0.5)];
            sep.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.1];
            [row addSubview:sep];
        }
    }
    sY += configs.count * 46 + 20;

    scroll.contentSize = CGSizeMake(w, sY);
}

// --- SETUP NON-ROOT FILE MANAGER TAB ---
- (void)setupFilesTabAtY:(CGFloat)y width:(CGFloat)w height:(CGFloat)h {
    _filesContainerView = [[UIView alloc] initWithFrame:CGRectMake(18, y, w, h)];
    _filesContainerView.hidden = YES;
    [self addSubview:_filesContainerView];

    _currentPath = NSHomeDirectory();

    // Shortcuts Bar (Sandbox, Documents, Library, Bundle, Root)
    UIScrollView *quickBar = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, 34)];
    quickBar.showsHorizontalScrollIndicator = NO;
    [_filesContainerView addSubview:quickBar];

    NSArray *shortcuts = @[
        @{@"t": @"Sandbox", @"p": NSHomeDirectory()},
        @{@"t": @"Documents", @"p": [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] ?: NSHomeDirectory()},
        @{@"t": @"Library", @"p": [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject] ?: NSHomeDirectory()},
        @{@"t": @"Bundle", @"p": [[NSBundle mainBundle] bundlePath]},
        @{@"t": @"Root /", @"p": @"/"}
    ];

    CGFloat qx = 0;
    for (NSDictionary *item in shortcuts) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        CGFloat bw = [item[@"t"] sizeWithAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightMedium]}].width + 20;
        btn.frame = CGRectMake(qx, 0, bw, 32);
        btn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
        btn.layer.cornerRadius = 10;
        [btn setTitle:item[@"t"] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
        btn.accessibilityIdentifier = item[@"p"];
        [btn addTarget:self action:@selector(shortcutTapped:) forControlEvents:UIControlEventTouchUpInside];
        [quickBar addSubview:btn];
        qx += bw + 8;
    }
    quickBar.contentSize = CGSizeMake(qx, 32);

    // Path & Up button Bar
    UIView *pathCard = [[UIView alloc] initWithFrame:CGRectMake(0, 42, w, 40)];
    pathCard.backgroundColor = [UIColor colorWithRed:0.16 green:0.16 blue:0.18 alpha:0.85];
    pathCard.layer.cornerRadius = 10;
    pathCard.layer.borderWidth = 0.5;
    pathCard.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    [_filesContainerView addSubview:pathCard];

    _currentPathLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, w - 50, 40)];
    _currentPathLabel.textColor = [UIColor whiteColor];
    _currentPathLabel.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    _currentPathLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    _currentPathLabel.text = _currentPath;
    [pathCard addSubview:_currentPathLabel];

    UIButton *upBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    upBtn.frame = CGRectMake(w - 38, 4, 32, 32);
    [upBtn setImage:[UIImage systemImageNamed:@"arrow.up.circle.fill"] forState:UIControlStateNormal];
    upBtn.tintColor = [UIColor systemBlueColor];
    [upBtn addTarget:self action:@selector(goUpDirectory) forControlEvents:UIControlEventTouchUpInside];
    [pathCard addSubview:upBtn];

    // ScrollView for Files
    CGFloat listY = 90;
    _filesScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, listY, w, h - listY)];
    _filesScrollView.showsVerticalScrollIndicator = YES;
    [_filesContainerView addSubview:_filesScrollView];
}

- (void)shortcutTapped:(UIButton *)btn {
    if (btn.accessibilityIdentifier) {
        _currentPath = btn.accessibilityIdentifier;
        [self reloadFilesList];
    }
}

- (void)goUpDirectory {
    if ([_currentPath isEqualToString:@"/"]) return;
    _currentPath = [_currentPath stringByDeletingLastPathComponent];
    if (_currentPath.length == 0) _currentPath = @"/";
    [self reloadFilesList];
}

- (void)reloadFilesList {
    for (UIView *v in [_filesScrollView.subviews copy]) [v removeFromSuperview];
    _currentPathLabel.text = _currentPath;

    NSError *err = nil;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_currentPath error:&err];

    CGFloat w = _filesScrollView.frame.size.width;
    if (err || !contents || contents.count == 0) {
        UILabel *empty = [[UILabel alloc] initWithFrame:CGRectMake(20, 40, w - 40, 60)];
        empty.text = err ? @"Protected / Inaccessible Directory (Sandbox)" : @"Directory is empty";
        empty.textColor = [UIColor secondaryLabelColor];
        empty.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        empty.numberOfLines = 2;
        empty.textAlignment = NSTextAlignmentCenter;
        [_filesScrollView addSubview:empty];
        _filesScrollView.contentSize = CGSizeMake(w, 120);
        return;
    }

    // Sort: directories first, then files
    NSMutableArray *dirs = [NSMutableArray array];
    NSMutableArray *files = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];

    for (NSString *name in contents) {
        NSString *full = [_currentPath stringByAppendingPathComponent:name];
        BOOL isDir = NO;
        [fm fileExistsAtPath:full isDirectory:&isDir];
        if (isDir) [dirs addObject:name];
        else [files addObject:name];
    }
    [dirs sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    [files sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

    NSMutableArray *allSorted = [NSMutableArray arrayWithArray:dirs];
    [allSorted addObjectsFromArray:files];

    CGFloat rowH = 46.0;
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, allSorted.count * rowH)];
    card.backgroundColor = [UIColor colorWithRed:0.16 green:0.16 blue:0.18 alpha:0.85];
    card.layer.cornerRadius = 14;
    card.layer.borderWidth = 0.5;
    card.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    card.clipsToBounds = YES;
    [_filesScrollView addSubview:card];

    for (int i = 0; i < allSorted.count; i++) {
        NSString *name = allSorted[i];
        NSString *full = [_currentPath stringByAppendingPathComponent:name];
        BOOL isDir = NO;
        [fm fileExistsAtPath:full isDirectory:&isDir];

        UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
        row.frame = CGRectMake(0, i * rowH, w, rowH);
        row.accessibilityIdentifier = full;
        [row addTarget:self action:@selector(fileRowTapped:) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:row];

        UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(14, 13, 20, 20)];
        icon.image = [UIImage systemImageNamed:isDir ? @"folder.fill" : @"doc.text.fill"];
        icon.tintColor = isDir ? [UIColor systemBlueColor] : [UIColor lightGrayColor];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        [row addSubview:icon];

        UILabel *nameLbl = [[UILabel alloc] initWithFrame:CGRectMake(42, 4, w - 120, 38)];
        nameLbl.text = name;
        nameLbl.textColor = [UIColor whiteColor];
        nameLbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        [row addSubview:nameLbl];

        if (isDir) {
            UIImageView *chev = [[UIImageView alloc] initWithFrame:CGRectMake(w - 24, 15, 14, 14)];
            chev.image = [UIImage systemImageNamed:@"chevron.right"];
            chev.tintColor = [UIColor secondaryLabelColor];
            chev.contentMode = UIViewContentModeScaleAspectFit;
            [row addSubview:chev];
        } else {
            NSDictionary *attr = [fm attributesOfItemAtPath:full error:nil];
            unsigned long long fSize = [attr fileSize];
            NSString *szStr = (fSize < 1024) ? [NSString stringWithFormat:@"%llu B", fSize] : (fSize < 1024 * 1024) ? [NSString stringWithFormat:@"%.1f KB", fSize / 1024.0] : [NSString stringWithFormat:@"%.1f MB", fSize / (1024.0 * 1024.0)];
            UILabel *sLbl = [[UILabel alloc] initWithFrame:CGRectMake(w - 90, 4, 76, 38)];
            sLbl.text = szStr;
            sLbl.textColor = [UIColor secondaryLabelColor];
            sLbl.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
            sLbl.textAlignment = NSTextAlignmentRight;
            [row addSubview:sLbl];
        }

        if (i < allSorted.count - 1) {
            UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(42, (i + 1) * rowH - 0.5, w - 42, 0.5)];
            sep.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
            [card addSubview:sep];
        }
    }
    _filesScrollView.contentSize = CGSizeMake(w, allSorted.count * rowH + 20);
}

- (void)fileRowTapped:(UIButton *)sender {
    NSString *path = sender.accessibilityIdentifier;
    if (!path) return;
    BOOL isDir = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir) {
        _currentPath = path;
        [self reloadFilesList];
    } else {
        // Quick File Preview Action Sheet / Alert
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        unsigned long long sz = [attrs fileSize];
        NSString *previewText = @"";

        // Read up to 800 bytes if readable text
        NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
        if (data && data.length > 0) {
            NSString *txt = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, MIN(data.length, (NSUInteger)800))] encoding:NSUTF8StringEncoding];
            if (txt) previewText = [NSString stringWithFormat:@"\n\nPreview:\n%@", txt];
        }

        NSString *msg = [NSString stringWithFormat:@"Path: %@\nSize: %llu bytes%@", path, sz, previewText];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[path lastPathComponent] message:msg preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"Copy Path" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = path;
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"Share" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *fileUrl = [NSURL fileURLWithPath:path];
            UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:@[fileUrl] applicationActivities:nil];
            UIViewController *root = self.window.rootViewController;
            if (root) [root presentViewController:avc animated:YES completion:nil];
        }]];

        [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];

        UIViewController *root = self.window.rootViewController;
        if (root) [root presentViewController:alert animated:YES completion:nil];
    }
}

- (void)updateLivePreview {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    float curOpacity = _opacitySlider ? _opacitySlider.value : [defs floatForKey:@"perf_pip_opacity"];
    if (curOpacity <= 0.05f) curOpacity = 0.85f;
    NSInteger curColorIdx = [defs integerForKey:@"perf_pip_color_idx"];
    float curScale = _sizeSlider ? _sizeSlider.value : [defs floatForKey:@"perf_pip_scale"];
    if (curScale < 0.6f || curScale > 1.6f) curScale = 1.0f;

    if (_previewPipView) {
        _previewPipView.backgroundColor = getPerfColorForIndex(curColorIdx, curOpacity);
        _previewPipView.transform = CGAffineTransformMakeScale(curScale, curScale);
    }
}

- (void)sizeSliderChanged:(UISlider *)sender {
    float val = sender.value;
    _sizeValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)(val * 100)];
    [[NSUserDefaults standardUserDefaults] setFloat:val forKey:@"perf_pip_scale"];
    [self updateLivePreview];
    if (sharedMonitorView) dispatch_async(dispatch_get_main_queue(), ^{ [sharedMonitorView applySettings]; });
}

- (void)opacitySliderChanged:(UISlider *)sender {
    float val = sender.value;
    _opacityValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)(val * 100)];
    [[NSUserDefaults standardUserDefaults] setFloat:val forKey:@"perf_pip_opacity"];
    [self updateLivePreview];
    if (sharedMonitorView) dispatch_async(dispatch_get_main_queue(), ^{ [sharedMonitorView applySettings]; });
}

- (void)colorSelected:(UIButton *)sender {
    @try {
        NSInteger idx = sender.tag - 100;
        [[NSUserDefaults standardUserDefaults] setInteger:idx forKey:@"perf_pip_color_idx"];

        UIView *parent = sender.superview;
        if (parent) {
            for (UIView *sub in parent.subviews) {
                if ([sub isKindOfClass:[UIButton class]] && sub.tag >= 100 && sub.tag <= 105) {
                    UIButton *btn = (UIButton *)sub;
                    BOOL isCur = (btn.tag == sender.tag);
                    btn.layer.borderWidth = isCur ? 2.5 : 1.0;
                    btn.layer.borderColor = isCur ? [UIColor systemBlueColor].CGColor : [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
                }
            }
        }
        [self updateLivePreview];
        @try {
            UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [gen impactOccurred];
        } @catch (NSException *e) {}

        if (sharedMonitorView) dispatch_async(dispatch_get_main_queue(), ^{ [sharedMonitorView applySettings]; });
    } @catch (NSException *ex) {}
}

- (void)metricSwitchChanged:(UISwitch *)sender {
    NSString *key = sender.accessibilityIdentifier;
    if (key) {
        [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:key];
        if (sharedMonitorView) dispatch_async(dispatch_get_main_queue(), ^{ [sharedMonitorView applySettings]; });
    }
}

- (void)rowTapped:(UITapGestureRecognizer *)gesture {
    UIView *row = gesture.view;
    for (UIView *sub in row.subviews) {
        if ([sub isKindOfClass:[UILabel class]] && sub.tag == 999) {
            UILabel *v = (UILabel *)sub;
            if (v.text) {
                [UIPasteboard generalPasteboard].string = v.text;
                @try {
                    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
                    [gen impactOccurred];
                } @catch (NSException *e) {}
                [self showToast:@"Copied to clipboard!"];
            }
            break;
        }
    }
}

- (void)showToast:(NSString *)text {
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake((self.bounds.size.width - 180) / 2.0, self.bounds.size.height - 100, 180, 36)];
    toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    toast.textColor = [UIColor whiteColor];
    toast.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.text = text;
    toast.layer.cornerRadius = 18;
    toast.layer.masksToBounds = YES;
    toast.alpha = 0.0;
    [self addSubview:toast];
    [UIView animateWithDuration:0.2 animations:^{ toast.alpha = 1.0; } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 delay:1.0 options:0 animations:^{ toast.alpha = 0.0; } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    }];
}

- (void)openGithubTapped {
    NSURL *url = [NSURL URLWithString:@"https://github.com/Eksemekse-dev/iOS-PerfMonitor"];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (void)shareTapped {
    if (!self.shareSummaryText) return;
    UIActivityViewController *vc = [[UIActivityViewController alloc] initWithActivityItems:@[self.shareSummaryText] applicationActivities:nil];
    UIViewController *root = self.window.rootViewController;
    if (root) [root presentViewController:vc animated:YES completion:nil];
}

- (void)runStressTestTapped { if (self.onRunTest) self.onRunTest(); }
- (void)closeTapped { if (self.onClose) self.onClose(); }

@end

// ===== MANAGER & STRESS TEST =====
@interface PerfMonitorManager : NSObject
+ (NSString *)getTestResultFilePath;
+ (void)runRamStressTest;
+ (void)checkPreviousCrashOrTestResult;
+ (BOOL)hasCompletedTutorial;
+ (void)setTutorialCompleted;
@end

@implementation PerfMonitorManager

+ (NSString *)getTestResultFilePath {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown_app";
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths[0] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_ram_test_state.plist", bundleId]];
}

+ (NSString *)getTutorialStateFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths[0] stringByAppendingPathComponent:@"perf_monitor_tutorial_v7.flag"];
}

+ (BOOL)hasCompletedTutorial {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self getTutorialStateFilePath]];
}

+ (void)setTutorialCompleted {
    [@"completed" writeToFile:[self getTutorialStateFilePath] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

+ (void)runRamStressTest {
    NSString *filePath = [self getTestResultFilePath];
    [@{ @"status": @"running", @"allocatedMB": @(0) } writeToFile:filePath atomically:YES];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSMutableArray *chunks = [NSMutableArray array];
        int totalAllocatedMB = 0;
        int chunkSizeMB = 50;
        while (YES) {
            @autoreleasepool {
                char *chunk = malloc(chunkSizeMB * 1024 * 1024);
                if (!chunk) break;
                memset(chunk, 1, chunkSizeMB * 1024 * 1024);
                [chunks addObject:[NSData dataWithBytesNoCopy:chunk length:chunkSizeMB * 1024 * 1024 freeWhenDone:YES]];
                totalAllocatedMB += chunkSizeMB;
                [@{ @"status": @"running", @"allocatedMB": @(totalAllocatedMB) } writeToFile:filePath atomically:YES];
                usleep(50000);
            }
        }
    });
}

+ (void)checkPreviousCrashOrTestResult {
    NSString *filePath = [self getTestResultFilePath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) return;
    NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:filePath];
    if (!state) return;
    NSString *status = state[@"status"];
    NSNumber *allocatedMB = state[@"allocatedMB"];
    if ([status isEqualToString:@"running"]) {
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *targetWindow = nil;
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    targetWindow = scene.windows.firstObject;
                    if (targetWindow) break;
                }
            }
            if (!targetWindow) return;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"RAM Test Result (Crash OOM)"
                                                                           message:[NSString stringWithFormat:@"App crashed due to Out Of Memory!\nMax allocated RAM before crash: %@ MB", allocatedMB]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            UIViewController *tempVC = [[UIViewController alloc] init];
            [targetWindow.rootViewController presentViewController:tempVC animated:NO completion:^{
                [tempVC presentViewController:alert animated:YES completion:nil];
            }];
        });
    }
}

@end

// ===== GESTURES & HANDLERS =====
@interface PerfMonitorGestureHandler : NSObject
+ (void)handleFourFingerTap:(UITapGestureRecognizer *)sender;
+ (void)handleFourFingerLongPress:(UILongPressGestureRecognizer *)sender;
+ (void)handleOrientationChange:(NSNotification *)notification;
+ (void)dismissTutorialAndExecute:(void(^)(void))action;
+ (void)openMenuNow;
@end

@implementation PerfMonitorGestureHandler

+ (void)dismissTutorialAndExecute:(void(^)(void))action {
    if (tutorialWindow) {
        [UIView animateWithDuration:0.3 animations:^{ tutorialWindow.alpha = 0.0; } completion:^(BOOL finished) {
            tutorialWindow.hidden = YES;
            tutorialWindow = nil;
            [PerfMonitorManager setTutorialCompleted];
            if (action) action();
        }];
    } else {
        if (action) action();
    }
}

+ (void)handleFourFingerTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateRecognized) {
        [self dismissTutorialAndExecute:^{
            if (sharedMonitorWindow) sharedMonitorWindow.hidden = !sharedMonitorWindow.hidden;
        }];
    }
}

+ (void)openMenuNow {
    if (fullScreenMenuWindow) return;
    UIWindowScene *targetScene = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) { targetScene = scene; break; }
    }
    if (!targetScene) return;

    fullScreenMenuWindow = [[UIWindow alloc] initWithFrame:targetScene.coordinateSpace.bounds];
    fullScreenMenuWindow.windowScene = targetScene;
    fullScreenMenuWindow.windowLevel = UIWindowLevelAlert + 2000;
    fullScreenMenuWindow.hidden = NO;

    PerfFullScreenMenuView *menuView = [[PerfFullScreenMenuView alloc] initWithFrame:fullScreenMenuWindow.bounds];
    __block UIWindow *menuWinRef = fullScreenMenuWindow;

    menuView.onClose = ^{
        menuWinRef.hidden = YES;
        fullScreenMenuWindow = nil;
    };

    menuView.onRunTest = ^{
        UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Warning"
                                                                         message:@"This test will allocate RAM until the app crashes to measure limits. Continue?"
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"Start" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull act) {
            if (menuWinRef) { menuWinRef.hidden = YES; fullScreenMenuWindow = nil; }
            [PerfMonitorManager runRamStressTest];
        }]];
        [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        UIViewController *vc = [[UIViewController alloc] init];
        menuWinRef.rootViewController = vc;
        [vc presentViewController:confirm animated:YES completion:nil];
    };

    fullScreenMenuWindow.rootViewController = [[UIViewController alloc] init];
    [fullScreenMenuWindow.rootViewController.view addSubview:menuView];
}

+ (void)handleFourFingerLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    if (fullScreenMenuWindow) return;

    @try {
        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [gen impactOccurred];
    } @catch (NSException *e) {}

    [self dismissTutorialAndExecute:^{
        [self openMenuNow];
    }];
}

+ (void)handleOrientationChange:(NSNotification *)notification {
    if (fullScreenMenuWindow || tutorialWindow) return;
    if (sharedMonitorWindow && !sharedMonitorWindow.isHidden) {
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        sharedMonitorWindow.center = CGPointMake(screenSize.width / 2.0, 90.0);
    }
}

@end

// ===== TWEAK ENTRY POINT =====
__attribute__((constructor)) static void tweakEntry() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *targetWindow = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                targetWindow = scene.windows.firstObject;
                if (targetWindow) break;
            }
        }
        if (!targetWindow) return;
        CGSize screenSize = [UIScreen mainScreen].bounds.size;

        if (!sharedMonitorWindow) {
            sharedMonitorWindow = [[PerfMonitorWindow alloc] initWithFrame:CGRectMake(0, 0, 142, 70)];
            sharedMonitorWindow.center = CGPointMake(screenSize.width / 2.0, 90.0);
            sharedMonitorWindow.windowLevel = UIWindowLevelAlert + 1000;
            sharedMonitorWindow.hidden = YES;
            if (@available(iOS 13.0, *)) {
                for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]]) {
                        sharedMonitorWindow.windowScene = scene;
                        break;
                    }
                }
            }
            sharedMonitorView = [[PerfMonitorView alloc] initWithFrame:sharedMonitorWindow.bounds];
            [sharedMonitorWindow addSubview:sharedMonitorView];
        }

        UITapGestureRecognizer *fourFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:[PerfMonitorGestureHandler class] action:@selector(handleFourFingerTap:)];
        fourFingerTap.numberOfTouchesRequired = 4;
        [targetWindow addGestureRecognizer:fourFingerTap];

        UILongPressGestureRecognizer *fourFingerLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:[PerfMonitorGestureHandler class] action:@selector(handleFourFingerLongPress:)];
        fourFingerLongPress.numberOfTouchesRequired = 4;
        fourFingerLongPress.minimumPressDuration = 0.6;
        fourFingerLongPress.allowableMovement = 40.0;
        [targetWindow addGestureRecognizer:fourFingerLongPress];

        [fourFingerTap requireGestureRecognizerToFail:fourFingerLongPress];

        [[NSNotificationCenter defaultCenter] addObserver:[PerfMonitorGestureHandler class]
                                                 selector:@selector(handleOrientationChange:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];

        if (![PerfMonitorManager hasCompletedTutorial]) {
            UIWindowScene *targetScene = nil;
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) { targetScene = scene; break; }
            }
            if (targetScene) {
                tutorialWindow = [[UIWindow alloc] initWithFrame:targetScene.coordinateSpace.bounds];
                tutorialWindow.windowScene = targetScene;
                tutorialWindow.windowLevel = UIWindowLevelAlert + 3000;
                tutorialWindow.hidden = NO;
                PerfTutorialView *tutorialView = [[PerfTutorialView alloc] initWithFrame:tutorialWindow.bounds];
                tutorialView.onCompleted = ^{
                    [PerfMonitorGestureHandler dismissTutorialAndExecute:nil];
                };
                tutorialWindow.rootViewController = [[UIViewController alloc] init];
                [tutorialWindow.rootViewController.view addSubview:tutorialView];
            }
        }

        [PerfMonitorManager checkPreviousCrashOrTestResult];
    });
}
