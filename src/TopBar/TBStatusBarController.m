#import "TBStatusBarController.h"
#import "TBHost.h"
#import "TBPreferences.h"
#import "TBPluginRegistry.h"
#import "TBStockItem.h"
#import "TBDebug.h"

#import <CoreText/CoreText.h>
#import <objc/runtime.h>

@class STUIStatusBarRegion;
@class STUIStatusBarDisplayItem;

@interface STUIStatusBar : UIView
@property (nonatomic, readonly) UIView *foregroundView;
@property (nonatomic, readonly) UIColor *foregroundColor;
- (STUIStatusBarRegion *)regionWithIdentifier:(NSString *)identifier;
@end

@interface STUIStatusBarRegion : NSObject
@property (nonatomic, readonly) UIView *contentView;
@property (nonatomic, readonly) NSOrderedSet *displayItems;
@end

@interface STUIStatusBarDisplayItem : NSObject
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) UIView *layoutItem;
@end

@interface TBStatusBarController () <UIGestureRecognizerDelegate>

@property (nonatomic, weak) STUIStatusBar *bar;
@property (nonatomic, weak) UIView *host;
@property (nonatomic, weak) UIView *regionContentView;
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<UIView *> *> *stockViews;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIView *> *pluginContainers;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UILabel *> *pluginLabels;
@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (nonatomic, assign) BOOL linkedStockGesture;
@property (nonatomic, copy) NSString *lastTapIdentifier;
@property (nonatomic, assign) NSTimeInterval lastTapTime;
@property (nonatomic, copy) NSString *lastLogSignature;
@property (nonatomic, assign) NSUInteger logCount;

@end

@implementation TBStatusBarController

- (instancetype)initWithStatusBar:(STUIStatusBar *)bar {
    self = [super init];
    if (self) {
        _bar = bar;
        _stockViews = @{};
        _pluginContainers = [NSMutableDictionary dictionary];
        _pluginLabels = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)ensureGesture {
    UIView *host = self.bar.foregroundView ?: self.bar;
    if (!host) return;
    host.userInteractionEnabled = YES;

    if (self.tapGesture && self.tapGesture.view == host) return;
    if (self.tapGesture) {
        [self.tapGesture.view removeGestureRecognizer:self.tapGesture];
    }
    self.host = host;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tap.delegate = self;
    tap.cancelsTouchesInView = YES;
    [host addGestureRecognizer:tap];
    self.tapGesture = tap;

    if (!self.linkedStockGesture) {
        @try {
            id stockGesture = [(id)self.bar valueForKey:@"_actionGestureRecognizer"];
            if ([stockGesture isKindOfClass:[UIGestureRecognizer class]] && stockGesture != tap) {
                [stockGesture requireGestureRecognizerToFail:tap];
                self.linkedStockGesture = YES;
            }
        } @catch (__unused NSException *exception) {
        }
    }
}

- (void)update {
    if (!self.bar || !self.bar.window || self.bar.window.hidden || self.bar.hidden || self.bar.alpha < 0.01) {
        [self hideCustomItems];
        return;
    }

    [self ensureGesture];

    STUIStatusBarRegion *region = nil;
    @try {
        region = [self.bar regionWithIdentifier:@"trailing"];
    } @catch (__unused NSException *exception) {
        region = nil;
    }
    UIView *contentView = nil;
    @try {
        contentView = region.contentView;
    } @catch (__unused NSException *exception) {
        contentView = nil;
    }
    if (![contentView isKindOfClass:[UIView class]]) {
        [self hideCustomItems];
        return;
    }

    self.regionContentView = contentView;
    contentView.userInteractionEnabled = YES;
    contentView.clipsToBounds = NO;

    if (self.logCount < 8) {
        TBDebugLog(@"update self=%p bar=%p window=%@", self, self.bar, NSStringFromClass(self.bar.window.class));
    }
    [self gatherStockViewsFromRegion:region];
    [self syncPluginContainers];
    [self layoutItems];
}

- (void)gatherStockViewsFromRegion:(STUIStatusBarRegion *)region {
    NSMutableDictionary<NSString *, NSMutableArray<UIView *> *> *groups = [NSMutableDictionary dictionary];
    NSOrderedSet *displayItems = region.displayItems;
    static NSUInteger gatherLogCount;
    if (gatherLogCount < 6) {
        gatherLogCount++;
        TBDebugLog(@"gather region=<%@> content=<%@> displayItems=<%@> count=%lu",
                   NSStringFromClass([region class]),
                   NSStringFromClass([region.contentView class]),
                   NSStringFromClass([displayItems class]),
                   (unsigned long)displayItems.count);
    }
    for (STUIStatusBarDisplayItem *displayItem in displayItems) {
        NSString *identifier = nil;
        UIView *view = nil;
        @try {
            identifier = displayItem.identifier;
            view = displayItem.layoutItem;
        } @catch (__unused NSException *exception) {
            continue;
        }
        if (gatherLogCount <= 6) {
            TBDebugLog(@"  displayItem %@ -> %@ %@", identifier, NSStringFromClass([view class]),
                       [view isKindOfClass:[UIView class]] ? NSStringFromCGRect(view.frame) : @"");
        }
        if (![view isKindOfClass:[UIView class]]) continue;
        if (view.frame.size.width < 0.5 || view.frame.size.height < 0.5) continue;

        NSString *stockID = [TBStockItem identifierForDisplayItemIdentifier:
            [identifier isKindOfClass:[NSString class]] ? identifier : [identifier description]];
        if (stockID.length == 0) continue;

        NSMutableArray<UIView *> *views = groups[stockID];
        if (!views) {
            views = [NSMutableArray array];
            groups[stockID] = views;
        }
        if (![views containsObject:view]) [views addObject:view];
    }

    NSMutableDictionary<NSString *, NSArray<UIView *> *> *sorted = [NSMutableDictionary dictionary];
    [groups enumerateKeysAndObjectsUsingBlock:^(NSString *identifier, NSMutableArray<UIView *> *views, __unused BOOL *stop) {
        [views sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
            if (a.frame.origin.x == b.frame.origin.x) return NSOrderedSame;
            return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
        }];
        sorted[identifier] = [views copy];
    }];
    self.stockViews = sorted;
}

