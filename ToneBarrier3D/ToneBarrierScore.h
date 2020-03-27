//
//  ToneBarrierScore.h
//  ToneBarrier3D
//
//  Created by Xcode Developer on 3/26/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ToneBarrierScore : NSObject

- (void)make;
- (void)prepareBread;
- (void)putBreadOnPlate;
- (void)addMeat;
- (void)addCondiments;
- (void)serve;

@end

NS_ASSUME_NONNULL_END
