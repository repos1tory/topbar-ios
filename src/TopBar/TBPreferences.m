#import "TBPreferences.h"
#import "TBHost.h"

static NSString *TBPreferencesPath(void) {
    return @"/var/mobile/Library/Preferences/com.alsinas.topbar.plist";
}

static NSString *TBPluginsSnapshotPath(void) {
    return @"/var/mobile/Library/Preferences/com.alsinas.topbar.plugins.plist";
}

static NSDictionary *TBReadDictionary(NSString *path) {
    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:path];
    return [dictionary isKindOfClass:[NSDictionary class]] ? dictionary : @{};
}

static BOOL TBWriteDictionary(NSDictionary *dictionary, NSString *path) {
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dictionary
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:NULL];
    return data && [data writeToFile:path atomically:YES];
}

@implementation TBPreferences

+ (id)objectForKey:(NSString *)key {
    if (key.length == 0) return nil;
    return TBReadDictionary(TBPreferencesPath())[key];
}

+ (void)setObject:(id)object forKey:(NSString *)key {
    if (key.length == 0) return;
    NSMutableDictionary *dictionary = [TBReadDictionary(TBPreferencesPath()) mutableCopy];
    if (object) {
        dictionary[key] = object;
    } else {
        [dictionary removeObjectForKey:key];
    }
    TBWriteDictionary(dictionary, TBPreferencesPath());
}

+ (NSArray<NSString *> *)order {
    id value = [self objectForKey:TBOrderKey];
    if (![value isKindOfClass:[NSArray class]]) return nil;

    NSMutableArray<NSString *> *order = [NSMutableArray array];
    for (id item in (NSArray *)value) {
        if ([item isKindOfClass:[NSString class]] && [item length] > 0) {
            [order addObject:item];
        }
    }
    return order;
}

+ (NSDictionary<NSString *, NSNumber *> *)enabled {
    id value = [self objectForKey:TBEnabledKey];
    if (![value isKindOfClass:[NSDictionary class]]) return @{};

    NSMutableDictionary<NSString *, NSNumber *> *enabled = [NSMutableDictionary dictionary];
    [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id obj, __unused BOOL *stop) {
        if ([key isKindOfClass:[NSString class]] && [obj respondsToSelector:@selector(boolValue)]) {
            enabled[key] = @([obj boolValue]);
        }
    }];
    return enabled;
}

+ (BOOL)isEnabledForIdentifier:(NSString *)identifier {
    NSNumber *value = [self enabled][identifier];
    return value ? value.boolValue : YES;
}

+ (void)setOrder:(NSArray<NSString *> *)order {
    [self setObject:order ?: @[] forKey:TBOrderKey];
}

+ (void)setEnabled:(NSDictionary<NSString *, NSNumber *> *)enabled {
    [self setObject:enabled ?: @{} forKey:TBEnabledKey];
}

+ (NSArray *)pluginsSnapshot {
    NSArray *snapshot = [NSArray arrayWithContentsOfFile:TBPluginsSnapshotPath()];
    return [snapshot isKindOfClass:[NSArray class]] ? snapshot : @[];
}

+ (void)setPluginsSnapshot:(NSArray *)snapshot {
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:(snapshot ?: @[])
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:NULL];
    if (data) [data writeToFile:TBPluginsSnapshotPath() atomically:YES];
}

+ (void)notifyChanged {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)TBPreferencesChangedNotificationName,
                                         NULL, NULL, true);
}

@end
