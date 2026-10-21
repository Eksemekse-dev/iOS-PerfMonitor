#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#include <unistd.h>

// --- TUTORIAL OVERVIEW WITH AUTO-DISMISS ON 4 FINGERS & SKIP ---
@interface PerfTutorialView : UIView
@property (nonatomic, copy) void (^onCompleted)(void);
- (void)clearDots;
@end

@implementation PerfTutorialView {
    UILabel *_headerInstructionLabel;
    UILabel *_stepSubtitleLabel;
    UIButton *_skipButton;
    BOOL _isTriggered;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
        self.multipleTouchEnabled = YES;
        _isTriggered = NO;

        UIEdgeInsets safeInsets = UIEdgeInsetsZero;
        if (@available(iOS 11.0, *)) {
            UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
            safeInsets = window.safeAreaInsets;
        }

        CGFloat topY = safeInsets.top > 0 ? safeInsets.top + 5 : 35;

        // Banner z instrukcją pod Dynamiczną Wyspą / Notchem
        _headerInstructionLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, topY, frame.size.width - 40, 38)];
        _headerInstructionLabel.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12];
        _headerInstructionLabel.textColor = [UIColor whiteColor];
        _headerInstructionLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        _headerInstructionLabel.textAlignment = NSTextAlignmentCenter;
        _headerInstructionLabel.layer.cornerRadius = 19;
        _headerInstructionLabel.layer.masksToBounds = YES;
        _headerInstructionLabel.layer.borderWidth = 1.0;
        _headerInstructionLabel.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.2].CGColor;
        _headerInstructionLabel.text = @"Place 4 fingers: Tap = PiP | Hold = Menu";
        [self addSubview:_headerInstructionLabel];

        _stepSubtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, topY + 44, frame.size.width - 40, 20)];
        _stepSubtitleLabel.textColor = [UIColor systemCyanColor];
        _stepSubtitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        _stepSubtitleLabel.textAlignment = NSTextAlignmentCenter;
        _stepSubtitleLabel.text = @"Or press Skip below";
        [self addSubview:_stepSubtitleLabel];

        // Przycisk Skip
        _skipButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _skipButton.frame = CGRectMake((frame.size.width - 100) / 2.0, topY + 72, 100, 32);
        _skipButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
        [_skipButton setTitle:@"Skip" forState:UIControlStateNormal];
        [_skipButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _skipButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        _skipButton.layer.cornerRadius = 16;
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

// --- SAFE TOUCH TRACKING & AUTO-TRIGGER ---
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
    
    for (UITouch *touch in allTouches) {
        if (touch.phase == UITouchPhaseBegan || touch.phase == UITouchPhaseMoved || touch.phase == UITouchPhaseStationary) {
            CGPoint loc = [touch locationInView:self];
            UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 46, 46)];
            dot.center = loc;
            dot.tag = 7777;
            dot.backgroundColor = dotColor;
            dot.layer.cornerRadius = 23;
            dot.layer.borderWidth = 2.5;
            dot.layer.borderColor = [UIColor whiteColor].CGColor;
            dot.userInteractionEnabled = NO;
            [self addSubview:dot];
        }
    }

    // Jeśli wykryto 4 palce, zmieniamy baner na zielony i po 1 sekundzie zamykamy poradnik
    if (isFourFingers && !_isTriggered) {
        _isTriggered = YES;
        
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];

        [UIView animateWithDuration:0.2 animations:^{
            self->_headerInstructionLabel.backgroundColor = [[UIColor systemGreenColor] colorWithAlphaComponent:0.3];
            self->_headerInstructionLabel.layer.borderColor = [UIColor systemGreenColor].CGColor;
            self->_headerInstructionLabel.textColor = [UIColor systemGreenColor];
            self->_headerInstructionLabel.text = @"Gesture detected! Launching...";
        }];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.onCompleted) {
                self.onCompleted();
            }
        });
    }
}

@end

// --- FLOATING PERFORMANCE MONITOR (PiP) ---
@interface PerfMonitorView : UIView
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation PerfMonitorView {
    CGPoint _initialCenter;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
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

        _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateStats) userInfo:nil repeats:YES];
    }
    return self;
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

    self.infoLabel.text = [NSString stringWithFormat:@"CPU: %.1f%%\nRAM: %.1f MB\nTemp: %@", cpuUsage, ramMB, thermalStr];
}

@end

@interface PerfMonitorWindow : UIWindow
@end

@implementation PerfMonitorWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = [super hitTest:point withEvent:event];
    return (view == self) ? nil : view;
}
@end

// --- MODERN PROFESSIONAL FULL-SCREEN MENU ---
@interface PerfFullScreenMenuView : UIView
@property (nonatomic, copy) void (^onClose)(void);
@property (nonatomic, copy) void (^onRunTest)(void);
@property (nonatomic, copy) NSString *shareSummaryText;
@end

