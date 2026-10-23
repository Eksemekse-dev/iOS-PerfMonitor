#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#include <unistd.h>
#include <dlfcn.h>

static inline UIColor *getPerfColorForIndex(NSInteger idx, CGFloat alpha) {
    switch (idx) {
        case 1: return [[UIColor colorWithRed:0.06 green:0.09 blue:0.18 alpha:1.0] colorWithAlphaComponent:alpha];
        case 2: return [[UIColor colorWithRed:0.03 green:0.20 blue:0.27 alpha:1.0] colorWithAlphaComponent:alpha];
        case 3: return [[UIColor colorWithRed:0.18 green:0.06 blue:0.38 alpha:1.0] colorWithAlphaComponent:alpha];
        case 4: return [[UIColor colorWithRed:0.02 green:0.28 blue:0.20 alpha:1.0] colorWithAlphaComponent:alpha];
        case 5: return [[UIColor colorWithRed:0.28 green:0.04 blue:0.04 alpha:1.0] colorWithAlphaComponent:alpha];
        default: return [[UIColor blackColor] colorWithAlphaComponent:alpha];
    }
}

// ===== TUTORIAL =====
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
                    if (window) { safeInsets = window.safeAreaInsets; break; }
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

- (void)skipTapped { if (self.onCompleted) self.onCompleted(); }

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

// ===== PiP MONITOR =====
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
    self.infoLabel.text = lines.count == 0 ? @"PiP Active" : [lines componentsJoinedByString:@"\n"];
}

@end

// ===== SECRET MENU (SwiftUI port) =====
@interface PerfFullScreenMenuView : UIView
@property (nonatomic, copy) void (^onClose)(void);
@property (nonatomic, copy) void (^onRunTest)(void);
@property (nonatomic, copy) NSString *shareSummaryText;
@end

@implementation PerfFullScreenMenuView {
    UIButton *_diagTabButton;
    UIButton *_settingsTabButton;
    UIScrollView *_diagScrollView;
    UIView *_settingsContainerView;
    UIButton *_testButton;
    UILabel *_opacityValueLabel;
    UISlider *_opacitySlider;
    UILabel *_sizeValueLabel;
    UISlider *_sizeSlider;
    UIView *_previewPipView;
    UILabel *_previewInfoLabel;
    BOOL _isDiagTab;
}

