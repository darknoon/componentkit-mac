// Copyright 2004-present Facebook. All Rights Reserved.

#import "CKMTextLabelComponent.h"

#import "NSString+CKMTextCache.h"

#import <ComponentKit/CKComponentSubclass.h>

static NSFont *labelFontOrDefault(NSFont *font) {
  return font ?: [NSFont labelFontOfSize:[NSFont systemFontSizeForControlSize:NSRegularControlSize]];
}

@implementation CKMTextLabelComponent {
  CKMTextLabelComponentAttrs _attrs;
}

+ (instancetype)newWithTextAttributes:(CKMTextLabelComponentAttrs)attrs
                       viewAttributes:(CKViewComponentAttributeValueMap)viewAttributes
                                 size:(CKComponentSize)size
{  
  CKViewComponentAttributeValueMap addl = {
    {@selector(setEditable:), @NO},
    {@selector(setSelectable:), @NO},
    {@selector(setStringValue:), attrs.text ?: @""},
    {@selector(setBackgroundColor:), attrs.backgroundColor},
    {@selector(setTextColor:), attrs.color},
    {@selector(setBezeled:), @NO},
    {@selector(setAlignment:), @(attrs.alignment)},
    {@selector(setFont:), labelFontOrDefault(attrs.font)},
    {@selector(setLineBreakMode:), @(attrs.lineBreakMode)},
  };
  viewAttributes.insert(addl.begin(), addl.end());

  CKMTextLabelComponent *c =
  [super
   newWithView:{
     {[NSTextField class]},
     {
       std::move(viewAttributes),
     },
   }
   size:size];
  if (c) {
    c->_attrs = std::move(attrs);
  }
  return c;
}

- (CKComponentLayout)computeLayoutThatFits:(CKSizeRange)constrainedSize
{
  const CGSize constraint = {
    isinf(constrainedSize.max.width) ? CGFLOAT_MAX : constrainedSize.max.width,
    isinf(constrainedSize.max.height) ? CGFLOAT_MAX : constrainedSize.max.height,
  };

  NSFont *font = labelFontOrDefault(_attrs.font);

  NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
  ps.lineBreakMode = _attrs.lineBreakMode;
  ps.alignment = _attrs.alignment;
  
  NSDictionary *attributes = @{
                               NSFontAttributeName: font,
                               NSParagraphStyleAttributeName: ps,
                               };
  

  CGRect rect = [_attrs.text ckm_boundingRectWithSize:constraint
                                              options:NSStringDrawingUsesLineFragmentOrigin
                                           attributes:attributes];

  rect.size.width = ceil(rect.size.width);

  // It turns out that centered text wants more space than left/right aligned text. Goodness knows why, but you can confirm in IB.
  NSEdgeInsets insetsNormal = {.left = -2, .right = -2};
  NSEdgeInsets insetsCenter = {.left = -4, .right = -4};

#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101100
  const NSEdgeInsets ei = _attrs.alignment == NSTextAlignmentCenter ? insetsCenter : insetsNormal;
#else
  const NSEdgeInsets ei = _attrs.alignment == NSCenterTextAlignment ? insetsCenter : insetsNormal;
#endif

  return {self, constrainedSize.clamp(rect.size), {}, nil, ei};
}

@end
