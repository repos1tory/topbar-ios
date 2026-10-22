#import <Foundation/Foundation.h>

#import "TBStatusPlugin.h"

@interface TBPlugin_Thermal : NSObject <TBStatusPlugin>
@property (nonatomic, copy) NSString *text;
@end

@implementation TBPlugin_Thermal

- (instancetype)init {
    self = [super init];
    if (self) [self refresh];
    return self;
}

- (NSString *)pluginIdentifier { return @"thermal.state"; }
- (NSString *)pluginDisplayName { return @"Thermal"; }
- (NSString *)pluginDescription { return @"System thermal pressure state."; }
- (NSString *)pluginVersion { return @"0.1.0"; }
- (NSString *)pluginAuthor { return @"alsinas"; }
- (BOOL)wantsTap { return NO; }

- (void)refresh {
    switch ([NSProcessInfo processInfo].thermalState) {
        case NSProcessInfoThermalStateNominal: self.text = @"T OK"; break;
        case NSProcessInfoThermalStateFair: self.text = @"T Warm"; break;
        case NSProcessInfoThermalStateSerious: self.text = @"T Hot"; break;
        case NSProcessInfoThermalStateCritical: self.text = @"T Crit"; break;
        default: self.text = @"T --"; break;
    }
}

- (NSString *)statusText {
    return self.text ?: @"T --";
}

@end

__attribute__((constructor))
static void TBPluginThermalConstructor(void) {
    (void)[TBPlugin_Thermal class];
}
