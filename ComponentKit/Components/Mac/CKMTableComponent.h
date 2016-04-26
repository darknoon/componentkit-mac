// Copyright 2004-present Facebook. All Rights Reserved.

#import <ComponentKit/CKComponent.h>

/**
 * A simple component to add async NSTableViews to your other component layouts.
 * It makes an NSTableView with one column.
 * @param
 */

@protocol CKMTableComponentCellProvider;

@interface CKMTableComponent : CKComponent

+ (instancetype)newWithScrollView:(CKComponentViewConfiguration)scrollView
                        tableView:(CKComponentViewConfiguration)tableView
                           models:(NSArray *)modelObjects
                        selection:(NSIndexSet *)selection
                componentProvider:(id<CKMTableComponentCellProvider>)componentProvider
                             size:(CKComponentSize)size;

@end


@protocol CKMTableComponentCellProvider

// Must be thread-safe
+ (CKComponent *)componentWithModel:(id)model selected:(BOOL)selected;

@end
