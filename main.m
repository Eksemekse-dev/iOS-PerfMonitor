#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#include <unistd.h>

// Color resolution helper for PiP presets
static inline UIColor *getPerfColorForIndex(NSInteger idx, CGFloat alpha) {
    switch (idx) {
        case 1: return [[UIColor colorWithRed:0.06 green:0.09 blue:0.18 alpha:1.0] colorWithAlphaComponent:alpha]; // Dark Slate / Navy
        case 2: return [[UIColor colorWithRed:0.03 green:0.20 blue:0.27 alpha:1.0] colorWithAlphaComponent:alpha]; // Cyber Cyan
        case 3: return [[UIColor colorWithRed:0.18 green:0.06 blue:0.38 alpha:1.0] colorWithAlphaComponent:alpha]; // Neon Purple
        case 4: return [[UIColor colorWithRed:0.02 green:0.28 blue:0.20 alpha:1.0] colorWithAlphaComponent:alpha]; // Emerald
        case 5: return [[UIColor colorWithRed:0.28 green:0.04 blue:0.04 alpha:1.0] colorWithAlphaComponent:alpha]; // Crimson
        default: return [[UIColor blackColor] colorWithAlphaComponent:alpha]; // OLED Black
    }
}

// --- UPGRADED INTERACTIVE TUTORIAL OVERVIEW ---
@interface PerfTutorialView : UIView
@property (nonatomic, copy) void (^onCompleted)(void);
- (void)clearDots;
@end

@implementation PerfTutorialView {
    UILabel *_headerInstructionLabel;
    UIView *_guideCardView;
    UILabel *_touchCountLabel;
    UIButton *_skipButton;
    BOOL _isTriggered;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.88];
        self.multipleTouchEnabled = YES;
        _isTriggered = NO;

        UIEdgeInsets safeInsets = UIEdgeInsetsZero;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindow *window = scene.windows.firstObject;
                    if (window) {
                        safeInsets = window.safeAreaInsets;
                        break;
                    }
                }
            }
        }

        CGFloat topY = safeInsets.top > 0 ? safeInsets.top + 5 : 35;

        _headerInstructionLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, topY, frame.size.width - 40, 42)];
        _headerInstructionLabel.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12];
        _headerInstructionLabel.textColor = [UIColor whiteColor];
        _headerInstructionLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        _headerInstructionLabel.textAlignment = NSTextAlignmentCenter;
        _headerInstructionLabel.layer.cornerRadius = 21;
        _headerInstructionLabel.layer.masksToBounds = YES;
        _headerInstructionLabel.layer.borderWidth = 1.0;
        _headerInstructionLabel.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.2].CGColor;
        _headerInstructionLabel.text = @"Touch with 4 fingers to test gesture";
        [self addSubview:_headerInstructionLabel];

        CGFloat cardW = frame.size.width - 40;
        CGFloat cardH = 220;
        _guideCardView = [[UIView alloc] initWithFrame:CGRectMake(20, (frame.size.height - cardH) / 2.0 - 20, cardW, cardH)];
        _guideCardView.backgroundColor = [[UIColor colorWithRed:0.12 green:0.12 blue:0.15 alpha:1.0] colorWithAlphaComponent:0.9];
        _guideCardView.layer.cornerRadius = 20;
        _guideCardView.layer.borderWidth = 1.0;
        _guideCardView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15].CGColor;
        _guideCardView.userInteractionEnabled = NO;
        [self addSubview:_guideCardView];

        UILabel *cardTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 16, cardW - 32, 24)];
        cardTitle.text = @"iOS PerfMonitor Gesture Guide";
        cardTitle.textColor = [UIColor systemCyanColor];
        cardTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
        cardTitle.textAlignment = NSTextAlignmentCenter;
        [_guideCardView addSubview:cardTitle];

        UILabel *instructions = [[UILabel alloc] initWithFrame:CGRectMake(20, 48, cardW - 40, 110)];
        instructions.textColor = [UIColor whiteColor];
        instructions.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        instructions.numberOfLines = 0;
        instructions.text = @"• 4-Finger Tap: Toggle floating PiP monitor\n\n• 4-Finger Hold (2s): Open Diagnostic & Settings Menu\n\n• Drag: Move PiP widget anywhere on screen";
        [_guideCardView addSubview:instructions];

        _touchCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 172, cardW - 40, 32)];
        _touchCountLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
        _touchCountLabel.textColor = [UIColor lightGrayColor];
        _touchCountLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
        _touchCountLabel.textAlignment = NSTextAlignmentCenter;
        _touchCountLabel.layer.cornerRadius = 16;
        _touchCountLabel.layer.masksToBounds = YES;
        _touchCountLabel.text = @"Touches detected: 0 / 4";
        [_guideCardView addSubview:_touchCountLabel];

        _skipButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _skipButton.frame = CGRectMake((frame.size.width - 140) / 2.0, CGRectGetMaxY(_guideCardView.frame) + 30, 140, 40);
        _skipButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
        [_skipButton setTitle:@"Skip Tutorial" forState:UIControlStateNormal];
        [_skipButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _skipButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        _skipButton.layer.cornerRadius = 20;
        _skipButton.layer.borderWidth = 1.0;
        _skipButton.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
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

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self renderTouchesFromEvent:event]; }
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self renderTouchesFromEvent:event]; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self renderTouchesFromEvent:event]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self clearDots]; }