- (UIColor *)perfTeal { return [UIColor colorWithRed:0.0 green:0.78 blue:0.70 alpha:1.0]; }

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor whiteColor];
        _isDiagTab = YES;
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
        CGFloat bottomY = frame.size.height - (safeInsets.bottom > 0 ? safeInsets.bottom + 15 : 25);
        CGFloat L = 24, R = 24;
        CGFloat contentW = frame.size.width - L - R;

        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(L, topY, contentW - 130, 42)];
        titleLabel.text = @"Secret Menu";
        titleLabel.textColor = [UIColor blackColor];
        titleLabel.font = [UIFont systemFontOfSize:32 weight:UIFontWeightHeavy];
        titleLabel.adjustsFontSizeToFitWidth = YES;
        titleLabel.minimumScaleFactor = 0.7;
        [self addSubview:titleLabel];

        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        closeButton.frame = CGRectMake(frame.size.width - R - 50, topY + 2, 50, 50);
        closeButton.backgroundColor = [self perfTeal];
        closeButton.layer.cornerRadius = 25;
        [closeButton setTitle:@"✕" forState:UIControlStateNormal];
        [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        closeButton.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
        [closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:closeButton];

        UIButton *shareButton = [UIButton buttonWithType:UIButtonTypeCustom];
        shareButton.frame = CGRectMake(frame.size.width - R - 50 - 8 - 50, topY + 2, 50, 50);
        shareButton.backgroundColor = [self perfTeal];
        shareButton.layer.cornerRadius = 25;
        [shareButton setTitle:@"⬆" forState:UIControlStateNormal];
        [shareButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        shareButton.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
        [shareButton addTarget:self action:@selector(shareTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:shareButton];

        CGFloat tabY = topY + 66;
        CGFloat tabW = (contentW - 12) / 2.0;

        _diagTabButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _diagTabButton.frame = CGRectMake(L, tabY, tabW, 50);
        _diagTabButton.backgroundColor = [self perfTeal];
        _diagTabButton.layer.cornerRadius = 25;
        [_diagTabButton setTitle:@"Diagnostics" forState:UIControlStateNormal];
        [_diagTabButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _diagTabButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        [_diagTabButton addTarget:self action:@selector(diagTabTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_diagTabButton];

        _settingsTabButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _settingsTabButton.frame = CGRectMake(L + tabW + 12, tabY, tabW, 50);
        _settingsTabButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.04];
        _settingsTabButton.layer.cornerRadius = 25;
        [_settingsTabButton setTitle:@"PiP Settings" forState:UIControlStateNormal];
        [_settingsTabButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        _settingsTabButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        [_settingsTabButton addTarget:self action:@selector(settingsTabTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_settingsTabButton];

        CGFloat contentY = tabY + 60;
        CGFloat contentH = (bottomY - 120) - contentY;

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
        if (sysctl(mib, 4, &kinfo, &ksize, NULL, 0) == 0) {
            debuggerAttached = ((kinfo.kp_proc.p_flag & P_TRACED) != 0);
        }

        struct task_basic_info taskInfo;
        mach_msg_type_number_t tSize = TASK_BASIC_INFO_COUNT;
        task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&taskInfo, &tSize);
        double appRamMB = taskInfo.resident_size / (1024.0 * 1024.0);
        unsigned long long totalDeviceRam = [[NSProcessInfo processInfo] physicalMemory] / (1024 * 1024);
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"Unknown";
        NSString *iosVersion = [[UIDevice currentDevice] systemVersion];

        BOOL jitEnabled = debuggerAttached;
        typedef int (*csops_t)(pid_t, unsigned int, void*, size_t);
        csops_t csops_ptr = (csops_t)dlsym(RTLD_DEFAULT, "csops");
        if (csops_ptr) {
            uint32_t csFlags = 0;
            if (csops_ptr(getpid(), 0, &csFlags, sizeof(csFlags)) == 0) {
                jitEnabled = ((csFlags & 0x10000000) != 0);
            }
        }

        self.shareSummaryText = [NSString stringWithFormat:
                                 @"📊 PerfMonitor Diagnostics\n------------------------\nDevice Model: %@\niOS Version: %@\nBundle ID: %@\nDebugger Attached: %@\nJIT: %@\nMemory+ Kernel: Active\nApp RAM Usage: %.1f MB\nTotal Device RAM: %llu MB",
                                 deviceModel, iosVersion, bundleId,
                                 debuggerAttached ? @"Yes" : @"No",
                                 jitEnabled ? @"Enabled" : @"Disabled",
                                 appRamMB, totalDeviceRam];

        _diagScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(L, contentY, contentW, contentH)];
        _diagScrollView.showsVerticalScrollIndicator = NO;
        [self addSubview:_diagScrollView];

        NSArray *items = @[
            @{@"title": @"Device Model",     @"value": deviceModel},
            @{@"title": @"iOS Version",      @"value": iosVersion},
            @{@"title": @"Bundle ID",        @"value": bundleId},
            @{@"title": @"Memory+ Kernel",   @"value": @"Active"},
            @{@"title": @"App RAM Usage",    @"value": [NSString stringWithFormat:@"%.1f MB", appRamMB]},
            @{@"title": @"Total Device RAM", @"value": [NSString stringWithFormat:@"%llu MB", totalDeviceRam]},
            @{@"title": @"JIT",              @"value": jitEnabled ? @"Enabled" : @"Disabled"}
        ];

        CGFloat rowH = 49, rowGap = 9, yOff = 0;
        for (NSDictionary *item in items) {
            UIView *row = [self createRowWithTitle:item[@"title"] value:item[@"value"] width:contentW height:rowH];
            row.frame = CGRectMake(0, yOff, contentW, rowH);
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(rowTapped:)];
            [row addGestureRecognizer:tap];
            [_diagScrollView addSubview:row];
            yOff += rowH + rowGap;
        }
        _diagScrollView.contentSize = CGSizeMake(contentW, yOff);

        _settingsContainerView = [[UIView alloc] initWithFrame:CGRectMake(L, contentY, contentW, contentH)];
        _settingsContainerView.hidden = YES;
        [self addSubview:_settingsContainerView];
        [self buildSettingsUIInView:_settingsContainerView width:contentW height:contentH];

        _testButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _testButton.frame = CGRectMake(L, bottomY - 118, contentW, 55);
        _testButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.02 alpha:1.0];
        _testButton.layer.cornerRadius = 27.5;
        _testButton.layer.borderWidth = 0.5;
        _testButton.layer.borderColor = [UIColor colorWithRed:1.0 green:0.18 blue:0.18 alpha:1.0].CGColor;
        [_testButton setTitle:@"Run RAM Stress Test (OOM)" forState:UIControlStateNormal];
        [_testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _testButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        [_testButton addTarget:self action:@selector(runStressTestTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_testButton];

        UIButton *githubButton = [UIButton buttonWithType:UIButtonTypeCustom];
        githubButton.frame = CGRectMake(frame.size.width - R - 98, bottomY - 52, 98, 50);
        githubButton.backgroundColor = [self perfTeal];
        githubButton.layer.cornerRadius = 25;
        [githubButton setTitle:@"GitHub" forState:UIControlStateNormal];
        [githubButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        githubButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        [githubButton addTarget:self action:@selector(openGithubTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:githubButton];

        UILabel *footerLabel = [[UILabel alloc] initWithFrame:CGRectMake(L, bottomY - 52, contentW - 108, 50)];
        footerLabel.text = @"Created by Eksemekse-dev with AI, Version 3.0";
        footerLabel.textColor = [UIColor blackColor];
        footerLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
        footerLabel.numberOfLines = 2;
        [self addSubview:footerLabel];
    }
    return self;
}

- (UIView *)createRowWithTitle:(NSString *)title value:(NSString *)value width:(CGFloat)width height:(CGFloat)height {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    row.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.04];
    row.layer.cornerRadius = 23;
    row.userInteractionEnabled = YES;
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, width * 0.52, height)];
    titleLabel.text = title;
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    titleLabel.userInteractionEnabled = NO;
    [row addSubview:titleLabel];
    UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(width * 0.52, 0, width * 0.48 - 16, height)];
    valueLabel.text = value;
    valueLabel.textColor = [UIColor blackColor];
    valueLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    valueLabel.textAlignment = NSTextAlignmentRight;
    valueLabel.adjustsFontSizeToFitWidth = YES;
    valueLabel.minimumScaleFactor = 0.6;
    valueLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    valueLabel.tag = 999;
    valueLabel.userInteractionEnabled = NO;
    [row addSubview:valueLabel];
    return row;
}

