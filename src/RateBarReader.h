#import <Foundation/Foundation.h>

typedef struct {
    double watts;
    BOOL charging;
    BOOL valid;
    NSInteger percent;
    NSInteger timeToEmptyMinutes; // -1 when unknown
    NSInteger timeToFullMinutes;  // -1 when unknown
} BRRateSample;

#ifdef __cplusplus
extern "C" {
#endif

/// Reads the signed battery power. Positive is charging, negative is draining.
BRRateSample BRReadRateSample(void);

/// Formats a signed wattage as one number, e.g. "+2.7W", "-1.4W", or "0W".
NSString *BRFormatRate(double watts);

/// Formats a duration as "35m", "1h16m", or "2h". Negative input returns "".
NSString *BRFormatDuration(NSInteger minutes);

#ifdef __cplusplus
}
#endif
