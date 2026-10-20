#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#include <unistd.h>
#include <dlfcn.h>

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

// --- MODERN FULL-SCREEN DIAGNOSTIC MENU ---
@interface PerfFullScreenMenuView : UIView
@property (nonatomic, copy) void (^onClose)(void);
@property (nonatomic, copy) void (^onRunTest)(void);
@end

@implementation PerfFullScreenMenuView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = self.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:blurView];

        UIView *cardView = [[UIView alloc] initWithFrame:CGRectMake(30, 60, frame.size.width - 60, frame.size.height - 120)];
        cardView.center = CGPointMake(frame.size.width / 2.0, frame.size.height / 2.0);
        cardView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        cardView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
        cardView.layer.cornerRadius = 24;
        cardView.layer.borderWidth = 1.0;
        cardView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.2].CGColor;
        [self addSubview:cardView];

        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, cardView.frame.size.width - 40, 30)];
        titleLabel.text = @"⚡ PerfMonitor Dashboard";
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        [cardView addSubview:titleLabel];

        // Safe debugger check using sysctl info flags alternative
        int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
        struct kinfo_proc info;
        size_t size = sizeof(info);
        BOOL debuggerAttached = NO;
        if (sysctl(mib, 4, &info, &size, NULL, 0) == 0) {
            // Check process flags safely across iOS SDK variants
            debuggerAttached = ((info.kp_proc.p_flag & P_TRACED) != 0);
        }

        struct task_basic_info taskInfo;
        mach_msg_type_number_t tSize = TASK_BASIC_INFO_COUNT;
        task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&taskInfo, &tSize);
        double appRamMB = taskInfo.resident_size / (1024.0 * 1024.0);
        unsigned long long totalDeviceRam = [[NSProcessInfo processInfo] physicalMemory] / (1024 * 1024);
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"Unknown";
        NSString *iosVersion = [[UIDevice currentDevice] systemVersion];

        UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(20, 70, cardView.frame.size.width - 40, cardView.frame.size.height - 160)];
        textView.backgroundColor = [UIColor clearColor];
        textView.textColor = [UIColor whiteColor];
        textView.font = [UIFont fontWithName:@"Courier" size:13] ?: [UIFont systemFontOfSize:13];
        textView.editable = NO;
        textView.text = [NSString stringWithFormat:
                         @"📱 iOS Version: %@\n"
                         @"📦 Bundle ID: %@\n"
                         @"🔍 Debugger Attached: %@\n"
                         @"🧠 Memory+ Kernel: Active\n"
                         @"📊 App RAM Usage: %.1f MB\n"
                         @"💾 Total Device RAM: %llu MB",
                         iosVersion, bundleId, debuggerAttached ? @"YES (Connected)" : @"NO (Clean)", appRamMB, totalDeviceRam];
        [cardView addSubview:textView];

        UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
        testButton.frame = CGRectMake(20, cardView.frame.size.height - 75, cardView.frame.size.width - 40, 44);
        testButton.backgroundColor = [UIColor systemRedColor];
        [testButton setTitle:@"Run RAM Stress Test (OOM)" forState:UIControlStateNormal];
        [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        testButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
        testButton.layer.cornerRadius = 12;
        [testButton addTarget:self action:@selector(runStressTestTapped) forControlEvents:UIControlEventTouchUpInside];
        [cardView addSubview:testButton];

        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        closeButton.frame = CGRectMake(cardView.frame.size.width - 45, 15, 30, 30);
        [closeButton setTitle:@"✕" forState:UIControlStateNormal];
        [closeButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        closeButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
        [closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
        [cardView addSubview:closeButton];
    }
    return self;
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

@interface PerfMonitorManager : NSObject
+ (NSString *)getTestResultFilePath;
+ (void)runRamStressTest;
+ (void)checkPreviousCrashOrTestResult;
@end

@implementation PerfMonitorManager

+ (NSString *)getTestResultFilePath {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown_app";
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths[0] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_ram_test_state.plist", bundleId]];
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
@end

@implementation PerfMonitorGestureHandler

+ (void)handleFourFingerTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateRecognized) {
        if (sharedMonitorWindow) {
            sharedMonitorWindow.hidden = !sharedMonitorWindow.hidden;
        }
    }
}

+ (void)handleFourFingerLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
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
        
        // Unsafe unretained pointer replacement for manual reference counting (MRC) compatibility
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
    }
}

+ (void)handleOrientationChange:(NSNotification *)notification {
    if (sharedMonitorWindow && !sharedMonitorWindow.isHidden) {
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        sharedMonitorWindow.center = CGPointMake(screenSize.width / 2.0, 90.0);
    }
    if (fullScreenMenuWindow) {
        fullScreenMenuWindow.frame = [UIScreen mainScreen].bounds;
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

        if (targetWindow && !sharedMonitorWindow) {
            CGSize screenSize = [UIScreen mainScreen].bounds.size;
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
            
            [PerfMonitorManager checkPreviousCrashOrTestResult];
        }
    });
}
