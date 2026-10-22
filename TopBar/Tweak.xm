#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <notify.h>

#import "src/TopBar/TBHost.h"
#import "src/TopBar/TBPreferences.h"
#import "src/TopBar/TBPluginRegistry.h"
#import "src/TopBar/TBStatusBarController.h"
#import "src/TopBar/TBDebug.h"

@interface STUIStatusBar : UIView
@property (nonatomic, readonly) UIView *foregroundView;
@property (nonatomic, readonly) UIColor *foregroundColor;
- (id)regionWithIdentifier:(NSString *)identifier;
@end

static NSMapTable<STUIStatusBar *, TBStatusBarController *> *TBControllers(void) {
    static NSMapTable *controllers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        controllers = [NSMapTable weakToStrongObjectsMapTable];
    });
    return controllers;
}

static void TBUpdateBar(STUIStatusBar *bar) {
    if (!bar) return;
    TBStatusBarController *controller = [TBControllers() objectForKey:bar];
    if (!controller) {
        controller = [[TBStatusBarController alloc] initWithStatusBar:bar];
        [TBControllers() setObject:controller forKey:bar];
    }
    [controller update];
}

static void TBUpdateAll(void) {
    for (STUIStatusBar *bar in [TBControllers() keyEnumerator]) {
        TBUpdateBar(bar);
    }
}

static void TBRefreshAndUpdate(void) {
    [[TBPluginRegistry sharedRegistry] refreshAllPlugins];
    TBUpdateAll();
}

static void TBRespringReload(void) {
    [[TBPluginRegistry sharedRegistry] reload];
    TBRefreshAndUpdate();
}

static void TBPreferencesChangedCallback(__unused CFNotificationCenterRef center,
                                         __unused void *observer,
                                         __unused CFStringRef name,
                                         __unused const void *object,
                                         __unused CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        TBRespringReload();
    });
}

%hook STUIStatusBar

- (void)layoutSubviews {
    %orig;
    TBUpdateBar(self);
}

- (void)didMoveToWindow {
    %orig;
    TBUpdateBar(self);
}

- (void)setForegroundColor:(UIColor *)color {
    %orig;
    TBUpdateBar(self);
}

%end

%ctor {
    @autoreleasepool {
        if (![[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;

#ifdef DEBUG
        [[NSFileManager defaultManager] removeItemAtPath:TBDebugLogPath error:NULL];
        TBDebugLog(@"TopBar ctor");
#endif

        [[NSNotificationCenter defaultCenter] addObserverForName:TBPluginDidUpdateNotificationName
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification *note) {
            TBUpdateAll();
        }];

        [[NSNotificationCenter defaultCenter] addObserverForName:TBPluginRegistryDidChangeNotificationName
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification *note) {
            TBUpdateAll();
        }];

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        (CFNotificationCallback)TBPreferencesChangedCallback,
                                        (__bridge CFStringRef)TBPreferencesChangedNotificationName,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        [NSTimer scheduledTimerWithTimeInterval:2.0
                                         repeats:YES
                                           block:^(__unused NSTimer *timer) {
            TBRefreshAndUpdate();
        }];

        NSArray<NSString *> *notifications = @[
            @"com.apple.system.powersources.source",
            @"com.apple.system.powersources.percent",
            @"com.apple.system.powersources.timeremaining"
        ];
        for (NSString *name in notifications) {
            int token = NOTIFY_TOKEN_INVALID;
            notify_register_dispatch(name.UTF8String, &token, dispatch_get_main_queue(), ^(__unused int t) {
                TBRefreshAndUpdate();
            });
        }

        for (NSNumber *delay in @[@0.5, @2.0, @5.0]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                TBRespringReload();
            });
        }
    }
}
