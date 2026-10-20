#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#import <objc/runtime.h>

#import "src/RateBarReader.h"

@interface STUIStatusBar : UIView
@property (nonatomic, readonly) UIView *foregroundView;
@property (nonatomic, readonly) UIColor *foregroundColor;
@end

static const void *kRateLabelKey = &kRateLabelKey;
static const NSTimeInterval kRefreshInterval = 2.0;

static NSHashTable<STUIStatusBar *> *BRStatusBars(void) {
    static NSHashTable *bars;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        bars = [NSHashTable weakObjectsHashTable];
    });
    return bars;
}

static BRRateSample BRCachedSample(void) {
    static BRRateSample sample;
    static NSTimeInterval sampledAt;
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (sampledAt == 0 || now - sampledAt >= 0.75) {
        sample = BRReadRateSample();
        sampledAt = now;
    }
    return sample;
}

static BOOL BRVisible(UIView *view) {
    return view && !view.hidden && view.alpha > 0.02 && view.window != nil;
}

static UIView *BRFindBatteryView(UIView *root, UIView *exclude) {
    UIView *fallback = nil;
    for (UIView *subview in root.subviews) {
        if (subview == exclude) continue;
        NSString *className = NSStringFromClass(subview.class);
        if ([className containsString:@"BatteryItemView"] && BRVisible(subview)) {
            return subview;
        }
        if ([className containsString:@"BatteryView"] && BRVisible(subview)) {
            if (!fallback) fallback = subview;
        }
        UIView *found = BRFindBatteryView(subview, exclude);
        if (found) {
            if ([NSStringFromClass(found.class) containsString:@"BatteryItemView"]) return found;
            if (!fallback) fallback = found;
        }
    }
    return fallback;
}

static BOOL BRLooksLikePercentLabel(UILabel *label) {
    if (![label isKindOfClass:[UILabel class]] || !BRVisible(label)) return NO;
    NSString *text = label.text;
    if (text.length == 0) return NO;
    return [text containsString:@"%"];
}

static UILabel *BRFindPercentLabel(UIView *root, UIView *host, CGRect batteryRect, UIView *exclude) {
    UILabel *best = nil;
    CGFloat bestScore = CGFLOAT_MAX;

    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:root];
    while (stack.count > 0) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        if (view == exclude) continue;

        if ([view isKindOfClass:[UILabel class]] && BRLooksLikePercentLabel((UILabel *)view)) {
            CGRect rect = [view convertRect:view.bounds toView:host];
            CGFloat dy = fabs(CGRectGetMidY(rect) - CGRectGetMidY(batteryRect));
            CGFloat dx = CGRectGetMaxX(rect) - CGRectGetMinX(batteryRect);
            if (dy < 24 && dx > -16 && dx < 140) {
                CGFloat score = dy * 2 + fabs(dx);
                if (score < bestScore) {
                    bestScore = score;
                    best = (UILabel *)view;
                }
            }
        }

        for (UIView *subview in view.subviews) {
            [stack addObject:subview];
        }
    }
    return best;
}

#ifdef DEBUG
static void BRDebugLog(NSString *line) {
    static NSMutableArray<NSString *> *lines;
    static NSUInteger count;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        lines = [NSMutableArray array];
    });
    if (count >= 120) return;
    count++;

    NSString *stamp = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                    dateStyle:NSDateFormatterNoStyle
                                                    timeStyle:NSDateFormatterMediumStyle];
    [lines addObject:[NSString stringWithFormat:@"%@ %@", stamp, line]];
    NSArray *snapshot = [lines copy];

    // SpringBoard's own domain is always writable by SpringBoard.
    CFPreferencesSetAppValue(CFSTR("RateBarDebugLines"),
                             (__bridge CFPropertyListRef)snapshot,
                             CFSTR("com.apple.springboard"));
    CFPreferencesAppSynchronize(CFSTR("com.apple.springboard"));

    NSString *text = [snapshot componentsJoinedByString:@"\n"];
    [text writeToFile:@"/var/jb/tmp/ratebar-debug.txt"
           atomically:YES
             encoding:NSUTF8StringEncoding
                error:NULL];
}

static NSString *BRDescribeView(UIView *view, UIView *host) {
    CGRect rect = [view convertRect:view.bounds toView:host];
    NSString *extra = @"";
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        extra = [NSString stringWithFormat:@" text=%@", label.text ?: @"(nil)"];
    } else if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        extra = [NSString stringWithFormat:@" image=%@ aid=%@ aLabel=%@",
                 imageView.image.description ?: @"(nil)",
                 imageView.accessibilityIdentifier ?: @"(nil)",
                 imageView.accessibilityLabel ?: @"(nil)"];
    }
    return [NSString stringWithFormat:@"%@ frame=(%.1f,%.1f %.1fx%.1f) hidden=%d alpha=%.2f%@",
            NSStringFromClass(view.class),
            rect.origin.x, rect.origin.y, rect.size.width, rect.size.height,
            view.hidden, view.alpha, extra];
}

