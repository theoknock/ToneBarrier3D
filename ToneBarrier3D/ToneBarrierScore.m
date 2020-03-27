//
//  ToneBarrierScore.m
//  ToneBarrier3D
//
//  Created by Xcode Developer on 3/26/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

#import "ToneBarrierScore.h"

@implementation ToneBarrierScore

- (void)make {
    [self prepareBread];
    [self putBreadOnPlate];
    [self addMeat];
    [self addCondiments];
    [self serve];
}

- (void)putBreadOnPlate {
    
}

- (void)serve {
    
}

// MARK: - Details will be handled by subclasses
- (void)prepareBread {
    [NSException raise:NSInternalInconsistencyException format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

- (void)addMeat {
    [NSException raise:NSInternalInconsistencyException format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

- (void)addCondiments {
    [NSException raise:NSInternalInconsistencyException format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

@end

@end
