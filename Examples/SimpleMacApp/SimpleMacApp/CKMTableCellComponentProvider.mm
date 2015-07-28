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

#import "CKMSampleExpandableComponent.h"

@implementation CKMTableCellComponentProvider

+ (CKComponent *)componentForModel:(id<NSObject>)model context:(id<NSObject>)context
{
  NSArray *mod = (NSArray *)model;
  NSString *string = (NSString *)mod[1];
  NSInteger idx = [(NSNumber *)mod[0] integerValue];
  bool expanded = mod.count > 2 ? [mod[2] boolValue] : false;

  return [CKMSampleExpandableComponent newWithString:string index:idx expanded:expanded];
}

@end