- (void)renderTouchesFromEvent:(UIEvent *)event {
    [self clearDots];
    NSSet<UITouch *> *allTouches = event.allTouches;
    BOOL isFourFingers = (allTouches.count >= 4);
    UIColor *dotColor = isFourFingers ? [UIColor systemGreenColor] : [[UIColor systemCyanColor] colorWithAlphaComponent:0.8];
    
    _touchCountLabel.text = [NSString stringWithFormat:@"Touches detected: %lu / 4", (unsigned long)allTouches.count];
    _touchCountLabel.textColor = isFourFingers ? [UIColor systemGreenColor] : [UIColor lightGrayColor];

    for (UITouch *touch in allTouches) {
        if (touch.phase == UITouchPhaseBegan || touch.phase == UITouchPhaseMoved || touch.phase == UITouchPhaseStationary) {
            CGPoint loc = [touch locationInView:self];
            UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
            dot.center = loc;
            dot.tag = 7777;
            dot.backgroundColor = dotColor;
            dot.layer.cornerRadius = 25;
            dot.layer.borderWidth = 2.5;
            dot.layer.borderColor = [UIColor whiteColor].CGColor;
            dot.userInteractionEnabled = NO;
            [self addSubview:dot];
        }
    }

    if (isFourFingers && !_isTriggered) {
        _isTriggered = YES;
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];

        [UIView animateWithDuration:0.25 animations:^{
            self->_headerInstructionLabel.backgroundColor = [[UIColor systemGreenColor] colorWithAlphaComponent:0.35];
            self->_headerInstructionLabel.layer.borderColor = [UIColor systemGreenColor].CGColor;
            self->_headerInstructionLabel.textColor = [UIColor systemGreenColor];
            self->_headerInstructionLabel.text = @"✓ 4-Finger gesture detected! Launching...";
        }];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.onCompleted) self.onCompleted();
        });
    }
}
@end

// --- FLOATING PERFORMANCE MONITOR (PiP) WITH SETTINGS ---
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

    if (_fpsLastTimestamp == 0) {
        _fpsLastTimestamp = linkTimestamp;
        return;
    }
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
    BOOL showRam = [defs objectForKey:@"perf_show_ram"] ? [defs boolForKey:@"perf_show_ram"] : YES;
    BOOL showTemp = [defs objectForKey:@"perf_show_temp"] ? [defs boolForKey:@"perf_show_temp"] : YES;
    BOOL showFps = [defs boolForKey:@"perf_show_fps"];

    int activeCount = (showCpu ? 1 : 0) + (showRam ? 1 : 0) + (showTemp ? 1 : 0) + (showFps ? 1 : 0);
    if (activeCount == 0) activeCount = 1;

    CGFloat baseH = 26 + activeCount * 17;
    CGFloat baseW = (showFps ? 150 : 142);
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

    NSProcessInfoThermalState thermal = [[NSProcessInfo processInfo] thermalState];
    NSString *thermalStr = @"Normal";
    if (thermal == NSProcessInfoThermalStateFair) thermalStr = @"Warm";
    else if (thermal == NSProcessInfoThermalStateSerious) thermalStr = @"Hot";
    else if (thermal == NSProcessInfoThermalStateCritical) thermalStr = @"Critical!";

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    BOOL showCpu = [defs objectForKey:@"perf_show_cpu"] ? [defs boolForKey:@"perf_show_cpu"] : YES;
    BOOL showRam = [defs objectForKey:@"perf_show_ram"] ? [defs boolForKey:@"perf_show_ram"] : YES;
    BOOL showTemp = [defs objectForKey:@"perf_show_temp"] ? [defs boolForKey:@"perf_show_temp"] : YES;
    BOOL showFps = [defs boolForKey:@"perf_show_fps"];

    NSMutableArray *lines = [NSMutableArray array];
    if (showCpu) [lines addObject:[NSString stringWithFormat:@"CPU: %.1f%%", cpuUsage]];
    if (showRam) [lines addObject:[NSString stringWithFormat:@"RAM: %.1f MB", ramMB]];
    if (showTemp) [lines addObject:[NSString stringWithFormat:@"Temp: %@", thermalStr]];
    if (showFps) [lines addObject:[NSString stringWithFormat:@"FPS: %ld", (long)_currentFps]];

    self.infoLabel.text = (lines.count == 0) ? @"PiP Active" : [lines componentsJoinedByString:@"\n"];
}
@end

