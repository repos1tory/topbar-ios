#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <mach/processor_info.h>

#import "TBStatusPlugin.h"

@interface TBPlugin_CPU : NSObject <TBStatusPlugin>
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) uint64_t lastTotal;
@property (nonatomic, assign) uint64_t lastBusy;
@end

@implementation TBPlugin_CPU

- (instancetype)init {
    self = [super init];
    if (self) [self refresh];
    return self;
}

- (NSString *)pluginIdentifier { return @"cpu.load"; }
- (NSString *)pluginDisplayName { return @"CPU"; }
- (NSString *)pluginDescription { return @"System CPU load percentage."; }
- (NSString *)pluginVersion { return @"0.1.0"; }
- (NSString *)pluginAuthor { return @"alsinas"; }
- (BOOL)wantsTap { return NO; }

- (void)refresh {
    natural_t cpuCount = 0;
    processor_info_array_t info = NULL;
    mach_msg_type_number_t infoCount = 0;
    kern_return_t result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                               &cpuCount, &info, &infoCount);
    if (result != KERN_SUCCESS || !info) {
        self.text = @"C--";
        return;
    }

    uint64_t total = 0;
    uint64_t busy = 0;
    processor_cpu_load_info_t load = (processor_cpu_load_info_t)info;
    for (natural_t i = 0; i < cpuCount; i++) {
        uint64_t user = load[i].cpu_ticks[CPU_STATE_USER];
        uint64_t system = load[i].cpu_ticks[CPU_STATE_SYSTEM];
        uint64_t nice = load[i].cpu_ticks[CPU_STATE_NICE];
        uint64_t idle = load[i].cpu_ticks[CPU_STATE_IDLE];
        total += user + system + nice + idle;
        busy += user + system + nice;
    }
    vm_deallocate(mach_task_self(), (vm_address_t)info, infoCount * sizeof(integer_t));

    double percent = 0;
    if (self.lastTotal > 0 && total > self.lastTotal) {
        percent = (double)(busy - self.lastBusy) * 100.0 / (double)(total - self.lastTotal);
    }
    self.lastTotal = total;
    self.lastBusy = busy;
    self.text = [NSString stringWithFormat:@"C%.0f%%", MAX(0.0, MIN(100.0, percent))];
}

- (NSString *)statusText {
    return self.text ?: @"C--";
}

@end

__attribute__((constructor))
static void TBPluginCPUConstructor(void) {
    (void)[TBPlugin_CPU class];
}
