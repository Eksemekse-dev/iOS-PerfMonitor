#import <UIKit/UIKit.h>
#import <mach/mach.h>

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

        // Płynne, wielokrotne przesuwanie całego okna
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
@end

__attribute__((constructor)) static void tweakEntry() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
        if (!keyWindow) keyWindow = [UIApplication sharedApplication].windows.firstObject;

        if (keyWindow && !sharedMonitorWindow) {
            sharedMonitorWindow = [[PerfMonitorWindow alloc] initWithFrame:CGRectMake(30, 90, 140, 70)];
            sharedMonitorWindow.windowLevel = UIWindowLevelAlert + 1000;
            sharedMonitorWindow.hidden = YES; // Ukryte domyślnie, odpala się 4 palcami
            
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
            [keyWindow addGestureRecognizer:fourFingerTap];
        }
    });
}