// --- MODERN PROFESSIONAL FULL-SCREEN MENU WITH iOS SETTINGS UI & LIGHT/DARK THEME ---
@interface PerfFullScreenMenuView : UIView
@property (nonatomic, copy) void (^onClose)(void);
@property (nonatomic, copy) void (^onRunTest)(void);
@property (nonatomic, copy) NSString *shareSummaryText;
@end

@implementation PerfFullScreenMenuView {
    UISegmentedControl *_segmentedControl;
    UIScrollView *_diagScrollView;
    UIView *_settingsContainerView;
    UIButton *_testButton;
    UISlider *_opacitySlider;
    UILabel *_opacityValueLabel;
    UISlider *_sizeSlider;
    UILabel *_sizeValueLabel;
    UIView *_previewPipView;
    UILabel *_previewInfoLabel;
    UISegmentedControl *_themeSegmentControl;
    UIVisualEffectView *_blurView;
    UIView *_cardView;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self updateThemeStyling];

        _cardView = [[UIView alloc] initWithFrame:CGRectMake(20, 40, frame.size.width - 40, frame.size.height - 80)];
        _cardView.center = CGPointMake(frame.size.width / 2.0, frame.size.height / 2.0);
        _cardView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        _cardView.layer.cornerRadius = 20;
        _cardView.layer.borderWidth = 0.5;
        [self addSubview:_cardView];

        // Title icon
        UIImageView *titleIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"gearshape.2.fill"]];
        titleIcon.frame = CGRectMake(20, 20, 24, 24);
        titleIcon.tintColor = [UIColor systemBlueColor];
        [_cardView addSubview:titleIcon];

        // Title label (iOS Settings Header style)
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(54, 16, _cardView.frame.size.width - 120, 30)];
        titleLabel.text = @"Ustawienia";
        titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
        [_cardView addSubview:titleLabel];

        // Close button
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        closeButton.frame = CGRectMake(_cardView.frame.size.width - 44, 16, 30, 30);
        [closeButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
        closeButton.tintColor = [UIColor secondaryLabelColor];
        [closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
        [_cardView addSubview:closeButton];

        // Segmented control: Diagnostics vs PiP Settings
        _segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Diagnostyka", @"PiP Ustawienia"]];
        _segmentedControl.frame = CGRectMake(16, 58, _cardView.frame.size.width - 32, 32);
        _segmentedControl.selectedSegmentIndex = 0;
        [_segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
        [_cardView addSubview:_segmentedControl];

        // --- GATHER DIAGNOSTICS INFO ---
        size_t modelSize;
        sysctlbyname("hw.machine", NULL, &modelSize, NULL, 0);
        char *machine = malloc(modelSize);
        sysctlbyname("hw.machine", machine, &modelSize, NULL, 0);
        NSString *deviceModel = [NSString stringWithUTF8String:machine];
        free(machine);

        int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
        struct kinfo_proc info;
        size_t size = sizeof(info);
        BOOL debuggerAttached = NO;
        if (sysctl(mib, 4, &info, &size, NULL, 0) == 0) {
            debuggerAttached = ((info.kp_proc.p_flag & P_TRACED) != 0);
        }

        struct task_basic_info taskInfo;
        mach_msg_type_number_t tSize = TASK_BASIC_INFO_COUNT;
        task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&taskInfo, &tSize);
        double appRamMB = taskInfo.resident_size / (1024.0 * 1024.0);
        unsigned long long totalDeviceRam = [[NSProcessInfo processInfo] physicalMemory] / (1024 * 1024);
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"Unknown";
        NSString *iosVersion = [[UIDevice currentDevice] systemVersion];

        self.shareSummaryText = [NSString stringWithFormat:
                                 @"📊 PerfMonitor Diagnostics\n"
                                 @"------------------------\n"
                                 @"Device Model: %@\n"
                                 @"iOS Version: %@\n"
                                 @"Bundle ID: %@\n"
                                 @"Debugger Attached: %@\n"
                                 @"App RAM Usage: %.1f MB\n"
                                 @"Total Device RAM: %llu MB",
                                 deviceModel, iosVersion, bundleId, debuggerAttached ? @"Yes" : @"No", appRamMB, totalDeviceRam];

        CGFloat contentY = 104;
        CGFloat contentH = _cardView.frame.size.height - contentY - 80;

        // --- TAB 1: DIAGNOSTICS VIEW ---
        _diagScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(16, contentY, _cardView.frame.size.width - 32, contentH)];
        _diagScrollView.showsVerticalScrollIndicator = NO;
        [_cardView addSubview:_diagScrollView];

        NSArray *items = @[
            @{@"icon": @"iphone", @"title": @"Model urządzenia", @"value": deviceModel},
            @{@"icon": @"gearshape", @"title": @"Wersja iOS", @"value": iosVersion},
            @{@"icon": @"app.badge", @"title": @"Bundle ID", @"value": bundleId},
            @{@"icon": @"ladybug", @"title": @"Debugger", @"value": debuggerAttached ? @"Tak" : @"Nie"},
            @{@"icon": @"memorychip", @"title": @"Zużycie RAM", @"value": [NSString stringWithFormat:@"%.1f MB", appRamMB]},
            @{@"icon": @"internaldrive", @"title": @"RAM urządzenia", @"value": [NSString stringWithFormat:@"%llu MB", totalDeviceRam]}
        ];

        CGFloat yOffset = 0;
        for (NSDictionary *item in items) {
            UIView *rowView = [[UIView alloc] initWithFrame:CGRectMake(0, yOffset, _diagScrollView.frame.size.width, 44)];
            rowView.backgroundColor = [self rowBackgroundColor];
            rowView.layer.cornerRadius = 10;

            UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:item[@"icon"]]];
            iconView.frame = CGRectMake(12, 12, 20, 20);
            iconView.tintColor = [UIColor systemBlueColor];
            [rowView addSubview:iconView];

            UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(44, 2, rowView.frame.size.width - 160, 40)];
            nameLabel.text = item[@"title"];
            nameLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
            [rowView addSubview:nameLabel];

            UILabel *valLabel = [[UILabel alloc] initWithFrame:rowView.frame.size.width - 120 > 44 ? CGRectMake(rowView.frame.size.width - 125, 2, 110, 40) : CGRectZero];
            valLabel.text = item[@"value"];
            valLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
            valLabel.textColor = [UIColor secondaryLabelColor];
            valLabel.textAlignment = NSTextAlignmentRight;
            [rowView addSubview:valLabel];

            [_diagScrollView addSubview:rowView];
            yOffset += 50;
        }
        _diagScrollView.contentSize = CGSizeMake(_diagScrollView.frame.size.width, yOffset);

        // Stress Test Button
        _testButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _testButton.frame = CGRectMake(16, _cardView.frame.size.height - 64, _cardView.frame.size.width - 32, 44);
        _testButton.backgroundColor = [UIColor systemRedColor];
        [_testButton setTitle:@"Uruchom Stress Test RAM (OOM)" forState:UIControlStateNormal];
        [_testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _testButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _testButton.layer.cornerRadius = 12;
        [_testButton addTarget:self action:@selector(runStressTestTapped) forControlEvents:UIControlEventTouchUpInside];
        [_cardView addSubview:_testButton];

        // --- TAB 2: PIP SETTINGS VIEW ---
        _settingsContainerView = [[UIView alloc] initWithFrame:CGRectMake(16, contentY, _cardView.frame.size.width - 32, contentH + 20)];
        _settingsContainerView.hidden = YES;
        [_cardView addSubview:_settingsContainerView];

        UIScrollView *settingsScroll = [[UIScrollView alloc] initWithFrame:_settingsContainerView.bounds];
        settingsScroll.showsVerticalScrollIndicator = NO;
        [_settingsContainerView addSubview:settingsScroll];

        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        float curOpacity = [defs floatForKey:@"perf_pip_opacity"];
        if (curOpacity <= 0.05f) curOpacity = 0.85f;
        NSInteger curColorIdx = [defs integerForKey:@"perf_pip_color_idx"];
        float curScale = [defs floatForKey:@"perf_pip_scale"];
        if (curScale < 0.6f || curScale > 1.6f) curScale = 1.0f;

        CGFloat sY = 0;

        // Theme Mode Selector Row
        UILabel *themeTitle = [[UILabel alloc] initWithFrame:CGRectMake(4, sY, 150, 32)];
        themeTitle.text = @"Wygląd Menu";
        themeTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        [settingsScroll addSubview:themeTitle];

        _themeSegmentControl = [[UISegmentedControl alloc] initWithItems:@[@"Ciemny", @"Jasny"]];
        _themeSegmentControl.frame = CGRectMake(settingsScroll.frame.size.width - 150, sY, 150, 32); // <-- Poprawiony nawias
        NSInteger themeIdx = [defs boolForKey:@"perf_is_light_theme"] ? 1 : 0;
        _themeSegmentControl.selectedSegmentIndex = themeIdx;
        [_themeSegmentControl addTarget:self action:@selector(themeChanged:) forControlEvents:UIControlEventValueChanged];
        [settingsScroll addSubview:_themeSegmentControl];
        sY += 50;

        // Preview Box
        UIView *previewBox = [[UIView alloc] initWithFrame:CGRectMake(0, sY, settingsScroll.frame.size.width, 90)];
        previewBox.backgroundColor = [self rowBackgroundColor];
        previewBox.layer.cornerRadius = 12;
        [settingsScroll addSubview:previewBox];

        _previewPipView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 130, 48)];
        _previewPipView.center = CGPointMake(previewBox.frame.size.width / 2.0, 45);
        _previewPipView.layer.cornerRadius = 10;
        _previewPipView.layer.masksToBounds = YES;
        _previewPipView.backgroundColor = getPerfColorForIndex(curColorIdx, curOpacity);
        _previewPipView.transform = CGAffineTransformMakeScale(curScale, curScale);
        [previewBox addSubview:_previewPipView];

        _previewInfoLabel = [[UILabel alloc] initWithFrame:_previewPipView.bounds];
        _previewInfoLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _previewInfoLabel.textColor = [UIColor whiteColor];
        _previewInfoLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        _previewInfoLabel.textAlignment = NSTextAlignmentCenter;
        _previewInfoLabel.text = @"CPU: 12.4%\nRAM: 48.2 MB";
        [_previewPipView addSubview:_previewInfoLabel];

        sY += 104;

        // Size Slider
        UILabel *szTitle = [[UILabel alloc] initWithFrame:CGRectMake(4, sY, 150, 20)];
        szTitle.text = @"Skala widżetu";
        szTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
        [settingsScroll addSubview:szTitle];

        _sizeValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(settingsScroll.frame.size.width - 70, sY, 66, 20)];
        _sizeValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)(curScale * 100)];
        _sizeValueLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        _sizeValueLabel.textColor = [UIColor systemBlueColor];
        _sizeValueLabel.textAlignment = NSTextAlignmentRight;
        [settingsScroll addSubview:_sizeValueLabel];
        sY += 26;

        _sizeSlider = [[UISlider alloc] initWithFrame:CGRectMake(4, sY, settingsScroll.frame.size.width - 8, 30)];
        _sizeSlider.minimumValue = 0.65f;
        _sizeSlider.maximumValue = 1.35f;
        _sizeSlider.value = curScale;
        [_sizeSlider addTarget:self action:@selector(sizeSliderChanged:) forControlEvents:UIControlEventValueChanged];
        [settingsScroll addSubview:_sizeSlider];
        sY += 45;

        // Opacity Slider
        UILabel *opTitle = [[UILabel alloc] initWithFrame:CGRectMake(4, sY, 150, 20)];
        opTitle.text = @"Przezroczystość";
        opTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
        [settingsScroll addSubview:opTitle];

        _opacityValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(settingsScroll.frame.size.width - 70, sY, 66, 20)];
        _opacityValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)(curOpacity * 100)];
        _opacityValueLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        _opacityValueLabel.textColor = [UIColor systemBlueColor];
        _opacityValueLabel.textAlignment = NSTextAlignmentRight;
        [settingsScroll addSubview:_opacityValueLabel];
        sY += 26;

        _opacitySlider = [[UISlider alloc] initWithFrame:CGRectMake(4, sY, settingsScroll.frame.size.width - 8, 30)];
        _opacitySlider.minimumValue = 0.2f;
        _opacitySlider.maximumValue = 1.0f;
        _opacitySlider.value = curOpacity;
        [_opacitySlider addTarget:self action:@selector(opacitySliderChanged:) forControlEvents:UIControlEventValueChanged];
        [settingsScroll addSubview:_opacitySlider];
        sY += 50;

        settingsScroll.contentSize = CGSizeMake(settingsScroll.frame.size.width, sY);
    }
    return self;
}

