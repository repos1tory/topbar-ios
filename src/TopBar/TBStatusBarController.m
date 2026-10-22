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
@property (nonatomic, weak) UIView *leftContentView;
@property (nonatomic, weak) UIView *rightContentView;
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<UIView *> *> *leftStockViews;
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<UIView *> *> *rightStockViews;
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
        _leftStockViews = @{};
        _rightStockViews = @{};
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
    if (self.tapGesture) [self.tapGesture.view removeGestureRecognizer:self.tapGesture];
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

- (STUIStatusBarRegion *)regionNamed:(NSString *)name {
    @try {
        return [self.bar regionWithIdentifier:name];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

- (UIView *)contentViewForRegion:(STUIStatusBarRegion *)region {
    @try {
        UIView *view = region.contentView;
        return [view isKindOfClass:[UIView class]] ? view : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

- (void)update {
    if (!self.bar || !self.bar.window || self.bar.window.hidden || self.bar.hidden || self.bar.alpha < 0.01) {
        [self hideCustomItems];
        return;
    }

    [self ensureGesture];

    STUIStatusBarRegion *rightRegion = [self regionNamed:@"trailing"];
    STUIStatusBarRegion *leftRegion = [self regionNamed:@"leading"];
    UIView *rightContent = [self contentViewForRegion:rightRegion];
    UIView *leftContent = [self contentViewForRegion:leftRegion];

    if (!leftRegion || leftRegion.displayItems.count == 0) {
        STUIStatusBarRegion *expanded = [self regionNamed:@"expandedLeading"];
        if (expanded.displayItems.count > 0) {
            leftRegion = expanded;
            leftContent = [self contentViewForRegion:expanded];
        }
    }
    if (!rightContent && !leftContent) {
        [self hideCustomItems];
        return;
    }

    self.leftContentView = leftContent;
    self.rightContentView = rightContent;
    leftContent.userInteractionEnabled = YES;
    leftContent.clipsToBounds = NO;
    rightContent.userInteractionEnabled = YES;
    rightContent.clipsToBounds = NO;

    self.leftStockViews = [self gatherStockViewsFromRegion:leftRegion side:@"left"];
    self.rightStockViews = [self gatherStockViewsFromRegion:rightRegion side:@"right"];

    [self syncPluginContainers];

    for (NSArray<UIView *> *views in self.leftStockViews.allValues) {
        for (UIView *view in views) view.hidden = YES;
    }
    for (NSArray<UIView *> *views in self.rightStockViews.allValues) {
        for (UIView *view in views) view.hidden = YES;
    }
    for (UIView *container in self.pluginContainers.allValues) container.hidden = YES;

    if (rightContent) [self layoutSide:@"right" contentView:rightContent];
    if (leftContent) [self layoutSide:@"left" contentView:leftContent];
}

- (NSDictionary<NSString *, NSArray<UIView *> *> *)gatherStockViewsFromRegion:(STUIStatusBarRegion *)region side:(NSString *)side {
    if (!region) return @{};
    NSMutableDictionary<NSString *, NSMutableArray<UIView *> *> *groups = [NSMutableDictionary dictionary];
    NSOrderedSet *displayItems = region.displayItems;
    for (STUIStatusBarDisplayItem *displayItem in displayItems) {
        NSString *identifier = nil;
        UIView *view = nil;
        @try {
            identifier = displayItem.identifier;
            view = displayItem.layoutItem;
        } @catch (__unused NSException *exception) {
            continue;
        }
        if (![view isKindOfClass:[UIView class]]) continue;
        if (view.frame.size.width < 0.5 || view.frame.size.height < 0.5) continue;

        NSString *identifierString = [identifier isKindOfClass:[NSString class]] ? identifier : [identifier description];
        NSString *stockID = [TBStockItem identifierForDisplayItemIdentifier:identifierString];
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
#ifdef DEBUG
    TBDebugLog(@"gather side=%@ region=%@ count=%lu stock=%@", side, NSStringFromClass(region.class),
               (unsigned long)displayItems.count, sorted.allKeys);
#endif
    return sorted;
}

- (NSDictionary<NSString *, NSArray<UIView *> *> *)stockViewsForSide:(NSString *)side {
    return [side isEqualToString:@"left"] ? self.leftStockViews : self.rightStockViews;
}

- (UIView *)contentViewForSide:(NSString *)side {
    return [side isEqualToString:@"left"] ? self.leftContentView : self.rightContentView;
}

- (UILabel *)referenceStockLabel {
    NSArray<UIView *> *batteryViews = self.rightStockViews[@"stock.battery"];
    for (UIView *view in batteryViews) {
        if ([view isKindOfClass:[UILabel class]]) return (UILabel *)view;
    }
    for (NSDictionary<NSString *, NSArray<UIView *> *> *groups in @[self.leftStockViews ?: @{}, self.rightStockViews ?: @{}]) {
        for (NSArray<UIView *> *views in groups.allValues) {
            for (UIView *view in views) {
                if ([view isKindOfClass:[UILabel class]]) return (UILabel *)view;
            }
        }
    }
    return nil;
}

- (UIFont *)statusFont {
    UILabel *stockLabel = [self referenceStockLabel];
    UIFont *baseFont = stockLabel.font;
    if (!baseFont || baseFont.pointSize < 8) baseFont = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
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

- (NSString *)sideForPluginRecord:(TBPluginRecord *)record {
    NSString *override = [TBPreferences sides][record.identifier];
    if ([override isEqualToString:@"left"] || [override isEqualToString:@"right"]) return override;
    if ([record.side isEqualToString:@"left"] || [record.side isEqualToString:@"right"]) return record.side;
    return @"right";
}

- (NSString *)sideForIdentifier:(NSString *)identifier {
    NSString *stockSide = [TBStockItem sideForIdentifier:identifier];
    if (stockSide) {
        if ([self.leftStockViews[identifier] count] > 0) return @"left";
        if ([self.rightStockViews[identifier] count] > 0) return @"right";
        return stockSide;
    }
    TBPluginRecord *record = nil;
    for (TBPluginRecord *candidate in [TBPluginRegistry sharedRegistry].records) {
        if ([candidate.identifier isEqualToString:identifier]) {
            record = candidate;
            break;
        }
    }
    return record ? [self sideForPluginRecord:record] : @"right";
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
        if (wantsTap) {
            container.accessibilityTraits = UIAccessibilityTraitButton;
            container.accessibilityHint = @"Tap to change";
        } else {
            container.accessibilityTraits = UIAccessibilityTraitStaticText;
            container.accessibilityHint = nil;
        }
    }

    for (NSString *identifier in self.pluginContainers.allKeys) {
        if ([liveIdentifiers containsObject:identifier]) continue;
        [self.pluginContainers[identifier] removeFromSuperview];
        [self.pluginContainers removeObjectForKey:identifier];
        [self.pluginLabels removeObjectForKey:identifier];
    }
}

- (NSArray<NSString *> *)effectiveOrderForSide:(NSString *)side {
    NSMutableDictionary<NSString *, NSNumber *> *defaults = [NSMutableDictionary dictionary];

    for (TBStockItem *item in [TBStockItem catalog]) {
        NSString *itemSide = item.side ?: @"right";
        if ([itemSide isEqualToString:side]) defaults[item.identifier] = @(item.defaultOrder);
    }
    for (NSString *identifier in [self stockViewsForSide:side].allKeys) {
        if (!defaults[identifier]) defaults[identifier] = @(2000 + defaults.count);
    }
    for (TBPluginRecord *record in [TBPluginRegistry sharedRegistry].records) {
        if ([[self sideForPluginRecord:record] isEqualToString:side]) {
            defaults[record.identifier] = @(record.defaultOrder);
        }
    }

    NSArray<NSString *> *saved = [side isEqualToString:@"left"] ? [TBPreferences leftOrder] : [TBPreferences rightOrder];
    if (!saved) {
        // Migrate the old single list on first run.
        NSArray<NSString *> *legacy = [TBPreferences order];
        NSMutableArray<NSString *> *filtered = [NSMutableArray array];
        for (NSString *identifier in legacy) {
            if ([[self sideForIdentifier:identifier] isEqualToString:side]) [filtered addObject:identifier];
        }
        saved = filtered;
    }

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
    if ([entry[@"type"] isEqualToString:@"stock"]) {
        CGFloat width = 0;
        NSArray<UIView *> *views = entry[@"views"];
        for (UIView *view in views) width += view.frame.size.width;
        if (views.count > 1) width += (views.count - 1) * 2.0;
        return width;
    }
    UILabel *label = entry[@"label"];
    return MAX(20.0, ceil(label.bounds.size.width) + 8.0);
}

- (void)layoutSide:(NSString *)side contentView:(UIView *)contentView {
    UIView *host = self.host ?: (self.bar.foregroundView ?: self.bar);
    if (!contentView || !host) return;

    NSDictionary<NSString *, NSArray<UIView *> *> *stockViews = [self stockViewsForSide:side];
    NSMutableArray<NSMutableDictionary *> *entries = [NSMutableArray array];

    for (NSString *identifier in [self effectiveOrderForSide:side]) {
        if (![TBPreferences isEnabledForIdentifier:identifier]) continue;

        NSArray<UIView *> *views = stockViews[identifier];
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
        if (![[self sideForIdentifier:identifier] isEqualToString:side]) continue;

        NSMutableDictionary *entry = [@{
            @"id": identifier,
            @"type": @"plugin",
            @"container": container,
            @"label": label,
        } mutableCopy];
        entry[@"width"] = @([self widthForEntry:entry]);
        [entries addObject:entry];
    }

    if (entries.count == 0) return;

    CGRect contentFrame = [contentView convertRect:contentView.bounds toView:host];
    CGFloat contentWidth = contentFrame.size.width;
    CGFloat contentHeight = contentView.bounds.size.height;
    CGFloat spacing = 6.0;
    CGFloat startMargin = [side isEqualToString:@"left"] ? 6.0 : 2.0;

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
        if ([side isEqualToString:@"left"]) {
            [entries removeLastObject];
        } else {
            [entries removeObjectAtIndex:0];
        }
        total = 0;
        for (NSMutableDictionary *entry in entries) total += [entry[@"width"] doubleValue];
        total += spacing * (entries.count - 1);
    }

    CGFloat x = [side isEqualToString:@"left"] ? startMargin : contentWidth - total - startMargin;
    if (x < 1.0) x = 1.0;

#ifdef DEBUG
    NSMutableArray<NSString *> *signatureParts = [NSMutableArray array];
#endif
    for (NSMutableDictionary *entry in entries) {
        CGFloat width = [entry[@"width"] doubleValue];
        if ([entry[@"type"] isEqualToString:@"stock"]) {
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
    NSString *signature = [NSString stringWithFormat:@"%@:%@", side, [signatureParts componentsJoinedByString:@","]];
    if (self.logCount < 12 || ![signature isEqualToString:self.lastLogSignature]) {
        self.logCount++;
        self.lastLogSignature = signature;
        TBDebugLog(@"side=%@ order=%@ width=%.0f stock=%@", side, signature, contentWidth, stockViews.allKeys);
        for (NSString *identifier in self.pluginContainers) {
            UIView *container = self.pluginContainers[identifier];
            UILabel *label = self.pluginLabels[identifier];
            TBDebugLog(@"  plugin %@ frame=%@ text=%@ hidden=%d", identifier,
                       NSStringFromCGRect(container.frame), label.text, container.hidden);
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
        return [plugin respondsToSelector:@selector(wantsTap)] && [plugin wantsTap];
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

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if ([identifier isEqualToString:self.lastTapIdentifier] && now - self.lastTapTime < 0.35) return;
    self.lastTapIdentifier = identifier;
    self.lastTapTime = now;

    if ([plugin respondsToSelector:@selector(handleTap)]) {
        @try {
            [plugin handleTap];
        } @catch (NSException *exception) {
            TBDebugLog(@"plugin tap threw: %@", exception.reason);
        }
        [self syncPluginContainers];
        [self update];
    }
}

@end
