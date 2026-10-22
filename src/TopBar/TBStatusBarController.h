#import <UIKit/UIKit.h>

@class STUIStatusBar;

@interface TBStatusBarController : NSObject

- (instancetype)initWithStatusBar:(STUIStatusBar *)bar;
- (void)update;

@end
