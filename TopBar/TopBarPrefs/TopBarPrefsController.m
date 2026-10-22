#import "TopBarPrefsController.h"

#import "TBHost.h"
#import "TBPreferences.h"
#import "TBStockItem.h"

#import <objc/runtime.h>

@interface TopBarPrefsController ()
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *items;
@end

@implementation TopBarPrefsController

- (void)setRootController:(id)rootController {
    _rootController = rootController;
}

- (void)setParentController:(id)parentController {
    _parentController = parentController;
}

- (void)setSpecifier:(id)specifier {
    _specifier = specifier;
}

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"TopBar";
    self.tableView.allowsSelectionDuringEditing = YES;
    self.tableView.rowHeight = 58.0;
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    [self reloadItems];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadItems];
    [self.tableView reloadData];
}

- (void)reloadItems {
    NSMutableDictionary<NSString *, NSMutableDictionary *> *byID = [NSMutableDictionary dictionary];

    for (TBStockItem *stock in [TBStockItem catalog]) {
        byID[stock.identifier] = [@{
            @"id": stock.identifier,
            @"name": stock.name ?: stock.identifier,
            @"kind": @"stock",
            @"detail": stock.detail ?: @"System item",
            @"defaultOrder": @(stock.defaultOrder),
        } mutableCopy];
    }

    NSDictionary<NSString *, NSDictionary *> *snapshotByID = [self pluginSnapshotByID];
    NSDictionary<NSString *, NSDictionary *> *manifestByID = [self manifestByID];

    NSMutableSet<NSString *> *pluginIDs = [NSMutableSet set];
    [pluginIDs addObjectsFromArray:snapshotByID.allKeys];
    [pluginIDs addObjectsFromArray:manifestByID.allKeys];

    for (NSString *identifier in pluginIDs) {
        NSDictionary *snapshot = snapshotByID[identifier];
        NSDictionary *manifest = manifestByID[identifier];
        NSString *name = manifest[@"Name"] ?: snapshot[@"Name"] ?: identifier;
        NSString *detail = manifest[@"Description"] ?: snapshot[@"Description"] ?: @"Plugin";
        NSString *version = manifest[@"Version"] ?: snapshot[@"Version"] ?: @"";
        BOOL loaded = [snapshot[@"Loaded"] boolValue];
        NSInteger defaultOrder = [manifest[@"DefaultOrder"] integerValue] ?: [snapshot[@"DefaultOrder"] integerValue];
        if (defaultOrder == 0) defaultOrder = 1000;

        NSString *subtitle = detail;
        if (version.length > 0) {
            subtitle = [NSString stringWithFormat:@"%@ • v%@", detail, version];
        }
        if (snapshot && !loaded) {
            subtitle = [subtitle stringByAppendingString:@" — respring to load"];
        }

        byID[identifier] = [@{
            @"id": identifier,
            @"name": name,
            @"kind": @"plugin",
            @"detail": subtitle,
            @"defaultOrder": @(defaultOrder),
            @"loaded": @(loaded),
        } mutableCopy];
    }

    NSArray<NSString *> *savedOrder = [TBPreferences order];
    NSMutableArray<NSString *> *order = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSString *identifier in savedOrder) {
        if (byID[identifier] && ![seen containsObject:identifier]) {
            [order addObject:identifier];
            [seen addObject:identifier];
        }
    }

    NSArray<NSString *> *remaining = [byID.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSInteger da = [byID[a][@"defaultOrder"] integerValue];
        NSInteger db = [byID[b][@"defaultOrder"] integerValue];
        if (da != db) return da < db ? NSOrderedAscending : NSOrderedDescending;
        return [byID[a][@"name"] compare:byID[b][@"name"]];
    }];
    for (NSString *identifier in remaining) {
        if (![seen containsObject:identifier]) {
            [order addObject:identifier];
            [seen addObject:identifier];
        }
    }

    self.items = [NSMutableArray array];
    for (NSString *identifier in order) {
        [self.items addObject:byID[identifier]];
    }

    [TBPreferences setOrder:order];
}

- (NSDictionary<NSString *, NSDictionary *> *)pluginSnapshotByID {
    id snapshot = [TBPreferences pluginsSnapshot];
    if (![snapshot isKindOfClass:[NSArray class]]) return @{};

    NSMutableDictionary<NSString *, NSDictionary *> *byID = [NSMutableDictionary dictionary];
    for (id row in (NSArray *)snapshot) {
        if (![row isKindOfClass:[NSDictionary class]]) continue;
        NSString *identifier = row[@"Identifier"];
        if ([identifier isKindOfClass:[NSString class]] && identifier.length > 0) {
            byID[identifier] = row;
        }
    }
    return byID;
}

