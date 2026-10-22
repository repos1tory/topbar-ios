#import <Foundation/Foundation.h>
#import "TBStatusPlugin.h"

@interface TBPluginRecord : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, copy) NSString *side;
@property (nonatomic, assign) NSInteger defaultOrder;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, strong) id<TBStatusPlugin> plugin;

@end

@interface TBPluginRegistry : NSObject

+ (instancetype)sharedRegistry;

- (void)reload;
- (NSArray<TBPluginRecord *> *)records;
- (id<TBStatusPlugin>)pluginForIdentifier:(NSString *)identifier;
- (void)refreshAllPlugins;

@end
