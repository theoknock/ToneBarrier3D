//
//  ToneBarrierScores.h
//  ToneBarrier3D
//
//  Created by Xcode Developer on 3/23/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^DataPlayedBackCompletionBlock)(NSString *);
typedef void (^DataRenderedCompletionBlock)(AVAudioPCMBuffer *, DataPlayedBackCompletionBlock);
typedef void (^RenderDataForToneBarrierScore)(DataRenderedCompletionBlock);

@interface ToneBarrierScores : NSObject

@end

NS_ASSUME_NONNULL_END
