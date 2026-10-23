#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#include <unistd.h>

// Forward declarations
@interface PerfMonitorView : UIView
- (void)applySettings;
@end

@interface PerfFullScreenMenuView : UIView
@property (nonatomic, copy) void (^onClose)(void);
@property (nonatomic, copy) NSString *shareSummaryText;
@end

static UIWindow *sharedMonitorWindow = nil;
static PerfMonitorView *sharedMonitorView = nil;
static UIWindow *fullScreenMenuWindow = nil;

// Color helper
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

// --- FLOATING MONITOR VIEW (PiP) ---
@interface PerfMonitorView ()
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation PerfMonitorView {
    CGPoint _initialCenter;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.layer.cornerRadius = 14;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
        self.userInteractionEnabled = YES;

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
        
        // Podwójne tapnięcie otwiera pełne menu ustawień
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        tap.numberOfTapsRequired = 2;
        [self addGestureRecognizer:tap];

        _infoLabel = [[UILabel alloc] initWithFrame:self.bounds];
        _infoLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _infoLabel.textColor = [UIColor whiteColor];
        _infoLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        _infoLabel.numberOfLines = 0;
        _infoLabel.textAlignment = NSTextAlignmentCenter;
        _infoLabel.text = @"PiP Active\nInicjalizacja...";
        [self addSubview:_infoLabel];

        [self applySettings];
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateStats) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)applySettings {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    float opacity = [defs floatForKey:@"perf_pip_opacity"];
    if (opacity <= 0.05f) opacity = 0.85f;
    NSInteger colorIdx = [defs integerForKey:@"perf_pip_color_idx"];
    self.backgroundColor = getPerfColorForIndex(colorIdx, opacity);
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

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    extern void showPerfFullScreenMenu(void);
    showPerfFullScreenMenu();
}

- (void)updateStats {
    struct task_basic_info info;
    mach_msg_type_number_t size = TASK_BASIC_INFO_COUNT;
    task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    double ramMB = info.resident_size / (1024.0 * 1024.0);
    self.infoLabel.text = [NSString stringWithFormat:@"RAM: %.1f MB\nPiP Działa", ramMB];
}
@end

// --- CUSTOM WINDOW FOR PiP (przepuszcza dotyk poza widżetem) ---
@interface PerfMonitorWindow : UIWindow
@end

@implementation PerfMonitorWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = [super hitTest:point withEvent:event];
    return (view == self) ? nil : view;
}
@end


// --- FULL SCREEN SETTINGS MENU (iOS Style + Light/Dark Mode) ---
@implementation PerfFullScreenMenuView {
    UIVisualEffectView *_blurView;
    UIView *_cardView;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        BOOL light = [[NSUserDefaults standardUserDefaults] boolForKey:@"perf_is_light_theme"];
        
        // Tło z rozmyciem (Blur) dostosowane do trybu
        _blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:light ? UIBlurEffectStyleLight : UIBlurEffectStyleDark]];
        _blurView.frame = self.bounds;
        _blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_blurView];

        // Główna karta menu w stylu iOS
        _cardView = [[UIView alloc] initWithFrame:CGRectMake(20, 40, frame.size.width - 40, frame.size.height - 80)];
        _cardView.center = CGPointMake(frame.size.width / 2.0, frame.size.height / 2.0);
        _cardView.backgroundColor = light ? [UIColor colorWithRed:0.95 green:0.95 blue:0.97 alpha:0.95] : [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:0.95];
        _cardView.layer.cornerRadius = 20;
        _cardView.layer.borderWidth = 0.5;
        _cardView.layer.borderColor = light ? [[UIColor lightGrayColor] CGColor] : [[UIColor darkGrayColor] CGColor];
        [self addSubview:_cardView];

        // Tytuł
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, _cardView.frame.size.width - 60, 30)];
        titleLabel.text = @"Ustawienia PerfMonitor";
        titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
        titleLabel.textColor = light ? [UIColor blackColor] : [UIColor whiteColor];
        [_cardView addSubview:titleLabel];

        // Przycisk zamknięcia (X)
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        closeButton.frame = CGRectMake(_cardView.frame.size.width - 50, 20, 30, 30);
        [closeButton setTitle:@"✕" forState:UIControlStateNormal];
        closeButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
        [closeButton tintColor];
        [closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
        [_cardView addSubview:closeButton];
        
        // Etykieta przełącznika motywu
        UILabel *themeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 75, 150, 30)];
        themeLabel.text = @"Tryb wyглеdu";
        themeLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
        themeLabel.textColor = light ? [UIColor darkGrayColor] : [UIColor lightGrayColor];
        [_cardView addSubview:themeLabel];

        // Przełącznik trybu Jasny / Ciemny
        UISegmentedControl *themeSwitch = [[UISegmentedControl alloc] initWithItems:@[@"Ciemny", @"Jasny"]];
        themeSwitch.frame = CGRectMake(_cardView.frame.size.width - 170, 75, 150, 32];
        themeSwitch.selectedSegmentIndex = light ? 1 : 0;
        [themeSwitch addTarget:self action:@selector(themeChanged:) forControlEvents:UIControlEventValueChanged];
        [_cardView addSubview:themeSwitch];
    }
    return self;
}

