#import <UIKit/UIKit.h>
#import <mach/mach.h>

@interface PerfMonitorView : UIView
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation PerfMonitorView {
    CGPoint _startTouchPosition;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
        self.layer.cornerRadius = 14;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.2].CGColor;
        self.userInteractionEnabled = YES;

        // Dodanie obsługi przeciągania (drag & drop gestem)
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:panGesture];

        _infoLabel = [[UILabel alloc] initWithFrame:self.bounds];
        _infoLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _infoLabel.textColor = [UIColor whiteColor];
        _infoLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        _infoLabel.numberOfLines = 0;
        _infoLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_infoLabel];

        _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateStats) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];
    if (gesture.state == UIGestureRecognizerStateBegan) {
        _startTouchPosition = self.center;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        self.center = CGPointMake(_startTouchPosition.x + translation.x, _startTouchPosition.y + translation.y);
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        // Opcjonalne: dosunięcie do krawędzi, żeby nie zgubić okienka poza ekranem
        CGRect screenRect = [UIScreen mainScreen].bounds;
        CGPoint center = self.center;
        if (center.x < 0) center.x = 70;
        if (center.x > screenRect.size.width) center.x = screenRect.size.width - 70;
        if (center.y < 40) center.y = 50;
        if (center.y > screenRect.size.height) center.y = screenRect.size.height - 50;
        
        [UIView animateWithDuration:0.3 animations:^{
            self.center = center;
        }];
    }
}

- (void)updateStats {
    // 1. Obliczanie RAM-u
    struct task_basic_info info;
    mach_msg_type_number_t size = TASK_BASIC_INFO_COUNT;
    task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    double ramMB = info.resident_size / (1024.0 * 1024.0);

    // 2. Obliczanie CPU (Thread info)
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

    // 3. Stan termiczny (Temperatura)
    NSProcessInfoThermalState thermal = [[NSProcessInfo processInfo] thermalState];
    NSString *thermalStr = @"Normal";
    if (thermal == NSProcessInfoThermalStateFair) thermalStr = @"Warm";
    else if (thermal == NSProcessInfoThermalStateSerious) thermalStr = @"Hot";
    else if (thermal == NSProcessInfoThermalStateCritical) thermalStr = @"Critical!";

    // Aktualizacja etykiety w języku angielskim
    self.infoLabel.text = [NSString stringWithFormat:@"CPU: %.1f%%\nRAM: %.1f MB\nTemp: %@", cpuUsage, ramMB, thermalStr];
}

@end

// Klasa pomocnicza dla okna, pozwalająca dotykać aplikacji pod spodem, ale przesuwać samo okienko
@interface PerfMonitorWindow : UIWindow
@end

@implementation PerfMonitorWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = [super hitTest:point withEvent:event];
    return (view == self) ? nil : view; // Przepuszcza kliknięcia tam, gdzie nie ma kontrolek
}
@end

__attribute__((constructor)) static void tweakEntry() {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            if (!keyWindow) return;

            // Tworzenie pływającego okna w stylu natywnego PiP / floating overlay
            PerfMonitorWindow *monitorWindow = [[PerfMonitorWindow alloc] initWithFrame:CGRectMake(20, 60, 130, 65)];
            monitorWindow.windowLevel = UIWindowLevelAlert + 1000;
            monitorWindow.hidden = NO;
            
            PerfMonitorView *monitorView = [[PerfMonitorView alloc] initWithFrame:monitorWindow.bounds];
            [monitorWindow addSubview:monitorView];
            
            // Przypisanie okna do głównego widoku, żeby żyło razem z aplikacją
            [keyWindow addSubview:monitorWindow];
        });
    });
}
