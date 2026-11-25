#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static const NSInteger kSRTGlassViewTag = 889900;

// MARK: - إجبار الطبقات الداخلية المعتمة على الشفافية ليظهر الزجاج
static void SRTClearOpaqueSublayers(UIView *view, int depth) {
    if (!view || depth > 3) return;
    for (UIView *sub in view.subviews) {
        if (sub.tag == kSRTGlassViewTag) continue;
        // استثناء الأيقونات والصور والنصوص
        if ([sub isKindOfClass:[UIImageView class]] ||
            [sub isKindOfClass:[UILabel class]] ||
            [sub isKindOfClass:[UIControl class]]) {
            continue;
        }
        // إذا كانت طبقة خلفية بعرض الشريط كامل، نجعلها شفافة
        if (CGRectGetWidth(sub.bounds) > CGRectGetWidth(view.bounds) * 0.75 &&
            CGRectGetHeight(sub.bounds) > CGRectGetHeight(view.bounds) * 0.65) {
            sub.backgroundColor = [UIColor clearColor];
            sub.opaque = NO;
            sub.layer.backgroundColor = [UIColor clearColor].CGColor;
        }
        SRTClearOpaqueSublayers(sub, depth + 1);
    }
}

// MARK: - تطبيق تأثير Liquid Glass حقيقي على الشريط
static void SRTApplyLiquidGlass(UIView *bar, BOOL floatingPill) {
    if (!bar) return;
    @try {
        bar.backgroundColor = [UIColor clearColor];
        bar.opaque = NO;
        bar.layer.backgroundColor = [UIColor clearColor].CGColor;
        SRTClearOpaqueSublayers(bar, 0);

        UIVisualEffectView *glass = [bar viewWithTag:kSRTGlassViewTag];
        if (!glass) {
            UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
            glass = [[UIVisualEffectView alloc] initWithEffect:blur];
            glass.tag = kSRTGlassViewTag;
            glass.userInteractionEnabled = NO;

            // لمعة زجاجية خفيفة في الأعلى (Specular highlight)
            CAGradientLayer *shine = [CAGradientLayer layer];
            shine.name = @"srt_glass_shine";
            shine.colors = @[
                (id)[[UIColor whiteColor] colorWithAlphaComponent:0.18].CGColor,
                (id)[[UIColor whiteColor] colorWithAlphaComponent:0.03].CGColor,
                (id)[[UIColor clearColor] CGColor]
            ];
            shine.locations = @[@0.0, @0.35, @1.0];
            [glass.contentView.layer addSublayer:shine];

            glass.layer.borderWidth = 0.65;
            glass.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.28].CGColor;

            [bar insertSubview:glass atIndex:0];
        }

        if (floatingPill) {
            CGRect insetRect = CGRectInset(bar.bounds, 10.0, 4.0);
            if (CGRectGetWidth(insetRect) > 40 && CGRectGetHeight(insetRect) > 24) {
                glass.frame = insetRect;
                glass.layer.cornerRadius = CGRectGetHeight(insetRect) / 2.0;
                glass.clipsToBounds = YES;
            } else {
                glass.frame = bar.bounds;
            }
        } else {
            glass.frame = bar.bounds;
            glass.layer.cornerRadius = 0;
        }

        for (CALayer *l in glass.contentView.layer.sublayers) {
            if ([l.name isEqualToString:@"srt_glass_shine"]) {
                l.frame = glass.bounds;
            }
        }
    } @catch (__unused NSException *e) {}
}

// MARK: - البحث عن أشرطة إنستغرام وتطبيق الزجاج السائل
static void SRTUpdateGlassInWindow(UIWindow *win) {
    if (!win) return;
    @try {
        CGFloat screenW = CGRectGetWidth(win.bounds);
        CGFloat screenH = CGRectGetHeight(win.bounds);

        NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:win];
        NSUInteger count = 0;

        while (queue.count > 0 && count < 500) {
            UIView *v = queue.firstObject;
            [queue removeObjectAtIndex:0];
            count++;

            if (!v || v.hidden || v.alpha < 0.05) continue;

            NSString *cls = [NSStringFromClass([v class]) ?: @"" lowercaseString];
            CGRect frameInWin = [v convertRect:v.bounds toView:win];

            // 1. شريط التبويب السفلي (Tab Bar) -> شكل كبسولة زجاجية عائمة (Liquid Glass Pill)
            BOOL isBottomBar = ([v isKindOfClass:[UITabBar class]] || [cls containsString:@"tabbar"]) &&
                               CGRectGetWidth(frameInWin) > screenW * 0.8 &&
                               CGRectGetHeight(frameInWin) >= 40 &&
                               CGRectGetHeight(frameInWin) <= 110 &&
                               CGRectGetMaxY(frameInWin) > screenH - 120;

            // 2. الهيدر العلوي (Navigation / Top Header)
            BOOL isTopHeader = ([v isKindOfClass:[UINavigationBar class]] ||
                                [cls containsString:@"navigationbar"] ||
                                [cls containsString:@"headerview"]) &&
                               CGRectGetWidth(frameInWin) > screenW * 0.8 &&
                               CGRectGetHeight(frameInWin) >= 36 &&
                               CGRectGetHeight(frameInWin) <= 120 &&
                               CGRectGetMinY(frameInWin) < 120;

            if (isBottomBar) {
                SRTApplyLiquidGlass(v, YES);
            } else if (isTopHeader) {
                SRTApplyLiquidGlass(v, NO);
            }

            for (UIView *sub in v.subviews) {
                if (sub && sub.tag != kSRTGlassViewTag) {
                    [queue addObject:sub];
                }
            }
        }
    } @catch (__unused NSException *e) {}
}

static UIWindow *SRTActiveWindow(void) {
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *w = SRTActiveWindow();
        if (w) SRTUpdateGlassInWindow(w);

        [NSTimer scheduledTimerWithTimeInterval:0.7 repeats:YES block:^(__unused NSTimer *t) {
            UIWindow *active = SRTActiveWindow();
            if (active) SRTUpdateGlassInWindow(active);
        }];
    });
}
