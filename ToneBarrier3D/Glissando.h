//
//  Glissando.h
//  ToneBarrier3D
//
//  Created by Xcode Developer on 3/26/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

#import "ToneBarrierScore.h"

NS_ASSUME_NONNULL_BEGIN

@interface Glissando : ToneBarrierScore


@property (class) float amplitude;
@property (class) float frequency;

- (void)putBreadOnPlate;
- (void)addMeat;
- (void)addCondiments;

- (void)cutRyeBread;
- (void)addCornBeef;
- (void)addSauerkraut;
- (void)addThousandIslandDressing;
- (void)addSwissCheese;

@end

NS_ASSUME_NONNULL_END
