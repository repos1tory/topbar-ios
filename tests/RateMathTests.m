#import <Foundation/Foundation.h>
#import <math.h>

#import "../src/RateMath.h"

static void expect(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void) {
    @autoreleasepool {
        expect([BRFormatRate(2.74) isEqualToString:@"+2.7"], @"charge formatting");
        expect([BRFormatRate(-1.44) isEqualToString:@"-1.4"], @"drain formatting");
        expect([BRFormatRate(0) isEqualToString:@"0"], @"zero formatting");
        expect([BRFormatRate(0.01) isEqualToString:@"0"], @"tiny value formatting");

        BRReadings charging = { 732, 3749, YES, YES, NO };
        expect(fabs(BRWattsFromReadings(charging) - 2.744) < 0.01, @"charging watts");

        BRReadings draining = { -500, 3749, NO, NO, NO };
        expect(fabs(BRWattsFromReadings(draining) + 1.8745) < 0.01, @"draining watts");

        BRReadings full = { 0, 3749, NO, YES, YES };
        expect(BRWattsFromReadings(full) == 0, @"full and plugged is zero");

        BRReadings noVoltage = { 500, 0, YES, YES, NO };
        expect(BRWattsFromReadings(noVoltage) == 0, @"missing voltage is zero");

        NSLog(@"RateMath tests passed");
    }
    return 0;
}
