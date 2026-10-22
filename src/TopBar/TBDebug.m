#import "TBDebug.h"
#import "TBHost.h"

#ifdef DEBUG
void TBDebugLog(NSString *format, ...) {
    static NSMutableArray<NSString *> *lines;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        lines = [NSMutableArray array];
    });
    if (lines.count >= 300) return;

    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSString *stamp = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                    dateStyle:NSDateFormatterNoStyle
                                                    timeStyle:NSDateFormatterMediumStyle];
    [lines addObject:[NSString stringWithFormat:@"%@ %@", stamp, message]];
    NSArray<NSString *> *snapshot = [lines copy];
    NSString *text = [snapshot componentsJoinedByString:@"\n"];
    [text writeToFile:TBDebugLogPath
           atomically:YES
             encoding:NSUTF8StringEncoding
                error:NULL];
}
#endif
