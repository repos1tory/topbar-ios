#import <Foundation/Foundation.h>

@interface TBStockItem : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, assign) NSInteger defaultOrder;

/// The catalog installed at /var/jb/Library/TopBar/StockItems.plist.
+ (NSArray<TBStockItem *> *)catalog;

/// Maps a private STUIStatusBar display-item identifier to our stable stock id.
+ (NSString *)identifierForDisplayItemIdentifier:(NSString *)identifier;

+ (NSString *)titleForIdentifier:(NSString *)identifier;

@end
