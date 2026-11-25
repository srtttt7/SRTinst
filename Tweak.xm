#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

// MARK: - مفاتيح حفظ الإعدادات
static NSString * const kGhostDMSeenKey       = @"srtplus_ghost_dm_seen";
static NSString * const kGhostViewOnceKey   = @"srtplus_ghost_view_once";
static NSString * const kGhostTypingKey     = @"srtplus_ghost_typing";
static NSString * const kSaveViewOnceKey    = @"srtplus_save_view_once";
static NSString * const kGhostStoryKey      = @"srtplus_ghost_story";
static NSString * const kKeepDeletedDMKey   = @"srtplus_keep_deleted_dm";
static NSString * const kVideoToVoiceKey    = @"srtplus_video_to_voice";

static NSString * const kReelDownloadKey    = @"srtplus_reel_download";
static NSString * const kReelCopyTextKey    = @"srtplus_reel_copy_text";

static NSString * const kStoryDownloadKey   = @"srtplus_story_download";
static NSString * const kStoryRevealTagsKey = @"srtplus_story_reveal_tags";

static NSString * const kLiquidGlassKey     = @"srtplus_liquid_glass";

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

static inline NSString *SRTLowerClass(id obj) {
    if (!obj) return @"";
    NSString *cls = NSStringFromClass([obj class]);
    return cls ? [cls lowercaseString] : @"";
}

// MARK: - تحويل الفيديو إلى مقطع صوتي لبصمة الصوت
static void SRTConvertVideoToVoiceURL(NSURL *videoURL, void (^completion)(NSURL *audioURL)) {
    @try {
        if (!videoURL) {
            if (completion) completion(nil);
            return;
        }
        AVAsset *asset = [AVAsset assetWithURL:videoURL];
        NSArray<AVAssetTrack *> *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
        AVAssetTrack *track = [audioTracks firstObject];
        if (!track) {
            if (completion) completion(nil);
            return;
        }

        NSString *outPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"srt_voice_note_%@.m4a", [[NSUUID UUID] UUIDString]]];
        NSURL *outURL = [NSURL fileURLWithPath:outPath];
        [[NSFileManager defaultManager] removeItemAtURL:outURL error:nil];

        AVMutableComposition *comp = [AVMutableComposition composition];
        AVMutableCompositionTrack *compTrack = [comp addMutableTrackWithMediaType:AVMediaTypeAudio
                                                               preferredTrackID:kCMPersistentTrackID_Invalid];
        [compTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                           ofTrack:track
                            atTime:kCMTimeZero
                             error:nil];

        AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:comp
                                                                       presetName:AVAssetExportPresetAppleM4A];
        if (!exporter) {
            if (completion) completion(nil);
            return;
        }
        exporter.outputURL = outURL;
        exporter.outputFileType = AVFileTypeAppleM4A;
        [exporter exportAsynchronouslyWithCompletionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (exporter.status == AVAssetExportSessionStatusCompleted) {
                    if (completion) completion(outURL);
                } else {
                    if (completion) completion(nil);
                }
            });
        }];
    } @catch (__unused NSException *e) {
        if (completion) completion(nil);
    }
}

static NSURL *SRTExtractMediaURL(id candidate) {
    if (!candidate) return nil;
    if ([candidate isKindOfClass:[NSURL class]]) return (NSURL *)candidate;
    if ([candidate isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)candidate;
        return [s hasPrefix:@"/"] ? [NSURL fileURLWithPath:s] : [NSURL URLWithString:s];
    }
    if ([candidate respondsToSelector:@selector(fileURL)]) {
        id u = [candidate performSelector:@selector(fileURL)];
        if ([u isKindOfClass:[NSURL class]]) return (NSURL *)u;
    }
    if ([candidate respondsToSelector:@selector(videoURL)]) {
        id u = [candidate performSelector:@selector(videoURL)];
        if ([u isKindOfClass:[NSURL class]]) return (NSURL *)u;
    }
    if ([candidate respondsToSelector:@selector(assetURL)]) {
        id u = [candidate performSelector:@selector(assetURL)];
        if ([u isKindOfClass:[NSURL class]]) return (NSURL *)u;
    }
    return nil;
}

// MARK: - محرك الأداة
@interface SRTPlusEngine : NSObject
+ (UIWindow *)activeWindow;
+ (UIViewController *)topVCFrom:(UIViewController *)vc;
+ (void)openSettings;
+ (void)syncAllOverlays;
+ (void)installHooks;
@end