- (NSDictionary<NSString *, NSDictionary *> *)manifestByID {
    NSMutableDictionary<NSString *, NSDictionary *> *byID = [NSMutableDictionary dictionary];
    NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:TBPluginsDirectory error:NULL];
    for (NSString *file in files) {
        if (![file.pathExtension.lowercaseString isEqualToString:@"plist"]) continue;
        NSDictionary *manifest = [NSDictionary dictionaryWithContentsOfFile:[TBPluginsDirectory stringByAppendingPathComponent:file]];
        if (![manifest isKindOfClass:[NSDictionary class]]) continue;
        NSString *identifier = manifest[@"Identifier"];
        if ([identifier isKindOfClass:[NSString class]] && identifier.length > 0) {
            byID[identifier] = manifest;
        }
    }
    return byID;
}

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? (NSInteger)self.items.count : 2;
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Top Bar Items" : @"Actions";
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"Drag the handles to reorder the bar from left to right. Switch an item off to hide it. Tap Edit to reorder. Stock items are live system indicators; plugins come from installed packages.";
    }
    return @"Changes apply to SpringBoard immediately. A newly installed plugin dylib needs one respring before SpringBoard can load it.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"TopBarCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
        cell.textLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        cell.detailTextLabel.numberOfLines = 2;
    }

    if (indexPath.section == 1) {
        cell.accessoryView = nil;
        cell.editingAccessoryView = nil;
        cell.showsReorderControl = NO;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.accessibilityTraits = UIAccessibilityTraitButton;
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Reload Plugins";
            cell.detailTextLabel.text = @"Scan for newly installed plugin manifests";
        } else {
            cell.textLabel.text = @"Reset to Defaults";
            cell.detailTextLabel.text = @"Restore the default order and enable everything";
        }
        return cell;
    }

    NSDictionary *item = self.items[(NSUInteger)indexPath.row];
    NSString *itemIdentifier = item[@"id"];
    cell.textLabel.text = item[@"name"];
    cell.detailTextLabel.text = item[@"detail"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.showsReorderControl = YES;

    UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
    toggle.on = [TBPreferences isEnabledForIdentifier:itemIdentifier];
    toggle.tag = indexPath.row;
    objc_setAssociatedObject(toggle, "TopBarIdentifier", itemIdentifier, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    cell.editingAccessoryView = nil;

    return cell;
}

- (BOOL)tableView:(__unused UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0;
}

- (BOOL)tableView:(__unused UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0;
}

- (UITableViewCellEditingStyle)tableView:(__unused UITableView *)tableView editingStyleForRowAtIndexPath:(__unused NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(__unused UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(__unused NSIndexPath *)indexPath {
    return NO;
}

- (NSIndexPath *)tableView:(__unused UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
    if (proposedDestinationIndexPath.section != 0) return sourceIndexPath;
    return proposedDestinationIndexPath;
}

- (void)tableView:(__unused UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if (sourceIndexPath.section != 0 || destinationIndexPath.section != 0) return;
    if (sourceIndexPath.row == destinationIndexPath.row) return;

    NSMutableDictionary *item = self.items[(NSUInteger)sourceIndexPath.row];
    [self.items removeObjectAtIndex:(NSUInteger)sourceIndexPath.row];
    [self.items insertObject:item atIndex:(NSUInteger)destinationIndexPath.row];
    [self saveOrder];
}

- (void)saveOrder {
    NSMutableArray<NSString *> *order = [NSMutableArray array];
    for (NSDictionary *item in self.items) [order addObject:item[@"id"]];
    [TBPreferences setOrder:order];
    [TBPreferences notifyChanged];
}

- (void)toggleChanged:(UISwitch *)sender {
    NSString *identifier = objc_getAssociatedObject(sender, "TopBarIdentifier");
    if (identifier.length == 0) return;

    NSMutableDictionary<NSString *, NSNumber *> *enabled = [[TBPreferences enabled] mutableCopy];
    enabled[identifier] = @(sender.isOn);
    [TBPreferences setEnabled:enabled];
    [TBPreferences notifyChanged];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 1) return;

    if (indexPath.row == 0) {
        [TBPreferences notifyChanged];
        [self reloadItems];
        [self.tableView reloadData];
    } else {
        [TBPreferences setOrder:@[]];
        [TBPreferences setEnabled:@{}];
        [TBPreferences notifyChanged];
        [self reloadItems];
        [self.tableView reloadData];
    }
}

@end
