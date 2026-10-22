#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <signal.h>

@interface STUIStatusBar : UIView
@property (nonatomic, readonly) UIView *foregroundView;
@property (nonatomic, readonly) UIColor *foregroundColor;
@end

static STUIStatusBar *__unsafe_unretained TBProbeBar;
static NSUInteger TBDumpSequence;

static NSString *TBDescribe(id obj, NSUInteger limit) {
    if (!obj) return @"(nil)";
    @try {
        NSString *text = [obj description];
        if (![text isKindOfClass:[NSString class]]) text = [NSString stringWithFormat:@"%@", obj];
        if (text.length > limit) text = [[text substringToIndex:limit] stringByAppendingString:@"…"];
        return text;
    } @catch (__unused NSException *exception) {
        return @"(description threw)";
    }
}

static id TBValue(id obj, NSString *key) {
    if (!obj) return nil;
    @try {
        if (![obj respondsToSelector:NSSelectorFromString(key)]) return nil;
        return [obj valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static void TBAppend(NSMutableString *out, NSUInteger depth, NSString *format, ...) {
    for (NSUInteger i = 0; i < depth; i++) [out appendString:@"  "];
    va_list args;
    va_start(args, format);
    NSString *line = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [out appendString:line];
    [out appendString:@"\n"];
}

static void TBDumpMethods(Class cls, NSArray<NSString *> *keywords, NSMutableString *out) {
    if (!cls) return;
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (unsigned int i = 0; i < count; i++) {
        NSString *name = NSStringFromSelector(method_getName(methods[i]));
        for (NSString *keyword in keywords) {
            if ([name localizedCaseInsensitiveContainsString:keyword]) {
                [names addObject:name];
                break;
            }
        }
    }
    free(methods);
    [names sortUsingSelector:@selector(compare:)];
    TBAppend(out, 0, @"  methods[%@] (%lu): %@", NSStringFromClass(cls), (unsigned long)names.count,
             [names componentsJoinedByString:@", "]);
}

static void TBDumpIvars(id obj, NSMutableString *out, NSUInteger depth) {
    if (!obj) return;
    Class cls = object_getClass(obj);
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(cls, &count);
    TBAppend(out, depth, @"ivars of %@ (%u):", NSStringFromClass(cls), count);
    for (unsigned int i = 0; i < count; i++) {
        const char *name = ivar_getName(ivars[i]);
        const char *type = ivar_getTypeEncoding(ivars[i]);
        NSString *value = @"";
        if (type && type[0] == '@') {
            @try {
                id child = object_getIvar(obj, ivars[i]);
                value = [NSString stringWithFormat:@" = <%@> %@", NSStringFromClass([child class]), TBDescribe(child, 220)];
            } @catch (__unused NSException *exception) {
                value = @" = (threw)";
            }
        }
        TBAppend(out, depth + 1, @"%s : %s%@", name ?: "?", type ?: "?", value);
    }
    free(ivars);
}

static void TBDumpItemView(UIView *view, NSMutableString *out, NSUInteger depth) {
    id item = TBValue(view, @"item");
    id displayItem = TBValue(view, @"displayItem");
    id identifier = TBValue(view, @"identifier");
    id region = TBValue(view, @"region");
    id priority = TBValue(view, @"priority");
    TBAppend(out, depth, @"itemView meta: identifier=%@ region=%@ priority=%@ item=<%@> %@ displayItem=<%@> %@",
             TBDescribe(identifier, 120), TBDescribe(region, 120), TBDescribe(priority, 80),
             NSStringFromClass([item class]), TBDescribe(item, 260),
             NSStringFromClass([displayItem class]), TBDescribe(displayItem, 300));
}

static void TBDumpView(UIView *view, NSMutableString *out, NSUInteger depth) {
    if (!view || depth > 24) return;

    NSMutableString *extra = [NSMutableString string];
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        [extra appendFormat:@" text=%@ font=%@/%.1f color=%@",
            TBDescribe(label.attributedText.string ?: label.text, 120),
            label.font.fontName ?: @"(nil)", label.font.pointSize,
            TBDescribe(label.textColor, 80)];
    } else if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        [extra appendFormat:@" image=%@ aid=%@ aLabel=%@",
            TBDescribe(imageView.image, 100),
            TBDescribe(imageView.accessibilityIdentifier, 80),
            TBDescribe(imageView.accessibilityLabel, 80)];
    }

    TBAppend(out, depth, @"%@ frame=(%.1f,%.1f %.1fx%.1f) hidden=%d alpha=%.2f super=%@%@",
             NSStringFromClass(view.class),
             view.frame.origin.x, view.frame.origin.y, view.frame.size.width, view.frame.size.height,
             view.hidden, view.alpha,
             NSStringFromClass(view.superview.class), extra);

    if ([NSStringFromClass(view.class) containsString:@"STUIStatusBar"] &&
        [view isKindOfClass:[UIView class]]) {
        TBDumpItemView(view, out, depth + 1);
    }

    for (UIView *subview in view.subviews) {
        TBDumpView(subview, out, depth + 1);
    }
}

static void TBDumpRegion(id region, NSString *key, NSMutableString *out) {
    if (!region) return;
    TBAppend(out, 0, @"--- region %@ (%@) ---", key, NSStringFromClass([region class]));
    TBDumpIvars(region, out, 0);
    TBDumpMethods([region class], @[@"item", @"layout", @"order", @"arrang", @"frame", @"view"], out);

    id layout = TBValue(region, @"layout");
    if (layout) {
        TBAppend(out, 0, @"layout %@", NSStringFromClass([layout class]));
        TBDumpIvars(layout, out, 0);
        TBDumpMethods([layout class], @[@"item", @"layout", @"order", @"arrang", @"frame", @"view"], out);
    }

    id containerItem = TBValue(region, @"containerItem");
    TBAppend(out, 0, @"containerItem=<%@> %@", NSStringFromClass([containerItem class]), TBDescribe(containerItem, 400));
    if (containerItem) {
        TBDumpIvars(containerItem, out, 0);
        TBDumpMethods([containerItem class], @[@"item", @"view", @"identifier", @"layout"], out);
    }

    NSArray *displayItems = TBValue(region, @"displayItems");
    TBAppend(out, 0, @"displayItems count=%lu", (unsigned long)displayItems.count);
    for (id displayItem in displayItems) {
        id identifier = TBValue(displayItem, @"identifier");
        id item = TBValue(displayItem, @"item");
        id layoutItem = TBValue(displayItem, @"layoutItem");
        id priority = TBValue(displayItem, @"priority");
        TBAppend(out, 1, @"displayItem %@ priority=%@ item=<%@> layoutItem=<%@> %@",
                 TBDescribe(identifier, 160), TBDescribe(priority, 80),
                 NSStringFromClass([item class]), TBDescribe(item, 240),
                 NSStringFromClass([layoutItem class]), TBDescribe(layoutItem, 360));
        if (item) {
            TBDumpIvars(item, out, 2);
            TBDumpMethods([item class], @[@"view", @"item", @"identifier", @"layout"], out);
        }
        if (layoutItem) {
            TBDumpIvars(layoutItem, out, 2);
        }
    }

    NSArray *absoluteFrames = TBValue(region, @"displayItemAbsoluteFrames");
    TBAppend(out, 0, @"displayItemAbsoluteFrames=%@", TBDescribe(absoluteFrames, 2000));
    NSArray *presentationFrames = TBValue(region, @"displayItemAbsolutePresentationFrames");
    TBAppend(out, 0, @"displayItemAbsolutePresentationFrames=%@", TBDescribe(presentationFrames, 2000));
    id layoutGuide = TBValue(region, @"layoutGuide");
    TBAppend(out, 0, @"layoutGuide=<%@> %@", NSStringFromClass([layoutGuide class]), TBDescribe(layoutGuide, 300));
}

static void TBDumpEverything(void) {
    NSMutableString *out = [NSMutableString string];
    STUIStatusBar *bar = TBProbeBar;
    TBAppend(out, 0, @"TopBarProbe %@", [NSDate date]);
    TBAppend(out, 0, @"idiom=%ld screen=%@ bounds=%@", (long)[UIDevice currentDevice].userInterfaceIdiom,
             TBDescribe(bar.window.screen, 200), NSStringFromCGRect(bar.window.bounds));
    TBAppend(out, 0, @"bar=%@ frame=%@ window=%@ foregroundView=%@",
             NSStringFromClass(bar.class), NSStringFromCGRect(bar.frame),
             TBDescribe(bar.window, 200), TBDescribe(bar.foregroundView, 200));

    TBDumpIvars(bar, out, 0);
    TBDumpMethods([bar class], @[@"item", @"layout", @"region", @"order", @"arrang", @"status"], out);

    NSDictionary *regions = TBValue(bar, @"regions");
    if (![regions isKindOfClass:[NSDictionary class]]) regions = TBValue(bar, @"_regions");
    TBAppend(out, 0, @"regions keys=%@", [[regions allKeys] componentsJoinedByString:@", "]);
    for (NSString *key in regions) {
        TBDumpRegion(regions[key], key, out);
    }

    NSDictionary *items = TBValue(bar, @"items");
    if (![items isKindOfClass:[NSDictionary class]]) items = TBValue(bar, @"_items");
    TBAppend(out, 0, @"items count=%lu", (unsigned long)items.count);
    for (id key in items) {
        id item = items[key];
        TBAppend(out, 0, @"item key=%@ class=%@ desc=%@",
                 TBDescribe(key, 200), NSStringFromClass([item class]), TBDescribe(item, 400));
        TBDumpIvars(item, out, 1);
        TBDumpMethods([item class], @[@"view", @"item", @"identifier", @"layout"], out);
    }

    if (bar.foregroundView && bar.foregroundView != bar && bar.foregroundView != (id)bar) {
        TBDumpIvars(bar.foregroundView, out, 0);
        TBDumpMethods([bar.foregroundView class], @[@"item", @"layout", @"region", @"order", @"arrang"], out);
    }

    TBAppend(out, 0, @"--- full hierarchy ---");
    TBDumpView(bar, out, 0);

    Class itemViewClass = NSClassFromString(@"STUIStatusBarItemView");
    Class displayItemClass = NSClassFromString(@"STUIStatusBarDisplayItem");
    Class layoutManagerClass = NSClassFromString(@"STUIStatusBarLayoutManager");
    Class regionClass = NSClassFromString(@"STUIStatusBarRegion");
    if (itemViewClass) TBDumpMethods(itemViewClass, @[@"item", @"layout", @"region", @"order"], out);
    if (displayItemClass) TBDumpMethods(displayItemClass, @[@"item", @"identifier", @"region", @"priority", @"order"], out);
    if (layoutManagerClass) TBDumpMethods(layoutManagerClass, @[@"item", @"layout", @"region", @"order", @"arrang"], out);
    if (regionClass) TBDumpMethods(regionClass, @[@"item", @"layout", @"order", @"arrang"], out);

    TBDumpSequence++;
    NSString *path = [NSString stringWithFormat:@"/var/jb/tmp/topbar-probe-%lu.txt", (unsigned long)TBDumpSequence];
    NSError *error = nil;
    BOOL ok = [out writeToFile:path
                    atomically:YES
                      encoding:NSUTF8StringEncoding
                         error:&error];
    if (ok) {
        [out writeToFile:@"/var/jb/tmp/topbar-probe.txt"
              atomically:YES
                encoding:NSUTF8StringEncoding
                   error:NULL];
    } else {
        NSLog(@"TopBarProbe write failed: %@", error);
    }
    NSLog(@"TopBarProbe wrote %lu bytes to %@", (unsigned long)out.length, path);
}

static void TBHandleDumpSignal(__unused int signalNumber) {
    dispatch_async(dispatch_get_main_queue(), ^{
        TBDumpEverything();
    });
}

%hook STUIStatusBar
- (void)layoutSubviews {
    %orig;
    if (!TBProbeBar) TBProbeBar = self;
}
%end

%ctor {
    @autoreleasepool {
        if (![[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
        signal(SIGUSR1, TBHandleDumpSignal);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            TBDumpEverything();
        });
    }
}
