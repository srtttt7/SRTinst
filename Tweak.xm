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

@interface SRTOpenHelper : NSObject
+ (void)presentSRTSettings;
@end

@implementation SRTOpenHelper

+ (UIViewController *)srt_topViewController {
    UIWindow *targetWindow = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] &&
            scene.activationState == UISceneActivationStateForegroundActive) {
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) {
                    targetWindow = w;
                    break;
                }
            }
            if (!targetWindow && ws.windows.count > 0) {
                targetWindow = ws.windows.firstObject;
            }
            if (targetWindow) break;
        }
    }
    UIViewController *vc = targetWindow.rootViewController;
    while (vc.presentedViewController) {
        vc = vc.presentedViewController;
    }
    return vc;
}

+ (void)presentSRTSettings {
    UIViewController *top = [self srt_topViewController];
    if (!top) return;
    SRTInstaSettingsVC *settingsVC = [[SRTInstaSettingsVC alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [top presentViewController:nav animated:YES completion:nil];
}

+ (void)injectNearHeartInView:(UIView *)view {
    if (!view || view.hidden || view.alpha < 0.01) return;
    for (UIView *sub in view.subviews) {
        NSString *lbl = [sub.accessibilityLabel lowercaseString] ?: @"";
        NSString *aid = [sub.accessibilityIdentifier lowercaseString] ?: @"";
        BOOL matchesHeart = [lbl containsString:@"activity"] ||
                            [lbl containsString:@"notification"] ||
                            [lbl containsString:@"الإشعارات"] ||
                            [lbl containsString:@"النشاط"] ||
                            [lbl containsString:@"heart"] ||
                            [aid containsString:@"activity"] ||
                            [aid containsString:@"news"];

        if (matchesHeart && sub.superview && CGRectGetWidth(sub.bounds) >= 20 && CGRectGetWidth(sub.bounds) <= 80) {
            if ([sub.superview viewWithTag:884422] == nil) {
                UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
                btn.tag = 884422;
                UIImage *icon = [UIImage systemImageNamed:@"slider.horizontal.3"];
                if (icon) {
                    [btn setImage:icon forState:UIControlStateNormal];
                } else {
                    [btn setTitle:@"SRT" forState:UIControlStateNormal];
                }
                btn.tintColor = sub.tintColor ?: [UIColor labelColor];
                CGFloat size = MAX(30.0, CGRectGetHeight(sub.frame));
                CGFloat x = MAX(6.0, CGRectGetMinX(sub.frame) - size - 6.0);
                CGFloat y = CGRectGetMidY(sub.frame) - (size / 2.0);
                btn.frame = CGRectMake(x, y, size, size);
                [btn addTarget:self action:@selector(presentSRTSettings) forControlEvents:UIControlEventTouchUpInside];
                [sub.superview addSubview:btn];
            }
            return;
        }
        [self injectNearHeartInView:sub];
    }
}

+ (void)scanActiveWindowForHeart {
    UIViewController *top = [self srt_topViewController];
    if (top.view) {
        [self injectNearHeartInView:top.view];
    }
}

@end

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        [SRTOpenHelper scanActiveWindowForHeart];
    });
}

%end
