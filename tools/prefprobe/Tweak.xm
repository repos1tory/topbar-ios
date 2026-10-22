#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UIViewController (PrefProbe)
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *)indexPathForIndex:(NSInteger)index;
@end

static void PLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSString *path = @"/var/jb/tmp/topbar-prefprobe.log";
    NSString *old = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL] ?: @"";
    [[old stringByAppendingFormat:@"%@ %@\n", [NSDate date], message] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

static void PLogController(UIViewController *controller, NSUInteger depth) {
    NSMutableString *prefix = [NSMutableString string];
    for (NSUInteger i = 0; i < depth; i++) [prefix appendString:@"  "];
    PLog(@"%@<%@> title=%@ presented=<%@>", prefix, NSStringFromClass(controller.class), controller.title,
         NSStringFromClass(controller.presentedViewController.class));
    @try {
        id specifiers = [controller valueForKey:@"specifiers"];
        if ([specifiers isKindOfClass:[NSArray class]]) {
            for (id specifier in specifiers) {
                NSString *name = nil;
                NSString *bundle = nil;
                NSString *detail = nil;
                @try { name = [specifier valueForKey:@"name"]; } @catch (__unused NSException *e) {}
                @try { bundle = [specifier valueForKey:@"bundle"]; } @catch (__unused NSException *e) {}
                @try { detail = [specifier valueForKey:@"detail"]; } @catch (__unused NSException *e) {}
                PLog(@"%@  spec name=%@ bundle=%@ detail=%@", prefix, name, bundle, detail);
            }
        }
    } @catch (__unused NSException *exception) {
    }
    if (depth < 3) {
        for (UIViewController *child in controller.childViewControllers) {
            PLogController(child, depth + 1);
        }
    }
}

static UIViewController *PTopViewController(void) {
    UIWindow *window = UIApplication.sharedApplication.windows.firstObject;
    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    return controller;
}

static UIViewController *PFindPrefsList(UIViewController *controller) {
    if ([NSStringFromClass(controller.class) containsString:@"PSUIPrefsListController"]) return controller;
    for (UIViewController *child in controller.childViewControllers) {
        UIViewController *found = PFindPrefsList(child);
        if (found) return found;
    }
    return nil;
}

static void PProbe(void) {
    UIViewController *root = PTopViewController();
    PLog(@"root=<%@>", NSStringFromClass(root.class));
    PLogController(root, 0);

    UIViewController *list = PFindPrefsList(root);
    PLog(@"prefs list=<%@>", NSStringFromClass(list.class));
    if (!list) return;

    NSArray *specifiers = nil;
    @try { specifiers = [list valueForKey:@"specifiers"]; } @catch (__unused NSException *e) {}
    NSUInteger row = NSNotFound;
    for (NSUInteger i = 0; i < specifiers.count; i++) {
        NSString *name = nil;
        @try { name = [specifiers[i] valueForKey:@"name"]; } @catch (__unused NSException *e) {}
        if ([name isEqualToString:@"TopBar"]) { row = i; break; }
    }
    PLog(@"TopBar row=%ld of %lu", (long)row, (unsigned long)specifiers.count);
    if (row == NSNotFound) return;

    UITableView *tableView = nil;
    @try { tableView = [list valueForKey:@"tableView"]; } @catch (__unused NSException *e) {}
    if (!tableView) tableView = [list valueForKey:@"table"];
    PLog(@"table=%@", tableView);
    if (!tableView) return;

    NSIndexPath *indexPath = nil;
    if ([list respondsToSelector:@selector(indexPathForIndex:)]) {
        indexPath = [(id)list indexPathForIndex:(NSInteger)row];
    }
    if (!indexPath) indexPath = [NSIndexPath indexPathForRow:(NSInteger)row inSection:0];
    PLog(@"TopBar indexPath=%@", indexPath);
    [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionMiddle];
    [list tableView:tableView didSelectRowAtIndexPath:indexPath];
    PLog(@"selected TopBar row");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        PLog(@"--- after selection ---");
        PLogController(root, 0);
        for (UIViewController *child in root.childViewControllers) {
            if ([child isKindOfClass:[UINavigationController class]]) {
                PLog(@"nav %@ stack=%@", child, ((UINavigationController *)child).viewControllers);
            }
        }
    });
}

%ctor {
    @autoreleasepool {
        if (![[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.Preferences"]) return;
        [[NSFileManager defaultManager] removeItemAtPath:@"/var/jb/tmp/topbar-prefprobe.log" error:NULL];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            PProbe();
        });
    }
}
