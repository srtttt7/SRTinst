#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// MARK: - مفاتيح حفظ الإعدادات
static NSString * const kGhostStoryKey    = @"srt_insta_ghost_story";
static NSString * const kGhostDMKey       = @"srt_insta_ghost_dm";
static NSString * const kDownloadStoryKey = @"srt_insta_download_story";
static NSString * const kVoiceToVideoKey  = @"srt_insta_voice_to_video";

static inline BOOL SRTBool(NSString *key, BOOL defaultVal) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if ([ud objectForKey:key] == nil) return defaultVal;
    return [ud boolForKey:key];
}

static inline void SRTSetBool(NSString *key, BOOL val) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setBool:val forKey:key];
    [ud synchronize];
}

// MARK: - صفحة الإعدادات الموحدة (SRT Insta Plus)
@interface SRTInstaSettingsVC : UITableViewController
@end

@implementation SRTInstaSettingsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"SRT Insta Plus";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"تم"
                style:UIBarButtonItemStyleDone
               target:self
               action:@selector(closeSettings)];
}

- (void)closeSettings {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2;
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"وضع الشبح (Ghost Mode)";
    if (section == 1) return @"الوسائط والستوريات";
    return @"المحادثات والرسائل";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UISwitch *sw = [[UISwitch alloc] init];
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];

    if (indexPath.section == 0 && indexPath.row == 0) {
        cell.textLabel.text = @"إخفاء مشاهدة الستوري";
        cell.detailTextLabel.text = @"مشاهدة الستوريات دون إشعار";
        sw.on = SRTBool(kGhostStoryKey, YES);
        sw.tag = 101;
    } else if (indexPath.section == 0 && indexPath.row == 1) {
        cell.textLabel.text = @"إخفاء قراءة الرسائل (Seen)";
        cell.detailTextLabel.text = @"قراءة الرسائل دون إشعار";
        sw.on = SRTBool(kGhostDMKey, YES);
        sw.tag = 102;
    } else if (indexPath.section == 1 && indexPath.row == 0) {
        cell.textLabel.text = @"زر تحميل الستوريات";
        cell.detailTextLabel.text = @"حفظ الصور والفيديو من الستوري";
        sw.on = SRTBool(kDownloadStoryKey, YES);
        sw.tag = 103;
    } else {
        cell.textLabel.text = @"إرسال الصوت كبصمة فيديو";
        cell.detailTextLabel.text = @"تحويل المقطع الصوتي إلى بصمة فيديو";
        sw.on = SRTBool(kVoiceToVideoKey, NO);
        sw.tag = 104;
    }

    cell.accessoryView = sw;
    return cell;
}

- (void)switchChanged:(UISwitch *)sender {
    switch (sender.tag) {
        case 101: SRTSetBool(kGhostStoryKey, sender.isOn); break;
        case 102: SRTSetBool(kGhostDMKey, sender.isOn); break;
        case 103: SRTSetBool(kDownloadStoryKey, sender.isOn); break;
        case 104: SRTSetBool(kVoiceToVideoKey, sender.isOn); break;
        default: break;
    }
}

@end

// MARK: - إدارة الزر الرايق الثابت بجانب القلب أعلى اليمين
@interface SRTHeaderButtonManager : NSObject
+ (void)openSettings;
+ (void)syncButtonInHeader;
@end

@implementation SRTHeaderButtonManager

+ (UIWindow *)mainWindow {
    @try {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] &&
                scene.activationState == UISceneActivationStateForegroundActive) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    if (w.isKeyWindow) return w;
                }
                if (ws.windows.count > 0) return ws.windows.firstObject;
            }
        }
    } @catch (__unused NSException *e) {}
    return nil;
}

+ (void)openSettings {
    @try {
        UIWindow *win = [self mainWindow];
        UIViewController *top = win.rootViewController;
        while (top.presentedViewController) {
            top = top.presentedViewController;
        }
        if (!top) return;
        SRTInstaSettingsVC *vc = [[SRTInstaSettingsVC alloc] initWithStyle:UITableViewStyleInsetGrouped];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.modalPresentationStyle = UIModalPresentationPageSheet;
        [top presentViewController:nav animated:YES completion:nil];
    } @catch (__unused NSException *e) {}
}

+ (void)syncButtonInHeader {
    @try {
        UIWindow *win = [self mainWindow];
        if (!win) return;

        CGFloat topInset = win.safeAreaInsets.top > 0 ? win.safeAreaInsets.top : 44.0;
        CGFloat btnSize = 32.0;
        // مكان رايق بجانب القلب في أعلى اليمين داخل شريط الهيدر
        CGFloat xPos = CGRectGetWidth(win.bounds) - 82.0;
        CGFloat yPos = topInset + 6.0;

        UIButton *btn = [win viewWithTag:556677];
        if (!btn) {
            btn = [UIButton buttonWithType:UIButtonTypeSystem];
            btn.tag = 556677;
            btn.backgroundColor = [UIColor clearColor];
            btn.tintColor = [UIColor whiteColor];
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightRegular];
            UIImage *img = [UIImage systemImageNamed:@"slider.horizontal.3" withConfiguration:cfg];
            if (img) {
                [btn setImage:img forState:UIControlStateNormal];
            } else {
                [btn setTitle:@"+" forState:UIControlStateNormal];
            }
            [btn addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
            [win addSubview:btn];
        }

        btn.frame = CGRectMake(xPos, yPos, btnSize, btnSize);
        [win bringSubviewToFront:btn];
    } @catch (__unused NSException *e) {}
}

@end

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SRTHeaderButtonManager syncButtonInHeader];
        [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(__unused NSTimer *t) {
            [SRTHeaderButtonManager syncButtonInHeader];
        }];
    });
}
