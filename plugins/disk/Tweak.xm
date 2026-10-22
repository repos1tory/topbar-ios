#import <Foundation/Foundation.h>

#import "TBStatusPlugin.h"

@interface TBPlugin_Disk : NSObject <TBStatusPlugin>
@property (nonatomic, copy) NSString *text;
@end

@implementation TBPlugin_Disk

- (instancetype)init {
    self = [super init];
    if (self) [self refresh];
    return self;
}

- (NSString *)pluginIdentifier { return @"disk.space"; }
- (NSString *)pluginDisplayName { return @"Disk Space"; }
- (NSString *)pluginDescription { return @"Free and total storage, e.g. 42/256G."; }
- (NSString *)pluginVersion { return @"0.1.0"; }
- (NSString *)pluginAuthor { return @"alsinas"; }
- (BOOL)wantsTap { return NO; }

- (void)refresh {
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:@"/" error:NULL];
    unsigned long long freeBytes = [attributes[NSFileSystemFreeSize] unsignedLongLongValue];
    unsigned long long totalBytes = [attributes[NSFileSystemSize] unsignedLongLongValue];
    if (totalBytes == 0) {
        self.text = @"--";
        return;
    }

    if (totalBytes >= 1000000000000ULL) {
        self.text = [NSString stringWithFormat:@"%.1f/%.1fT",
                     (double)freeBytes / 1000000000000.0,
                     (double)totalBytes / 1000000000000.0];
    } else {
        self.text = [NSString stringWithFormat:@"%.0f/%.0fG",
                     (double)freeBytes / 1000000000.0,
                     (double)totalBytes / 1000000000.0];
    }
}

- (NSString *)statusText {
    return self.text ?: @"--";
}

@end

__attribute__((constructor))
static void TBPluginDiskConstructor(void) {
    (void)[TBPlugin_Disk class];
}
