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

        // Top Status Notification Banner
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

        // Central Guide Card
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

        // Skip button
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
    if (self.onCompleted) {
        self.onCompleted();
    }
}

- (void)clearDots {
    for (UIView *subview in [self.subviews copy]) {
        if (subview.tag == 7777) {
            [subview removeFromSuperview];
        }
    }
}

// Multi-touch tracking
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self renderTouchesFromEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self renderTouchesFromEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self renderTouchesFromEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self clearDots];
}

- (void)renderTouchesFromEvent:(UIEvent *)event {
    [self clearDots];
    NSSet<UITouch *> *allTouches = event.allTouches;
    
    BOOL isFourFingers = (allTouches.count >= 4);
    UIColor *dotColor = isFourFingers ? [UIColor systemGreenColor] : [[UIColor systemCyanColor] colorWithAlphaComponent:0.8];
    
    _touchCountLabel.text = [NSString stringWithFormat:@"Touches detected: %lu / 4", (unsigned long)allTouches.count];
    if (isFourFingers) {
        _touchCountLabel.textColor = [UIColor systemGreenColor];
    } else {
        _touchCountLabel.textColor = [UIColor lightGrayColor];
    }

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
            if (self.onCompleted) {
                self.onCompleted();
            }
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

        // Start FPS tracking via runtime dynamic resolution (compiles without QuartzCore static link requirement)
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
    if (linkTimestamp <= 0) {
        linkTimestamp = [[NSDate date] timeIntervalSince1970];
    }

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
    
    // Opacity
    float opacity = [defs floatForKey:@"perf_pip_opacity"];
    if (opacity <= 0.05f) opacity = 0.85f;

    // Color
    NSInteger colorIdx = [defs integerForKey:@"perf_pip_color_idx"];
    self.backgroundColor = getPerfColorForIndex(colorIdx, opacity);

    // Count visible lines to auto-size window
    BOOL showCpu = [defs objectForKey:@"perf_show_cpu"] ? [defs boolForKey:@"perf_show_cpu"] : YES;
    BOOL showRam = [defs objectForKey:@"perf_show_ram"] ? [defs boolForKey:@"perf_show_ram"] : YES;
    BOOL showTemp = [defs objectForKey:@"perf_show_temp"] ? [defs boolForKey:@"perf_show_temp"] : YES;
    BOOL showFps = [defs boolForKey:@"perf_show_fps"];

    int activeCount = (showCpu ? 1 : 0) + (showRam ? 1 : 0) + (showTemp ? 1 : 0) + (showFps ? 1 : 0);
    if (activeCount == 0) activeCount = 1;

    CGFloat newH = 26 + activeCount * 17;
    CGFloat newW = (showFps ? 150 : 142);

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

    if (lines.count == 0) {
        self.infoLabel.text = @"PiP Active";
    } else {
        self.infoLabel.text = [lines componentsJoinedByString:@"\n"];
    }
}

@end

