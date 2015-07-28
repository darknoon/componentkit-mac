// Copyright 2004-present Facebook. All Rights Reserved.

#import <ComponentKit/CKComponent.h>

@interface CKMButtonComponent : CKComponent

+ (instancetype)newWithTitle:(NSString *)title;

+ (instancetype)newWithView:(CKComponentViewConfiguration)view title:(NSString *)title;

@end