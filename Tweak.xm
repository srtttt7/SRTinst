#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

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

// MARK: - دوال مساعدة للنافذة والواجهة
@interface SRTTweakEngine : NSObject
+ (UIWindow *)activeWindow;
+ (UIViewController *)topVisibleViewControllerFrom:(UIViewController *)vc;
+ (void)openSettings;
+ (void)syncHomeButton;
+ (void)syncStoryDownloadButton;
+ (void)installRuntimeHooks;
@end

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
        cell.detailTextLabel.text = @"منع إرسال إشعار مشاهدة الستوري";
        sw.on = SRTBool(kGhostStoryKey, YES);
        sw.tag = 101;
    } else if (indexPath.section == 0 && indexPath.row == 1) {
        cell.textLabel.text = @"إخفاء قراءة الرسائل (Seen)";
        cell.detailTextLabel.text = @"منع إرسال إشعار قراءة رسائل الدايركت";
        sw.on = SRTBool(kGhostDMKey, YES);
        sw.tag = 102;
    } else if (indexPath.section == 1 && indexPath.row == 0) {
        cell.textLabel.text = @"زر تحميل الستوريات";
        cell.detailTextLabel.text = @"إظهار زر حفظ الستوري داخل شاشة الستوري";
        sw.on = SRTBool(kDownloadStoryKey, YES);
        sw.tag = 103;
    } else {
        cell.textLabel.text = @"إرسال الصوت كبصمة فيديو";
        cell.detailTextLabel.text = @"تحويل المقطع الصوتي إلى فيديو عند الإرسال";
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
        case 103:
            SRTSetBool(kDownloadStoryKey, sender.isOn);
            [SRTTweakEngine syncStoryDownloadButton];
            break;
        case 104: SRTSetBool(kVoiceToVideoKey, sender.isOn); break;
        default: break;
    }
}

@end

// MARK: - هوكات وضع الشبح والصوت كبصمة فيديو عبر Runtime
static void (*orig_IGMarkStorySeen)(id, SEL, id) = NULL;
static void hooked_IGMarkStorySeen(id self, SEL _cmd, id item) {
    if (SRTBool(kGhostStoryKey, YES)) {
        return;
    }
    if (orig_IGMarkStorySeen) orig_IGMarkStorySeen(self, _cmd, item);
}

static void (*orig_IGMarkDirectSeen)(id, SEL, id) = NULL;
static void hooked_IGMarkDirectSeen(id self, SEL _cmd, id thread) {
    if (SRTBool(kGhostDMKey, YES)) {
        return;
    }
    if (orig_IGMarkDirectSeen) orig_IGMarkDirectSeen(self, _cmd, thread);
}

static void (*orig_IGSendAudioAsVideo)(id, SEL, id, id) = NULL;
static void hooked_IGSendAudioAsVideo(id self, SEL _cmd, id audioData, id extra) {
    if (SRTBool(kVoiceToVideoKey, NO) && [audioData isKindOfClass:[NSData class]]) {
        NSURL *tmpAudio = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"srt_voice_tmp.m4a"]];
        [(NSData *)audioData writeToURL:tmpAudio atomically:YES];
        NSURL *outVideo = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"srt_voice_note.mp4"]];
        [[NSFileManager defaultManager] removeItemAtURL:outVideo error:nil];

        AVAsset *asset = [AVAsset assetWithURL:tmpAudio];
        AVAssetTrack *audioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
        if (audioTrack) {
            AVMutableComposition *comp = [AVMutableComposition composition];
            AVMutableCompositionTrack *compAudio = [comp addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            [compAudio insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:audioTrack atTime:kCMTimeZero error:nil];

            AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:comp presetName:AVAssetExportPresetAppleM4A];
            exporter.outputURL = outVideo;
            exporter.outputFileType = AVFileTypeMPEG4;
            [exporter exportAsynchronouslyWithCompletionHandler:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (orig_IGSendAudioAsVideo) {
                        orig_IGSendAudioAsVideo(self, _cmd, outVideo, extra);
                    }
                });
            }];
            return;
        }
    }
    if (orig_IGSendAudioAsVideo) orig_IGSendAudioAsVideo(self, _cmd, audioData, extra);
}

static void SRTReplaceMethodIfExists(const char *className, const char *selName, IMP newIMP, void **origIMP) {
    Class cls = objc_getClass(className);
    if (!cls) return;
    SEL sel = sel_registerName(selName);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    if (origIMP) *origIMP = (void *)method_getImplementation(m);
    method_setImplementation(m, newIMP);
}

