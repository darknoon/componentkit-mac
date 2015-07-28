//
//  CKMSampleExpandableComponent.h
//  SimpleMacApp
//
//  Created by Andrew Pouliot on 7/28/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import <ComponentKit/ComponentKit.h>

@interface CKMSampleExpandableComponent : CKCompositeComponent

+ (instancetype)newWithString:(NSString *)string index:(NSInteger)idx expanded:(BOOL)expanded;

@property (nonatomic, readonly) NSInteger index;

@end