// MARK: - شاشة الإعدادات الموحدة (SRTplus)
@interface SRTPlusSettingsVC : UITableViewController
@end

@implementation SRTPlusSettingsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"SRTplus";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"تم"
                style:UIBarButtonItemStyleDone
               target:self
               action:@selector(closeVC)];
    [self applyGlassAppearance];
}

- (void)applyGlassAppearance {
    if (SRTBool(kLiquidGlassKey, YES)) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
        UIVisualEffectView *bgView = [[UIVisualEffectView alloc] initWithEffect:blur];
        bgView.frame = self.tableView.bounds;
        bgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.tableView.backgroundView = bgView;
        self.tableView.backgroundColor = [UIColor clearColor];
    } else {
        self.tableView.backgroundView = nil;
        self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
}

- (void)closeVC {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 5;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 5; // وضع الشبح والستوري والمشاهدة لمرة واحدة
        case 1: return 2; // الرسائل (حفظ المحذوفات + فيديو كبصمة صوتية)
        case 2: return 2; // الريلز
        case 3: return 2; // الستوريات والتاقات
        default: return 1; // المطور SRT في الأسفل
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"وضع الشبح (Ghost Mode)";
        case 1: return @"الرسائل (Messages)";
        case 2: return @"الريلز (Reels)";
        case 3: return @"الستوريات والتاقات (Stories)";
        default: return @"المطور";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (SRTBool(kLiquidGlassKey, YES)) {
        cell.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.72];
    }

    if (indexPath.section == 4) {
        cell.textLabel.text = @"المطور SRT";
        cell.detailTextLabel.text = @"@evv2g · فتح تيليجرام";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }

    UISwitch *sw = [[UISwitch alloc] init];
    [sw addTarget:self action:@selector(switchToggled:) forControlEvents:UIControlEventValueChanged];
    sw.tag = indexPath.section * 100 + indexPath.row;

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"إخفاء مشاهدة الرسائل";
            cell.detailTextLabel.text = @"قراءة رسائل الدايركت دون علم الطرف الآخر";
            sw.on = SRTBool(kGhostDMSeenKey, YES);
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"مشاهدة الصور لمرة واحدة بدون علمه";
            cell.detailTextLabel.text = @"فتح وسائط المشاهدة لمرة واحدة دون إشعار";
            sw.on = SRTBool(kGhostViewOnceKey, YES);
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"إخفاء حالة الكتابة";
            cell.detailTextLabel.text = @"عدم إظهار للطرف الآخر أنك تكتب";
            sw.on = SRTBool(kGhostTypingKey, YES);
        } else if (indexPath.row == 3) {
            cell.textLabel.text = @"تحميل صور المشاهدة لمرة واحدة";
            cell.detailTextLabel.text = @"حفظ صور/وسائط المشاهدة لمرة واحدة في الاستوديو";
            sw.on = SRTBool(kSaveViewOnceKey, YES);
        } else {
            cell.textLabel.text = @"إخفاء مشاهدة الستوري";
            cell.detailTextLabel.text = @"مشاهدة الستوري دون علم صاحبها";
            sw.on = SRTBool(kGhostStoryKey, YES);
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"حفظ الرسائل المحذوفة";
            cell.detailTextLabel.text = @"منع اختفاء الرسائل بعد حذفها من الطرف الآخر";
            sw.on = SRTBool(kKeepDeletedDMKey, YES);
        } else {
            cell.textLabel.text = @"إرسال فيديو كبصمة رسالة صوتية";
            cell.detailTextLabel.text = @"تحويل الفيديو المرسل إلى بصمة صوتية";
            sw.on = SRTBool(kVideoToVoiceKey, YES);
        }
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"زر تحميل الريلز";
            cell.detailTextLabel.text = @"إظهار زر التحميل فوق علامة الإعجاب في الريلز";
            sw.on = SRTBool(kReelDownloadKey, YES);
        } else {
            cell.textLabel.text = @"نسخ تعليقات وبايو الريل";
            cell.detailTextLabel.text = @"تسهيل نسخ تعليقات الريل وبايو الحساب";
            sw.on = SRTBool(kReelCopyTextKey, YES);
        }
    } else if (indexPath.section == 3) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"تنزيل الستوريات";
            cell.detailTextLabel.text = @"حفظ صور وفيديوهات الستوري";
            sw.on = SRTBool(kStoryDownloadKey, YES);
        } else {
            cell.textLabel.text = @"إظهار التاقات المخفية والحسابات";
            cell.detailTextLabel.text = @"إظهار زر التاق أسفل اليسار عند وجود تاق فقط";
            sw.on = SRTBool(kStoryRevealTagsKey, YES);
        }
    }

    cell.accessoryView = sw;
    return cell;
}

