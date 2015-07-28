//
//  CKMSampleExpandableComponent.m
//  SimpleMacApp
//
//  Created by Andrew Pouliot on 7/28/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "CKMSampleExpandableComponent.h"

#import <ComponentKit/CKComponentSubclass.h>

#import "CKMSampleActions.h"

@implementation CKMSampleExpandableComponent

+ (instancetype)newWithString:(NSString *)string index:(NSInteger)idx expanded:(BOOL)expanded
{
  CKComponentScope scope(self, @(idx));

  CKMSampleExpandableComponent *c =
  [self
   newWithComponent:
   [CKStackLayoutComponent
    newWithView:{}
    size:{.width = 320}
    style:{CKStackLayoutDirectionHorizontal}
    children:{
      // Show a label with the text
      {[CKMTextLabelComponent
        newWithTextAttributes:{
          .text = string,
          .color = [NSColor secondaryLabelColor],
          .backgroundColor = expanded ? [NSColor redColor] : [NSColor clearColor],
        }
        viewAttributes:{}
        size:{
          .maxWidth = 150,
          .minHeight = expanded ? 150 : 22,
        }]},

      // A button collapses or expands the cell
      {[CKMButtonComponent
        newWithView:{{},
          {
            CKComponentActionAttribute(@selector(clickedExpand:)),
          }
        }
        title:expanded ? @"Collapse" : @"Expand"]},
    }]];
  
  if (!c) {
    return nil;
  }

  c->_index = idx;

  return c;
}

- (CKComponentBoundsAnimation)boundsAnimationFromPreviousComponent:(CKComponent *)previousComponent
{
  return {.duration = 0.2};
}

- (void)clickedExpand:(CKComponent *)c
{
  id responder = [self targetForAction:@selector(expandCell:atIndex:) withSender:self];
  [responder expandCell:self atIndex:_index];
}

@end
