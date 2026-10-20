#import "RateBarReader.h"

#import "RateMath.h"

#import <IOKit/IOKitLib.h>
#import <math.h>

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
    BRRateSample sample = {
        .watts = 0,
        .charging = NO,
        .valid = NO,
        .percent = 0,
        .timeToEmptyMinutes = -1,
        .timeToFullMinutes = -1,
    };

    NSDictionary *properties = BRBatteryProperties();
    if (!properties) return sample;

    NSNumber *instant = properties[@"InstantAmperage"];
    NSNumber *average = properties[@"Amperage"];
    NSNumber *displayCurrent = instant ?: average;
    double averageMilliamps = average.doubleValue;
    if (averageMilliamps == 0) averageMilliamps = displayCurrent.doubleValue;

    double millivolts = [properties[@"Voltage"] doubleValue];
    NSDictionary *batteryData = properties[@"BatteryData"];
    if (![batteryData isKindOfClass:[NSDictionary class]]) batteryData = nil;
    if (millivolts <= 0 && batteryData) {
        millivolts = [batteryData[@"Voltage"] doubleValue];
    }

    BRReadings readings = {
        .milliamps = displayCurrent.doubleValue,
        .millivolts = millivolts,
        .charging = [properties[@"IsCharging"] boolValue],
        .externalConnected = [properties[@"ExternalConnected"] boolValue],
        .fullyCharged = [properties[@"FullyCharged"] boolValue],
    };

    sample.watts = BRWattsFromReadings(readings);
    sample.charging = sample.watts > 0.05;
    sample.valid = millivolts > 0;
    sample.percent = [properties[@"CurrentCapacity"] integerValue];

    NSInteger rawCurrent = [properties[@"AppleRawCurrentCapacity"] integerValue];
    NSInteger rawMax = [properties[@"AppleRawMaxCapacity"] integerValue];
    if (rawMax <= 0 && batteryData) {
        rawMax = [batteryData[@"MaxCapacity"] integerValue];
        if (rawMax <= 0) rawMax = [batteryData[@"FullAvailableCapacity"] integerValue];
    }
    if (rawCurrent <= 0 && rawMax > 0) {
        rawCurrent = (rawMax * sample.percent) / 100;
    }

    NSInteger systemMinutes = [properties[@"TimeRemaining"] integerValue];
    if (systemMinutes <= 0 || systemMinutes > 60000) {
        systemMinutes = -1;
    }

    double magnitude = fabs(averageMilliamps);
    if (sample.watts > 0.05) {
        // Charging: project the remaining capacity at the current net charge rate.
        sample.timeToFullMinutes = BRMinutesToFull(rawCurrent, rawMax, magnitude);
    } else if (sample.watts < -0.05) {
        // Discharging: prefer the system's coulomb-counted estimate.
        if (systemMinutes > 0) {
            sample.timeToEmptyMinutes = systemMinutes;
        } else {
            sample.timeToEmptyMinutes = BRMinutesToEmpty(rawCurrent, magnitude);
        }
    }

    return sample;
}
