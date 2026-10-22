#import "TopBarPrefsController.h"

#import "TBHost.h"
#import "TBPreferences.h"
#import "TBStockItem.h"

#import <objc/runtime.h>

@interface TopBarPrefsController ()
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *leftItems;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *rightItems;
@end

@implementation TopBarPrefsController

- (void)setRootController:(id)rootController { _rootController = rootController; }
- (void)setParentController:(id)parentController { _parentController = parentController; }
- (void)setSpecifier:(id)specifier { _specifier = specifier; }

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
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

- (NSDictionary<NSString *, NSDictionary *> *)pluginSnapshotByID {
    id snapshot = [TBPreferences pluginsSnapshot];
    if (![snapshot isKindOfClass:[NSArray class]]) return @{};
    NSMutableDictionary<NSString *, NSDictionary *> *byID = [NSMutableDictionary dictionary];
    for (id row in (NSArray *)snapshot) {
        if (![row isKindOfClass:[NSDictionary class]]) continue;
        NSString *identifier = row[@"Identifier"];
        if ([identifier isKindOfClass:[NSString class]] && identifier.length > 0) byID[identifier] = row;
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
        if ([identifier isKindOfClass:[NSString class]] && identifier.length > 0) byID[identifier] = manifest;
    }
    return byID;
}

- (void)reloadItems {
    NSMutableDictionary<NSString *, NSMutableDictionary *> *byID = [NSMutableDictionary dictionary];

    for (TBStockItem *stock in [TBStockItem catalog]) {
        NSString *side = stock.side ?: @"right";
        byID[stock.identifier] = [@{
            @"id": stock.identifier,
            @"name": stock.name ?: stock.identifier,
            @"kind": @"stock",
            @"side": side,
            @"detail": stock.detail ?: @"System item",
            @"defaultOrder": @(stock.defaultOrder),
        } mutableCopy];
    }

    NSDictionary<NSString *, NSDictionary *> *snapshotByID = [self pluginSnapshotByID];
    NSDictionary<NSString *, NSDictionary *> *manifestByID = [self manifestByID];
    NSDictionary<NSString *, NSString *> *sideOverrides = [TBPreferences sides];
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

        NSString *side = sideOverrides[identifier];
        if (![side isEqualToString:@"left"] && ![side isEqualToString:@"right"]) {
            side = manifest[@"Side"] ?: snapshot[@"Side"] ?: @"right";
            if (![side isEqualToString:@"left"] && ![side isEqualToString:@"right"]) side = @"right";
        }

        NSString *subtitle = detail;
        if (version.length > 0) subtitle = [NSString stringWithFormat:@"%@ • v%@", detail, version];
        if (snapshot && !loaded) subtitle = [subtitle stringByAppendingString:@" — respring to load"];

        byID[identifier] = [@{
            @"id": identifier,
            @"name": name,
            @"kind": @"plugin",
            @"side": side,
            @"detail": subtitle,
            @"defaultOrder": @(defaultOrder),
            @"loaded": @(loaded),
        } mutableCopy];
    }

    NSArray<NSString *> *leftSaved = [TBPreferences leftOrder];
    NSArray<NSString *> *rightSaved = [TBPreferences rightOrder];
    if (!leftSaved && !rightSaved) {
        NSArray<NSString *> *legacy = [TBPreferences order];
        NSMutableArray<NSString *> *left = [NSMutableArray array];
        NSMutableArray<NSString *> *right = [NSMutableArray array];
        for (NSString *identifier in legacy) {
            NSDictionary *item = byID[identifier];
            if (!item) continue;
            if ([item[@"side"] isEqualToString:@"left"]) [left addObject:identifier];
            else [right addObject:identifier];
        }
        leftSaved = left;
        rightSaved = right;
    }

    self.leftItems = [self orderedItemsForSide:@"left" saved:leftSaved byID:byID];
    self.rightItems = [self orderedItemsForSide:@"right" saved:rightSaved byID:byID];

    NSMutableArray<NSString *> *leftOrder = [NSMutableArray array];
    for (NSDictionary *item in self.leftItems) [leftOrder addObject:item[@"id"]];
    NSMutableArray<NSString *> *rightOrder = [NSMutableArray array];
    for (NSDictionary *item in self.rightItems) [rightOrder addObject:item[@"id"]];

    NSMutableDictionary<NSString *, NSString *> *sides = [NSMutableDictionary dictionary];
    for (NSString *identifier in pluginIDs) {
        NSDictionary *item = byID[identifier];
        if ([item[@"kind"] isEqualToString:@"plugin"]) sides[identifier] = item[@"side"];
    }

    [TBPreferences setLeftOrder:leftOrder];
    [TBPreferences setRightOrder:rightOrder];
    [TBPreferences setSides:sides];
    [TBPreferences setOrder:[leftOrder arrayByAddingObjectsFromArray:rightOrder]];
}

