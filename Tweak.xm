#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static const NSInteger kSRTGlassTag = 778899;

// MARK: - إضافة طبقة الزجاج السائل على أي عنصر واجهة بأمان
static void SRTApplyLiquidGlassToView(UIView *view, CGFloat cornerRadius, BOOL addBorder) {
    if (!view || [view viewWithTag:kSRTGlassTag] != nil) return;
    @try {
        UIBlurEffectStyle style = UIBlurEffectStyleSystemUltraThinMaterial;
        if (@available(iOS 13.0, *)) {
            style = UIBlurEffectStyleSystemUltraThinMaterial;
        }
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:style];
        UIVisualEffectView *glassView = [[UIVisualEffectView alloc] initWithEffect:blur];
        glassView.tag = kSRTGlassTag;
        glassView.frame = view.bounds;
        glassView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        glassView.userInteractionEnabled = NO;
        glassView.alpha = 0.92;

        if (cornerRadius > 0) {
            glassView.layer.cornerRadius = cornerRadius;
            glassView.clipsToBounds = YES;
        }

        if (addBorder) {
            glassView.layer.borderWidth = 0.6;
            glassView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.22].CGColor;
        }

        view.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.04];
        [view insertSubview:glassView atIndex:0];
    } @catch (__unused NSException *e) {}
}

// MARK: - فحص أشرطة التطبيق وتطبيق مظهر الزجاج عليها
static void SRTScanAndGlassWindow(UIWindow *win) {
    if (!win) return;
    @try {
        NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:win];
        NSUInteger visited = 0;

        while (queue.count > 0 && visited < 450) {
            UIView *current = queue.firstObject;
            [queue removeObjectAtIndex:0];
            visited++;

            if (!current || current.hidden || current.alpha < 0.05) continue;

            NSString *clsName = NSStringFromClass([current class]) ?: @"";
            NSString *lower = [clsName lowercaseString];

            // أشرطة التبويب والتنقل والهيدر
            if ([current isKindOfClass:[UITabBar class]] ||
                [current isKindOfClass:[UINavigationBar class]] ||
                [lower containsString:@"tabbar"] ||
                [lower containsString:@"navigationbar"] ||
                [lower containsString:@"headerview"] ||
                [lower containsString:@"storiesbar"]) {
                SRTApplyLiquidGlassToView(current, 0, NO);
            }
            // البطاقات والقوائم المنبثقة
            else if ([lower containsString:@"actionsheet"] ||
                     [lower containsString:@"bottomsheet"] ||
                     [lower containsString:@"popover"]) {
                SRTApplyLiquidGlassToView(current, 18.0, YES);
            }

            for (UIView *sub in current.subviews) {
                if (sub) [queue addObject:sub];
            }
        }
    } @catch (__unused NSException *e) {}
}

static UIWindow *SRTGetActiveWindow(void) {
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

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *w = SRTGetActiveWindow();
        if (w) SRTScanAndGlassWindow(w);

        [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(__unused NSTimer *timer) {
            UIWindow *active = SRTGetActiveWindow();
            if (active) SRTScanAndGlassWindow(active);
        }];
    });
}
