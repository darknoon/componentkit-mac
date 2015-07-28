//
//  CKMSampleActions.h
//  SimpleMacApp
//
//  Created by Andrew Pouliot on 7/24/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#ifndef SimpleMacApp_CKMSampleActions_h
#define SimpleMacApp_CKMSampleActions_h


@protocol CKMSampleActions <NSObject>

- (void)expandCell:(CKComponent *)cell atIndex:(NSInteger)idx;

@end

#endif
