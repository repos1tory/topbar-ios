#import <Foundation/Foundation.h>

#import "TBStatusPlugin.h"
#import "TBHost.h"

@interface TBPlugin_SunMoon : NSObject <TBStatusPlugin>
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *sunrise;
@property (nonatomic, copy) NSString *sunset;
@property (nonatomic, copy) NSString *moon;
@property (nonatomic, assign) NSInteger mode;
@property (nonatomic, assign) NSTimeInterval lastFetch;
@property (nonatomic, assign) BOOL fetching;
@end

@implementation TBPlugin_SunMoon

- (instancetype)init {
    self = [super init];
    if (self) [self refresh];
    return self;
}

- (NSString *)pluginIdentifier { return @"sun.moon"; }
- (NSString *)pluginDisplayName { return @"Sun & Moon"; }
- (NSString *)pluginDescription { return @"Sunrise, sunset, and moon phase. Tap to cycle."; }
- (NSString *)pluginVersion { return @"0.1.0"; }
- (NSString *)pluginAuthor { return @"alsinas"; }
- (BOOL)wantsTap { return YES; }

- (NSString *)shortTime:(NSString *)time {
    if (time.length >= 5) return [time substringToIndex:5];
    return time;
}

- (void)updateText {
    switch (self.mode % 3) {
        case 0:
            self.text = self.sunrise.length > 0 ? [NSString stringWithFormat:@"↑%@", [self shortTime:self.sunrise]] : @"--";
            break;
        case 1:
            self.text = self.sunset.length > 0 ? [NSString stringWithFormat:@"↓%@", [self shortTime:self.sunset]] : @"--";
            break;
        default:
            self.text = self.moon.length > 0 ? self.moon : @"☾";
            break;
    }
}

- (void)refresh {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (self.sunrise.length > 0 && now - self.lastFetch < 21600.0) {
        [self updateText];
        return;
    }
    [self fetchSunMoon];
}

- (void)fetchSunMoon {
    if (self.fetching) return;
    self.fetching = YES;

    NSURL *url = [NSURL URLWithString:@"https://wttr.in/?format=%S|%s|%m"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:10.0];
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            NSString *sunrise = nil;
            NSString *sunset = nil;
            NSString *moon = nil;
            NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
            if (!error && http.statusCode == 200 && data.length > 0) {
                NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                body = [body stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                NSArray<NSString *> *parts = [body componentsSeparatedByString:@"|"];
                if (parts.count >= 1) sunrise = [parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (parts.count >= 2) sunset = [parts[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (parts.count >= 3) moon = [parts[2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                self.fetching = NO;
                if (sunrise.length > 0) {
                    self.sunrise = sunrise;
                    self.sunset = sunset ?: @"";
                    self.moon = moon ?: @"";
                    self.lastFetch = [NSDate timeIntervalSinceReferenceDate];
                    [self updateText];
                    [[NSNotificationCenter defaultCenter] postNotificationName:TBPluginDidUpdateNotificationName object:self];
                }
            });
        }];
    [task resume];
}

- (NSString *)statusText {
    return self.text.length > 0 ? self.text : @"--";
}

- (void)handleTap {
    self.mode = (self.mode + 1) % 3;
    [self updateText];
    if (self.sunrise.length == 0) [self fetchSunMoon];
    [[NSNotificationCenter defaultCenter] postNotificationName:TBPluginDidUpdateNotificationName object:self];
}

@end

__attribute__((constructor))
static void TBPluginSunMoonConstructor(void) {
    (void)[TBPlugin_SunMoon class];
}
