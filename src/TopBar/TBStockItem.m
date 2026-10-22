#import "TBStockItem.h"
#import "TBHost.h"

#import <ctype.h>

@implementation TBStockItem

+ (NSArray<TBStockItem *> *)fallbackCatalog {
    NSArray<NSDictionary *> *rows = @[
        @{ @"Identifier": @"stock.timeDate", @"Name": @"Time & Date", @"DefaultOrder": @5, @"Side": @"left", @"Description": @"System clock and date" },
        @{ @"Identifier": @"stock.wifi", @"Name": @"Wi-Fi", @"DefaultOrder": @10, @"Description": @"System Wi-Fi indicator" },
        @{ @"Identifier": @"stock.vpn", @"Name": @"VPN", @"DefaultOrder": @20, @"Description": @"System VPN indicator" },
        @{ @"Identifier": @"stock.rotation", @"Name": @"Rotation Lock", @"DefaultOrder": @30, @"Description": @"System rotation lock" },
        @{ @"Identifier": @"stock.cellular", @"Name": @"Cellular", @"DefaultOrder": @40, @"Description": @"System cellular signal" },
        @{ @"Identifier": @"stock.focus", @"Name": @"Focus", @"DefaultOrder": @50, @"Description": @"System Focus indicator" },
        @{ @"Identifier": @"stock.alarm", @"Name": @"Alarm", @"DefaultOrder": @60, @"Description": @"System alarm indicator" },
        @{ @"Identifier": @"stock.location", @"Name": @"Location", @"DefaultOrder": @70, @"Description": @"System location indicator" },
        @{ @"Identifier": @"stock.bluetooth", @"Name": @"Bluetooth", @"DefaultOrder": @80, @"Description": @"System Bluetooth indicator" },
        @{ @"Identifier": @"stock.airplane", @"Name": @"Airplane Mode", @"DefaultOrder": @90, @"Description": @"System airplane mode indicator" },
        @{ @"Identifier": @"stock.battery", @"Name": @"Battery", @"DefaultOrder": @120, @"Description": @"System battery icon and percentage" },
    ];

    NSMutableArray<TBStockItem *> *items = [NSMutableArray array];
    for (NSDictionary *row in rows) {
        TBStockItem *item = [[TBStockItem alloc] init];
        item.identifier = row[@"Identifier"];
        item.name = row[@"Name"];
        item.detail = row[@"Description"];
        item.side = row[@"Side"] ?: @"right";
        item.defaultOrder = [row[@"DefaultOrder"] integerValue];
        [items addObject:item];
    }
    return items;
}

+ (NSArray<TBStockItem *> *)catalog {
    static NSArray<TBStockItem *> *catalog;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *rows = [NSArray arrayWithContentsOfFile:TBStockItemsPath];
        if (![rows isKindOfClass:[NSArray class]] || rows.count == 0) {
            catalog = [self fallbackCatalog];
            return;
        }

        NSMutableArray<TBStockItem *> *items = [NSMutableArray array];
        for (NSDictionary *row in rows) {
            if (![row isKindOfClass:[NSDictionary class]]) continue;
            NSString *identifier = row[@"Identifier"];
            if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0) continue;
            TBStockItem *item = [[TBStockItem alloc] init];
            item.identifier = identifier;
            item.name = [row[@"Name"] isKindOfClass:[NSString class]] ? row[@"Name"] : identifier;
            item.detail = [row[@"Description"] isKindOfClass:[NSString class]] ? row[@"Description"] : @"System item";
            item.side = [row[@"Side"] isKindOfClass:[NSString class]] ? row[@"Side"] : @"right";
            item.defaultOrder = [row[@"DefaultOrder"] integerValue];
            [items addObject:item];
        }
        catalog = items.count ? items : [self fallbackCatalog];
    });
    return catalog;
}