- (void)buildSettingsUIInView:(UIView *)container width:(CGFloat)width height:(CGFloat)height {
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    scroll.showsVerticalScrollIndicator = NO;
    [container addSubview:scroll];

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    float curOpacity = [defs floatForKey:@"perf_pip_opacity"];
    if (curOpacity <= 0.05f) curOpacity = 0.85f;
    NSInteger curColorIdx = [defs integerForKey:@"perf_pip_color_idx"];
    float curScale = [defs floatForKey:@"perf_pip_scale"];
    if (curScale < 0.6f || curScale > 1.6f) curScale = 1.0f;

    CGFloat sY = 0;

    UIView *previewBox = [[UIView alloc] initWithFrame:CGRectMake(0, sY, width, 110)];
    previewBox.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.04];
    previewBox.layer.cornerRadius = 23;
    previewBox.clipsToBounds = YES;
    [scroll addSubview:previewBox];

    UILabel *previewTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 8, width - 32, 16)];
    previewTitle.text = @"LIVE PIP PREVIEW";
    previewTitle.textColor = [self perfTeal];
    previewTitle.font = [UIFont systemFontOfSize:11 weight:UIFontWeightHeavy];
    [previewBox addSubview:previewTitle];

    _previewPipView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 142, 56)];
    _previewPipView.center = CGPointMake(width / 2.0, 72);
    _previewPipView.layer.cornerRadius = 12;
    _previewPipView.layer.masksToBounds = YES;
    _previewPipView.layer.borderWidth = 1.0;
    _previewPipView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
    _previewPipView.backgroundColor = getPerfColorForIndex(curColorIdx, curOpacity);
    _previewPipView.transform = CGAffineTransformMakeScale(curScale, curScale);
    [previewBox addSubview:_previewPipView];

    _previewInfoLabel = [[UILabel alloc] initWithFrame:_previewPipView.bounds];
    _previewInfoLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _previewInfoLabel.textColor = [UIColor whiteColor];
    _previewInfoLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    _previewInfoLabel.numberOfLines = 0;
    _previewInfoLabel.textAlignment = NSTextAlignmentCenter;
    _previewInfoLabel.text = @"CPU: 14.8%\nRAM: 52.4 MB\nTemp: Normal";
    [_previewPipView addSubview:_previewInfoLabel];

    sY += 118;

    UILabel *szTitle = [[UILabel alloc] initWithFrame:CGRectMake(4, sY, width - 80, 20)];
    szTitle.text = @"PiP Size";
    szTitle.textColor = [UIColor blackColor];
    szTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    [scroll addSubview:szTitle];

    _sizeValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(width - 70, sY, 66, 20)];
    _sizeValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)(curScale * 100)];
    _sizeValueLabel.textColor = [self perfTeal];
    _sizeValueLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    _sizeValueLabel.textAlignment = NSTextAlignmentRight;
    [scroll addSubview:_sizeValueLabel];
    sY += 26;

    _sizeSlider = [[UISlider alloc] initWithFrame:CGRectMake(4, sY, width - 8, 30)];
    _sizeSlider.minimumValue = 0.65f;
    _sizeSlider.maximumValue = 1.35f;
    _sizeSlider.value = curScale;
    _sizeSlider.tintColor = [self perfTeal];
    [_sizeSlider addTarget:self action:@selector(sizeSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [scroll addSubview:_sizeSlider];
    sY += 44;

    UILabel *opTitle = [[UILabel alloc] initWithFrame:CGRectMake(4, sY, width - 80, 20)];
    opTitle.text = @"PiP Opacity";
    opTitle.textColor = [UIColor blackColor];
    opTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    [scroll addSubview:opTitle];

    _opacityValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(width - 70, sY, 66, 20)];
    _opacityValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)(curOpacity * 100)];
    _opacityValueLabel.textColor = [self perfTeal];
    _opacityValueLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    _opacityValueLabel.textAlignment = NSTextAlignmentRight;
    [scroll addSubview:_opacityValueLabel];
    sY += 26;

    _opacitySlider = [[UISlider alloc] initWithFrame:CGRectMake(4, sY, width - 8, 30)];
    _opacitySlider.minimumValue = 0.2f;
    _opacitySlider.maximumValue = 1.0f;
    _opacitySlider.value = curOpacity;
    _opacitySlider.tintColor = [self perfTeal];
    [_opacitySlider addTarget:self action:@selector(opacitySliderChanged:) forControlEvents:UIControlEventValueChanged];
    [scroll addSubview:_opacitySlider];
    sY += 44;

    UILabel *colTitle = [[UILabel alloc] initWithFrame:CGRectMake(4, sY, width - 8, 20)];
    colTitle.text = @"PiP Background Color";
    colTitle.textColor = [UIColor blackColor];
    colTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    [scroll addSubview:colTitle];
    sY += 26;

    NSArray *colorNames = @[@"Black", @"Navy", @"Cyan", @"Purple", @"Emerald", @"Crimson"];
    CGFloat btnW = (width - 16) / 3.0;
    CGFloat btnH = 34;
    for (int i = 0; i < 6; i++) {
        CGFloat colX = (i % 3) * (btnW + 8);
        CGFloat colY = sY + (i / 3) * (btnH + 8);
        UIButton *colBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        colBtn.frame = CGRectMake(colX, colY, btnW, btnH);
        colBtn.backgroundColor = getPerfColorForIndex(i, 0.95);
        colBtn.layer.cornerRadius = 10;
        colBtn.layer.borderWidth = (i == curColorIdx) ? 2.5 : 1.0;
        colBtn.layer.borderColor = (i == curColorIdx) ? [self perfTeal].CGColor : [[UIColor whiteColor] colorWithAlphaComponent:0.2].CGColor;
        [colBtn setTitle:colorNames[i] forState:UIControlStateNormal];
        colBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        colBtn.tag = 100 + i;
        [colBtn addTarget:self action:@selector(colorSelected:) forControlEvents:UIControlEventTouchUpInside];
        [scroll addSubview:colBtn];
    }
    sY += (btnH + 8) * 2 + 12;

    UILabel *metricsTitle = [[UILabel alloc] initWithFrame:CGRectMake(4, sY, width - 8, 20)];
    metricsTitle.text = @"Visible Metrics";
    metricsTitle.textColor = [UIColor blackColor];
    metricsTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    [scroll addSubview:metricsTitle];
    sY += 26;

    NSArray *switchesConfig = @[
        @{@"key": @"perf_show_cpu",  @"label": @"Show CPU Usage",     @"def": @YES},
        @{@"key": @"perf_show_ram",  @"label": @"Show RAM Usage",     @"def": @YES},
        @{@"key": @"perf_show_temp", @"label": @"Show Thermal State", @"def": @YES},
        @{@"key": @"perf_show_fps",  @"label": @"Show Render FPS",    @"def": @NO}
    ];
    for (NSDictionary *cfg in switchesConfig) {
        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, sY, width, 42)];
        row.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.04];
        row.layer.cornerRadius = 12;
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 11, row.frame.size.width - 70, 20)];
        lbl.text = cfg[@"label"];
        lbl.textColor = [UIColor blackColor];
        lbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        [row addSubview:lbl];
        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(row.frame.size.width - 62, 6, 50, 30)];
        BOOL val = [defs objectForKey:cfg[@"key"]] ? [defs boolForKey:cfg[@"key"]] : [cfg[@"def"] boolValue];
        sw.on = val;
        sw.onTintColor = [self perfTeal];
        sw.accessibilityIdentifier = cfg[@"key"];
        [sw addTarget:self action:@selector(metricSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        [row addSubview:sw];
        [scroll addSubview:row];
        sY += 48;
    }
    scroll.contentSize = CGSizeMake(width, sY + 20);
}

