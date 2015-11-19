// Copyright 2004-present Facebook. All Rights Reserved.
#import "CKMTableComponent.h"

#import <ComponentKit/CKComponentInternal.h>
#import <ComponentKit/CKComponentSubclass.h>
#import <ComponentKit/CKComponentMemoizer.h>
#import <ComponentKit/CKNSTableViewDataSource.h>
#import <ComponentKit/CKComponentViewInterface.h>
#import <ComponentKit/CKTransactionalComponentDataSourceConfiguration.h>
#import <ComponentKit/CKTransactionalComponentDataSourceChangeset.h>
#import <ComponentKit/CKComponentDelegateForwarder.h>
#import <ComponentKit/ComponentViewManager.h>

/*
 When actions bubble up to the table cell level, we need to redirect them back to the table component
 controller (which will bubble to the table component's supercomponent.

 _CKMTableComponentCell intercepts component-responder events and forwards them to the component controller,
 but won't mess with NSResponder events like cursor updates.
*/
@interface _CKMTableComponentCell : CKCompositeComponent

+ (instancetype)newWithComponent:(CKComponent *)component target:(__weak id)target;

@end

@implementation _CKMTableComponentCell {
  __weak id _target;
}

+ (instancetype)newWithComponent:(CKComponent *)component target:(__weak id)target
{
  _CKMTableComponentCell *c = [super newWithComponent:component];
  if (!c) return nil;

  c->_target = target;

  return c;
}

- (id)targetForAction:(SEL)action withSender:(id)sender
{
  return [_target targetForAction:action withSender:sender];
}

@end

static NSIndexSet *symmetricDifference(NSIndexSet *set, NSIndexSet *other)
{
  NSMutableIndexSet *a = [set mutableCopy];
  NSMutableIndexSet *b = [other mutableCopy];
  [a removeIndexes:other];
  [b removeIndexes:set];
  [a addIndexes:b];
  return [a copy];
}

@interface CKMTableComponent () {
  @package
  CKComponentViewConfiguration _tableConfiguration;
  id<NSTableViewDelegate> _forwardDelegate;
}

@property (nonatomic, copy, readonly) NSArray *models;
@property (nonatomic, copy, readonly) NSIndexSet *selection;

@property (nonatomic, weak, readonly) id<CKMTableComponentCellProvider> cellProvider;

@end

@interface CKMTableComponentController : CKComponentController <NSTableViewDelegate, NSTableViewDataSource>
@end

