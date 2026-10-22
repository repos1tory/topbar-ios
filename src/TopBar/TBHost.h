#import <Foundation/Foundation.h>

#define TBPreferencesDomain CFSTR("com.alsinas.topbar")
#define TBPluginsDirectory @"/var/jb/Library/TopBar/Plugins"
#define TBStockItemsPath @"/var/jb/Library/TopBar/StockItems.plist"
#define TBDebugLogPath @"/var/jb/tmp/topbar-debug.txt"

static NSString *const TBPreferencesChangedNotificationName = @"com.alsinas.topbar/prefsChanged";
static NSString *const TBPluginDidUpdateNotificationName = @"TBStatusPluginDidUpdateNotification";
static NSString *const TBPluginRegistryDidChangeNotificationName = @"TBPluginRegistryDidChangeNotification";

static NSString *const TBOrderKey = @"Order";
static NSString *const TBEnabledKey = @"Enabled";
