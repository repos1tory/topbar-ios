#import <Foundation/Foundation.h>

#import "TBStatusPlugin.h"

@interface TBPlugin_Uptime : NSObject <TBStatusPlugin>
@property (nonatomic, copy) NSString *text;
@end

@implementation TBPlugin_Uptime

- (instancetype)init {
    self = [super init];
    if (self) [self refresh];
    return self;
}

- (NSString *)pluginIdentifier { return @"uptime"; }
- (NSString *)pluginDisplayName { return @"Uptime"; }
- (NSString *)pluginDescription { return @"Time since the device booted."; }
- (NSString *)pluginVersion { return @"0.1.0"; }
- (NSString *)pluginAuthor { return @"alsinas"; }
- (BOOL)wantsTap { return NO; }

- (void)refresh {
    NSTimeInterval seconds = [NSProcessInfo processInfo].systemUptime;
    NSInteger totalMinutes = (NSInteger)(seconds / 60.0);
    NSInteger days = totalMinutes / (24 * 60);
    NSInteger hours = (totalMinutes / 60) % 24;
    NSInteger minutes = totalMinutes % 60;

    if (days > 0) {
        self.text = [NSString stringWithFormat:@"%ldd%ldh", (long)days, (long)hours];
    } else if (hours > 0) {
        self.text = [NSString stringWithFormat:@"%ldh%02ldm", (long)hours, (long)minutes];
    } else {
        self.text = [NSString stringWithFormat:@"%ldm", (long)minutes];
    }
}

- (NSString *)statusText {
    return self.text ?: @"--";
}

@end

__attribute__((constructor))
static void TBPluginUptimeConstructor(void) {
    (void)[TBPlugin_Uptime class];
}