// --- MODERN PROFESSIONAL FULL-SCREEN MENU WITH SETTINGS ---
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
    UILabel *_opacityValueLabel;
    UISlider *_opacitySlider;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = self.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:blurView];

        UIView *cardView = [[UIView alloc] initWithFrame:CGRectMake(24, 35, frame.size.width - 48, frame.size.height - 70)];
        cardView.center = CGPointMake(frame.size.width / 2.0, frame.size.height / 2.0);
        cardView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        cardView.backgroundColor = [[UIColor colorWithRed:0.12 green:0.12 blue:0.15 alpha:1.0] colorWithAlphaComponent:0.95];
        cardView.layer.cornerRadius = 24;
        cardView.layer.borderWidth = 1.0;
        cardView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15].CGColor;
        [self addSubview:cardView];

        // Title icon
        UIImageView *titleIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"waveform.path.ecg"]];
        titleIcon.frame = CGRectMake(18, 20, 24, 24);
        titleIcon.tintColor = [UIColor systemBlueColor];
        [cardView addSubview:titleIcon];

        // Title label
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(48, 16, cardView.frame.size.width - 130, 30)];
        titleLabel.text = @"Performance Dashboard";
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
        [cardView addSubview:titleLabel];

        // Share button
        UIButton *shareButton = [UIButton buttonWithType:UIButtonTypeSystem];
        shareButton.frame = CGRectMake(cardView.frame.size.width - 78, 16, 30, 30);
        [shareButton setImage:[UIImage systemImageNamed:@"square.and.arrow.up"] forState:UIControlStateNormal];
        shareButton.tintColor = [UIColor systemBlueColor];
        [shareButton addTarget:self action:@selector(shareTapped) forControlEvents:UIControlEventTouchUpInside];
        [cardView addSubview:shareButton];

        // Close button
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        closeButton.frame = CGRectMake(cardView.frame.size.width - 42, 16, 30, 30);
        [closeButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
        closeButton.tintColor = [UIColor secondaryLabelColor];
        [closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
        [cardView addSubview:closeButton];

        // Segmented control: Diagnostics vs PiP Settings
        _segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Diagnostics", @"PiP Settings"]];
        _segmentedControl.frame = CGRectMake(18, 54, cardView.frame.size.width - 36, 32);
        _segmentedControl.selectedSegmentIndex = 0;
        [_segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
        [cardView addSubview:_segmentedControl];

        // --- TAB 1: DIAGNOSTICS VIEW ---
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
                                 @"Memory+ Kernel: Active\n"
                                 @"App RAM Usage: %.1f MB\n"
                                 @"Total Device RAM: %llu MB",
                                 deviceModel, iosVersion, bundleId, debuggerAttached ? @"Yes" : @"No", appRamMB, totalDeviceRam];

        CGFloat contentY = 94;
        CGFloat contentH = cardView.frame.size.height - contentY - 100;

        _diagScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(18, contentY, cardView.frame.size.width - 36, contentH)];
        _diagScrollView.showsVerticalScrollIndicator = NO;
        [cardView addSubview:_diagScrollView];

        NSArray *items = @[
            @{@"icon": @"iphone", @"title": @"Device Model", @"value": deviceModel},
            @{@"icon": @"gearshape", @"title": @"iOS Version", @"value": iosVersion},
            @{@"icon": @"app.badge", @"title": @"Bundle ID", @"value": bundleId},
            @{@"icon": @"ladybug", @"title": @"Debugger Attached", @"value": debuggerAttached ? @"Yes (Connected)" : @"No (Clean)"},
            @{@"icon": @"cpu", @"title": @"Memory+ Kernel", @"value": @"Active"},
            @{@"icon": @"memorychip", @"title": @"App RAM Usage", @"value": [NSString stringWithFormat:@"%.1f MB", appRamMB]},
            @{@"icon": @"internaldrive", @"title": @"Total Device RAM", @"value": [NSString stringWithFormat:@"%llu MB", totalDeviceRam]}
        ];

        CGFloat yOffset = 0;
        for (NSDictionary *item in items) {
            UIButton *rowButton = [UIButton buttonWithType:UIButtonTypeCustom];
            rowButton.frame = CGRectMake(0, yOffset, _diagScrollView.frame.size.width, 46);
            rowButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
            rowButton.layer.cornerRadius = 12;

            UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:item[@"icon"]]];
            iconView.frame = CGRectMake(12, 13, 20, 20);
            iconView.tintColor = [UIColor systemCyanColor];
            iconView.contentMode = UIViewContentModeScaleAspectFit;
            iconView.userInteractionEnabled = NO;
            [rowButton addSubview:iconView];

            UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(42, 3, rowButton.frame.size.width - 150, 40)];
            nameLabel.text = item[@"title"];
            nameLabel.textColor = [UIColor lightGrayColor];
            nameLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            nameLabel.userInteractionEnabled = NO;
            [rowButton addSubview:nameLabel];

            UILabel *valLabel = [[UILabel alloc] initWithFrame:CGRectMake(rowButton.frame.size.width - 110, 3, 100, 40)];
            valLabel.text = item[@"value"];
            valLabel.textColor = [UIColor whiteColor];
            valLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
            valLabel.textAlignment = NSTextAlignmentRight;
            valLabel.userInteractionEnabled = NO;
            valLabel.tag = 999;
            [rowButton addSubview:valLabel];

            [rowButton addTarget:self action:@selector(copyRowValue:) forControlEvents:UIControlEventTouchUpInside];
            [_diagScrollView addSubview:rowButton];
            yOffset += 52;
        }
        _diagScrollView.contentSize = CGSizeMake(_diagScrollView.frame.size.width, yOffset);

        // Przycisk Stress Test
        _testButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _testButton.frame = CGRectMake(18, cardView.frame.size.height - 98, cardView.frame.size.width - 36, 40);
        _testButton.backgroundColor = [UIColor systemRedColor];
        [_testButton setTitle:@"Run RAM Stress Test (OOM)" forState:UIControlStateNormal];
        [_testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _testButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        _testButton.layer.cornerRadius = 12;
        [_testButton addTarget:self action:@selector(runStressTestTapped) forControlEvents:UIControlEventTouchUpInside];
        [cardView addSubview:_testButton];

        // --- TAB 2: PIP SETTINGS VIEW ---
        _settingsContainerView = [[UIView alloc] initWithFrame:CGRectMake(18, contentY, cardView.frame.size.width - 36, cardView.frame.size.height - contentY - 56)];
        _settingsContainerView.hidden = YES;
        [cardView addSubview:_settingsContainerView];

        UIScrollView *settingsScroll = [[UIScrollView alloc] initWithFrame:_settingsContainerView.bounds];
        settingsScroll.showsVerticalScrollIndicator = NO;
        [_settingsContainerView addSubview:settingsScroll];

        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        float curOpacity = [defs floatForKey:@"perf_pip_opacity"];
        if (curOpacity <= 0.05f) curOpacity = 0.85f;
        NSInteger curColorIdx = [defs integerForKey:@"perf_pip_color_idx"];

        CGFloat sY = 4;

        // 1. Opacity Header & Slider
        UILabel *opTitle = [[UILabel alloc] initWithFrame:CGRectMake(4, sY, settingsScroll.frame.size.width - 80, 20)];
        opTitle.text = @"PiP Opacity (Przeźroczystość)";
        opTitle.textColor = [UIColor whiteColor];
        opTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        [settingsScroll addSubview:opTitle];

        _opacityValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(settingsScroll.frame.size.width - 70, sY, 66, 20)];
        _opacityValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)(curOpacity * 100)];
        _opacityValueLabel.textColor = [UIColor systemCyanColor];
        _opacityValueLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        _opacityValueLabel.textAlignment = NSTextAlignmentRight;
        [settingsScroll addSubview:_opacityValueLabel];
        sY += 26;

        _opacitySlider = [[UISlider alloc] initWithFrame:CGRectMake(4, sY, settingsScroll.frame.size.width - 8, 30)];
        _opacitySlider.minimumValue = 0.2f;
        _opacitySlider.maximumValue = 1.0f;
        _opacitySlider.value = curOpacity;
        _opacitySlider.tintColor = [UIColor systemCyanColor];
        [_opacitySlider addTarget:self action:@selector(opacitySliderChanged:) forControlEvents:UIControlEventValueChanged];
        [settingsScroll addSubview:_opacitySlider];
        sY += 40;

        // 2. Color Selection Palette
        UILabel *colTitle = [[UILabel alloc] initWithFrame:CGRectMake(4, sY, settingsScroll.frame.size.width - 8, 20)];
        colTitle.text = @"PiP Background Color (Kolor tła)";
        colTitle.textColor = [UIColor whiteColor];
        colTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        [settingsScroll addSubview:colTitle];
        sY += 26;

        NSArray *colorNames = @[@"Black", @"Navy", @"Cyan", @"Purple", @"Emerald", @"Crimson"];
        CGFloat btnW = (settingsScroll.frame.size.width - 20) / 3.0;
        CGFloat btnH = 34;

        for (int i = 0; i < 6; i++) {
            CGFloat colX = (i % 3) * (btnW + 8);
            CGFloat colY = sY + (i / 3) * (btnH + 8);

            UIButton *colBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            colBtn.frame = CGRectMake(colX, colY, btnW, btnH);
            colBtn.backgroundColor = getPerfColorForIndex(i, 0.95);
            colBtn.layer.cornerRadius = 10;
            colBtn.layer.borderWidth = (i == curColorIdx) ? 2.5 : 1.0;
            colBtn.layer.borderColor = (i == curColorIdx) ? [UIColor whiteColor].CGColor : [[UIColor whiteColor] colorWithAlphaComponent:0.2].CGColor;
            [colBtn setTitle:colorNames[i] forState:UIControlStateNormal];
            colBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
            colBtn.tag = 100 + i;
            [colBtn addTarget:self action:@selector(colorSelected:) forControlEvents:UIControlEventTouchUpInside];
            [settingsScroll addSubview:colBtn];
        }
        sY += (btnH + 8) * 2 + 12;

        // 3. Visible Metrics Toggles
        UILabel *metricsTitle = [[UILabel alloc] initWithFrame:CGRectMake(4, sY, settingsScroll.frame.size.width - 8, 20)];
        metricsTitle.text = @"Visible Metrics (Wyświetlane dane)";
        metricsTitle.textColor = [UIColor whiteColor];
        metricsTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        [settingsScroll addSubview:metricsTitle];
        sY += 26;

        NSArray *switchesConfig = @[
            @{@"key": @"perf_show_cpu", @"label": @"Show CPU Usage", @"def": @YES},
            @{@"key": @"perf_show_ram", @"label": @"Show RAM Usage", @"def": @YES},
            @{@"key": @"perf_show_temp", @"label": @"Show Thermal State", @"def": @YES},
            @{@"key": @"perf_show_fps", @"label": @"Show Render FPS", @"def": @NO}
        ];

        for (NSDictionary *cfg in switchesConfig) {
            UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, sY, settingsScroll.frame.size.width, 42)];
            row.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
            row.layer.cornerRadius = 10;

            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 11, row.frame.size.width - 70, 20)];
            lbl.text = cfg[@"label"];
            lbl.textColor = [UIColor lightTextColor];
            lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            [row addSubview:lbl];

            UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(row.frame.size.width - 62, 6, 50, 30)];
            BOOL val = [defs objectForKey:cfg[@"key"]] ? [defs boolForKey:cfg[@"key"]] : [cfg[@"def"] boolValue];
            sw.on = val;
            sw.accessibilityIdentifier = cfg[@"key"];
            [sw addTarget:self action:@selector(metricSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            [row addSubview:sw];

            [settingsScroll addSubview:row];
            sY += 48;
        }

        settingsScroll.contentSize = CGSizeMake(settingsScroll.frame.size.width, sY + 20);

        // --- FOOTER: CREATED BY EKSEMEKSE-DEV WITH AI + GITHUB BUTTON ---
        UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(18, cardView.frame.size.height - 52, cardView.frame.size.width - 36, 44)];
        [cardView addSubview:footerView];

        UILabel *creditLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, footerView.frame.size.width - 95, 44)];
        creditLabel.text = @"Created by Eksemekse-dev with AI";
        creditLabel.textColor = [UIColor darkGrayColor];
        creditLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        creditLabel.numberOfLines = 2;
        [footerView addSubview:creditLabel];

        UIButton *githubButton = [UIButton buttonWithType:UIButtonTypeSystem];
        githubButton.frame = CGRectMake(footerView.frame.size.width - 90, 6, 90, 32);
        [githubButton setImage:[UIImage systemImageNamed:@"network"] forState:UIControlStateNormal];
        [githubButton setTitle:@" GitHub" forState:UIControlStateNormal];
        githubButton.tintColor = [UIColor systemBlueColor];
        githubButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
        githubButton.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.12];
        githubButton.layer.cornerRadius = 8;
        githubButton.layer.borderWidth = 1.0;
        githubButton.layer.borderColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.3].CGColor;
        [githubButton addTarget:self action:@selector(openGithubTapped) forControlEvents:UIControlEventTouchUpInside];
        [footerView addSubview:githubButton];
    }
    return self;
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    if (sender.selectedSegmentIndex == 0) {
        _diagScrollView.hidden = NO;
        _testButton.hidden = NO;
        _settingsContainerView.hidden = YES;
    } else {
        _diagScrollView.hidden = YES;
        _testButton.hidden = YES;
        _settingsContainerView.hidden = NO;
    }
}