- (UILabel *)referenceStockLabel {
    NSArray<UIView *> *batteryViews = self.stockViews[@"stock.battery"];
    for (UIView *view in batteryViews) {
        if ([view isKindOfClass:[UILabel class]]) return (UILabel *)view;
    }
    for (NSArray<UIView *> *views in self.stockViews.allValues) {
        for (UIView *view in views) {
            if ([view isKindOfClass:[UILabel class]]) return (UILabel *)view;
        }
    }
    return nil;
}

- (UIFont *)statusFont {
    UILabel *stockLabel = [self referenceStockLabel];
    UIFont *baseFont = stockLabel.font;
    if (!baseFont || baseFont.pointSize < 8) {
        baseFont = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    }
    UIFontDescriptor *descriptor = baseFont.fontDescriptor;
    UIFontDescriptor *tabular = [descriptor fontDescriptorByAddingAttributes:@{
        UIFontDescriptorFeatureSettingsAttribute: @[
            @{ UIFontFeatureTypeIdentifierKey: @(kNumberSpacingType),
               UIFontFeatureSelectorIdentifierKey: @(kMonospacedNumbersSelector) }
        ]
    }];
    UIFont *font = [UIFont fontWithDescriptor:tabular size:baseFont.pointSize];
    return font ?: baseFont;
}

- (UIColor *)statusColor {
    UILabel *stockLabel = [self referenceStockLabel];
    UIColor *tint = stockLabel.textColor;
    if (!tint || CGColorGetAlpha(tint.CGColor) < 0.05) tint = self.bar.foregroundColor;
    if (!tint) tint = [UIColor labelColor];
    return tint;
}