static void BRDumpRightCluster(UIView *view, UIView *host, NSMutableArray<NSString *> *lines, NSUInteger depth) {
    if (!view || !BRVisible(view) || depth > 12) return;
    CGRect rect = [view convertRect:view.bounds toView:host];
    if (CGRectGetMaxX(rect) >= 760 && rect.size.width > 0 && rect.size.height > 0) {
        [lines addObject:[NSString stringWithFormat:@"%@%@", [@"" stringByPaddingToLength:depth withString:@"  " startingAtIndex:0],
                          BRDescribeView(view, host)]];
    }
    for (UIView *subview in view.subviews) {
        BRDumpRightCluster(subview, host, lines, depth + 1);
    }
}
#endif


static const void *kOriginalXKey = &kOriginalXKey;

static void BRMakeRoomForRateLabel(UILabel *label, UIView *anchorView, UIView *batteryView) {
    if ([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad) return;
    if (!label || !anchorView) return;

    UIView *container = anchorView.superview;
    if (!container) return;

    static CGSize lastHostSize;
    static NSUInteger lastPrefixCount;
    UIView *host = container.superview ?: container;
    CGSize hostSize = host.bounds.size;
    CGFloat anchorMinX = CGRectGetMinX(anchorView.frame);

    NSMutableArray<UIView *> *prefixViews = [NSMutableArray array];
    for (UIView *sibling in container.subviews) {
        if (sibling == anchorView || sibling == batteryView || sibling == label) continue;
        if (!BRVisible(sibling)) continue;
        CGRect rect = sibling.frame;
        if (CGRectGetMaxX(rect) <= anchorMinX + 0.5) {
            [prefixViews addObject:sibling];
        }
    }

    if (!CGSizeEqualToSize(lastHostSize, hostSize) || prefixViews.count != lastPrefixCount) {
        for (UIView *sibling in container.subviews) {
            objc_setAssociatedObject(sibling, kOriginalXKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        lastHostSize = hostSize;
        lastPrefixCount = prefixViews.count;
    }

    CGRect labelInContainer = [label convertRect:label.bounds toView:container];
    CGFloat rightmostPrefixMaxX = -CGFLOAT_MAX;
    for (UIView *sibling in prefixViews) {
        NSNumber *original = objc_getAssociatedObject(sibling, kOriginalXKey);
        CGFloat x = original ? original.doubleValue : CGRectGetMinX(sibling.frame);
        rightmostPrefixMaxX = MAX(rightmostPrefixMaxX, x + CGRectGetWidth(sibling.frame));
    }

    CGFloat shift = 0;
    if (rightmostPrefixMaxX > CGRectGetMinX(labelInContainer)) {
        shift = rightmostPrefixMaxX - CGRectGetMinX(labelInContainer) + 3;
    }
    if (shift < 0) shift = 0;

    for (UIView *sibling in prefixViews) {
        CGRect rect = sibling.frame;
        NSNumber *original = objc_getAssociatedObject(sibling, kOriginalXKey);
        if (!original) {
            original = @(rect.origin.x);
            objc_setAssociatedObject(sibling, kOriginalXKey, original, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        CGFloat targetX = original.doubleValue - shift;
        if (fabs(rect.origin.x - targetX) > 0.1) {
            sibling.frame = CGRectMake(targetX, rect.origin.y, rect.size.width, rect.size.height);
        }
    }
}

static void BRRestoreShiftedIcons(UIView *anchorView) {
    UIView *container = anchorView.superview;
    if (!container) return;
    for (UIView *sibling in container.subviews) {
        NSNumber *original = objc_getAssociatedObject(sibling, kOriginalXKey);
        if (!original) continue;
        CGRect rect = sibling.frame;
        if (fabs(rect.origin.x - original.doubleValue) > 0.1) {
            sibling.frame = CGRectMake(original.doubleValue, rect.origin.y, rect.size.width, rect.size.height);
        }
        objc_setAssociatedObject(sibling, kOriginalXKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void BRUpdateStatusBar(STUIStatusBar *bar) {
    if (![bar isKindOfClass:[UIView class]]) return;
    if ([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad) return;

    UIView *host = bar.foregroundView ?: bar;
    if (!host) return;

    UILabel *label = objc_getAssociatedObject(bar, kRateLabelKey);
    if (!bar.window) {
        label.hidden = YES;
        return;
    }

    UIView *batteryView = BRFindBatteryView(host, label);
    if (!batteryView) {
        label.hidden = YES;
        return;
    }

    CGRect batteryRect = [batteryView convertRect:batteryView.bounds toView:host];
    if (batteryRect.size.width < 1 || batteryRect.size.height < 1) {
        label.hidden = YES;
        return;
    }

    UILabel *percentLabel = BRFindPercentLabel(host, host, batteryRect, label);
    CGRect percentRect = percentLabel ? [percentLabel convertRect:percentLabel.bounds toView:host] : CGRectNull;
    UIView *anchorView = percentLabel ?: batteryView;

    if (!label) {
        label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.userInteractionEnabled = NO;
        label.backgroundColor = [UIColor clearColor];
        label.numberOfLines = 1;
        label.textAlignment = NSTextAlignmentRight;
        label.adjustsFontSizeToFitWidth = NO;
        label.opaque = NO;
        label.text = @"0";
        objc_setAssociatedObject(bar, kRateLabelKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (label.superview != host) {
        [host addSubview:label];
    }

    UIFont *baseFont = percentLabel.font;
    CGFloat pointSize = baseFont ? baseFont.pointSize : 13.0;
    if (pointSize < 9) pointSize = 9;
    if (pointSize > 18) pointSize = 18;
    label.font = [UIFont monospacedDigitSystemFontOfSize:pointSize weight:UIFontWeightSemibold];

    UIColor *tint = percentLabel.textColor;
    if (!tint || CGColorGetAlpha(tint.CGColor) < 0.05) tint = bar.foregroundColor;
    if (!tint) tint = [UIColor labelColor];
    label.textColor = tint;

    BRRateSample sample = BRCachedSample();
    label.text = sample.valid ? BRFormatRate(sample.watts) : @"--";
    [label sizeToFit];
    label.frame = CGRectMake(label.frame.origin.x,
                             label.frame.origin.y,
                             ceil(label.frame.size.width),
                             ceil(label.font.lineHeight));

    CGFloat anchorX = CGRectGetMinX(batteryRect);
    if (!CGRectIsNull(percentRect)) anchorX = MIN(anchorX, CGRectGetMinX(percentRect));

    CGFloat gap = 3.0;
    CGFloat x = anchorX - gap - label.frame.size.width;
    CGFloat y = CGRectGetMidY(CGRectIsNull(percentRect) ? batteryRect : percentRect) - label.frame.size.height / 2.0;
    CGFloat scale = host.window.screen.scale > 0 ? host.window.screen.scale : 2.0;
    x = round(x * scale) / scale;
    y = round(y * scale) / scale;

    BOOL offscreen = x < 2 || y < 0 || CGRectGetMaxY(label.frame) > CGRectGetHeight(host.bounds) + 2;
    label.hidden = offscreen;
    if (!offscreen) {
        label.frame = CGRectMake(x, y, label.frame.size.width, label.frame.size.height);
        BRMakeRoomForRateLabel(label, anchorView, batteryView);
        [host bringSubviewToFront:label];
    } else {
        BRRestoreShiftedIcons(anchorView);
    }

#ifdef DEBUG
    static NSUInteger layoutLogCount;
    if (layoutLogCount < 12) {
        layoutLogCount++;
        BRDebugLog([NSString stringWithFormat:@"bar=%@ host=%@ battery=%@ percent=%@ label=%@ shown=%d text=%@",
                    NSStringFromClass(bar.class),
                    NSStringFromClass(host.class),
                    BRDescribeView(batteryView, host),
                    percentLabel ? BRDescribeView(percentLabel, host) : @"(none)",
                    BRDescribeView(label, host),
                    !label.hidden,
                    label.text ?: @"(nil)"]);
        if (percentLabel) {
            static BOOL dumpedCluster;
            if (!dumpedCluster) {
                dumpedCluster = YES;
                NSMutableArray<NSString *> *lines = [NSMutableArray array];
                BRDumpRightCluster(host, host, lines, 0);
                BRDebugLog([lines componentsJoinedByString:@"\n"]);
            }
        }
    }
#endif
}

static void BRRegisterStatusBar(STUIStatusBar *bar) {
    if (!bar) return;
    [BRStatusBars() addObject:bar];
    BRUpdateStatusBar(bar);
}

static void BRRefreshAll(void) {
    for (STUIStatusBar *bar in BRStatusBars().allObjects) {
        BRUpdateStatusBar(bar);
    }
}

%hook STUIStatusBar

- (void)layoutSubviews {
    %orig;
    BRRegisterStatusBar(self);
}

- (void)didMoveToWindow {
    %orig;
    BRRegisterStatusBar(self);
}

- (void)setForegroundColor:(UIColor *)color {
    %orig;
    BRUpdateStatusBar(self);
}

%end

%ctor {
    @autoreleasepool {
        if (![[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;

#ifdef DEBUG
        BRDebugLog(@"ctor");
#endif

        [NSTimer scheduledTimerWithTimeInterval:kRefreshInterval
                                         repeats:YES
                                           block:^(__unused NSTimer *timer) {
            BRRefreshAll();
        }];

        NSArray<NSString *> *notifications = @[
            @"com.apple.system.powersources.source",
            @"com.apple.system.powersources.percent",
            @"com.apple.system.powersources.timeremaining"
        ];
        for (NSString *name in notifications) {
            int token = NOTIFY_TOKEN_INVALID;
            notify_register_dispatch(name.UTF8String, &token, dispatch_get_main_queue(), ^(__unused int t) {
                BRRefreshAll();
            });
        }
    }
}
