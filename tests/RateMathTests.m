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
        expect([BRFormatRate(2.74) isEqualToString:@"+2.7W"], @"charge formatting");
        expect([BRFormatRate(-1.44) isEqualToString:@"-1.4W"], @"drain formatting");
        expect([BRFormatRate(0) isEqualToString:@"0W"], @"zero formatting");
        expect([BRFormatRate(0.01) isEqualToString:@"0W"], @"tiny value formatting");
        expect([BRFormatDuration(34) isEqualToString:@"34m"], @"minutes formatting");
        expect([BRFormatDuration(60) isEqualToString:@"1h"], @"exact hour formatting");
        expect([BRFormatDuration(76) isEqualToString:@"1h16m"], @"hour and minute formatting");
        expect([BRFormatDuration(120) isEqualToString:@"2h"], @"two hours formatting");
        expect([BRFormatDuration(125) isEqualToString:@"2h05m"], @"padded minutes formatting");
        expect([BRFormatDuration(-1) isEqualToString:@""], @"unknown duration formatting");
        expect([BRFormatDuration(6000) isEqualToString:@"99h+"], @"duration cap");
        expect(BRMinutesToEmpty(1041, 1540) == 41, @"minutes to empty");
        expect(BRMinutesToEmpty(965, 973) == 60, @"minutes to empty near one hour");
        expect(BRMinutesToEmpty(0, 1000) == -1, @"minutes to empty invalid capacity");
        expect(BRMinutesToFull(965, 7695, 650) == 621, @"minutes to full");
        expect(BRMinutesToFull(7695, 7695, 650) == -1, @"minutes to full when full");

        BRReadings charging = { 732, 3749, YES, YES, NO };
        expect(fabs(BRWattsFromReadings(charging) - 2.744) < 0.01, @"charging watts");

        BRReadings draining = { -500, 3749, NO, NO, NO };
        expect(fabs(BRWattsFromReadings(draining) + 1.8745) < 0.01, @"draining watts");

        BRReadings pluggedButDraining = { -973, 3682, YES, YES, NO };
        expect(BRWattsFromReadings(pluggedButDraining) < -3.5, @"plugged-in load can still drain");

        BRReadings full = { 0, 3749, NO, YES, YES };
        expect(BRWattsFromReadings(full) == 0, @"full and plugged is zero");

        BRReadings noVoltage = { 500, 0, YES, YES, NO };
        expect(BRWattsFromReadings(noVoltage) == 0, @"missing voltage is zero");

        NSLog(@"RateMath tests passed");
    }
    return 0;
}