- (void)switchToggled:(UISwitch *)sw {
    BOOL val = sw.isOn;
    switch (sw.tag) {
        case 0: SRTSetBool(kGhostDMSeenKey, val); break;
        case 1: SRTSetBool(kGhostViewOnceKey, val); break;
        case 2: SRTSetBool(kGhostTypingKey, val); break;
        case 3: SRTSetBool(kSaveViewOnceKey, val); break;
        case 4: SRTSetBool(kGhostStoryKey, val); break;
        case 100: SRTSetBool(kKeepDeletedDMKey, val); break;
        case 101: SRTSetBool(kVideoToVoiceKey, val); break;
        case 200: SRTSetBool(kReelDownloadKey, val); break;
        case 201: SRTSetBool(kReelCopyTextKey, val); break;
        case 300: SRTSetBool(kStoryDownloadKey, val); break;
        case 301: SRTSetBool(kStoryRevealTagsKey, val); break;
        default: break;
    }
    [SRTPlusEngine syncAllOverlays];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 4) {
        NSURL *tgApp = [NSURL URLWithString:@"tg://resolve?domain=evv2g"];
        NSURL *tgWeb = [NSURL URLWithString:@"https://t.me/evv2g"];
        UIApplication *app = [UIApplication sharedApplication];
        if ([app canOpenURL:tgApp]) {
            [app openURL:tgApp options:@{} completionHandler:nil];
        } else {
            [app openURL:tgWeb options:@{} completionHandler:nil];
        }
    }
}

@end

// MARK: - هوكات وضع الشبح وحفظ المحذوفات وفيديو كبصمة صوتية
static void (*orig_SeenHook)(id, SEL, id) = NULL;
static void hooked_SeenBlock(id self, SEL _cmd, id arg) {
    NSString *selStr = NSStringFromSelector(_cmd) ?: @"";
    if ([selStr containsString:@"Story"] && SRTBool(kGhostStoryKey, YES)) return;
    if (([selStr containsString:@"ViewOnce"] || [selStr containsString:@"Ephemeral"]) && SRTBool(kGhostViewOnceKey, YES)) return;
    if (SRTBool(kGhostDMSeenKey, YES)) return;
    if (orig_SeenHook) orig_SeenHook(self, _cmd, arg);
}

static void (*orig_TypingHook)(id, SEL, BOOL) = NULL;
static void hooked_TypingBlock(id self, SEL _cmd, BOOL typing) {
    if (typing && SRTBool(kGhostTypingKey, YES)) return;
    if (orig_TypingHook) orig_TypingHook(self, _cmd, typing);
}

static void (*orig_DeleteMsgHook)(id, SEL, id) = NULL;
static void hooked_DeleteMsgBlock(id self, SEL _cmd, id msg) {
    if (SRTBool(kKeepDeletedDMKey, YES)) return;
    if (orig_DeleteMsgHook) orig_DeleteMsgHook(self, _cmd, msg);
}

static void (*orig_SendVideoHook)(id, SEL, id, id) = NULL;
static void hooked_SendVideoAsVoiceNote(id self, SEL _cmd, id mediaObj, id extra) {
    if (SRTBool(kVideoToVoiceKey, YES)) {
        NSURL *srcURL = SRTExtractMediaURL(mediaObj);
        if (srcURL) {
            SRTConvertVideoToVoiceURL(srcURL, ^(NSURL *audioURL) {
                if (audioURL && orig_SendVideoHook) {
                    orig_SendVideoHook(self, _cmd, audioURL, extra);
                } else if (orig_SendVideoHook) {
                    orig_SendVideoHook(self, _cmd, mediaObj, extra);
                }
            });
            return;
        }
    }
    if (orig_SendVideoHook) orig_SendVideoHook(self, _cmd, mediaObj, extra);
}

static void SRTSafeHook(const char *clsName, const char *selName, IMP imp, void **orig) {
    Class cls = objc_getClass(clsName);
    if (!cls) return;
    SEL sel = sel_registerName(selName);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    if (orig) *orig = (void *)method_getImplementation(m);
    method_setImplementation(m, imp);
}

