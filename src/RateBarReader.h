#import <Foundation/Foundation.h>

typedef struct {
    double watts;
    BOOL charging;
    BOOL valid;
    NSInteger percent;
} BRRateSample;

#ifdef __cplusplus
extern "C" {
#endif

/// Reads the signed battery power. Positive is charging, negative is draining.
BRRateSample BRReadRateSample(void);

/// Formats a signed wattage as one number, e.g. "+2.7", "-1.4", or "0".
NSString *BRFormatRate(double watts);

#ifdef __cplusplus
}
#endif
