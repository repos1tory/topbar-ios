#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <mach/vm_statistics.h>

#import "TBStatusPlugin.h"

@interface TBPlugin_RAM : NSObject <TBStatusPlugin>
@property (nonatomic, copy) NSString *text;
@end

@implementation TBPlugin_RAM

- (instancetype)init {
    self = [super init];
    if (self) [self refresh];
    return self;
}

- (NSString *)pluginIdentifier { return @"ram.usage"; }
- (NSString *)pluginDisplayName { return @"RAM"; }
- (NSString *)pluginDescription { return @"System memory usage percentage."; }
- (NSString *)pluginVersion { return @"0.1.0"; }
- (NSString *)pluginAuthor { return @"alsinas"; }
- (BOOL)wantsTap { return NO; }

- (void)refresh {
    vm_statistics64_data_t stats;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    kern_return_t result = host_statistics64(mach_host_self(), HOST_VM_INFO64,
                                             (host_info64_t)&stats, &count);
    if (result != KERN_SUCCESS) {
        self.text = @"R--";
        return;
    }

    vm_size_t pageSize = 0;
    host_page_size(mach_host_self(), &pageSize);
    uint64_t freeBytes = (uint64_t)(stats.free_count + stats.speculative_count) * pageSize;
    uint64_t totalBytes = [NSProcessInfo processInfo].physicalMemory;
    if (totalBytes == 0) {
        self.text = @"R--";
        return;
    }

    double percent = (1.0 - (double)freeBytes / (double)totalBytes) * 100.0;
    self.text = [NSString stringWithFormat:@"R%.0f%%", MAX(0.0, MIN(100.0, percent))];
}

- (NSString *)statusText {
    return self.text ?: @"R--";
}

@end

__attribute__((constructor))
static void TBPluginRAMConstructor(void) {
    (void)[TBPlugin_RAM class];
}