- (NSMutableArray<NSMutableDictionary *> *)orderedItemsForSide:(NSString *)side
                                                        saved:(NSArray<NSString *> *)saved
                                                         byID:(NSDictionary<NSString *, NSMutableDictionary *> *)byID {
    NSMutableArray<NSString *> *order = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSString *identifier in saved) {
        NSDictionary *item = byID[identifier];
        if (!item || ![item[@"side"] isEqualToString:side] || [seen containsObject:identifier]) continue;
        [order addObject:identifier];
        [seen addObject:identifier];
    }

    NSArray<NSString *> *remaining = [byID.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSDictionary *ia = byID[a];
        NSDictionary *ib = byID[b];
        if (![ia[@"side"] isEqualToString:side] || ![ib[@"side"] isEqualToString:side]) return NSOrderedSame;
        NSInteger da = [ia[@"defaultOrder"] integerValue];
        NSInteger db = [ib[@"defaultOrder"] integerValue];
        if (da != db) return da < db ? NSOrderedAscending : NSOrderedDescending;
        return [ia[@"name"] compare:ib[@"name"]];
    }];
    for (NSString *identifier in remaining) {
        NSDictionary *item = byID[identifier];
        if (![item[@"side"] isEqualToString:side] || [seen containsObject:identifier]) continue;
        [order addObject:identifier];
        [seen addObject:identifier];
    }

    NSMutableArray<NSMutableDictionary *> *items = [NSMutableArray array];
    for (NSString *identifier in order) [items addObject:byID[identifier]];
    return items;
}

- (NSArray<NSMutableDictionary *> *)itemsForSection:(NSInteger)section {
    if (section == 0) return self.leftItems;
    if (section == 1) return self.rightItems;
    return @[];
}

