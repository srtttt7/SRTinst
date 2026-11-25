#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

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

@interface SRTSafeBridge : NSObject
+ (void)openSettingsSafe;
+ (void)scanInView:(UIView *)view depth:(int)depth;
@end

@implementation SRTSafeBridge

+ (UIViewController *)topVC {
    @try {
        UIWindow *win = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] &&
                scene.activationState == UISceneActivationStateForegroundActive) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    if (w.isKeyWindow) { win = w; break; }
                }
                if (!win) win = ws.windows.firstObject;
                if (win) break;
            }
        }
        UIViewController *vc = win.rootViewController;
        while (vc.presentedViewController) {
            vc = vc.presentedViewController;
        }
        return vc;
    } @catch (__unused NSException *e) {
        return nil;
    }
}

+ (void)openSettingsSafe {
    @try {
        UIViewController *top = [self topVC];
        if (!top) return;
        SRTInstaSettingsVC *vc = [[SRTInstaSettingsVC alloc] initWithStyle:UITableViewStyleInsetGrouped];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.modalPresentationStyle = UIModalPresentationPageSheet;
        [top presentViewController:nav animated:YES completion:nil];
    } @catch (__unused NSException *e) {
    }
}

+ (void)scanInView:(UIView *)view depth:(int)depth {
    if (!view || depth > 8) return;
    @try {
        NSArray<UIView *> *subs = [view.subviews copy];
        for (UIView *sub in subs) {
            if (![sub isKindOfClass:[UIView class]] || sub.hidden) continue;

            NSString *lbl = @"";
            NSString *aid = @"";
            @try {
                if (sub.accessibilityLabel) lbl = [sub.accessibilityLabel lowercaseString];
                if (sub.accessibilityIdentifier) aid = [sub.accessibilityIdentifier lowercaseString];
            } @catch (__unused NSException *e) {}

            BOOL isHeart = [lbl containsString:@"activity"] ||
                           [lbl containsString:@"notification"] ||
                           [lbl containsString:@"الإشعارات"] ||
                           [lbl containsString:@"النشاط"] ||
                           [aid containsString:@"activity"] ||
                           [aid containsString:@"news"];

            if (isHeart && sub.superview && [sub.superview viewWithTag:775533] == nil) {
                CGRect f = sub.frame;
                if (f.size.width >= 18 && f.size.width <= 90) {
                    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
                    btn.tag = 775533;
                    UIImage *img = [UIImage systemImageNamed:@"slider.horizontal.3"];
                    if (img) {
                        [btn setImage:img forState:UIControlStateNormal];
                    } else {
                        [btn setTitle:@"SRT" forState:UIControlStateNormal];
                    }
                    btn.tintColor = sub.tintColor ?: [UIColor labelColor];
                    CGFloat sz = MAX(28.0, f.size.height);
                    btn.frame = CGRectMake(MAX(4.0, f.origin.x - sz - 4.0), f.origin.y, sz, sz);
                    [btn addTarget:self action:@selector(openSettingsSafe) forControlEvents:UIControlEventTouchUpInside];
                    [sub.superview addSubview:btn];
                    return;
                }
            }
            [self scanInView:sub depth:depth + 1];
        }
    } @catch (__unused NSException *e) {
    }
}

@end

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *top = [SRTSafeBridge topVC];
        if (top.view) {
            [SRTSafeBridge scanInView:top.view depth:0];
        }
    });
}