- (BOOL)isLightTheme {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"perf_is_light_theme"];
}

- (void)updateThemeStyling {
    BOOL light = [self isLightTheme];
    UIBlurEffectStyle blurStyle = light ? UIBlurEffectStyleLight : UIBlurEffectStyleDark;
    
    if (!_blurView) {
        _blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
        _blurView.frame = self.bounds;
        _blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self insertSubview:_blurView atIndex:0];
    } else {
        _blurView.effect = [UIBlurEffect effectWithStyle:blurStyle];
    }

    if (_cardView) {
        _cardView.backgroundColor = light ? [UIColor colorWithRed:0.95 green:0.95 blue:0.97 alpha:0.95] : [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:0.95];
        _cardView.layer.borderColor = light ? [[UIColor lightGrayColor] CGColor] : [[UIColor darkGrayColor] CGColor];
    }
}

- (UIColor *)rowBackgroundColor {
    return [self isLightTheme] ? [UIColor whiteColor] : [UIColor colorWithRed:0.17 green:0.17 blue:0.18 alpha:1.0];
}

- (void)themeChanged:(UISegmentedControl *)sender {
    BOOL isLight = (sender.selectedSegmentIndex == 1);
    [[NSUserDefaults standardUserDefaults] setBool:isLight forKey:@"perf_is_light_theme"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [UIView animateWithDuration:0.3 animations:^{
        [self updateThemeStyling];
    }];
    
    if (fullScreenMenuWindow) {
        fullScreenMenuWindow.rootViewController.view = [[PerfFullScreenMenuView alloc] initWithFrame:fullScreenMenuWindow.bounds];
    }
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    BOOL isDiag = (sender.selectedSegmentIndex == 0);
    _diagScrollView.hidden = !isDiag;
    _testButton.hidden = !isDiag;
    _settingsContainerView.hidden = isDiag;
}

- (void)sizeSliderChanged:(UISlider *)slider {
    float val = slider.value;
    _sizeValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)(val * 100)];
    [[NSUserDefaults standardUserDefaults] setFloat:val forKey:@"perf_pip_scale"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    _previewPipView.transform = CGAffineTransformMakeScale(val, val);
    if (sharedMonitorView) [sharedMonitorView applySettings];
}

- (void)opacitySliderChanged:(UISlider *)slider {
    float val = slider.value;
    _opacityValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)(val * 100)];
    [[NSUserDefaults standardUserDefaults] setFloat:val forKey:@"perf_pip_opacity"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSInteger colorIdx = [[NSUserDefaults standardUserDefaults] integerForKey:@"perf_pip_color_idx"];
    _previewPipView.backgroundColor = getPerfColorForIndex(colorIdx, val);
    if (sharedMonitorView) [sharedMonitorView applySettings];
}

- (void)closeTapped {
    if (fullScreenMenuWindow) {
        [UIView animateWithDuration:0.2 animations:^{
            self.alpha = 0;
        } completion:^(BOOL finished) {
            fullScreenMenuWindow.hidden = YES;
            fullScreenMenuWindow = nil;
        }];
    }
}

- (void)runStressTestTapped {
    if (self.onRunTest) self.onRunTest();
}
@end