- (NSDictionary *)itemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSMutableDictionary *> *items = [self itemsForSection:indexPath.section];
    if (indexPath.row < 0 || indexPath.row >= (NSInteger)items.count) return nil;
    return items[(NSUInteger)indexPath.row];
}

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return (NSInteger)self.leftItems.count;
    if (section == 1) return (NSInteger)self.rightItems.count;
    return 2;
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Left Side";
    if (section == 1) return @"Right Side";
    return @"Actions";
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"Time & Date and left-side plugins. Tap Edit to reorder; drag a plugin between Left and Right to move it.";
    }
    if (section == 1) {
        return @"Stock right-side items and plugins. Switch an item off to hide it.";
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

    if (indexPath.section == 2) {
        cell.accessoryView = nil;
        cell.editingAccessoryView = nil;
        cell.showsReorderControl = NO;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Reload Plugins";
            cell.detailTextLabel.text = @"Scan for newly installed plugin manifests";
        } else {
            cell.textLabel.text = @"Reset to Defaults";
            cell.detailTextLabel.text = @"Restore the default order and enable everything";
        }
        return cell;
    }

    NSDictionary *item = [self itemAtIndexPath:indexPath];
    NSString *itemIdentifier = item[@"id"];
    cell.textLabel.text = item[@"name"];
    cell.detailTextLabel.text = item[@"detail"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.showsReorderControl = YES;

    UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
    toggle.on = [TBPreferences isEnabledForIdentifier:itemIdentifier];
    objc_setAssociatedObject(toggle, "TopBarIdentifier", itemIdentifier, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    cell.editingAccessoryView = nil;
    return cell;
}

- (BOOL)tableView:(__unused UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0 || indexPath.section == 1;
}

- (BOOL)tableView:(__unused UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0 || indexPath.section == 1;
}

- (UITableViewCellEditingStyle)tableView:(__unused UITableView *)tableView editingStyleForRowAtIndexPath:(__unused NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(__unused UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(__unused NSIndexPath *)indexPath {
    return NO;
}

- (NSIndexPath *)tableView:(__unused UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
    if (proposedDestinationIndexPath.section == 2) return sourceIndexPath;
    NSDictionary *item = [self itemAtIndexPath:sourceIndexPath];
    if (!item) return sourceIndexPath;

    NSInteger destinationSection = proposedDestinationIndexPath.section;
    if (![item[@"kind"] isEqualToString:@"plugin"] && destinationSection != sourceIndexPath.section) {
        return sourceIndexPath;
    }
    if ([item[@"kind"] isEqualToString:@"plugin"] && destinationSection != 0 && destinationSection != 1) {
        return sourceIndexPath;
    }
    NSArray *destination = [self itemsForSection:destinationSection];
    NSInteger row = proposedDestinationIndexPath.row;
    if (row < 0) row = 0;
    if (row > (NSInteger)destination.count) row = (NSInteger)destination.count;
    return [NSIndexPath indexPathForRow:row inSection:destinationSection];
}

- (void)tableView:(__unused UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if (sourceIndexPath.section == 2 || destinationIndexPath.section == 2) return;
    NSMutableArray<NSMutableDictionary *> *source = sourceIndexPath.section == 0 ? self.leftItems : self.rightItems;
    NSMutableArray<NSMutableDictionary *> *destination = destinationIndexPath.section == 0 ? self.leftItems : self.rightItems;
    if (sourceIndexPath.row < 0 || sourceIndexPath.row >= (NSInteger)source.count) return;

    NSMutableDictionary *item = source[(NSUInteger)sourceIndexPath.row];
    [source removeObjectAtIndex:(NSUInteger)sourceIndexPath.row];
    NSInteger row = MIN(destinationIndexPath.row, (NSInteger)destination.count);
    [destination insertObject:item atIndex:(NSUInteger)row];
    if (sourceIndexPath.section != destinationIndexPath.section && [item[@"kind"] isEqualToString:@"plugin"]) {
        item[@"side"] = destinationIndexPath.section == 0 ? @"left" : @"right";
    }
    [self saveOrder];
}

- (void)saveOrder {
    NSMutableArray<NSString *> *leftOrder = [NSMutableArray array];
    for (NSDictionary *item in self.leftItems) [leftOrder addObject:item[@"id"]];
    NSMutableArray<NSString *> *rightOrder = [NSMutableArray array];
    for (NSDictionary *item in self.rightItems) [rightOrder addObject:item[@"id"]];

    NSMutableDictionary<NSString *, NSString *> *sides = [[TBPreferences sides] mutableCopy];
    for (NSDictionary *item in self.leftItems) {
        if ([item[@"kind"] isEqualToString:@"plugin"]) sides[item[@"id"]] = @"left";
    }
    for (NSDictionary *item in self.rightItems) {
        if ([item[@"kind"] isEqualToString:@"plugin"]) sides[item[@"id"]] = @"right";
    }

    [TBPreferences setLeftOrder:leftOrder];
    [TBPreferences setRightOrder:rightOrder];
    [TBPreferences setSides:sides];
    [TBPreferences setOrder:[leftOrder arrayByAddingObjectsFromArray:rightOrder]];
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
    if (indexPath.section != 2) return;

    if (indexPath.row == 0) {
        [TBPreferences notifyChanged];
    } else {
        [TBPreferences setOrder:@[]];
        [TBPreferences setLeftOrder:@[]];
        [TBPreferences setRightOrder:@[]];
        [TBPreferences setEnabled:@{}];
        [TBPreferences setSides:@{}];
        [TBPreferences notifyChanged];
    }
    [self reloadItems];
    [self.tableView reloadData];
}

@end