// MARK: - تنفيذ المحرك
@implementation SRTTweakEngine

+ (void)installRuntimeHooks {
    @try {
        SRTReplaceMethodIfExists("IGStoryViewerViewController", "markItemAsSeen:", (IMP)hooked_IGMarkStorySeen, (void **)&orig_IGMarkStorySeen);
        SRTReplaceMethodIfExists("IGStoryDataController", "markStoryItemSeen:", (IMP)hooked_IGMarkStorySeen, (void **)&orig_IGMarkStorySeen);
        SRTReplaceMethodIfExists("IGDirectThreadViewController", "markThreadAsSeen:", (IMP)hooked_IGMarkDirectSeen, (void **)&orig_IGMarkDirectSeen);
        SRTReplaceMethodIfExists("IGDirectOutgoingMessageSendController", "sendAudioMessage:recipient:", (IMP)hooked_IGSendAudioAsVideo, (void **)&orig_IGSendAudioAsVideo);
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

+ (UIViewController *)topVisibleViewControllerFrom:(UIViewController *)vc {
    @try {
        if (!vc) return nil;
        if (vc.presentedViewController) {
            return [self topVisibleViewControllerFrom:vc.presentedViewController];
        }
        if ([vc isKindOfClass:[UINavigationController class]]) {
            return [self topVisibleViewControllerFrom:((UINavigationController *)vc).topViewController];
        }
        if ([vc isKindOfClass:[UITabBarController class]]) {
            return [self topVisibleViewControllerFrom:((UITabBarController *)vc).selectedViewController];
        }
        for (UIViewController *child in vc.childViewControllers) {
            if (child.isViewLoaded && child.view.window && !child.view.hidden && child.view.alpha > 0.01) {
                NSString *c = [NSStringFromClass([child class]) lowercaseString];
                if ([c containsString:@"feed"] || [c containsString:@"story"] ||
                    [c containsString:@"direct"] || [c containsString:@"login"]) {
                    return [self topVisibleViewControllerFrom:child];
                }
            }
        }
        return vc;
    } @catch (__unused NSException *e) {
        return vc;
    }
}

+ (BOOL)hasPlusButtonInTopBarOfView:(UIView *)view depth:(int)depth {
    if (!view || depth > 6 || view.hidden || view.alpha < 0.01) return NO;
    @try {
        for (UIView *sub in view.subviews) {
            CGRect f = sub.frame;
            if (f.origin.y < 140 && f.origin.x < 90 && f.size.width >= 20 && f.size.width <= 70) {
                NSString *lbl = [sub.accessibilityLabel lowercaseString] ?: @"";
                NSString *aid = [sub.accessibilityIdentifier lowercaseString] ?: @"";
                if ([lbl containsString:@"create"] || [lbl containsString:@"new post"] ||
                    [lbl containsString:@"إضافة"] || [lbl containsString:@"إنشاء"] ||
                    [aid containsString:@"create"] || [aid containsString:@"plus"] ||
                    [sub isKindOfClass:[UIButton class]]) {
                    return YES;
                }
            }
            if ([self hasPlusButtonInTopBarOfView:sub depth:depth + 1]) {
                return YES;
            }
        }
    } @catch (__unused NSException *e) {}
    return NO;
}

+ (BOOL)isOnHomeFeedScreenInWindow:(UIWindow *)win {
    @try {
        if (!win || !win.rootViewController) return NO;
        UIViewController *top = [self topVisibleViewControllerFrom:win.rootViewController];
        if (!top || top.presentingViewController != nil) return NO;

        NSString *lowerCls = [[NSStringFromClass([top class]) ?: @""] lowercaseString];
        NSArray<NSString *> *blocked = @[
            @"story", @"reel", @"clip", @"direct", @"thread", @"inbox",
            @"login", @"signin", @"signup", @"auth", @"onboarding", @"nux",
            @"profile", @"explore", @"search", @"camera", @"media", @"viewer"
        ];
        for (NSString *kw in blocked) {
            if ([lowerCls containsString:kw]) return NO;
        }
        return [self hasPlusButtonInTopBarOfView:win depth:0];
    } @catch (__unused NSException *e) {
        return NO;
    }
}

+ (BOOL)isOnStoryScreenInWindow:(UIWindow *)win {
    @try {
        if (!win || !win.rootViewController) return NO;
        UIViewController *top = [self topVisibleViewControllerFrom:win.rootViewController];
        NSString *lowerCls = [[NSStringFromClass([top class]) ?: @""] lowercaseString];
        if ([lowerCls containsString:@"story"]) return YES;
        for (UIView *v in win.subviews) {
            NSString *vl = [[NSStringFromClass([v class]) ?: @""] lowercaseString];
            if ([vl containsString:@"story"] && !v.hidden && v.alpha > 0.01) return YES;
        }
    } @catch (__unused NSException *e) {}
    return NO;
}

+ (void)showToast:(NSString *)msg inViewController:(UIViewController *)vc {
    if (!vc) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"SRT Insta Plus"
                                                                  message:msg
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [vc presentViewController:alert animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

+ (UIImage *)captureStoryImageFromWindow:(UIWindow *)win {
    @try {
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:win.bounds];
        return [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *ctx) {
            [win drawViewHierarchyInRect:win.bounds afterScreenUpdates:NO];
        }];
    } @catch (__unused NSException *e) {
        return nil;
    }
}

+ (void)downloadCurrentStory {
    @try {
        UIWindow *win = [self activeWindow];
        UIViewController *top = [self topVisibleViewControllerFrom:win.rootViewController];
        UIImage *img = [self captureStoryImageFromWindow:win];
        if (!img) {
            [self showToast:@"تعذر التقاط محتوى الستوري" inViewController:top];
            return;
        }
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
                    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                        [PHAssetChangeRequest creationRequestForAssetFromImage:img];
                    } completionHandler:^(BOOL success, __unused NSError *error) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self showToast:(success ? @"تم حفظ الستوري في الاستوديو" : @"فشل حفظ الستوري") inViewController:top];
                        });
                    }];
                } else {
                    [self showToast:@"فعّل صلاحية الصور من الإعدادات لحفظ الستوري" inViewController:top];
                }
            });
        }];
    } @catch (__unused NSException *e) {}
}

