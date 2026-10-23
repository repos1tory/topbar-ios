#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <math.h>

#import "TBStatusPlugin.h"
#import "TBHost.h"

@interface TBPlugin_BatteryHealth : NSObject <TBStatusPlugin>
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) NSInteger mode;
@property (nonatomic, assign) NSInteger healthPercent;
@property (nonatomic, assign) NSInteger cycles;
@property (nonatomic, assign) NSInteger adapterWatts;
@end

@implementation TBPlugin_BatteryHealth

- (instancetype)init {
    self = [super init];
    if (self) [self refresh];
    return self;
}

- (NSString *)pluginIdentifier { return @"battery.health"; }
- (NSString *)pluginDisplayName { return @"Battery Health"; }
- (NSString *)pluginDescription { return @"Health, cycle count, and adapter watts. Tap to cycle."; }
- (NSString *)pluginVersion { return @"0.1.0"; }
- (NSString *)pluginAuthor { return @"alsinas"; }
- (BOOL)wantsTap { return YES; }

- (void)readBattery {
    self.healthPercent = -1;
    self.cycles = -1;
    self.adapterWatts = -1;

    io_service_t service = IOServiceGetMatchingService(0, IOServiceMatching("IOPMPowerSource"));
    if (!service) return;
    CFMutableDictionaryRef properties = NULL;
    kern_return_t result = IORegistryEntryCreateCFProperties(service, &properties, NULL, 0);
    IOObjectRelease(service);
    if (result != KERN_SUCCESS || !properties) return;

    NSDictionary *dictionary = (__bridge_transfer NSDictionary *)properties;
    NSInteger design = [dictionary[@"DesignCapacity"] integerValue];
    NSInteger maximum = [dictionary[@"AppleRawMaxCapacity"] integerValue];
    if (maximum <= 0) maximum = [dictionary[@"NominalChargeCapacity"] integerValue];
    if (design > 0 && maximum > 0) {
        self.healthPercent = (NSInteger)llround((double)maximum * 100.0 / (double)design);
    }

    NSInteger cycles = [dictionary[@"CycleCount"] integerValue];
    if (cycles > 0) self.cycles = cycles;

    id adapter = dictionary[@"AdapterDetails"];
    if ([adapter isKindOfClass:[NSArray class]] && [(NSArray *)adapter count] > 0) {
        adapter = [(NSArray *)adapter firstObject];
    }
    if ([adapter isKindOfClass:[NSDictionary class]]) {
        NSInteger watts = [adapter[@"Watts"] integerValue];
        if (watts > 0) self.adapterWatts = watts;
    }
}

- (void)refresh {
    [self readBattery];
    switch (self.mode % 3) {
        case 0:
            self.text = self.healthPercent >= 0 ? [NSString stringWithFormat:@"H%ld%%", (long)self.healthPercent] : @"H--";
            break;
        case 1:
            self.text = self.cycles >= 0 ? [NSString stringWithFormat:@"%ldcy", (long)self.cycles] : @"--cy";
            break;
        default:
            self.text = self.adapterWatts >= 0 ? [NSString stringWithFormat:@"%ldW", (long)self.adapterWatts] : @"0W";
            break;
    }
}

- (NSString *)statusText {
    return self.text ?: @"H--";
}

- (void)handleTap {
    self.mode = (self.mode + 1) % 3;
    [self refresh];
    [[NSNotificationCenter defaultCenter] postNotificationName:TBPluginDidUpdateNotificationName object:self];
}

@end

__attribute__((constructor))
static void TBPluginBatteryHealthConstructor(void) {
    (void)[TBPlugin_BatteryHealth class];
}
