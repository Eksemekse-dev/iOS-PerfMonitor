#import <UIKit/UIKit.h>
#import <mach/mach.h>

@interface PerfMonitorWindow : UIWindow
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation PerfMonitorWindow

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.windowLevel = UIWindowLevelAlert + 1000;
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
        self.layer.cornerRadius = 12;
        self.layer.masksToBounds = YES;
        self.userInteractionEnabled = YES;

        _infoLabel = [[UILabel alloc] initWithFrame:self.bounds];
        _infoLabel.textColor = [UIColor whiteColor];
        _infoLabel.font = [UIFont boldSystemFontOfSize:11];
        _infoLabel.numberOfLines = 0;
        _infoLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_infoLabel];

        _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateStats) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)updateStats {
    struct task_basic_info info;
    mach_msg_type_number_t size = TASK_BASIC_INFO_COUNT;
    task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    double ramMB = info.resident_size / (1024.0 * 1024.0);

    NSProcessInfoThermalState thermal = [[NSProcessInfo processInfo] thermalState];
    NSString *thermalStr = @"Norma";
    if (thermal == NSProcessInfoThermalStateFair) thermalStr = @"Ciepło";
    else if (thermal == NSProcessInfoThermalStateSerious) thermalStr = @"Gorąco";
    else if (thermal == NSProcessInfoThermalStateCritical) thermalStr = @"Przegrzanie!";

    self.infoLabel.text = [NSString stringWithFormat:@"RAM: %.1f MB\nTemp: %@", ramMB, thermalStr];
}

@end

// Automatyczne uruchomienie okienka po załadowaniu biblioteki do aplikacji
__attribute__((constructor)) static void initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        PerfMonitorWindow *monitorWindow = [[PerfMonitorWindow alloc] initWithFrame:CGRectMake(50, 100, 130, 55)];
        monitorWindow.hidden = NO;
        [keyWindow addSubview:monitorWindow];
    });
}