- (void)opacitySliderChanged:(UISlider *)sender {
    @try {
        float val = sender.value;
        _opacityValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)(val * 100)];
        [[NSUserDefaults standardUserDefaults] setFloat:val forKey:@"perf_pip_opacity"];
        if (sharedMonitorView) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [sharedMonitorView applySettings];
            });
        }
    } @catch (NSException *e) {}
}

- (void)colorSelected:(UIButton *)sender {
    @try {
        NSInteger idx = sender.tag - 100;
        [[NSUserDefaults standardUserDefaults] setInteger:idx forKey:@"perf_pip_color_idx"];

        UIView *parentView = sender.superview;
        if (parentView) {
            for (UIView *subview in parentView.subviews) {
                if ([subview isKindOfClass:[UIButton class]] && subview.tag >= 100 && subview.tag <= 105) {
                    UIButton *btn = (UIButton *)subview;
                    BOOL isCurrent = (btn.tag == sender.tag);
                    btn.layer.borderWidth = isCurrent ? 2.5 : 1.0;
                    btn.layer.borderColor = isCurrent ? [UIColor whiteColor].CGColor : [[UIColor whiteColor] colorWithAlphaComponent:0.2].CGColor;
                }
            }
        }

        @try {
            Class feedbackClass = NSClassFromString(@"UIImpactFeedbackGenerator");
            if (feedbackClass) {
                UIImpactFeedbackGenerator *gen = [[(UIImpactFeedbackGenerator *)[feedbackClass alloc] initWithStyle:UIImpactFeedbackStyleLight] init];
                [gen impactOccurred];
            }
        } @catch (NSException *ex) {}

        if (sharedMonitorView) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [sharedMonitorView applySettings];
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"[PerfMonitor] colorSelected error: %@", exception);
    }
}

