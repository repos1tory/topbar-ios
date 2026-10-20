#import <Foundation/Foundation.h>

typedef struct {
    double milliamps;
    double millivolts;
    BOOL charging;
    BOOL externalConnected;
    BOOL fullyCharged;
} BRReadings;

#ifdef __cplusplus
extern "C" {
#endif

/// Returns signed watts: positive while charging, negative while draining.
double BRWattsFromReadings(BRReadings readings);

/// Formats one signed number, e.g. "+2.7W", "-1.4W", or "0W".
NSString *BRFormatRate(double watts);

/// Formats a duration as "35m", "1h16m", or "2h". Negative input returns "".
NSString *BRFormatDuration(NSInteger minutes);

/// Estimated minutes until empty. Returns -1 when the inputs are unusable.
NSInteger BRMinutesToEmpty(NSInteger currentCapacitymAh, double milliamps);

/// Estimated minutes until full. Returns -1 when already full or inputs are unusable.
NSInteger BRMinutesToFull(NSInteger currentCapacitymAh, NSInteger maxCapacitymAh, double milliamps);

#ifdef __cplusplus
}
#endif