+ (NSString *)identifierForDisplayItemIdentifier:(NSString *)identifier {
    if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0) return nil;
    if ([identifier containsString:@"SpacerItem"]) return nil;
    if ([identifier containsString:@"TimeItem"] ||
        [identifier containsString:@"DateTimeItem"] ||
        [identifier containsString:@"DateItem"]) return @"stock.timeDate";
    if ([identifier containsString:@"BatteryItem"]) return @"stock.battery";
    if ([identifier containsString:@"WifiItem"]) return @"stock.wifi";
    if ([identifier containsString:@"VPNItem"]) return @"stock.vpn";
    if ([identifier containsString:@"RotationLockItem"]) return @"stock.rotation";
    if ([identifier containsString:@"QuietModeItem"]) return @"stock.focus";
    if ([identifier containsString:@"AlarmItem"]) return @"stock.alarm";
    if ([identifier containsString:@"LocationItem"]) return @"stock.location";
    if ([identifier containsString:@"BluetoothItem"]) return @"stock.bluetooth";
    if ([identifier containsString:@"Cellular"]) return @"stock.cellular";
    if ([identifier containsString:@"AirplaneModeItem"]) return @"stock.airplane";
    if ([identifier containsString:@"AirPlayItem"]) return @"stock.airplay";
    if ([identifier containsString:@"CarPlayItem"]) return @"stock.carplay";
    if ([identifier containsString:@"TTYItem"]) return @"stock.tty";
    if ([identifier containsString:@"StudentItem"]) return @"stock.student";
    if ([identifier containsString:@"ThermalItem"]) return @"stock.thermal";
    if ([identifier containsString:@"SatelliteItem"]) return @"stock.satellite";
    if ([identifier containsString:@"LiquidDetectionItem"]) return @"stock.liquid";
    if ([identifier containsString:@"SensorActivityItem"]) return @"stock.sensor";
    if ([identifier containsString:@"ActivityItem"]) return @"stock.activity";
    if ([identifier containsString:@"LockItem"]) return @"stock.lock";
    if ([identifier containsString:@"NavigationItem"]) return @"stock.navigation";
    if ([identifier containsString:@"PersonNameItem"]) return @"stock.person";
    if ([identifier containsString:@"BuildVersionItem"]) return @"stock.build";
    if ([identifier containsString:@"VoiceControl"]) return @"stock.voicecontrol";
    if ([identifier containsString:@"DisplayWarningItem"]) return @"stock.displaywarning";
    if ([identifier containsString:@"IndicatorAssistantItem"]) return @"stock.assistant";
    if ([identifier containsString:@"Pill"]) return @"stock.pill";

    NSMutableString *slug = [identifier mutableCopy];
    for (NSString *prefix in @[@"STUIStatusBar", @"UIStatusBar"]) {
        if ([slug hasPrefix:prefix]) [slug deleteCharactersInRange:NSMakeRange(0, prefix.length)];
    }
    if ([slug hasSuffix:@"Item"]) [slug deleteCharactersInRange:NSMakeRange(slug.length - 4, 4)];
    NSCharacterSet *allowed = [NSCharacterSet alphanumericCharacterSet];
    NSMutableString *clean = [NSMutableString string];
    for (NSUInteger i = 0; i < slug.length; i++) {
        unichar c = [slug characterAtIndex:i];
        if ([allowed characterIsMember:c]) {
            [clean appendFormat:@"%C", (unichar)tolower(c)];
        }
    }
    if (clean.length == 0) return nil;
    return [@"stock." stringByAppendingString:clean];
}

+ (NSString *)titleForIdentifier:(NSString *)identifier {
    for (TBStockItem *item in [self catalog]) {
        if ([item.identifier isEqualToString:identifier]) return item.name;
    }
    NSString *title = identifier;
    if ([title hasPrefix:@"stock."]) title = [title substringFromIndex:6];
    if (title.length == 0) return @"System";
    return [title stringByReplacingOccurrencesOfString:@"." withString:@" "];
}

+ (NSString *)sideForIdentifier:(NSString *)identifier {
    for (TBStockItem *item in [self catalog]) {
        if ([item.identifier isEqualToString:identifier]) return item.side ?: @"right";
    }
    return nil;
}

@end