- (void)metricSwitchChanged:(UISwitch *)sender {
    @try {
        NSString *key = sender.accessibilityIdentifier;
        if (key) {
            [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:key];
            if (sharedMonitorView) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [sharedMonitorView applySettings];
                });
            }
        }
    } @catch (NSException *e) {}
}

- (void)openGithubTapped {
    NSURL *url = [NSURL URLWithString:@"https://github.com/Eksemekse-dev/iOS-PerfMonitor"];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (void)copyRowValue:(UIButton *)sender {
    for (UIView *subview in sender.subviews) {
        if ([subview isKindOfClass:[UILabel class]] && subview.tag == 999) {
            UILabel *valLabel = (UILabel *)subview;
            if (valLabel.text) {
                [UIPasteboard generalPasteboard].string = valLabel.text;
                UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
                [generator impactOccurred];

                UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake((self.frame.size.width - 160) / 2.0, self.frame.size.height - 110, 160, 36)];
                toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
                toast.textColor = [UIColor whiteColor];
                toast.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
                toast.textAlignment = NSTextAlignmentCenter;
                toast.text = @"Copied to clipboard!";
                toast.layer.cornerRadius = 18;
                toast.layer.masksToBounds = YES;
                toast.alpha = 0.0;
                [self addSubview:toast];

                [UIView animateWithDuration:0.2 animations:^{
                    toast.alpha = 1.0;
                } completion:^(BOOL finished) {
                    [UIView animateWithDuration:0.3 delay:1.2 options:0 animations:^{
                        toast.alpha = 0.0;
                    } completion:^(BOOL finished) {
                        [toast removeFromSuperview];
                    }];
                }];
            }
            break;
        }
    }
}