- (void)syncPluginContainers {
    UIView *host = self.host ?: (self.bar.foregroundView ?: self.bar);
    if (!host) return;

    NSMutableSet<NSString *> *liveIdentifiers = [NSMutableSet set];
    for (TBPluginRecord *record in [TBPluginRegistry sharedRegistry].records) {
        if (!record.loaded || !record.plugin) continue;
        [liveIdentifiers addObject:record.identifier];

        UIView *container = self.pluginContainers[record.identifier];
        UILabel *label = self.pluginLabels[record.identifier];
        if (!container || !label) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.backgroundColor = [UIColor clearColor];
            button.userInteractionEnabled = YES;
            button.isAccessibilityElement = YES;
            button.accessibilityTraits = UIAccessibilityTraitStaticText;
            objc_setAssociatedObject(button, "TBPluginIdentifier", record.identifier, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [button addTarget:self action:@selector(handleContainerTap:) forControlEvents:UIControlEventTouchUpInside];
            container = button;

            label = [[UILabel alloc] initWithFrame:CGRectZero];
            label.backgroundColor = [UIColor clearColor];
            label.textAlignment = NSTextAlignmentCenter;
            label.numberOfLines = 1;
            label.lineBreakMode = NSLineBreakByClipping;
            label.userInteractionEnabled = NO;
            [container addSubview:label];

            [host addSubview:container];
            self.pluginContainers[record.identifier] = container;
            self.pluginLabels[record.identifier] = label;
        }
        if (container.superview != host) [host addSubview:container];

        BOOL wantsTap = [record.plugin respondsToSelector:@selector(wantsTap)] && [record.plugin wantsTap];
        container.userInteractionEnabled = wantsTap;

        NSString *text = nil;
        @try {
            text = [record.plugin statusText];
        } @catch (__unused NSException *exception) {
            text = nil;
        }
        if (![text isKindOfClass:[NSString class]]) text = @"--";
        text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        label.text = text;
        label.font = [self statusFont];
        label.textColor = [self statusColor];
        [label sizeToFit];
        container.accessibilityLabel = record.name;
        if ([record.plugin respondsToSelector:@selector(wantsTap)] && [record.plugin wantsTap]) {
            container.accessibilityTraits = UIAccessibilityTraitButton;
            container.accessibilityHint = @"Tap to change";
        } else {
            container.accessibilityTraits = UIAccessibilityTraitStaticText;
            container.accessibilityHint = nil;
        }
    }

    for (NSString *identifier in self.pluginContainers.allKeys) {
        if ([liveIdentifiers containsObject:identifier]) continue;
        UIView *container = self.pluginContainers[identifier];
        [container removeFromSuperview];
        [self.pluginContainers removeObjectForKey:identifier];
        [self.pluginLabels removeObjectForKey:identifier];
    }
}

- (NSArray<NSString *> *)effectiveOrder {
    NSMutableDictionary<NSString *, NSNumber *> *defaults = [NSMutableDictionary dictionary];

    for (TBStockItem *item in [TBStockItem catalog]) {
        defaults[item.identifier] = @(item.defaultOrder);
    }
    for (NSString *identifier in self.stockViews.allKeys) {
        if (!defaults[identifier]) defaults[identifier] = @(2000 + defaults.count);
    }
    for (TBPluginRecord *record in [TBPluginRegistry sharedRegistry].records) {
        defaults[record.identifier] = @(record.defaultOrder);
    }

    NSArray<NSString *> *saved = [TBPreferences order];
    NSMutableArray<NSString *> *ordered = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSString *identifier in saved) {
        if (defaults[identifier] && ![seen containsObject:identifier]) {
            [ordered addObject:identifier];
            [seen addObject:identifier];
        }
    }

    NSArray<NSString *> *remaining = [defaults.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSInteger da = defaults[a].integerValue;
        NSInteger db = defaults[b].integerValue;
        if (da != db) return da < db ? NSOrderedAscending : NSOrderedDescending;
        return [a compare:b];
    }];
    for (NSString *identifier in remaining) {
        if (![seen containsObject:identifier]) [ordered addObject:identifier];
    }
    return ordered;
}

- (void)hideCustomItems {
    for (UIView *container in self.pluginContainers.allValues) container.hidden = YES;
}

- (CGFloat)widthForEntry:(NSMutableDictionary *)entry {
    NSString *type = entry[@"type"];
    if ([type isEqualToString:@"stock"]) {
        CGFloat width = 0;
        NSArray<UIView *> *views = entry[@"views"];
        for (UIView *view in views) width += view.frame.size.width;
        if (views.count > 1) width += (views.count - 1) * 2.0;
        return width;
    }

    UILabel *label = entry[@"label"];
    return MAX(20.0, ceil(label.bounds.size.width) + 8.0);
}

