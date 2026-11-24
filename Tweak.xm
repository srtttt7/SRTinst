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

%ctor {
    NSLog(@"[SRTInstaPlus] Loaded cleanly");
}
