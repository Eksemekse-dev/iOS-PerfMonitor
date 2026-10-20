#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <sys/sysctl.h>

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

static PerfMonitorWindow *sharedMonitorWindow = nil;

@interface PerfMonitorManager : NSObject
+ (NSString *)getTestResultFilePath;
+ (void)runRamStressTest;
+ (void)checkPreviousCrashOrTestResult;
+ (NSString *)getDeviceModelName;
+ (BOOL)isJITActive;
@end

@implementation PerfMonitorManager

+ (NSString *)getTestResultFilePath {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown_app";
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_ram_test_state.plist", bundleId]];
}

+ (NSString *)getDeviceModelName {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *model = [NSString stringWithUTF8String:machine];
    free(machine);
    return model;
}

+ (BOOL)isJITActive {
    void *addr = mmap(NULL, getpagesize(), PROT_READ | PROT_WRITE | PROT_EXEC, MAP_ANON | MAP_PRIVATE, -1, 0);
    if (addr == MAP_FAILED) return NO;
    munmap(addr, getpagesize());
    return YES;
}

+ (void)runRamStressTest {
    NSString *filePath = [self getTestResultFilePath];
    
    [@{
        @"status": @"running",
        @"allocatedMB": @(0)
    } writeToFile:filePath atomically:YES];

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
                
                NSDictionary *state = @{
                    @"status": @"running",
                    @"allocatedMB": @(totalAllocatedMB)
                };
                [state writeToFile:filePath atomically:YES];
                
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
            UIWindow *keyWindow = nil;
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    for (UIWindow *win in scene.windows) {
                        if (win.isKeyWindow) {
                            keyWindow = win;
                            break;
                        }
                    }
                }
                if (keyWindow) break;
            }
            UIViewController *rootVC = keyWindow ? keyWindow.rootViewController : nil;
            while (rootVC.presentedViewController) {
                rootVC = rootVC.presentedViewController;
            }
            if (!rootVC) return;

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"RAM Test Result (Crash OOM)"
                                                                           message:[NSString stringWithFormat:@"App crashed due to Out Of Memory!\nMax allocated RAM before crash: %@ MB", allocatedMB]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [rootVC presentViewController:alert animated:YES completion:nil];
        });
    }
}

@end

@interface PerfMonitorGestureHandler : NSObject
@end

@implementation PerfMonitorGestureHandler

+ (void)handleFourFingerTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateRecognized) {
        if (sharedMonitorWindow) {
            // Stukanie 4 palcami przełącza widoczność małego PiP
            sharedMonitorWindow.hidden = !sharedMonitorWindow.hidden;
        }
    }
}

+ (void)handleFourFingerLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        UIWindow *keyWindow = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *win in scene.windows) {
                    if (win.isKeyWindow) {
                        keyWindow = win;
                        break;
                    }
                }
            }
            if (keyWindow) break;
        }
        
        UIViewController *rootVC = keyWindow ? keyWindow.rootViewController : nil;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        if (!rootVC) return;

        NSString *model = [PerfMonitorManager getDeviceModelName];
        NSString *iosVersion = [[UIDevice currentDevice] systemVersion];
        BOOL jitActive = [PerfMonitorManager isJITActive];
        
        struct task_basic_info info;
        mach_msg_type_number_t size = TASK_BASIC_INFO_COUNT;
        task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
        double appRamMB = info.resident_size / (1024.0 * 1024.0);
        unsigned long long totalDeviceRam = [[NSProcessInfo processInfo] physicalMemory] / (1024 * 1024);
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"Unknown";

        NSString *message = [NSString stringWithFormat:
                             @"Model: %@\niOS: %@\nBundle ID: %@\nJIT Active: %@\nMemory+: Enabled (Mach)\nApp RAM: %.1f MB\nTotal Device RAM: %llu MB",
                             model, iosVersion, bundleId, jitActive ? @"YES" : @"NO", appRamMB, totalDeviceRam];

        UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"iOS PerfMonitor Menu"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];

        [menu addAction:[UIAlertAction actionWithTitle:@"Run RAM Stress Test (OOM)"
                                                 style:UIAlertActionStyleDestructive
                                               handler:^(UIAlertAction * _Nonnull action) {
            UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Warning"
                                                                             message:@"This test will allocate RAM until the app crashes to measure limits. Continue?"
                                                                      preferredStyle:UIAlertControllerStyleAlert];
            [confirm addAction:[UIAlertAction actionWithTitle:@"Start" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull act) {
                [PerfMonitorManager runRamStressTest];
            }]];
            [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [rootVC presentViewController:confirm animated:YES completion:nil];
        }]];

        [menu addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];

        [rootVC presentViewController:menu animated:YES completion:nil];
    }
}

+ (void)handleOrientationChange:(NSNotification *)notification {
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
                for (UIWindow *win in scene.windows) {
                    if (win.isKeyWindow) {
                        targetWindow = win;
                        break;
                    }
                }
            }
            if (targetWindow) break;
        }
        
        if (!targetWindow) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    targetWindow = scene.windows.firstObject;
                    if (targetWindow) break;
                }
            }
        }

        if (targetWindow && !sharedMonitorWindow) {
            CGSize screenSize = [UIScreen mainScreen].bounds.size;
            sharedMonitorWindow = [[PerfMonitorWindow alloc] initWithFrame:CGRectMake(0, 0, 140, 70)];
            sharedMonitorWindow.center = CGPointMake(screenSize.width / 2.0, 90.0);
            sharedMonitorWindow.windowLevel = UIWindowLevelAlert + 1000;
            sharedMonitorWindow.hidden = YES; // Ukryte domyślnie
            
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
            
            // Pojedyncze stuknięcie 4 palcami -> włącza/wyłącza widok PiP
            UITapGestureRecognizer *fourFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:[PerfMonitorGestureHandler class] action:@selector(handleFourFingerTap:)];
            fourFingerTap.numberOfTouchesRequired = 4;
            [targetWindow addGestureRecognizer:fourFingerTap];

            // Przytrzymanie 4 palcami przez 2 sekundy -> otwiera ukryte menu diagnostyczne
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
