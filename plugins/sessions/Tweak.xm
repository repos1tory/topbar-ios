#import <Foundation/Foundation.h>

#import "TBStatusPlugin.h"
#import "TBHost.h"

@interface TBPlugin_Sessions : NSObject <TBStatusPlugin>
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) BOOL fetching;
@end

@implementation TBPlugin_Sessions

- (instancetype)init {
    self = [super init];
    if (self) [self refresh];
    return self;
}

- (NSString *)pluginIdentifier { return @"opencode.sessions"; }
- (NSString *)pluginDisplayName { return @"OpenCode Sessions"; }
- (NSString *)pluginDescription { return @"Number of running OpenCode sessions."; }
- (NSString *)pluginVersion { return @"0.1.0"; }
- (NSString *)pluginAuthor { return @"alsinas"; }
- (BOOL)wantsTap { return NO; }

- (void)refresh {
    if (self.fetching) return;
    self.fetching = YES;

    NSURL *url = [NSURL URLWithString:@"http://127.0.0.1:4097/api/session/active"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:3.0];
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            NSInteger count = -1;
            NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
            if (!error && http.statusCode == 200 && data.length > 0) {
                id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                id payload = [json isKindOfClass:[NSDictionary class]] ? json[@"data"] : nil;
                if ([payload isKindOfClass:[NSDictionary class]]) {
                    count = (NSInteger)[(NSDictionary *)payload count];
                } else if ([payload isKindOfClass:[NSArray class]]) {
                    count = (NSInteger)[(NSArray *)payload count];
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                self.fetching = NO;
                self.text = count >= 0 ? [NSString stringWithFormat:@"S:%ld", (long)count] : @"S:--";
                [[NSNotificationCenter defaultCenter] postNotificationName:TBPluginDidUpdateNotificationName object:self];
            });
        }];
    [task resume];
}

- (NSString *)statusText {
    return self.text.length > 0 ? self.text : @"S:--";
}

@end

__attribute__((constructor))
static void TBPluginSessionsConstructor(void) {
    (void)[TBPlugin_Sessions class];
}
