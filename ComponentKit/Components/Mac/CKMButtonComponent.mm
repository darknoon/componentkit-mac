// Copyright 2004-present Facebook. All Rights Reserved.

#import "CKMButtonComponent.h"

#import <ComponentKit/CKComponentSubclass.h>

#import "NSString+CKMTextCache.h"

@implementation CKMButtonComponent {
  NSString *_title;
}

+ (instancetype)newWithTitle:(NSString *)title
{
  return [self newWithView:{} title:title];
}

+ (instancetype)newWithView:(CKComponentViewConfiguration)view title:(NSString *)title
{
  // UGH, we need to cleanup CKComponentViewConfiguration's initializers!
  CKComponentViewClass vc = view.viewClass();
  if (!view.viewClass().hasView()) {
    vc = {[NSButton class]};
  }

  CKViewComponentAttributeValueMap attrs = *view.attributes();
  attrs.insert({
      {@selector(setButtonType:), @(NSMomentaryLightButton)},
      {@selector(setBezelStyle:), @(NSRoundedBezelStyle)},
      {@selector(setTitle:), title},
  });

  CKMButtonComponent *c =
  [super
   newWithView:{
     std::move(vc),
     std::move(attrs),
   }
   size:{}];
  if (c) {
    c->_title = title;
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
  return {self, constrainedSize.clamp(rect.size)};
}

@end
