#import "RateMath.h"

#import <math.h>

double BRWattsFromReadings(BRReadings readings) {
    if (readings.millivolts <= 0 || !isfinite(readings.milliamps)) return 0;

    double watts = readings.milliamps * readings.millivolts / 1000000.0;
    if (!isfinite(watts)) return 0;
    if (fabs(watts) < 0.05) return 0;
    return watts;
}

NSString *BRFormatRate(double watts) {
    if (!isfinite(watts)) return @"--";
    if (fabs(watts) < 0.05) return @"0W";
    return [NSString stringWithFormat:@"%+.1fW", watts];
}

NSString *BRFormatDuration(NSInteger minutes) {
    if (minutes < 0) return @"";
    if (minutes > 99 * 60 + 59) return @"99h+";

    if (minutes < 60) {
        return [NSString stringWithFormat:@"%ldm", (long)minutes];
    }

    NSInteger hours = minutes / 60;
    NSInteger remainder = minutes % 60;
    if (remainder == 0) {
        return [NSString stringWithFormat:@"%ldh", (long)hours];
    }
    return [NSString stringWithFormat:@"%ldh%02ldm", (long)hours, (long)remainder];
}

NSInteger BRMinutesToEmpty(NSInteger currentCapacitymAh, double milliamps) {
    if (currentCapacitymAh <= 0 || milliamps == 0 || !isfinite(milliamps)) return -1;
    double hours = (double)currentCapacitymAh / fabs(milliamps);
    if (!isfinite(hours) || hours < 0) return -1;
    return (NSInteger)llround(hours * 60.0);
}

NSInteger BRMinutesToFull(NSInteger currentCapacitymAh, NSInteger maxCapacitymAh, double milliamps) {
    if (maxCapacitymAh <= currentCapacitymAh || milliamps == 0 || !isfinite(milliamps)) return -1;
    double hours = (double)(maxCapacitymAh - currentCapacitymAh) / fabs(milliamps);
    if (!isfinite(hours) || hours < 0) return -1;
    return (NSInteger)llround(hours * 60.0);
}
