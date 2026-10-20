#import "RateMath.h"

#import <math.h>

double BRWattsFromReadings(BRReadings readings) {
    if (readings.millivolts <= 0 || !isfinite(readings.milliamps)) return 0;

    double watts = fabs(readings.milliamps * readings.millivolts / 1000000.0);
    if (!isfinite(watts)) return 0;

    if (readings.charging) return watts;
    if (readings.externalConnected && readings.fullyCharged) return 0;
    return -watts;
}

NSString *BRFormatRate(double watts) {
    if (!isfinite(watts)) return @"--";
    if (fabs(watts) < 0.05) return @"0";
    return [NSString stringWithFormat:@"%+.1f", watts];
}