+ (void)openSettings {
    @try {
        UIWindow *win = [self activeWindow];
        UIViewController *top = [self topVisibleViewControllerFrom:win.rootViewController];
        if (!top) return;
        SRTInstaSettingsVC *vc = [[SRTInstaSettingsVC alloc] initWithStyle:UITableViewStyleInsetGrouped];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.modalPresentationStyle = UIModalPresentationPageSheet;
        [top presentViewController:nav animated:YES completion:nil];
    } @catch (__unused NSException *e) {}
}

+ (void)syncHomeButton {
    @try {
        UIWindow *win = [self activeWindow];
        if (!win) return;

        CGFloat topInset = win.safeAreaInsets.top > 0 ? win.safeAreaInsets.top : 44.0;
        CGFloat btnSize = 32.0;
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
        BOOL shouldShow = [self isOnHomeFeedScreenInWindow:win];
        btn.hidden = !shouldShow;
        if (shouldShow) {
            [win bringSubviewToFront:btn];
        }
    } @catch (__unused NSException *e) {}
}

+ (void)syncStoryDownloadButton {
    @try {
        UIWindow *win = [self activeWindow];
        if (!win) return;

        UIButton *dlBtn = [win viewWithTag:667788];
        BOOL enabled = SRTBool(kDownloadStoryKey, YES);
        BOOL inStory = enabled && [self isOnStoryScreenInWindow:win];

        if (!dlBtn) {
            dlBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            dlBtn.tag = 667788;
            CGFloat topInset = win.safeAreaInsets.top > 0 ? win.safeAreaInsets.top : 44.0;
            dlBtn.frame = CGRectMake(16.0, topInset + 12.0, 36.0, 36.0);
            dlBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
            dlBtn.layer.cornerRadius = 18.0;
            dlBtn.tintColor = [UIColor whiteColor];
            UIImage *img = [UIImage systemImageNamed:@"arrow.down.circle"];
            if (img) {
                [dlBtn setImage:img forState:UIControlStateNormal];
            } else {
                [dlBtn setTitle:@"DL" forState:UIControlStateNormal];
            }
            [dlBtn addTarget:self action:@selector(downloadCurrentStory) forControlEvents:UIControlEventTouchUpInside];
            [win addSubview:dlBtn];
        }

        dlBtn.hidden = !inStory;
        if (inStory) {
            [win bringSubviewToFront:dlBtn];
        }
    } @catch (__unused NSException *e) {}
}

@end

%ctor {
    [SRTTweakEngine installRuntimeHooks];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SRTTweakEngine syncHomeButton];
        [SRTTweakEngine syncStoryDownloadButton];
        [NSTimer scheduledTimerWithTimeInterval:0.6 repeats:YES block:^(__unused NSTimer *t) {
            [SRTTweakEngine syncHomeButton];
            [SRTTweakEngine syncStoryDownloadButton];
        }];
    });
}
