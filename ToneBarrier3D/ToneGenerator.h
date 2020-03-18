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


NS_ASSUME_NONNULL_BEGIN

@protocol ToneGeneratorDelegate <NSObject>

@required
- (IBAction)play:(UIButton *)sender;

@end

@interface ToneGenerator : NSObject

+ (nonnull ToneGenerator *)sharedGenerator;

@property (nonatomic, readonly) AVAudioEngine * _Nonnull audioEngine;
@property (weak) id<ToneGeneratorDelegate> delegate;

- (void)play;

@end

NS_ASSUME_NONNULL_END
