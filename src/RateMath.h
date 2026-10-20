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

/// Formats one signed number, e.g. "+2.7", "-1.4", or "0".
NSString *BRFormatRate(double watts);

#ifdef __cplusplus
}
#endif
