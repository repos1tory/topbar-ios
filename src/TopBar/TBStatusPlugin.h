#import <Foundation/Foundation.h>

/// A TopBar plugin is a normal SpringBoard dylib that exposes one class named
/// TBPlugin_<anything> conforming to this protocol. The host discovers classes
/// by name, so plugins do not need to link against the host.
@protocol TBStatusPlugin <NSObject>

@required
/// Stable identifier. It should match the plugin's manifest Identifier.
- (NSString *)pluginIdentifier;

/// Human-readable name shown in Settings.
- (NSString *)pluginDisplayName;

/// The current text for the status bar.
- (NSString *)statusText;

/// Called by the host on a timer and when the user changes settings.
- (void)refresh;

@optional
/// Return YES if tapping the item should do something.
- (BOOL)wantsTap;

/// Called when the item is tapped.
- (void)handleTap;

- (NSString *)pluginDescription;
- (NSString *)pluginVersion;
- (NSString *)pluginAuthor;

@end
