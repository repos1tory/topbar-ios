#import "RateBarReader.h"

#import "RateMath.h"

#import <IOKit/IOKitLib.h>

static NSDictionary *BRBatteryProperties(void) {
    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                       IOServiceMatching("IOPMPowerSource"));
    if (!service) return nil;

    CFMutableDictionaryRef properties = NULL;
    kern_return_t result = IORegistryEntryCreateCFProperties(service, &properties, NULL, 0);
    IOObjectRelease(service);
    if (result != KERN_SUCCESS || !properties) return nil;

    return (__bridge_transfer NSDictionary *)properties;
}

BRRateSample BRReadRateSample(void) {
    BRRateSample sample = { .watts = 0, .charging = NO, .valid = NO, .percent = 0 };

    NSDictionary *properties = BRBatteryProperties();
    if (!properties) return sample;

    NSNumber *instant = properties[@"InstantAmperage"];
    NSNumber *average = properties[@"Amperage"];
    NSNumber *current = instant ?: average;

    double millivolts = [properties[@"Voltage"] doubleValue];
    if (millivolts <= 0) {
        NSDictionary *batteryData = properties[@"BatteryData"];
        if ([batteryData isKindOfClass:[NSDictionary class]]) {
            millivolts = [batteryData[@"Voltage"] doubleValue];
        }
    }

    BRReadings readings = {
        .milliamps = current.doubleValue,
        .millivolts = millivolts,
        .charging = [properties[@"IsCharging"] boolValue],
        .externalConnected = [properties[@"ExternalConnected"] boolValue],
        .fullyCharged = [properties[@"FullyCharged"] boolValue],
    };

    sample.watts = BRWattsFromReadings(readings);
    sample.charging = readings.charging;
    sample.valid = millivolts > 0;
    sample.percent = [properties[@"CurrentCapacity"] integerValue];
    return sample;
}
