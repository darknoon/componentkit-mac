// Copyright 2004-present Facebook. All Rights Reserved.

#import "CKMRootViewController.h"
#import "CKMSampleComponentProvider.h"

#import "CKMTableCellComponentProvider.h"

#import <ComponentKit/CKComponent.h>
#import <ComponentKit/CKComponentHostingView.h>
#import <ComponentKit/CKComponentHostingViewDelegate.h>
#import <ComponentKit/CKComponentSizeRangeProviding.h>
#import <ComponentKit/CKComponentFlexibleSizeRangeProvider.h>

#import <ComponentKit/CKTransactionalComponentDataSourceChangeset.h>

#import <ComponentKit/CKNSTableViewDataSource.h>

#define SHOW_TABLEVIEW 0

@interface CKMRootViewController ()

@property (nonatomic, copy) NSArray<NSString *> *model;

@property (nonatomic, strong) CKComponentHostingView *hostingView;

@end


@implementation CKMRootViewController

- (void)loadView
{
  self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 480, 200)];

  self.hostingView = [[CKComponentHostingView alloc] initWithComponentProvider:[CKMSampleComponentProvider class]
                                                             sizeRangeProvider:nil];

  // Build up a nice changeset with our rows
  NSMutableArray *data = [NSMutableArray array];
  for (NSInteger i = 0; i<800; i++) {
    NSMutableString *ms = [NSMutableString string];
    NSInteger idx = i % ('z' - 'a' + 1);
    char c = 'a' + (char)idx;
    // Repeat idx times
    [ms appendFormat:@"%c", c];
    for (NSInteger j = 1; j <= idx; j++) {
      [ms appendFormat:@" %c", c];
    }
    [data addObject:[ms copy]];
  }

  self.model = data;

  self.hostingView.frame = self.view.bounds;
  self.hostingView.autoresizingMask = (NSViewWidthSizable | NSViewHeightSizable);
  [self.view addSubview:self.hostingView];
}

- (void)setModel:(NSArray<NSString *> *)model
{
  if (_model == model || [_model isEqualToArray:model]) return;
  _model = [model copy];
  [self.hostingView updateModel:model mode:CKUpdateModeSynchronous];
}

#pragma mark - NSTableViewDataSource (Drag+Drop)

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
  [pboard declareTypes:@[kCKMSamplePasteboardType] owner:self];
  [pboard setData:data forType:kCKMSamplePasteboardType];
  return YES;
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
  if (dropOperation == NSTableViewDropOn) {
    return NSDragOperationNone;
  }
  return NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation
{
  if ([[info draggingPasteboard] dataForType:kCKMSamplePasteboardType]) {
    NSPasteboard *pasteboard = [info draggingPasteboard];
    NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:[pasteboard dataForType:kCKMSamplePasteboardType]];

    NSUInteger countBeforeRow = [rowIndexes countOfIndexesInRange:NSMakeRange(0, row)];
    NSMutableArray *mutableModel = [self.model mutableCopy];
    NSArray *objectsToInsert = [mutableModel objectsAtIndexes:rowIndexes];
    [mutableModel removeObjectsAtIndexes:rowIndexes];
    [mutableModel insertObjects:objectsToInsert atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row - countBeforeRow, objectsToInsert.count)]];
    self.model = mutableModel;
  }
  return NO;
}

@end
