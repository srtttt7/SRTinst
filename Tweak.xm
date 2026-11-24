#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

// MARK: - مفاتيح حفظ الإعدادات
static NSString * const kGhostStoryKey      = @"srt_insta_ghost_story";
static NSString * const kGhostDMKey         = @"srt_insta_ghost_dm";
static NSString * const kDownloadStoryKey   = @"srt_insta_download_story";
static NSString * const kVoiceToVideoKey    = @"srt_insta_voice_to_video";

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

// MARK: - نافذة الإعدادات الموحدة (SRT Settings)
@interface SRTInstaSettingsVC : UITableViewController
@end

@implementation SRTInstaSettingsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"SRT Insta Plus";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
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
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 2; // وضع الشبح
        case 1: return 1; // تحميل الستوريات
        case 2: return 1; // الصوت كبصمة فيديو
        default: return 1; // حقوق المطور
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"وضع الشبح (Ghost Mode)";
        case 1: return @"الوسائط والستوريات";
        case 2: return @"المحادثات والرسائل";
        default: return @"حول الأداة";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (indexPath.section == 3) {
        cell.textLabel.text = @"SRT STORE · @evv2g";
        cell.detailTextLabel.text = @"إعدادات مخصصة لإنستغرام";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }

    UISwitch *sw = [[UISwitch alloc] init];
    sw.onTintColor = [UIColor colorWithRed:0.20 green:0.75 blue:0.95 alpha:1.0];
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];

    if (indexPath.section == 0 && indexPath.row == 0) {
        cell.textLabel.text = @"إخفاء مشاهدة الستوري";
        cell.detailTextLabel.text = @"مشاهدة الستوريات دون ظهور اسمك";
        sw.on = SRTBool(kGhostStoryKey, YES);
        sw.tag = 101;
    } else if (indexPath.section == 0 && indexPath.row == 1) {
        cell.textLabel.text = @"إخفاء قراءة الرسائل (Seen)";
        cell.detailTextLabel.text = @"قراءة رسائل الدايركت دون إشعار الطرف الآخر";
        sw.on = SRTBool(kGhostDMKey, YES);
        sw.tag = 102;
    } else if (indexPath.section == 1 && indexPath.row == 0) {
        cell.textLabel.text = @"زر تحميل الستوريات";
        cell.detailTextLabel.text = @"إضافة زر حفظ الصور والفيديو داخل الستوري";
        sw.on = SRTBool(kDownloadStoryKey, YES);
        sw.tag = 103;
    } else if (indexPath.section == 2 && indexPath.row == 0) {
        cell.textLabel.text = @"إرسال الصوت كبصمة فيديو";
        cell.detailTextLabel.text = @"تحويل الرسالة الصوتية إلى بصمة فيديو عند الإرسال";
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 3) {
        NSURL *tg = [NSURL URLWithString:@"https://t.me/evv2g"];
        if ([[UIApplication sharedApplication] canOpenURL:tg]) {
            [[UIApplication sharedApplication] openURL:tg options:@{} completionHandler:nil];
        }
    }
}

@end

static void SRTOpenSettings(void) {
    UIWindow *win = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:[UIWindowScene class]]) {
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isKeyWindow) { win = w; break; }
            }
        }
    }
    UIViewController *top = win.rootViewController;
    while (top.presentedViewController) {
        top = top.presentedViewController;
    }
    if (!top) return;

    SRTInstaSettingsVC *vc = [[SRTInstaSettingsVC alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [top presentViewController:nav animated:YES completion:nil];
}

// MARK: - حقن زر الإعدادات بجانب أيقونة القلب (الإشعارات)
static void SRTScanAndInjectHeaderButton(UIView *root) {
    if (!root) return;
    for (UIView *sub in root.subviews) {
        NSString *label = [sub.accessibilityLabel lowercaseString];
        NSString *ident = [sub.accessibilityIdentifier lowercaseString];
        BOOL isHeart = [label containsString:@"activity"] ||
                       [label containsString:@"notification"] ||
                       [label containsString:@"الإشعارات"] ||
                       [label containsString:@"النشاط"] ||
                       [ident containsString:@"activity"] ||
                       [ident containsString:@"news"];

        if (isHeart && sub.superview && [sub.superview viewWithTag:987654] == nil) {
            UIButton *srtBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            srtBtn.tag = 987654;
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
            [srtBtn setImage:[UIImage systemImageNamed:@"slider.horizontal.3" withConfiguration:cfg] forState:UIControlStateNormal];
            srtBtn.tintColor = sub.tintColor ?: [UIColor labelColor];
            CGRect f = sub.frame;
            srtBtn.frame = CGRectMake(MAX(8, f.origin.x - f.size.width - 8), f.origin.y, MAX(32, f.size.width), MAX(32, f.size.height));
            [srtBtn addTarget:[NSValue class] action:@selector(srt_openMenu) forControlEvents:UIControlEventTouchUpInside];
            [sub.superview addSubview:srtBtn];
            return;
        }
        SRTScanAndInjectHeaderButton(sub);
    }
}

@implementation NSValue (SRTMenuAction)
+ (void)srt_openMenu {
    SRTOpenSettings();
}
@end

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *cls = NSStringFromClass([self class]);
    if ([cls containsString:@"IGMainFeed"] || [cls containsString:@"IGNavigation"] || [cls containsString:@"IGTabBar"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SRTScanAndInjectHeaderButton(self.view);
        });
    }
}

%end