// MARK: - تنفيذ الواجهة والأزرار
@implementation SRTPlusEngine

+ (void)installHooks {
    @try {
        SRTSafeHook("IGStoryViewerViewController", "markItemAsSeen:", (IMP)hooked_SeenBlock, (void **)&orig_SeenHook);
        SRTSafeHook("IGStoryDataController", "markStoryItemSeen:", (IMP)hooked_SeenBlock, (void **)&orig_SeenHook);
        SRTSafeHook("IGDirectThreadViewController", "markThreadAsSeen:", (IMP)hooked_SeenBlock, (void **)&orig_SeenHook);
        SRTSafeHook("IGDirectThreadViewController", "setTypingIndicatorVisible:", (IMP)hooked_TypingBlock, (void **)&orig_TypingHook);
        SRTSafeHook("IGDirectThreadViewController", "deleteMessage:", (IMP)hooked_DeleteMsgBlock, (void **)&orig_DeleteMsgHook);
        SRTSafeHook("IGDirectOutgoingMessageSendController", "sendVideoMessage:recipient:", (IMP)hooked_SendVideoAsVoiceNote, (void **)&orig_SendVideoHook);
        SRTSafeHook("IGDirectOutgoingMessageSendController", "sendVideo:recipient:", (IMP)hooked_SendVideoAsVoiceNote, (void **)&orig_SendVideoHook);
    } @catch (__unused NSException *e) {}
}

+ (UIWindow *)activeWindow {
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

+ (UIViewController *)topVCFrom:(UIViewController *)vc {
    @try {
        if (!vc) return nil;
        if (vc.presentedViewController) return [self topVCFrom:vc.presentedViewController];
        if ([vc isKindOfClass:[UINavigationController class]]) return [self topVCFrom:((UINavigationController *)vc).topViewController];
        if ([vc isKindOfClass:[UITabBarController class]]) return [self topVCFrom:((UITabBarController *)vc).selectedViewController];
        for (UIViewController *child in vc.childViewControllers) {
            if (child.isViewLoaded && child.view.window && !child.view.hidden && child.view.alpha > 0.01) {
                NSString *c = SRTLowerClass(child);
                if ([c containsString:@"feed"] || [c containsString:@"story"] || [c containsString:@"reel"] || [c containsString:@"clip"]) {
                    return [self topVCFrom:child];
                }
            }
        }
        return vc;
    } @catch (__unused NSException *e) {
        return vc;
    }
}

+ (BOOL)hasHomeTopPlusButtonIn:(UIView *)view depth:(int)depth {
    if (!view || depth > 6 || view.hidden || view.alpha < 0.01) return NO;
    @try {
        for (UIView *sub in view.subviews) {
            CGRect f = sub.frame;
            if (f.origin.y < 140 && f.origin.x < 90 && f.size.width >= 20 && f.size.width <= 70 && [sub isKindOfClass:[UIButton class]]) {
                return YES;
            }
            if ([self hasHomeTopPlusButtonIn:sub depth:depth + 1]) return YES;
        }
    } @catch (__unused NSException *e) {}
    return NO;
}

+ (BOOL)isOnHomeFeed:(UIWindow *)win {
    @try {
        if (!win || !win.rootViewController) return NO;
        UIViewController *top = [self topVCFrom:win.rootViewController];
        if (!top || top.presentingViewController != nil) return NO;
        NSString *c = SRTLowerClass(top);
        NSArray<NSString *> *blocked = @[@"story", @"reel", @"clip", @"direct", @"thread", @"inbox", @"login", @"signin", @"signup", @"auth", @"profile", @"explore", @"search", @"camera"];
        for (NSString *k in blocked) {
            if ([c containsString:k]) return NO;
        }
        return [self hasHomeTopPlusButtonIn:win depth:0];
    } @catch (__unused NSException *e) {
        return NO;
    }
}

+ (BOOL)isOnStory:(UIWindow *)win {
    @try {
        UIViewController *top = [self topVCFrom:win.rootViewController];
        if ([SRTLowerClass(top) containsString:@"story"]) return YES;
        for (UIView *v in win.subviews) {
            if ([SRTLowerClass(v) containsString:@"story"] && !v.hidden && v.alpha > 0.01) return YES;
        }
    } @catch (__unused NSException *e) {}
    return NO;
}

+ (BOOL)isOnReels:(UIWindow *)win {
    @try {
        UIViewController *top = [self topVCFrom:win.rootViewController];
        NSString *c = SRTLowerClass(top);
        if ([c containsString:@"reel"] || [c containsString:@"clip"]) return YES;
        for (UIView *v in win.subviews) {
            NSString *vc = SRTLowerClass(v);
            if (([vc containsString:@"reel"] || [vc containsString:@"clip"]) && !v.hidden && v.alpha > 0.01) return YES;
        }
    } @catch (__unused NSException *e) {}
    return NO;
}

+ (BOOL)storyHasTagInWindow:(UIWindow *)win {
    @try {
        return [self hasTagLabelInView:win depth:0];
    } @catch (__unused NSException *e) {
        return NO;
    }
}

+ (BOOL)hasTagLabelInView:(UIView *)view depth:(int)depth {
    if (!view || depth > 12 || view.hidden || view.alpha < 0.01) return NO;
    if ([view isKindOfClass:[UILabel class]]) {
        NSString *txt = ((UILabel *)view).text ?: @"";
        if ([txt containsString:@"@"] || [txt rangeOfString:@"tag" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    for (UIView *sub in view.subviews) {
        if ([self hasTagLabelInView:sub depth:depth + 1]) return YES;
    }
    return NO;
}

+ (void)styleGlassButton:(UIButton *)btn cornerRadius:(CGFloat)r {
    btn.layer.cornerRadius = r;
    btn.clipsToBounds = YES;
    if (SRTBool(kLiquidGlassKey, YES)) {
        btn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.14];
        btn.layer.borderWidth = 0.7;
        btn.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.35].CGColor;
    } else {
        btn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
        btn.layer.borderWidth = 0;
    }
    btn.tintColor = [UIColor whiteColor];
}

+ (void)toast:(NSString *)msg {
    @try {
        UIWindow *win = [self activeWindow];
        UIViewController *top = [self topVCFrom:win.rootViewController];
        if (!top) return;
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"SRTplus" message:msg preferredStyle:UIAlertControllerStyleAlert];
        [top presentViewController:a animated:YES completion:^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [a dismissViewControllerAnimated:YES completion:nil];
            });
        }];
    } @catch (__unused NSException *e) {}
}