- (void)diagTabTapped {
    if (_isDiagTab) return;
    _isDiagTab = YES;
    _diagTabButton.backgroundColor = [self perfTeal];
    [_diagTabButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _settingsTabButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.04];
    [_settingsTabButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    _diagScrollView.hidden = NO;
    _settingsContainerView.hidden = YES;
}

- (void)settingsTabTapped {
    if (!_isDiagTab) return;
    _isDiagTab = NO;
    _settingsTabButton.backgroundColor = [self perfTeal];
    [_settingsTabButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _diagTabButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.04];
    [_diagTabButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    _diagScrollView.hidden = YES;
    _settingsContainerView.hidden = NO;
    [self updateLivePreview];
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
    @try {
        float val = sender.value;
        _sizeValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)(val * 100)];
        [[NSUserDefaults standardUserDefaults] setFloat:val forKey:@"perf_pip_scale"];
        [self updateLivePreview];
        if (sharedMonitorView) {
            dispatch_async(dispatch_get_main_queue(), ^{ [sharedMonitorView applySettings]; });
        }
    } @catch (NSException *e) {}
}

- (void)opacitySliderChanged:(UISlider *)sender {
    @try {
        float val = sender.value;
        _opacityValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)(val * 100)];
        [[NSUserDefaults standardUserDefaults] setFloat:val forKey:@"perf_pip_opacity"];
        [self updateLivePreview];
        if (sharedMonitorView) {
            dispatch_async(dispatch_get_main_queue(), ^{ [sharedMonitorView applySettings]; });
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
                    btn.layer.borderColor = isCurrent ? [self perfTeal].CGColor : [[UIColor whiteColor] colorWithAlphaComponent:0.2].CGColor;
                }
            }
        }
        [self updateLivePreview];
        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [gen impactOccurred];
        if (sharedMonitorView) {
            dispatch_async(dispatch_get_main_queue(), ^{ [sharedMonitorView applySettings]; });
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
                dispatch_async(dispatch_get_main_queue(), ^{ [sharedMonitorView applySettings]; });
            }
        }
    } @catch (NSException *e) {}
}

