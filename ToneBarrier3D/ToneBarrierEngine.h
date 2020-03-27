//
//  ToneBarrierEngine.h
//  ToneBarrier3D
//
//  Created by Xcode Developer on 3/26/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>


NS_ASSUME_NONNULL_BEGIN

@protocol ToneBarrierEngineDelegate <NSObject>

@required
- (IBAction)play:(UIButton *)sender;

@end


@interface ToneBarrierEngine : NSObject

@property (nonatomic, readonly) AVAudioEngine * _Nonnull audioEngine;
@property (nonatomic, readonly) AVAudioPlayerNode * _Nullable playerNode;
@property (nonatomic, readonly) AVAudioPlayerNode * _Nullable playerNodeAux;

@property (weak) id<ToneBarrierEngineDelegate> delegate;

- (void)play;

@end

NS_ASSUME_NONNULL_END