+ (void)saveCurrentScreenImageWithLabel:(NSString *)label {
    @try {
        UIWindow *win = [self activeWindow];
        if (!win) return;
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:win.bounds];
        UIImage *img = [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *ctx) {
            [win drawViewHierarchyInRect:win.bounds afterScreenUpdates:NO];
        }];
        if (!img) return;
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
                    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                        [PHAssetChangeRequest creationRequestForAssetFromImage:img];
                    } completionHandler:^(BOOL ok, __unused NSError *err) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self toast:(ok ? [NSString stringWithFormat:@"تم حفظ %@", label] : @"فشل الحفظ")];
                        });
                    }];
                } else {
                    [self toast:@"فعّل صلاحية الصور من الإعدادات"];
                }
            });
        }];
    } @catch (__unused NSException *e) {}
}

+ (void)downloadReelAction {
    [self saveCurrentScreenImageWithLabel:@"الريل"];
}

+ (void)downloadStoryAction {
    [self saveCurrentScreenImageWithLabel:@"الستوري"];
}

+ (void)revealStoryTagsAction {
    [self toast:@"تم إظهار التاقات والحسابات المتاحة في الستوري"];
}

+ (void)openSettings {
    @try {
        UIWindow *win = [self activeWindow];
        UIViewController *top = [self topVCFrom:win.rootViewController];
        if (!top) return;
        SRTPlusSettingsVC *vc = [[SRTPlusSettingsVC alloc] initWithStyle:UITableViewStyleInsetGrouped];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.modalPresentationStyle = UIModalPresentationPageSheet;
        [top presentViewController:nav animated:YES completion:nil];
    } @catch (__unused NSException *e) {}
}