- (void)shareTapped {
    if (!self.shareSummaryText) return;
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[self.shareSummaryText] applicationActivities:nil];
    UIWindow *keyWindow = self.window;
    UIViewController *rootVC = keyWindow.rootViewController;
    if (rootVC) {
        [rootVC presentViewController:activityVC animated:YES completion:nil];
    }
}

- (void)runStressTestTapped {
    if (self.onRunTest) self.onRunTest();
}

- (void)closeTapped {
    if (self.onClose) self.onClose();
}

@end

// --- GESTURE & LIFECYCLE MANAGERS ---
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

// --- GESTURES & HANDLERS ---
@interface PerfMonitorGestureHandler : NSObject
+ (void)handleFourFingerTap:(UITapGestureRecognizer *)sender;
+ (void)handleFourFingerLongPress:(UILongPressGestureRecognizer *)sender;
+ (void)handleOrientationChange:(NSNotification *)notification;
+ (void)dismissTutorialAndExecute:(void(^)(void))action;
@end

@implementation PerfMonitorGestureHandler

+ (void)dismissTutorialAndExecute:(void(^)(void))action {
    if (tutorialWindow) {
        [UIView animateWithDuration:0.3 animations:^{
            tutorialWindow.alpha = 0.0;
        } completion:^(BOOL finished) {
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
            if (sharedMonitorWindow) {
                sharedMonitorWindow.hidden = !sharedMonitorWindow.hidden;
            }
        }];
    }
}

