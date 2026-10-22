#import <Foundation/Foundation.h>

#import "TBStatusPlugin.h"
#import "TBHost.h"

@interface TBPlugin_Weather : NSObject <TBStatusPlugin>
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) NSTimeInterval lastFetch;
@property (nonatomic, assign) BOOL fetching;
@end

@implementation TBPlugin_Weather

- (instancetype)init {
    self = [super init];
    if (self) [self refresh];
    return self;
}

- (NSString *)pluginIdentifier { return @"weather"; }
- (NSString *)pluginDisplayName { return @"Weather"; }
- (NSString *)pluginDescription { return @"Current temperature and conditions from wttr.in."; }
- (NSString *)pluginVersion { return @"0.1.0"; }
- (NSString *)pluginAuthor { return @"alsinas"; }
- (BOOL)wantsTap { return YES; }

static NSString *TBWeatherSymbol(NSString *condition) {
    NSString *lower = condition.lowercaseString;
    if ([lower containsString:@"thunder"] || [lower containsString:@"storm"]) return @"⚡";
    if ([lower containsString:@"snow"] || [lower containsString:@"sleet"] || [lower containsString:@"ice"]) return @"❄";
    if ([lower containsString:@"rain"] || [lower containsString:@"drizzle"] || [lower containsString:@"shower"]) return @"☂";
    if ([lower containsString:@"fog"] || [lower containsString:@"mist"] || [lower containsString:@"cloud"] || [lower containsString:@"overcast"]) return @"☁";
    if ([lower containsString:@"sun"] || [lower containsString:@"clear"]) return @"☀";
    return @"";
}

- (void)refresh {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (self.fetching) return;
    if (self.text.length > 0 && now - self.lastFetch < 900.0) return;
    [self fetchWeather];
}

- (void)fetchWeather {
    if (self.fetching) return;
    self.fetching = YES;

    NSURL *url = [NSURL URLWithString:@"https://wttr.in/?format=%t|%C"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:10.0];
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            __block NSString *temperature = nil;
            NSString *condition = nil;
            NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
            if (!error && http.statusCode == 200 && data.length > 0) {
                NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                body = [body stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                NSArray<NSString *> *parts = [body componentsSeparatedByString:@"|"];
                if (parts.count >= 1) temperature = [parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (parts.count >= 2) condition = [parts[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                self.fetching = NO;
                if (temperature.length > 0) {
                    if ([temperature hasPrefix:@"+"]) temperature = [temperature substringFromIndex:1];
                    NSString *symbol = condition.length > 0 ? TBWeatherSymbol(condition) : @"";
                    self.text = symbol.length > 0 ? [NSString stringWithFormat:@"%@ %@", temperature, symbol] : temperature;
                    self.lastFetch = [NSDate timeIntervalSinceReferenceDate];
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
    self.lastFetch = 0;
    [self fetchWeather];
}

@end

__attribute__((constructor))
static void TBPluginWeatherConstructor(void) {
    (void)[TBPlugin_Weather class];
}
