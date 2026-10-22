#import <Foundation/Foundation.h>

#import "TBHost.h"
#import "TBStatusPlugin.h"

#import <arpa/inet.h>
#import <ifaddrs.h>
#import <net/if.h>

static NSString *TBIPPreferencesPath(void) {
    return @"/var/mobile/Library/Preferences/com.alsinas.topbar.ip.plist";
}

static BOOL TBIPPublicMode(void) {
    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:TBIPPreferencesPath()];
    return [dictionary[@"IPPublicMode"] boolValue];
}

static void TBSetIPPublicMode(BOOL publicMode) {
    NSDictionary *dictionary = @{ @"IPPublicMode": @(publicMode) };
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dictionary
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:NULL];
    if (data) [data writeToFile:TBIPPreferencesPath() atomically:YES];
}

@interface TBPlugin_IP : NSObject <TBStatusPlugin>
@property (nonatomic, assign) BOOL publicMode;
@property (nonatomic, copy) NSString *localIP;
@property (nonatomic, copy) NSString *publicIP;
@property (nonatomic, assign) NSTimeInterval lastPublicFetch;
@property (nonatomic, assign) BOOL fetching;
@end

@implementation TBPlugin_IP

- (instancetype)init {
    self = [super init];
    if (self) {
        _publicMode = TBIPPublicMode();
        [self refreshLocalIP];
    }
    return self;
}

- (NSString *)pluginIdentifier {
    return @"ip.address";
}

- (NSString *)pluginDisplayName {
    return @"IP Address";
}

- (NSString *)pluginDescription {
    return @"Local or public IP address. Tap to switch.";
}

- (NSString *)pluginVersion {
    return @"0.1.0";
}

- (NSString *)pluginAuthor {
    return @"alsinas";
}

- (BOOL)wantsTap {
    return YES;
}

- (NSString *)statusText {
    NSString *address = self.publicMode ? self.publicIP : self.localIP;
    if (address.length == 0) return @"--";
    return [NSString stringWithFormat:@"%@%@", self.publicMode ? @"W:" : @"L:", address];
}

- (void)refresh {
    [self refreshLocalIP];
    if (!self.publicMode) return;
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (self.publicIP.length == 0 || now - self.lastPublicFetch > 300.0) {
        [self fetchPublicIP];
    }
}

- (void)handleTap {
    self.publicMode = !self.publicMode;
    TBSetIPPublicMode(self.publicMode);

    if (self.publicMode) {
        [self fetchPublicIP];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:TBPluginDidUpdateNotificationName object:self];
}

- (void)refreshLocalIP {
    NSString *address = nil;
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) == 0) {
        address = [self addressFromInterfaces:interfaces preferredInterface:"en0"];
        if (address.length == 0) {
            address = [self addressFromInterfaces:interfaces preferredInterface:"pdp_ip0"];
        }
        if (address.length == 0) {
            address = [self addressFromInterfaces:interfaces preferredInterface:NULL];
        }
        freeifaddrs(interfaces);
    }
    self.localIP = address;
}

- (NSString *)addressFromInterfaces:(struct ifaddrs *)interfaces preferredInterface:(const char *)preferred {
    NSString *fallback = nil;
    for (struct ifaddrs *interface = interfaces; interface != NULL; interface = interface->ifa_next) {
        if (!interface->ifa_addr || interface->ifa_addr->sa_family != AF_INET) continue;
        if (!(interface->ifa_flags & IFF_UP) || (interface->ifa_flags & IFF_LOOPBACK)) continue;

        char buffer[INET_ADDRSTRLEN] = {0};
        struct sockaddr_in *addr = (struct sockaddr_in *)interface->ifa_addr;
        if (!inet_ntop(AF_INET, &addr->sin_addr, buffer, sizeof(buffer))) continue;
        NSString *address = [NSString stringWithUTF8String:buffer];
        if (address.length == 0) continue;
        if ([address hasPrefix:@"169.254."]) continue;

        if (preferred && interface->ifa_name && strcmp(interface->ifa_name, preferred) == 0) {
            return address;
        }
        if (!fallback) fallback = address;
    }
    return fallback;
}

- (void)fetchPublicIP {
    if (self.fetching) return;
    self.fetching = YES;

    NSURL *url = [NSURL URLWithString:@"https://api.ipify.org"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:8.0];
    request.HTTPMethod = @"GET";

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            NSString *address = nil;
            NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
            if (!error && http.statusCode == 200 && data.length > 0) {
                NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (text.length > 0 && text.length <= 64 &&
                    [text rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location == NSNotFound) {
                    address = text;
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                self.fetching = NO;
                if (address.length > 0) {
                    self.publicIP = address;
                    self.lastPublicFetch = [NSDate timeIntervalSinceReferenceDate];
                    [[NSNotificationCenter defaultCenter] postNotificationName:TBPluginDidUpdateNotificationName object:self];
                }
            });
        }];
    [task resume];
}

@end

__attribute__((constructor))
static void TBPluginIPConstructor(void) {
    (void)[TBPlugin_IP class];
}
