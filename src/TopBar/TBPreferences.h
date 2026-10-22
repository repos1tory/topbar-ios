#import <Foundation/Foundation.h>

@interface TBPreferences : NSObject

+ (NSArray<NSString *> *)order;
+ (NSDictionary<NSString *, NSNumber *> *)enabled;
+ (BOOL)isEnabledForIdentifier:(NSString *)identifier;

+ (void)setOrder:(NSArray<NSString *> *)order;
+ (void)setEnabled:(NSDictionary<NSString *, NSNumber *> *)enabled;

+ (NSArray *)pluginsSnapshot;
+ (void)setPluginsSnapshot:(NSArray *)snapshot;

+ (id)objectForKey:(NSString *)key;
+ (void)setObject:(id)object forKey:(NSString *)key;

+ (void)notifyChanged;

@end