- (void)rowTapped:(UITapGestureRecognizer *)gesture {
    UIView *row = gesture.view;
    for (UIView *sub in row.subviews) {
        if ([sub isKindOfClass:[UILabel class]] && sub.tag == 999) {
            UILabel *valLabel = (UILabel *)sub;
            if (valLabel.text) {
                [UIPasteboard generalPasteboard].string = valLabel.text;
                UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
                [gen impactOccurred];
                [self showToast:@"Copied to clipboard!"];
            }
            break;
        }
    }
}

- (void)showToast:(NSString *)text {
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake((self.bounds.size.width - 200) / 2.0, self.bounds.size.height - 200, 200, 38)];
    toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    toast.textColor = [UIColor whiteColor];
    toast.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.text = text;
    toast.layer.cornerRadius = 19;
    toast.layer.masksToBounds = YES;
    toast.alpha = 0.0;
    [self addSubview:toast];
    [UIView animateWithDuration:0.2 animations:^{ toast.alpha = 1.0; } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 delay:1.2 options:0 animations:^{ toast.alpha = 0.0; } completion:^(BOOL finished) {
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
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[self.shareSummaryText] applicationActivities:nil];
    UIWindow *keyWindow = self.window;
    UIViewController *rootVC = keyWindow.rootViewController;
    if (rootVC) [rootVC presentViewController:activityVC animated:YES completion:nil];
}

- (void)runStressTestTapped { if (self.onRunTest) self.onRunTest(); }
- (void)closeTapped { if (self.onClose) self.onClose(); }

@end

// ===== MANAGER =====
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

// ===== GESTURES =====
@interface PerfMonitorGestureHandler : NSObject
+ (void)handleFourFingerTap:(UITapGestureRecognizer *)sender;
+ (void)handleFourFingerLongPress:(UILongPressGestureRecognizer *)sender;
+ (void)handleOrientationChange:(NSNotification *)notification;
+ (void)dismissTutorialAndExecute:(void(^)(void))action;
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

+ (void)handleFourFingerLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        [self dismissTutorialAndExecute:^{
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
        }];
    }
}

+ (void)handleOrientationChange:(NSNotification *)notification {
    if (fullScreenMenuWindow || tutorialWindow) return;
    if (sharedMonitorWindow && !sharedMonitorWindow.isHidden) {
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        sharedMonitorWindow.center = CGPointMake(screenSize.width / 2.0, 90.0);
    }
}

@end

// ===== ENTRY =====
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
        fourFingerLongPress.minimumPressDuration = 2.0;
        [targetWindow addGestureRecognizer:fourFingerLongPress];

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
