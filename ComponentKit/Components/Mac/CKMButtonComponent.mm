// Copyright 2004-present Facebook. All Rights Reserved.

#import "CKMButtonComponent.h"

#import <ComponentKit/CKComponentSubclass.h>

#import "NSString+CKMTextCache.h"

@implementation CKMButtonComponent {
  NSString *_title;
  NSButtonType _type;
}

+ (instancetype)newWithTitle:(NSString *)title type:(NSButtonType)type viewAttributes:(CKViewComponentAttributeValueMap)viewAttributes
{
  viewAttributes.insert({@selector(setTitle:), title});
  viewAttributes.insert({@selector(setButtonType:), @(type)});

  // Add a default bezel style if one is not specified
  if (viewAttributes.find(@selector(setBezelStyle:)) == viewAttributes.end()) {
    viewAttributes.insert({@selector(setBezelStyle:), @(NSRoundedBezelStyle)});
  }

  CKMButtonComponent *c =
  [super
   newWithView:{
     {[NSButton class]},
     {
       std::move(viewAttributes),
     },
   }
   size:{}];
  if (c) {
    c->_title = title;
    c->_type = type;
  }
  
  return c;
}

- (CKComponentLayout)computeLayoutThatFits:(CKSizeRange)constrainedSize
{
  const CGSize constraint = {
    isinf(constrainedSize.max.width) ? CGFLOAT_MAX : constrainedSize.max.width,
    CGFLOAT_MAX
  };

  NSDictionary *attributes = @{
                               NSFontAttributeName: [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSRegularControlSize]]
                               };
  CGRect rect = [_title ckm_boundingRectWithSize:constraint
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:attributes];

  rect.size.height = 24.0;
  rect.size.width += 14.0 * 2;  // for padding around button's title
  rect.size.width = ceil(rect.size.width);

  UIEdgeInsets insets = {.left = -6, .right = -6};

  // Our insets need to be different for checkbox/radio button
  if (_type == NSSwitchButton || _type == NSRadioButton) {
    insets = UIEdgeInsetsZero;
  }

  return {self, constrainedSize.clamp(rect.size), {}, nil, insets};
}

@end
