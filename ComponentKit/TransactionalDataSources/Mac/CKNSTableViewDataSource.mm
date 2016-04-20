/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "CKNSTableViewDataSource.h"


#import <ComponentKit/CKArgumentPrecondition.h>
#import <ComponentKit/CKAssert.h>
#import <ComponentKit/CKMacros.h>

#import "CKComponentLayout.h"
#import "CKTransactionalComponentDataSource.h"
#import "CKTransactionalComponentDataSourceState.h"
#import "CKTransactionalComponentDataSourceListener.h"
#import "CKTransactionalComponentDataSourceItem.h"
#import "CKTransactionalComponentDataSourceAppliedChanges.h"
#import "CKTransactionalComponentDataSourceChangeset.h"
#import "CKComponentDataSourceAttachController.h"

#import "CKComponent.h"

#import "CKComponentRootView.h"
#import "CKComponentScopeRoot.h"
#import "CKTransactionalComponentDataSourceConfiguration.h"

NSString *const CKNSTableViewDataSourceSelectionKey = @"selection";

@interface CKNSTableViewDataSource () <CKTransactionalComponentDataSourceListener>
@end

@implementation CKNSTableViewDataSource
{
  CKTransactionalComponentDataSourceConfiguration *_config;
  CKTransactionalComponentDataSource *_componentDataSource;
  CKComponentDataSourceAttachController *_attachController;
}

CK_FINAL_CLASS([CKNSTableViewDataSource class]);

#pragma mark - Lifecycle

- (instancetype)initWithTableView:(NSTableView *)tableView
                    configuration:(CKTransactionalComponentDataSourceConfiguration *)configuration
{
  self = [super init];
  if (self) {
    _config = configuration;
    
    _componentDataSource = [[CKTransactionalComponentDataSource alloc] initWithConfiguration:_config];
    [_componentDataSource addListener:self];
    
    _attachController = [[CKComponentDataSourceAttachController alloc] init];
    
    _tableView = tableView;
  }
  return self;
}

- (instancetype)init
{
  CK_NOT_DESIGNATED_INITIALIZER();
}

#pragma mark - Changesets

- (void)applyChangeset:(CKTransactionalComponentDataSourceChangeset *)changeset
                  mode:(CKUpdateMode)mode
              userInfo:(NSDictionary *)userInfo
{
  [_componentDataSource applyChangeset:changeset mode:mode userInfo:userInfo];
}

- (void)updateContextAndEnqueueReload:(id)newContext
{
  CKAssertMainThread();
  
  // Update just the context
  _config = [[CKTransactionalComponentDataSourceConfiguration alloc] initWithComponentProvider:_config.componentProvider
                                                                                       context:newContext
                                                                                     sizeRange:_config.sizeRange];

  [_componentDataSource updateConfiguration:_config mode:CKUpdateModeSynchronous userInfo:nil];
}

- (id<NSObject>)modelForRow:(NSInteger)rowIndex
{
  return [[[_componentDataSource state] objectAtIndexPath:[NSIndexPath indexPathForItem:rowIndex inSection:0]] model];
}

- (CGFloat)heightForRow:(NSInteger)rowIndex
{
  return [[[_componentDataSource state] objectAtIndexPath:[NSIndexPath indexPathForItem:rowIndex inSection:0]] layout].size.height;
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
  return _componentDataSource.state.numberOfSections > 0 ? [[_componentDataSource state] numberOfObjectsInSection:0] : 0;
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
  static NSString *reuseIdentifier = @"ComponentKit";

  // Dequeue a reusable cell for this identifer
  NSView *v = [tableView makeViewWithIdentifier:reuseIdentifier owner:nil];
  if (!v) {
    v = [[NSView alloc] initWithFrame:CGRect{{0,0}, {100, 100}}];
    v.identifier = reuseIdentifier;
  }
  
  CKTransactionalComponentDataSourceItem *item = [[_componentDataSource state] objectAtIndexPath:[NSIndexPath indexPathForItem:row inSection:0]];
  [_attachController attachComponentLayout:item.layout withScopeIdentifier:item.scopeRoot.globalIdentifier toView:v];
  
  return v;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
  CKTransactionalComponentDataSourceItem *item = [[_componentDataSource state] objectAtIndexPath:[NSIndexPath indexPathForItem:row inSection:0]];
  const CKComponentLayout &layout = item.layout;
  return layout.size.height;
}

#pragma mark - CKTransactionalComponentDataSourceListener

static NSIndexSet *firstSectionIndexSet(NSSet *indices) {
  NSMutableIndexSet *s = [NSMutableIndexSet indexSet];
  for (NSIndexPath *ip in indices) {
    if (ip.section == 0) {
      [s addIndex:ip.row];
    }
  }
  return [s copy];
}

- (void)_detachComponentLayoutForRemovedItemsAtIndexPaths:(NSSet *)removedIndexPaths
                                                  inState:(CKTransactionalComponentDataSourceState *)state
{
  for (NSIndexPath *indexPath in removedIndexPaths) {
    CKComponentScopeRootIdentifier identifier = [[[state objectAtIndexPath:indexPath] scopeRoot] globalIdentifier];
    [_attachController detachComponentLayoutWithScopeIdentifier:identifier];
  }
}

- (void)transactionalComponentDataSource:(CKTransactionalComponentDataSource *)dataSource
                  didModifyPreviousState:(CKTransactionalComponentDataSourceState *)previousState
                       byApplyingChanges:(CKTransactionalComponentDataSourceAppliedChanges *)changes
{
  bool needsUpdate =
     changes.removedIndexPaths.count > 0
  || changes.insertedIndexPaths.count > 0
  || changes.updatedIndexPaths.count > 0
  || changes.movedIndexPaths.count > 0;
  
  // NSTableView updates
  if (needsUpdate) {
    [_tableView beginUpdates];
    
    if (changes.removedIndexPaths.count > 0) {
      [_tableView removeRowsAtIndexes:firstSectionIndexSet(changes.removedIndexPaths)
                        withAnimation:NSTableViewAnimationEffectNone];
    }
    
    if (changes.insertedIndexPaths.count > 0) {
      [_tableView insertRowsAtIndexes:firstSectionIndexSet(changes.insertedIndexPaths)
                        withAnimation:NSTableViewAnimationEffectNone];
    }
    
    if (changes.updatedIndexPaths.count > 0) {
      [_tableView reloadDataForRowIndexes:firstSectionIndexSet(changes.updatedIndexPaths)
                            columnIndexes:[NSIndexSet indexSetWithIndexesInRange:NSRange{.length = NSUInteger(_tableView.numberOfColumns)}]];
    }
    
    [changes.movedIndexPaths enumerateKeysAndObjectsUsingBlock:^(NSIndexPath *key, NSIndexPath *obj, BOOL *stop) {
      [_tableView moveRowAtIndex:key.row toIndex:obj.row];
    }];
    
    [self _detachComponentLayoutForRemovedItemsAtIndexPaths:[changes removedIndexPaths]
                                                    inState:previousState];
    
    [_tableView endUpdates];
  }
  
  // Selection updates
  NSIndexSet *selection = changes.userInfo[CKNSTableViewDataSourceSelectionKey];
  NSIndexSet *currentSelection = _tableView.selectedRowIndexes;
  if ([selection isKindOfClass:[NSIndexSet class]]) {
    if (selection != currentSelection || ![selection isEqualToIndexSet:currentSelection]) {
      [_tableView selectRowIndexes:selection byExtendingSelection:NO];
      [_tableView scrollRowToVisible:selection.firstIndex];
    }
  }
  

}

@end