@implementation CKMTableComponentController {
  NSTableView *_tableView;
  CKNSTableViewDataSource *_dataSource;
  CKComponentDelegateForwarder *_delegateForwarder;
  CKComponentDelegateForwarder *_dataSourceForwarder;

  // This queue protects access to the things that affect both cells in the tableview (async) and remounting main thread
  dispatch_queue_t _coordinationQueue;
  NSArray *_models;
  NSIndexSet *_selection;
  __weak id<CKMTableComponentCellProvider> _cellProvider;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _coordinationQueue = dispatch_queue_create("com.fb.diamond.CKMTableComponent", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (NSTableView *)tableView
{
  return _tableView;
}

- (CKMTableComponent *)tableComponent
{
  return (CKMTableComponent *)self.component;
}

static bool enableReloadSelection = true;

static CKTransactionalComponentDataSourceChangeset *replaceItems(NSArray *oldModels, NSArray *models, NSIndexSet *oldSelection, NSIndexSet *newSelection) {
  if (oldModels == models || [oldModels isEqualToArray:models]) {

    // Ok, models are the same, but selection could have changed
    if (enableReloadSelection && !(oldSelection == newSelection || [newSelection isEqualToIndexSet:oldSelection])) {
      NSIndexSet *needsReload = symmetricDifference(oldSelection ?: [NSIndexSet indexSet], newSelection ?: [NSIndexSet indexSet]);

      NSMutableDictionary *reload = [NSMutableDictionary dictionary];
      [models enumerateObjectsAtIndexes:needsReload options:0 usingBlock:^(id  _Nonnull model, NSUInteger idx, BOOL * _Nonnull stop) {
        reload[[NSIndexPath indexPathForItem:idx inSection:0]] = model;
      }];

      return [[[CKTransactionalComponentDataSourceChangesetBuilder transactionalComponentDataSourceChangeset] withUpdatedItems:reload] build];
    } else if (!enableReloadSelection) {
      return [[CKTransactionalComponentDataSourceChangesetBuilder transactionalComponentDataSourceChangeset] build];
    }

    return nil;
  }

  // Kinda gross to do this (should diff them and only emit a subset instead)
  NSMutableSet *removedSet = [NSMutableSet set];
  for (NSUInteger i=0; i < oldModels.count; i++) {
    [removedSet addObject:[NSIndexPath indexPathForItem:i inSection:0]];
  }
  NSMutableDictionary *insert = [NSMutableDictionary dictionary];
  NSInteger idx = 0;
  for (id model : models) {
    insert[[NSIndexPath indexPathForItem:idx inSection:0]] = model;
    idx++;
  }

  return [[[[CKTransactionalComponentDataSourceChangesetBuilder transactionalComponentDataSourceChangeset] withRemovedItems:removedSet] withInsertedItems:insert] build];
}

static CKTransactionalComponentDataSourceChangeset *insertItems(NSArray *models, NSUInteger startIndex) {
  NSMutableDictionary *insert = [NSMutableDictionary dictionary];
  NSInteger idx = startIndex;
  for (id model : models) {
    insert[[NSIndexPath indexPathForItem:idx inSection:0]] = model;
    idx++;
  }
  return [[[CKTransactionalComponentDataSourceChangesetBuilder transactionalComponentDataSourceChangeset] withInsertedItems:insert] build];
};

// Use our NSTableView to tell the dataSource how to make layout the content in our cells
- (CKSizeRange)sizeRangeForDataSource
{
  NSScrollView *sv = (NSScrollView *)self.view;
  CGFloat rightInset = sv.verticalScroller.bounds.size.width;
  CGFloat contentWidth = _tableView.bounds.size.width - rightInset;

  return {
    {contentWidth, 0.0},
    {contentWidth, HUGE_VALF},
  };
}

CKComponentDelegateForwarder *appendSelectorsToForwarder(CKComponentDelegateForwarder *existing, CKComponentForwardedSelectors selectors)
{
  // Union our selectors with those of the existing delegate
  CKComponentForwardedSelectors neue = existing.selectors;
  neue.insert(neue.end(), selectors.begin(), selectors.end());

  CKComponentDelegateForwarder *newForwarder = [CKComponentDelegateForwarder newWithSelectors:neue];
  newForwarder.view = existing.view;
  return newForwarder;
}

- (void)didMount
{
  [super didMount];

  NSScrollView *scrollView = (NSScrollView *)self.view;

  const CKComponentViewConfiguration &tableViewConfig = self.tableComponent->_tableConfiguration;

  NSTableView *tableView = (NSTableView *)tableViewConfig.viewClass().createView();
  CKAssert([tableView isKindOfClass:[NSTableView class]], @"You passed %@ to %@ when we expect a subclass of NSTableView", tableView, self.class);

  // Hack hack, allow delegate forwarding to follow component chain from here (since it's a property ostensibly on tableView).
  tableView.ck_component = self.component;
  CK::Component::AttributeApplicator::apply(tableView, tableViewConfig);

  // Setup tableView in a sane way
  if (tableView.numberOfColumns == 0) {
    NSTableColumn *c = [[NSTableColumn alloc] initWithIdentifier:@""];
    c.width = scrollView.bounds.size.width - 3;
    c.maxWidth = 1000000;
    c.resizingMask = NSTableColumnAutoresizingMask;
    [tableView addTableColumn:c];

    tableView.headerView = nil;

    tableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
  }
  _tableView = tableView;
  scrollView.documentView = _tableView;

  NSArray *models = self.tableComponent.models;
  NSIndexSet *selection = [self.tableComponent.selection copy];
  id<CKMTableComponentCellProvider> cellProvider = self.tableComponent.cellProvider;

  dispatch_async(_coordinationQueue, ^{
    _models = [models copy];
    _selection = selection;
    _cellProvider = cellProvider;
  });

//  NSLog(@"Mount with selection: %@", selection);

  NSDictionary *context = selection ? @{CKNSTableViewDataSourceSelectionKey : self.tableComponent.selection} : nil;

  CKTransactionalComponentDataSourceConfiguration *config =
  [[CKTransactionalComponentDataSourceConfiguration alloc] initWithComponentProvider:(Class<CKComponentProvider>)self
                                                                             context:context
                                                                           sizeRange:self.sizeRangeForDataSource];

  _dataSource = [[CKNSTableViewDataSource alloc] initWithTableView:_tableView configuration:config];

  // If there already was a proxy delegate set here, we're ok
  if (!_tableView.delegate) {
    _tableView.delegate = self;
  } else if ([_tableView.delegate isKindOfClass:[CKComponentDelegateForwarder class]]) {
    // This is a hack for if you also set the delegate on the outside

    CKComponentDelegateForwarder *forwarder = _tableView.delegate;
     _delegateForwarder = appendSelectorsToForwarder(forwarder, {
      @selector(tableView:heightOfRow:),
      @selector(tableView:viewForTableColumn:row:),
    });
    _tableView.delegate = (id<NSTableViewDelegate>)_delegateForwarder;
  }

  // If there already was a proxy dataSource set here, we're ok
  if (!_tableView.dataSource) {
    _tableView.dataSource = self;
  } else if ([_tableView.dataSource isKindOfClass:[CKComponentDelegateForwarder class]]) {
    // This is a hack for if you also set the dataSource on the outside

    CKComponentDelegateForwarder *forwarder = _tableView.dataSource;
    _dataSourceForwarder = appendSelectorsToForwarder(forwarder, {
      @selector(numberOfRowsInTableView:),
    });
    _tableView.dataSource = (id<NSTableViewDataSource>)_dataSourceForwarder;
  }

  // Make sure we have 1 section
  CKTransactionalComponentDataSourceChangeset *base =
  [[CKTransactionalComponentDataSourceChangeset alloc] initWithUpdatedItems:nil
                                                               removedItems:nil
                                                            removedSections:nil
                                                                 movedItems:nil
                                                           insertedSections:[NSIndexSet indexSetWithIndex:0]
                                                              insertedItems:nil];

  [_dataSource applyChangeset:base mode:CKUpdateModeSynchronous userInfo:nil];


  [_dataSource applyChangeset:insertItems(_models, 0)
                         mode:CKUpdateModeAsynchronous
                     userInfo:context];

}

// Pass on to our component provider
// WARNING: GETS CALLED ON BACKGROUND THREAD
- (CKComponent *)componentForModel:(id<NSObject>)model context:(id<NSObject>)context
{
  __block CKComponent *c;
  dispatch_sync(_coordinationQueue, ^{
    NSUInteger index = [_models indexOfObjectIdenticalTo:model];
    c = [_cellProvider componentWithModel:model selected:[_selection containsIndex:index]];
  });
  // Wrap the component so we can bubble events back onto the component hierarchy above us
  return [_CKMTableComponentCell newWithComponent:c target:self];
}

- (void)didRemount
{
  _tableView.ck_component = self.component;

  NSArray *newModels = self.tableComponent.models;
  NSIndexSet *newSelection = self.tableComponent.selection;
  id<CKMTableComponentCellProvider> newCellProvider = self.tableComponent.cellProvider;
//  NSLog(@"Remount with selection: %@", newSelection);

  __block CKTransactionalComponentDataSourceChangeset *changeSet;
  __block NSDictionary *context = newSelection ? @{CKNSTableViewDataSourceSelectionKey : newSelection} : nil;
  dispatch_sync(_coordinationQueue, ^{
    changeSet = replaceItems(_models, newModels, _selection, newSelection);

    _selection = newSelection;
    _models = [newModels copy];
    _cellProvider = newCellProvider;
  });

  if (changeSet) {
    [_dataSource applyChangeset:changeSet
                           mode:CKUpdateModeSynchronous // We have to do this synchronously to make selection work for now
                       userInfo:context];
  }

  [super didRemount];
}

- (void)didUnmount
{
  _tableView.ck_component = nil;
  _tableView = nil;
  _dataSource = nil;

  [super didUnmount];
}

#pragma mark - NSTableViewDelegate

/*
 * We handle some of the NSTableView delegate methods to provide component-based content.
 * Any additional methods must be added in the CKComponentDelegateForwarder code in -didMount,
 * so if a delegate is set from the outside we still are able to see the events.
 */

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
  return [_dataSource tableView:tableView heightOfRow:row];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
  return [_dataSource tableView:tableView viewForTableColumn:tableColumn row:row];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
  return [_dataSource numberOfRowsInTableView:tableView];
}

@end

@implementation CKMTableComponent


+ (instancetype)newWithScrollView:(CKComponentViewConfiguration)scrollView
                        tableView:(CKComponentViewConfiguration)tableView
                           models:(NSArray *)modelObjects
                        selection:(NSIndexSet *)selection
                componentProvider:(id<CKMTableComponentCellProvider>)componentProvider
                             size:(CKComponentSize)size;
{
  bool disableMemoization = false;

  CKComponentScope s(self);

  auto create = ^id{
    CKMTableComponent *c =
    [self newWithView:scrollView
                 size:size];

    if (!c) return nil;

    c->_tableConfiguration = std::move(tableView);
    c->_cellProvider = componentProvider;
    c->_models = [modelObjects copy];
    c->_selection = [selection copy];

    return c;
  };

  return disableMemoization ? create() : CKMemoize(CKMakeTupleMemoizationKey(scrollView, tableView, modelObjects, selection, componentProvider, size), create);
}

@end
