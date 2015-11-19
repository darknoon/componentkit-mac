/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "CKMTableCellComponentProvider.h"

@implementation CKMTableCellComponentProvider

+ (CKComponent *)componentWithModel:(id)model selected:(BOOL)selected
{
  NSString *string = (NSString *)model;

  return [CKStackLayoutComponent
          newWithView:{}
          size:{.width = 320}
          style:{CKStackLayoutDirectionHorizontal}
          children:{
            {[CKMTextLabelComponent
              newWithTextAttributes:{
                .text = string,
                .color = [NSColor labelColor],
              }
              viewAttributes:{}
              size:{
                .maxWidth = 150,
              }],
              .spacingBefore = 2, // If you drag in a default table view in IB, you get this spacing
              .spacingAfter = 10, // IB suggests this if you put a label next to a button
            },
            {[CKMButtonComponent
              newWithTitle: @"Do Something"
              type:NSMomentaryLightButton
              viewAttributes:{}]},
            {[CKMButtonComponent
              newWithTitle: @"Checkbox!!"
              type:NSSwitchButton
              viewAttributes:{}]},
            {[CKMButtonComponent
              newWithTitle: @"Radio!!"
              type:NSRadioButton
              viewAttributes:{}]},
          }];

}


@end
