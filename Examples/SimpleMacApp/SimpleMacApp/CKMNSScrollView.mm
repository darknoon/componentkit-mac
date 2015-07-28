//
//  CKMNSTableView.m
//  SimpleMacApp
//
//  Created by Andrew Pouliot on 7/24/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "CKMNSScrollView.h"

#import <ComponentKit/ComponentKit.h>
#import <ComponentKit/CKComponentViewInterface.h>

@implementation CKMNSScrollView

- (id)targetForAction:(SEL)action withSender:(id)sender
{
  // Redirect back onto components responder chain from NSView responder chain
  return [self respondsToSelector:action] ? self : [(id)self.ck_component targetForAction:action withSender:sender];
}

@end