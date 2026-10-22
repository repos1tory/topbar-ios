#import "TBPluginRegistry.h"
#import "TBHost.h"
#import "TBPreferences.h"
#import "TBDebug.h"

#import <objc/runtime.h>

@implementation TBPluginRecord
@end

@interface TBPluginRegistry ()
@property (nonatomic, strong) NSArray<TBPluginRecord *> *cachedRecords;
@end

@implementation TBPluginRegistry {
    NSMutableDictionary<NSString *, id<TBStatusPlugin>> *_plugins;
    NSMutableSet<NSString *> *_instantiatedClasses;
}

+ (instancetype)sharedRegistry {
    static TBPluginRegistry *registry;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        registry = [[TBPluginRegistry alloc] init];
    });
    return registry;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _plugins = [NSMutableDictionary dictionary];
        _instantiatedClasses = [NSMutableSet set];
        _cachedRecords = @[];
    }
    return self;
}

static NSString *TBStringValue(NSDictionary *dictionary, NSString *key, NSString *fallback) {
    id value = dictionary[key];
    return [value isKindOfClass:[NSString class]] && [value length] > 0 ? value : fallback;
}

- (NSDictionary<NSString *, NSDictionary *> *)manifestRecords {
    NSMutableDictionary<NSString *, NSDictionary *> *manifests = [NSMutableDictionary dictionary];
    NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:TBPluginsDirectory error:NULL];
    for (NSString *file in files) {
        if (![file.pathExtension.lowercaseString isEqualToString:@"plist"]) continue;
        NSString *path = [TBPluginsDirectory stringByAppendingPathComponent:file];
        NSDictionary *manifest = [NSDictionary dictionaryWithContentsOfFile:path];
        if (![manifest isKindOfClass:[NSDictionary class]]) continue;
        NSString *identifier = TBStringValue(manifest, @"Identifier", nil);
        if (identifier.length == 0) continue;
        manifests[identifier] = manifest;
    }
    return manifests;
}

- (void)scanPluginClasses {
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return;

    Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * (NSUInteger)count);
    if (!classes) return;
    count = objc_getClassList(classes, count);

    for (int i = 0; i < count; i++) {
        Class cls = classes[i];
        const char *name = class_getName(cls);
        if (!name || strncmp(name, "TBPlugin_", 9) != 0) continue;

        NSString *className = [NSString stringWithUTF8String:name];
        if ([_instantiatedClasses containsObject:className]) continue;
        [_instantiatedClasses addObject:className];

        @try {
            id instance = [[cls alloc] init];
            if (![instance conformsToProtocol:@protocol(TBStatusPlugin)] &&
                ![instance respondsToSelector:@selector(pluginIdentifier)]) {
                continue;
            }
            NSString *identifier = [instance pluginIdentifier];
            if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0) continue;
            _plugins[identifier] = instance;
            TBDebugLog(@"plugin class %@ -> %@", className, identifier);
        } @catch (NSException *exception) {
            TBDebugLog(@"plugin class %@ threw: %@", className, exception.reason);
        }
    }
    free(classes);
}

- (void)reload {
    NSDictionary<NSString *, NSDictionary *> *manifests = [self manifestRecords];
    [self scanPluginClasses];

    NSMutableDictionary<NSString *, TBPluginRecord *> *records = [NSMutableDictionary dictionary];
    NSInteger index = 0;
    for (NSString *identifier in manifests) {
        NSDictionary *manifest = manifests[identifier];
        TBPluginRecord *record = [[TBPluginRecord alloc] init];
        record.identifier = identifier;
        record.name = TBStringValue(manifest, @"Name", identifier);
        record.detail = TBStringValue(manifest, @"Description", @"Plugin");
        record.version = TBStringValue(manifest, @"Version", @"");
        record.author = TBStringValue(manifest, @"Author", @"");
        record.side = [TBStringValue(manifest, @"Side", @"right") lowercaseString];
        record.defaultOrder = [manifest[@"DefaultOrder"] integerValue] ?: (1000 + index);
        record.loaded = NO;
        records[identifier] = record;
        index++;
    }

    [_plugins enumerateKeysAndObjectsUsingBlock:^(NSString *identifier, id<TBStatusPlugin> plugin, __unused BOOL *stop) {
        TBPluginRecord *record = records[identifier];
        if (!record) {
            record = [[TBPluginRecord alloc] init];
            record.identifier = identifier;
            record.defaultOrder = 1000 + index;
            records[identifier] = record;
        }
        record.plugin = plugin;
        record.loaded = YES;
        if (record.name.length == 0 || [record.name isEqualToString:identifier]) {
            @try { record.name = [plugin pluginDisplayName] ?: identifier; } @catch (__unused NSException *e) {}
        }
        if (record.detail.length == 0) {
            @try { record.detail = [plugin pluginDescription] ?: @"Plugin"; } @catch (__unused NSException *e) {}
        }
        if (record.version.length == 0) {
            @try { record.version = [plugin pluginVersion] ?: @""; } @catch (__unused NSException *e) {}
        }
        if (record.author.length == 0) {
            @try { record.author = [plugin pluginAuthor] ?: @""; } @catch (__unused NSException *e) {}
        }
        if (record.side.length == 0) {
            @try {
                NSString *side = [plugin respondsToSelector:@selector(pluginSide)] ? [plugin pluginSide] : nil;
                record.side = [side isKindOfClass:[NSString class]] && side.length > 0 ? side.lowercaseString : @"right";
            } @catch (__unused NSException *e) {
                record.side = @"right";
            }
        }
    }];

    NSArray<TBPluginRecord *> *sorted = [records.allValues sortedArrayUsingComparator:^NSComparisonResult(TBPluginRecord *a, TBPluginRecord *b) {
        if (a.defaultOrder != b.defaultOrder) return a.defaultOrder < b.defaultOrder ? NSOrderedAscending : NSOrderedDescending;
        return [a.name compare:b.name];
    }];
    self.cachedRecords = sorted;

    NSMutableArray<NSDictionary *> *snapshot = [NSMutableArray array];
    for (TBPluginRecord *record in sorted) {
        [snapshot addObject:@{
            @"Identifier": record.identifier,
            @"Name": record.name ?: record.identifier,
            @"Description": record.detail ?: @"Plugin",
            @"Version": record.version ?: @"",
            @"Author": record.author ?: @"",
            @"Side": record.side ?: @"right",
            @"DefaultOrder": @(record.defaultOrder),
            @"Loaded": @(record.loaded),
        }];
    }
    [TBPreferences setPluginsSnapshot:snapshot];

    TBDebugLog(@"registry reload: %lu manifests, %lu plugins, %lu records",
               (unsigned long)manifests.count, (unsigned long)_plugins.count, (unsigned long)sorted.count);

    [[NSNotificationCenter defaultCenter] postNotificationName:TBPluginRegistryDidChangeNotificationName object:self];
}

- (NSArray<TBPluginRecord *> *)records {
    return self.cachedRecords ?: @[];
}

- (id<TBStatusPlugin>)pluginForIdentifier:(NSString *)identifier {
    return _plugins[identifier];
}

- (void)refreshAllPlugins {
    [_plugins enumerateKeysAndObjectsUsingBlock:^(__unused NSString *identifier, id<TBStatusPlugin> plugin, __unused BOOL *stop) {
        @try {
            [plugin refresh];
        } @catch (NSException *exception) {
            TBDebugLog(@"plugin refresh threw: %@", exception.reason);
        }
    }];
}

@end
