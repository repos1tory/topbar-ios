#import <Foundation/Foundation.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <net/if_var.h>

#import "TBStatusPlugin.h"

@interface TBPlugin_NetworkSpeed : NSObject <TBStatusPlugin>
@property (nonatomic, assign) uint64_t lastRx;
@property (nonatomic, assign) uint64_t lastTx;
@property (nonatomic, assign) NSTimeInterval lastTime;
@property (nonatomic, copy) NSString *text;
@end

@implementation TBPlugin_NetworkSpeed

- (instancetype)init {
    self = [super init];
    if (self) [self refresh];
    return self;
}

- (NSString *)pluginIdentifier { return @"network.speed"; }
- (NSString *)pluginDisplayName { return @"Network Speed"; }
- (NSString *)pluginDescription { return @"Live download and upload throughput."; }
- (NSString *)pluginVersion { return @"0.1.0"; }
- (NSString *)pluginAuthor { return @"alsinas"; }
- (BOOL)wantsTap { return NO; }

static void TBNetworkBytes(uint64_t *rx, uint64_t *tx) {
    *rx = 0;
    *tx = 0;
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) != 0) return;
    for (struct ifaddrs *interface = interfaces; interface; interface = interface->ifa_next) {
        if (!interface->ifa_addr || interface->ifa_addr->sa_family != AF_LINK || !interface->ifa_data) continue;
        if (!interface->ifa_name) continue;
        if (strcmp(interface->ifa_name, "en0") != 0 && strcmp(interface->ifa_name, "pdp_ip0") != 0) continue;
        struct if_data *data = (struct if_data *)interface->ifa_data;
        *rx += (uint64_t)data->ifi_ibytes;
        *tx += (uint64_t)data->ifi_obytes;
    }
    freeifaddrs(interfaces);
}

static NSString *TBRate(uint64_t bytes, double seconds) {
    if (seconds <= 0) return @"0";
    double value = (double)bytes / seconds;
    if (value >= 1000000000.0) return [NSString stringWithFormat:@"%.1fG", value / 1000000000.0];
    if (value >= 1000000.0) return [NSString stringWithFormat:@"%.1fM", value / 1000000.0];
    if (value >= 1000.0) return [NSString stringWithFormat:@"%.0fK", value / 1000.0];
    return [NSString stringWithFormat:@"%.0f", value];
}

- (void)refresh {
    uint64_t rx = 0, tx = 0;
    TBNetworkBytes(&rx, &tx);
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];

    if (self.lastTime > 0 && now > self.lastTime) {
        double seconds = now - self.lastTime;
        uint64_t deltaRx = rx >= self.lastRx ? rx - self.lastRx : 0;
        uint64_t deltaTx = tx >= self.lastTx ? tx - self.lastTx : 0;
        self.text = [NSString stringWithFormat:@"↓%@ ↑%@", TBRate(deltaRx, seconds), TBRate(deltaTx, seconds)];
    } else {
        self.text = @"↓0 ↑0";
    }

    self.lastRx = rx;
    self.lastTx = tx;
    self.lastTime = now;
}

- (NSString *)statusText {
    return self.text ?: @"↓0 ↑0";
}

@end

__attribute__((constructor))
static void TBPluginNetworkSpeedConstructor(void) {
    (void)[TBPlugin_NetworkSpeed class];
}