- (void)layoutItems {    UIView *contentView = self.regionContentView;
    UIView *host = self.host ?: (self.bar.foregroundView ?: self.bar);
    if (!contentView || !host) {
        [self hideCustomItems];
        return;
    }

    for (NSArray<UIView *> *views in self.stockViews.allValues) {
        for (UIView *view in views) view.hidden = YES;
    }
    for (UIView *container in self.pluginContainers.allValues) container.hidden = YES;

    NSArray<NSString *> *order = [self effectiveOrder];
    NSMutableArray<NSMutableDictionary *> *entries = [NSMutableArray array];

    for (NSString *identifier in order) {
        if (![TBPreferences isEnabledForIdentifier:identifier]) continue;

        NSArray<UIView *> *views = self.stockViews[identifier];
        if (views.count > 0) {
            NSMutableDictionary *entry = [@{
                @"id": identifier,
                @"type": @"stock",
                @"views": views,
            } mutableCopy];
            entry[@"width"] = @([self widthForEntry:entry]);
            if ([entry[@"width"] doubleValue] > 0.5) [entries addObject:entry];
            continue;
        }

        UIView *container = self.pluginContainers[identifier];
        UILabel *label = self.pluginLabels[identifier];
        if (!container || !label) continue;

        NSMutableDictionary *entry = [@{
            @"id": identifier,
            @"type": @"plugin",
            @"container": container,
            @"label": label,
        } mutableCopy];
        entry[@"width"] = @([self widthForEntry:entry]);
        [entries addObject:entry];
    }

    if (entries.count == 0) {
        TBDebugLog(@"no enabled entries; stock groups=%@", self.stockViews.allKeys);
        return;
    }

    CGRect contentFrame = [contentView convertRect:contentView.bounds toView:host];
    CGFloat contentWidth = contentFrame.size.width;
    CGFloat contentHeight = contentView.bounds.size.height;
    CGFloat rightMargin = 2.0;
    CGFloat spacing = 6.0;

    NSArray<NSNumber *> *widths = [entries valueForKey:@"width"];
    CGFloat total = 0;
    for (NSNumber *width in widths) total += width.doubleValue;
    total += spacing * (entries.count - 1);

    if (total > contentWidth - 4.0) {
        spacing = 2.0;
        total = 0;
        for (NSNumber *width in widths) total += width.doubleValue;
        total += spacing * (entries.count - 1);
    }

    if (total > contentWidth - 4.0) {
        UIFont *smallFont = [[self statusFont] fontWithSize:10.0];
        for (NSMutableDictionary *entry in entries) {
            if (![entry[@"type"] isEqualToString:@"plugin"]) continue;
            UILabel *label = entry[@"label"];
            label.font = smallFont;
            [label sizeToFit];
            entry[@"width"] = @([self widthForEntry:entry]);
        }
        total = 0;
        for (NSMutableDictionary *entry in entries) total += [entry[@"width"] doubleValue];
        total += spacing * (entries.count - 1);
    }

    while (total > contentWidth - 4.0 && entries.count > 1) {
        [entries removeObjectAtIndex:0];
        total = 0;
        for (NSMutableDictionary *entry in entries) total += [entry[@"width"] doubleValue];
        total += spacing * (entries.count - 1);
    }

    CGFloat x = contentWidth - total - rightMargin;
    if (x < 1.0) x = 1.0;

#ifdef DEBUG
    NSMutableArray<NSString *> *signatureParts = [NSMutableArray array];
#endif
    for (NSMutableDictionary *entry in entries) {
        NSString *type = entry[@"type"];
        CGFloat width = [entry[@"width"] doubleValue];
        if ([type isEqualToString:@"stock"]) {
            NSArray<UIView *> *views = entry[@"views"];
            CGFloat innerX = x;
            for (NSUInteger i = 0; i < views.count; i++) {
                UIView *view = views[i];
                CGRect frame = view.frame;
                view.hidden = NO;
                view.frame = CGRectMake(innerX, frame.origin.y, frame.size.width, frame.size.height);
                innerX += frame.size.width + 2.0;
            }
        } else {
            UIView *container = entry[@"container"];
            UILabel *label = entry[@"label"];
            container.hidden = NO;
            container.frame = CGRectMake(contentFrame.origin.x + x,
                                         contentFrame.origin.y + (contentHeight - 20.0) / 2.0,
                                         width, 20.0);
            label.frame = container.bounds;
            [host bringSubviewToFront:container];
        }
#ifdef DEBUG
        [signatureParts addObject:[NSString stringWithFormat:@"%@@%.0f", entry[@"id"], width]];
#endif
        x += width + spacing;
    }

#ifdef DEBUG
    NSString *signature = [signatureParts componentsJoinedByString:@","];
    if (self.logCount < 8 || ![signature isEqualToString:self.lastLogSignature]) {
        self.logCount++;
        self.lastLogSignature = signature;
        NSMutableArray<NSString *> *groups = [NSMutableArray array];
        [self.stockViews enumerateKeysAndObjectsUsingBlock:^(NSString *identifier, NSArray<UIView *> *views, __unused BOOL *stop) {
            NSMutableArray *frames = [NSMutableArray array];
            for (UIView *view in views) {
                [frames addObject:[NSString stringWithFormat:@"%@ %.0fx%.0f", NSStringFromClass(view.class),
                                   view.frame.size.width, view.frame.size.height]];
            }
            [groups addObject:[NSString stringWithFormat:@"%@[%@]", identifier, [frames componentsJoinedByString:@"; "]]];
        }];
        TBDebugLog(@"order self=%p bar=%p entries=%@ width=%.0f startX=%.1f stock=%@",
                   self, self.bar, signature, contentWidth, contentWidth - total - rightMargin,
                   [groups componentsJoinedByString:@" "]);
        for (NSString *identifier in self.pluginContainers) {
            UIView *container = self.pluginContainers[identifier];
            UILabel *label = self.pluginLabels[identifier];
            TBDebugLog(@"  plugin %@ frame=%@ text=%@ hidden=%d",
                       identifier, NSStringFromCGRect(container.frame), label.text, container.hidden);
        }
    }
#endif
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (gestureRecognizer != self.tapGesture) return YES;
    CGPoint point = [touch locationInView:self.host];
    for (NSString *identifier in self.pluginContainers) {
        UIView *container = self.pluginContainers[identifier];
        if (container.hidden) continue;
        if (!CGRectContainsPoint(container.frame, point)) continue;

        id<TBStatusPlugin> plugin = [[TBPluginRegistry sharedRegistry] pluginForIdentifier:identifier];
        if ([plugin respondsToSelector:@selector(wantsTap)] && [plugin wantsTap]) return YES;
        return NO;
    }
    return NO;
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded) return;
    CGPoint point = [gesture locationInView:self.host];
    for (NSString *identifier in self.pluginContainers) {
        UIView *container = self.pluginContainers[identifier];
        if (container.hidden || !CGRectContainsPoint(container.frame, point)) continue;
        [self performPluginTap:identifier];
        return;
    }
}

