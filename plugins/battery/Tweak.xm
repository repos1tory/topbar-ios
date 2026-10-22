#import <Foundation/Foundation.h>

#import "RateBarReader.h"
#import "TBStatusPlugin.h"

@interface TBPlugin_BatteryRate : NSObject <TBStatusPlugin>
@property (nonatomic, copy) NSString *text;
@end

@implementation TBPlugin_BatteryRate

- (instancetype)init {
    self = [super init];
    if (self) {
        [self refresh];
    }
    return self;
}

- (NSString *)pluginIdentifier {
    return @"battery.rate";
}

- (NSString *)pluginDisplayName {
    return @"Battery Rate";
}

- (NSString *)pluginDescription {
    return @"Signed charge/drain watts and time estimate.";
}

- (NSString *)pluginVersion {
    return @"0.1.0";
}

- (NSString *)pluginAuthor {
    return @"alsinas";
}

- (BOOL)wantsTap {
    return NO;
}

- (void)refresh {
    BRRateSample sample = BRReadRateSample();
    NSString *rate = sample.valid ? BRFormatRate(sample.watts) : @"--";

    NSInteger minutes = -1;
    if (sample.valid) {
        if (sample.watts > 0.05) {
            minutes = sample.timeToFullMinutes;
        } else if (sample.watts < -0.05) {
            minutes = sample.timeToEmptyMinutes;
        }
    }
    NSString *duration = minutes > 0 ? BRFormatDuration(minutes) : nil;
    self.text = duration.length > 0 ? [NSString stringWithFormat:@"%@ %@", rate, duration] : rate;
}

- (NSString *)statusText {
    if (self.text.length == 0) [self refresh];
    return self.text ?: @"--";
}

@end

__attribute__((constructor))
static void TBPluginBatteryConstructor(void) {
    (void)[TBPlugin_BatteryRate class];
}
