//
//  ToneGenerator.h
//  ToneBarrier3D
//
//  Created by Xcode Developer on 2/1/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, ToneBarrierScore) {
    ToneBarrierScoreHeadphones,
    ToneBarrierScoreSpeaker,
    ToneBarrierScoreAlarm,
    ToneBarrierScoreNone
};


NS_ASSUME_NONNULL_BEGIN

@protocol ToneGeneratorDelegate <NSObject>

@required
#if TARGET_OS_IOS
- (IBAction)play:(UIButton *)sender;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
#else
- (IBAction)play;
#endif


@end

@interface ToneGenerator : NSObject

+ (nonnull ToneGenerator *)sharedGenerator;

@property (nonatomic, readonly) AVAudioEngine * _Nonnull audioEngine;
@property (nonatomic, readonly) AVAudioPlayerNode * _Nullable playerNode;
@property (nonatomic, readonly) AVAudioPlayerNode * _Nullable playerNodeAux;

@property (weak) id<ToneGeneratorDelegate> delegate;

- (void)play:(ToneBarrierScore)toneBarrierScore;

@end

NS_ASSUME_NONNULL_END