+ (void)syncAllOverlays {
    @try {
        UIWindow *win = [self activeWindow];
        if (!win) return;

        CGFloat w = CGRectGetWidth(win.bounds);
        CGFloat h = CGRectGetHeight(win.bounds);
        CGFloat topInset = win.safeAreaInsets.top > 0 ? win.safeAreaInsets.top : 44.0;
        CGFloat botInset = win.safeAreaInsets.bottom > 0 ? win.safeAreaInsets.bottom : 34.0;

        UIButton *homeBtn = [win viewWithTag:91001];
        if (!homeBtn) {
            homeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            homeBtn.tag = 91001;
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightRegular];
            UIImage *img = [UIImage systemImageNamed:@"slider.horizontal.3" withConfiguration:cfg];
            if (img) [homeBtn setImage:img forState:UIControlStateNormal];
            else [homeBtn setTitle:@"SRT" forState:UIControlStateNormal];
            [homeBtn addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
            [win addSubview:homeBtn];
        }
        homeBtn.frame = CGRectMake(w - 82.0, topInset + 6.0, 32.0, 32.0);
        homeBtn.tintColor = [UIColor whiteColor];
        homeBtn.backgroundColor = SRTBool(kLiquidGlassKey, YES) ? [[UIColor whiteColor] colorWithAlphaComponent:0.10] : [UIColor clearColor];
        homeBtn.layer.cornerRadius = 8.0;
        BOOL showHome = [self isOnHomeFeed:win];
        homeBtn.hidden = !showHome;
        if (showHome) [win bringSubviewToFront:homeBtn];

        UIButton *reelBtn = [win viewWithTag:91002];
        if (!reelBtn) {
            reelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            reelBtn.tag = 91002;
            UIImage *img = [UIImage systemImageNamed:@"arrow.down.circle.fill"];
            if (img) [reelBtn setImage:img forState:UIControlStateNormal];
            else [reelBtn setTitle:@"DL" forState:UIControlStateNormal];
            [reelBtn addTarget:self action:@selector(downloadReelAction) forControlEvents:UIControlEventTouchUpInside];
            [win addSubview:reelBtn];
        }
        reelBtn.frame = CGRectMake(w - 54.0, h - botInset - 270.0, 38.0, 38.0);
        [self styleGlassButton:reelBtn cornerRadius:19.0];
        BOOL showReel = SRTBool(kReelDownloadKey, YES) && [self isOnReels:win];
        reelBtn.hidden = !showReel;
        if (showReel) [win bringSubviewToFront:reelBtn];

        UIButton *storyDlBtn = [win viewWithTag:91003];
        if (!storyDlBtn) {
            storyDlBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            storyDlBtn.tag = 91003;
            UIImage *img = [UIImage systemImageNamed:@"arrow.down.to.line"];
            if (img) [storyDlBtn setImage:img forState:UIControlStateNormal];
            else [storyDlBtn setTitle:@"Save" forState:UIControlStateNormal];
            [storyDlBtn addTarget:self action:@selector(downloadStoryAction) forControlEvents:UIControlEventTouchUpInside];
            [win addSubview:storyDlBtn];
        }
        storyDlBtn.frame = CGRectMake(16.0, topInset + 14.0, 36.0, 36.0);
        [self styleGlassButton:storyDlBtn cornerRadius:18.0];
        BOOL inStory = [self isOnStory:win];
        BOOL showStoryDl = SRTBool(kStoryDownloadKey, YES) && inStory;
        storyDlBtn.hidden = !showStoryDl;
        if (showStoryDl) [win bringSubviewToFront:storyDlBtn];

        UIButton *storyTagBtn = [win viewWithTag:91004];
        if (!storyTagBtn) {
            storyTagBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            storyTagBtn.tag = 91004;
            UIImage *img = [UIImage systemImageNamed:@"person.crop.circle.badge.checkmark"];
            if (img) [storyTagBtn setImage:img forState:UIControlStateNormal];
            else [storyTagBtn setTitle:@"Tag" forState:UIControlStateNormal];
            [storyTagBtn addTarget:self action:@selector(revealStoryTagsAction) forControlEvents:UIControlEventTouchUpInside];
            [win addSubview:storyTagBtn];
        }
        storyTagBtn.frame = CGRectMake(16.0, h - botInset - 54.0, 38.0, 38.0);
        [self styleGlassButton:storyTagBtn cornerRadius:19.0];
        BOOL hasTag = inStory && SRTBool(kStoryRevealTagsKey, YES) && [self storyHasTagInWindow:win];
        storyTagBtn.hidden = !hasTag;
        if (hasTag) [win bringSubviewToFront:storyTagBtn];

    } @catch (__unused NSException *e) {}
}

@end

%ctor {
    [SRTPlusEngine installHooks];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SRTPlusEngine syncAllOverlays];
        [NSTimer scheduledTimerWithTimeInterval:0.7 repeats:YES block:^(__unused NSTimer *t) {
            [SRTPlusEngine syncAllOverlays];
        }];
    });
}
