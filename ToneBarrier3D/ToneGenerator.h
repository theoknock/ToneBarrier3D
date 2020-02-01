//
//  ToneGenerator.h
//  ToneBarrier3D
//
//  Created by Xcode Developer on 2/1/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ToneGenerator : NSObject

+ (nonnull ToneGenerator *)sharedGenerator;

@property (nonatomic, readonly) AVAudioEngine * _Nonnull audioEngine;

- (void)play;

@end

NS_ASSUME_NONNULL_END
