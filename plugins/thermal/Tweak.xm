#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>

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
- (NSString *)pluginDescription { return @"Battery temperature in Celsius, with thermal-state fallback."; }
- (NSString *)pluginVersion { return @"0.1.0"; }
- (NSString *)pluginAuthor { return @"alsinas"; }
- (BOOL)wantsTap { return NO; }

- (double)batteryTemperature {
    io_service_t service = IOServiceGetMatchingService(0, IOServiceMatching("IOPMPowerSource"));
    if (!service) return -1;
    CFMutableDictionaryRef properties = NULL;
    kern_return_t result = IORegistryEntryCreateCFProperties(service, &properties, NULL, 0);
    IOObjectRelease(service);
    if (result != KERN_SUCCESS || !properties) return -1;

    NSDictionary *dictionary = (__bridge_transfer NSDictionary *)properties;
    NSNumber *temperature = dictionary[@"Temperature"];
    if (![temperature isKindOfClass:[NSNumber class]]) return -1;
    double celsius = temperature.doubleValue / 100.0;
    return celsius > 0 ? celsius : -1;
}

- (void)refresh {
    double temperature = [self batteryTemperature];
    if (temperature > 0) {
        self.text = [NSString stringWithFormat:@"%.0f°C", temperature];
        return;
    }

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