+ (void)handleFourFingerLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        [self dismissTutorialAndExecute:^{
            if (fullScreenMenuWindow) return;

            UIWindowScene *targetScene = nil;
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    targetScene = scene;
                    break;
                }
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
                    if (menuWinRef) {
                        menuWinRef.hidden = YES;
                        fullScreenMenuWindow = nil;
                    }
                    [PerfMonitorManager runRamStressTest];
                }]];
                [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
                
                UIViewController *vc = [[UIViewController alloc] init];
                menuWinRef.rootViewController = vc;
                [vc presentViewController:confirm animated:YES completion:nil];
            };

            fullScreenMenuWindow.rootViewController = [[UIViewController alloc] init];
            [fullScreenMenuWindow.rootViewController.view addSubview:menuView];
        }];
    }
}

+ (void)handleOrientationChange:(NSNotification *)notification {
    if (fullScreenMenuWindow || tutorialWindow) {
        return;
    }

    if (sharedMonitorWindow && !sharedMonitorWindow.isHidden) {
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        sharedMonitorWindow.center = CGPointMake(screenSize.width / 2.0, 90.0);
    }
}

@end

__attribute__((constructor)) static void tweakEntry() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *targetWindow = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                targetWindow = scene.windows.firstObject;
                if (targetWindow) break;
            }
        }

        if (targetWindow) {
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
            fourFingerLongPress.minimumPressDuration = 2.0;
            [targetWindow addGestureRecognizer:fourFingerLongPress];

            [[NSNotificationCenter defaultCenter] addObserver:[PerfMonitorGestureHandler class]
                                                     selector:@selector(handleOrientationChange:)
                                                         name:UIDeviceOrientationDidChangeNotification
                                                       object:nil];
            
            if (![PerfMonitorManager hasCompletedTutorial]) {
                UIWindowScene *targetScene = nil;
                for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]]) {
                        targetScene = scene;
                        break;
                    }
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
        }
    });
}