- (void)handleContainerTap:(UIButton *)sender {
    NSString *identifier = objc_getAssociatedObject(sender, "TBPluginIdentifier");
    if (identifier.length > 0) [self performPluginTap:identifier];
}

- (void)performPluginTap:(NSString *)identifier {
    UIView *container = self.pluginContainers[identifier];
    if (!container || container.hidden) return;

    id<TBStatusPlugin> plugin = [[TBPluginRegistry sharedRegistry] pluginForIdentifier:identifier];
    if (!plugin) return;
    if ([plugin respondsToSelector:@selector(wantsTap)] && ![plugin wantsTap]) return;

    // The host tap gesture and the button fallback can both see the same touch.
    // Ignore the duplicate so one tap toggles the plugin exactly once.
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if ([identifier isEqualToString:self.lastTapIdentifier] && now - self.lastTapTime < 0.35) return;
    self.lastTapIdentifier = identifier;
    self.lastTapTime = now;

    if ([plugin respondsToSelector:@selector(handleTap)]) {
        TBDebugLog(@"tap %@", identifier);
        @try {
            [plugin handleTap];
        } @catch (NSException *exception) {
            TBDebugLog(@"plugin tap threw: %@", exception.reason);
        }
        [self syncPluginContainers];
        [self layoutItems];
    }
}

@end