@implementation PerfFullScreenMenuView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = self.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:blurView];

        UIView *cardView = [[UIView alloc] initWithFrame:CGRectMake(30, 40, frame.size.width - 60, frame.size.height - 80)];
        cardView.center = CGPointMake(frame.size.width / 2.0, frame.size.height / 2.0);
        cardView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        cardView.backgroundColor = [[UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0] colorWithAlphaComponent:0.9];
        cardView.layer.cornerRadius = 24;
        cardView.layer.borderWidth = 1.0;
        cardView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15].CGColor;
        [self addSubview:cardView];

        UIImageView *titleIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"waveform.path.ecg"]];
        titleIcon.frame = CGRectMake(20, 24, 24, 24);
        titleIcon.tintColor = [UIColor systemBlueColor];
        [cardView addSubview:titleIcon];

        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(52, 20, cardView.frame.size.width - 140, 30)];
        titleLabel.text = @"Performance Dashboard";
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
        [cardView addSubview:titleLabel];

        UIButton *shareButton = [UIButton buttonWithType:UIButtonTypeSystem];
        shareButton.frame = CGRectMake(cardView.frame.size.width - 80, 20, 30, 30);
        [shareButton setImage:[UIImage systemImageNamed:@"square.and.arrow.up"] forState:UIControlStateNormal];
        shareButton.tintColor = [UIColor systemBlueColor];
        [shareButton addTarget:self action:@selector(shareTapped) forControlEvents:UIControlEventTouchUpInside];
        [cardView addSubview:shareButton];

        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        closeButton.frame = CGRectMake(cardView.frame.size.width - 42, 20, 30, 30);
        [closeButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
        closeButton.tintColor = [UIColor secondaryLabelColor];
        [closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
        [cardView addSubview:closeButton];

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

        UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(20, 65, cardView.frame.size.width - 40, cardView.frame.size.height - 185)];
        scrollView.showsVerticalScrollIndicator = NO;
        [cardView addSubview:scrollView];

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
            rowButton.frame = CGRectMake(0, yOffset, scrollView.frame.size.width, 48);
            rowButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
            rowButton.layer.cornerRadius = 12;

            UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:item[@"icon"]]];
            iconView.frame = CGRectMake(14, 14, 20, 20);
            iconView.tintColor = [UIColor systemCyanColor];
            iconView.contentMode = UIViewContentModeScaleAspectFit;
            iconView.userInteractionEnabled = NO;
            [rowButton addSubview:iconView];

            UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(46, 4, rowButton.frame.size.width - 160, 40)];
            nameLabel.text = item[@"title"];
            nameLabel.textColor = [UIColor lightGrayColor];
            nameLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            nameLabel.userInteractionEnabled = NO;
            [rowButton addSubview:nameLabel];

            UILabel *valLabel = [[UILabel alloc] initWithFrame:CGRectMake(rowButton.frame.size.width - 110, 4, 100, 40)];
            valLabel.text = item[@"value"];
            valLabel.textColor = [UIColor whiteColor];
            valLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
            valLabel.textAlignment = NSTextAlignmentRight;
            valLabel.userInteractionEnabled = NO;
            valLabel.tag = 999;
            [rowButton addSubview:valLabel];

            [rowButton addTarget:self action:@selector(copyRowValue:) forControlEvents:UIControlEventTouchUpInside];
            [scrollView addSubview:rowButton];
            yOffset += 56;
        }
        scrollView.contentSize = CGSizeMake(scrollView.frame.size.width, yOffset);

        // Przycisk Stress Test
        UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
        testButton.frame = CGRectMake(20, cardView.frame.size.height - 110, cardView.frame.size.width - 40, 42);
        testButton.backgroundColor = [UIColor systemRedColor];
        [testButton setTitle:@"Run RAM Stress Test (OOM)" forState:UIControlStateNormal];
        [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        testButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        testButton.layer.cornerRadius = 12;
        [testButton addTarget:self action:@selector(runStressTestTapped) forControlEvents:UIControlEventTouchUpInside];
        [cardView addSubview:testButton];

        // --- FOOTER: CREATED BY EKSEMEKSE-DEV WITH AI + GITHUB LOGO ---
        UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(20, cardView.frame.size.height - 58, cardView.frame.size.width - 40, 46)];
        [cardView addSubview:footerView];

        UILabel *creditLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, footerView.frame.size.width - 40, 46)];
        creditLabel.text = @"Created by Eksemekse-dev with AI";
        creditLabel.textColor = [UIColor darkGrayColor];
        creditLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        creditLabel.numberOfLines = 2;
        [footerView addSubview:creditLabel];

        UIButton *githubButton = [UIButton buttonWithType:UIButtonTypeSystem];
        githubButton.frame = CGRectMake(footerView.frame.size.width - 36, 5, 36, 36);
        // Użycie ikony powiązanej z repozytorium/GitHub (alternatywnie standardowa symboliczna grafika sieciowa)
        [githubButton setImage:[UIImage systemImageNamed:@"network"] forState:UIControlStateNormal];
        githubButton.tintColor = [UIColor systemBlueColor];
        [githubButton addTarget:self action:@selector(openGithubTapped) forControlEvents:UIControlEventTouchUpInside];
        [footerView addSubview:githubButton];
    }
    return self;
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

static PerfMonitorWindow *sharedMonitorWindow = nil;
static UIWindow *fullScreenMenuWindow = nil;
static UIWindow *tutorialWindow = nil;

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
                sharedMonitorWindow = [[PerfMonitorWindow alloc] initWithFrame:CGRectMake(0, 0, 140, 70)];
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
                
                PerfMonitorView *monitorView = [[PerfMonitorView alloc] initWithFrame:sharedMonitorWindow.bounds];
                [sharedMonitorWindow addSubview:monitorView];
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
