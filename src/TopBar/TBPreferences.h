#import <Foundation/Foundation.h>

@interface TBPreferences : NSObject

+ (NSArray<NSString *> *)order;
+ (NSDictionary<NSString *, NSNumber *> *)enabled;
+ (BOOL)isEnabledForIdentifier:(NSString *)identifier;

+ (NSArray<NSString *> *)leftOrder;
+ (NSArray<NSString *> *)rightOrder;
+ (NSDictionary<NSString *, NSString *> *)sides;

+ (void)setOrder:(NSArray<NSString *> *)order;
+ (void)setEnabled:(NSDictionary<NSString *, NSNumber *> *)enabled;
+ (void)setLeftOrder:(NSArray<NSString *> *)order;
+ (void)setRightOrder:(NSArray<NSString *> *)order;
+ (void)setSides:(NSDictionary<NSString *, NSString *> *)sides;

+ (NSArray *)pluginsSnapshot;
+ (void)setPluginsSnapshot:(NSArray *)snapshot;

+ (id)objectForKey:(NSString *)key;
+ (void)setObject:(id)object forKey:(NSString *)key;

+ (void)notifyChanged;

@end