- (void)themeChanged:(UISegmentedControl *)sender {
    BOOL isLight = (sender.selectedSegmentIndex == 1);
    [[NSUserDefaults standardUserDefaults] setBool:isLight forKey:@"perf_is_light_theme"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Natychmiastowe odświeżenie okna menu
    if (fullScreenMenuWindow) {
        fullScreenMenuWindow.rootViewController.view = [[PerfFullScreenMenuView alloc] initWithFrame:fullScreenMenuWindow.bounds];
    }
}

- (void)closeTapped {
    if (fullScreenMenuWindow) {
        [UIView animateWithDuration:0.2 animations:^{
            self.alpha = 0;
        } completion:^(BOOL finished) {
            [fullScreenMenuWindow setHidden:YES];
            fullScreenMenuWindow = nil;
        }];
    }
}
@end


// --- FUNKCJA WYWOŁUJĄCA PEŁNE MENU ---
void showPerfFullScreenMenu(void) {
    if (fullScreenMenuWindow) return;
    
    UIWindowScene *scene = nil;
    for (UIWindowScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) {
            scene = s;
            break;
        }
    }
    
    if (scene) {
        fullScreenMenuWindow = [[UIWindow alloc] initWithWindowScene:scene];
    } else {
        fullScreenMenuWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    
    fullScreenMenuWindow.windowLevel = UIWindowLevelAlert + 1;
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view = [[PerfFullScreenMenuView alloc] initWithFrame:fullScreenMenuWindow.bounds];
    fullScreenMenuWindow.rootViewController = vc;
    [fullScreenMenuWindow makeKeyAndVisible];
}

// --- AUTOMATYCZNY KONSTRUKTOR INICJALIZUJĄCY BIBLIOTEKĘ ---
__attribute__((constructor)) static void initPerfMonitor() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindowScene *targetScene = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                targetScene = (UIWindowScene *)scene;
                break;
            }
        }
        
        if (targetScene) {
            sharedMonitorWindow = [[PerfMonitorWindow alloc] initWithWindowScene:targetScene];
        } else {
            sharedMonitorWindow = [[PerfMonitorWindow alloc] initWithFrame:CGRectMake(20, 100, 140, 60)];
        }
        
        sharedMonitorWindow.windowLevel = UIWindowLevelStatusBar + 100;
        sharedMonitorWindow.frame = CGRectMake(30, 100, 142, 56);
        
        UIViewController *rootVc = [[UIViewController alloc] init];
        sharedMonitorView = [[PerfMonitorView alloc] initWithFrame:rootVc.view.bounds];
        sharedMonitorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [rootVc.view addSubview:sharedMonitorView];
        
        sharedMonitorWindow.rootViewController = rootVc;
        sharedMonitorWindow.hidden = NO;
        [sharedMonitorWindow makeKeyAndVisible];
    });
}
