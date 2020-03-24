//
//  ToneBarrierScores.m
//  ToneBarrier3D
//
//  Created by Xcode Developer on 3/23/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

#import "ToneBarrierScores.h"

@implementation ToneBarrierScores

//+(RenderDataForToneBarrierScore)harmony {
//    return ^float(float time) {
//        return _amplitude * sin(2.0 * ((float)M_PI) * _frequency * time);
//    };
//}
//
//+(RenderDataForToneBarrierScore)glissando {
//    return ^float(float time) {
//        
//        double period = 1.0 / (double)Oscillator.frequency;
//        double currentTime = fmod((double)time, period);
//        double value = currentTime / period;
//        double result = 0.0;
//
//        if (value < 0.25) {
//            result = value * 4.0;
//        } else if (value < 0.75) {
//            result = 2.0 - (value * 4.0);
//        } else {
//            result = value * 4.0 - 4.0;
//        }
//        
//        // Compact format, but how readable is it really?
//        // result = value < 0.25 ? value * 4 : (value < 0.75 ? 2.0 - (value * 4.0) : value * 4 - 4.0);
//        
//        return Oscillator.amplitude * (float)result;
//    };
//}

@end
