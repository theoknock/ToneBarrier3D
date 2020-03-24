//
//  ToneGenerator.m
//  ToneBarrier3D
//
//  Created by Xcode Developer on 2/1/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

// TO-DO: Create moving sound (velocity) to stimulate instinctive sound localizaton; cues for sound source localization: time- and level-differences (or intensity-difference) between both ears
//

// TO-DO: convert all functions and class methods to blocks

#import "ToneGenerator.h"

#define max_frequency      3000.00
#define min_frequency       200.00
#define max_trill_interval   18.00
#define min_trill_interval    2.00
#define sum_duration_interval 2.00
#define max_duration_interval 1.25
#define min_duration_interval 0.25

#define RANDOM_NUMF(MIN, MAX) MIN+arc4random_uniform(MAX-MIN+1)

typedef NS_ENUM(NSUInteger, TonalHarmony) {
    TonalHarmonyConsonance,
    TonalHarmonyDissonance,
    TonalHarmonyRandom
};

typedef NS_ENUM(NSUInteger, TonalInterval) {
    TonalIntervalUnison,
    TonalIntervalOctave,
    TonalIntervalMajorSixth,
    TonalIntervalPerfectFifth,
    TonalIntervalPerfectFourth,
    TonalIntervalMajorThird,
    TonalIntervalMinorThird,
    TonalIntervalRandom
};

typedef NS_ENUM(NSUInteger, TonalEnvelope) {
    TonalEnvelopeAverageSustain,
    TonalEnvelopeLongSustain,
    TonalEnvelopeShortSustain
};

//typedef double (^Trill)(double, double, double);
//typedef double(^Amplitude)(double);
//static void (^renderTone)(double, double, double, AVAudioFormat *, Trill, Amplitude);

typedef void(^RandomizedFrequenciesCompletionBlock)(double, double);
typedef void(^RandomFrequencies)(RandomizedFrequenciesCompletionBlock);

typedef void   (^DataPlayedBackCompletionBlock)(NSString *);
typedef void   (^DataRenderedCompletionBlock)(AVAudioPCMBuffer *, DataPlayedBackCompletionBlock);
typedef double (^FrequencyBufferData)(double, double, double);
typedef double (^FrequencyEnvelopeInterval)(double, double, double);
typedef double (^Amplitude)(double, double);
typedef void (^Tones)(AVAudioFormat *, DataRenderedCompletionBlock dataRenderedCompletionBlock);

//static AVAudioPCMBuffer *(^ToneBuffer)(double, double, double, double(^)(double, double, double(^)(double)), double(^)(double), AVAudioFormat * audioFormat);
//
//static AVAudioPCMBuffer * (^glissando)(double, double, double, AVAudioFormat *, Amplitude, FrequencyEnvelope);
//static void (^renderDataForToneBarrierScoreWithGlissando)(DataRenderedCompletionBlock);
//static AVAudioPCMBuffer * (^harmony)(double, double, double, AVAudioFormat *);
//static void (^renderDataForToneBarrierScoreWithHarmony)(DataRenderedCompletionBlock);

typedef struct block_struct {
    double frequency;
    double(^oscillateFrequency)(double, double);
    double(^trillFrequency)(double, double, double(^)(double frequency));
    double(^envelopeFrequency)(double);
} ChannelBufferSpecs;

@interface ToneGenerator ()
{
    double(^Normalize)(double, double);
    double(^Scale)(double, double, double, double, double);
    double(^RandomFrequency)(double, double, double);
    double(^HarmonizeFrequency)(double, TonalHarmony, TonalInterval);
    double(^BufferData)(double, double);
    ChannelBufferSpecs (^BufferSpecsForChannel)(double, double(^)(double), double(^)(double, double, double(^)(double)));
    double(^Interval)(double, TonalInterval);
    double(^TrillInterval)(double);
    //    double(^Amplitude)(double);
    
    
    double(^RenderTone)(double, ChannelBufferSpecs, ChannelBufferSpecs);
    double(^Tonality)(double, TonalInterval, TonalHarmony);
    double(^Trill)(double, double, double(^)(double frequency));
    double(^TrillInverse)(double, double, double(^)(double));
    double(^RandomDurationInterval)(void);
}

@property (class, readonly) Tones glissando;
@property (class, readonly) double(^scale)(double, double, double, double, double);
@property (class, readonly) double(^randomFrequency)(double, double, double);
@property (class, readonly) FrequencyBufferData frequencyGlissando;
@property (class, readonly) double(^frequencyEnvelope)(double, double, double, FrequencyEnvelopeInterval);
@property (class, readonly) FrequencyEnvelopeInterval frequencyEnvelopeInterval;
@property (class, readonly) Amplitude amplitude;
@property (class, readonly) double(^percentage)(double, double);
@property (class, readonly) AVAudioPCMBuffer * (^buffer)(double frequency, double harmonic_frequency, double duration, AVAudioFormat * audioFormat, FrequencyEnvelopeInterval frequencyEnvelopeBufferData, Amplitude amplitude, FrequencyBufferData frequencyBufferData);

@property (nonatomic, readonly) AVAudioMixerNode * _Nullable mainNode;
@property (nonatomic, readonly) AVAudioMixerNode * _Nullable mixerNode;
@property (nonatomic, readonly) AVAudioFormat * _Nullable audioFormat;
@property (nonatomic, readonly) AVAudioUnitReverb * _Nullable reverb;
@property (nonatomic, readonly) AVAudioTime * _Nullable time;
@property (nonatomic, readonly) AVAudioTime * _Nullable timeAux;


@end

@implementation ToneGenerator

//+ (RandomFrequencies)randomizeFrequencies
//{
//    return ^void(RandomizedFrequenciesCompletionBlock randomizedFrequencies)
//    {
//        NSUInteger r = arc4random_uniform(2);
//        NSLog(@"r == %lu", (unsigned long)r);
//        double frequency, harmonic_frequency;
//
//        double random = drand48();
//        random = pow(random, 1.0);
//        random = Scale(random, 0.0, 1.0, min_frequency, min_frequency);
//
//        switch (r) {
//            case 0:
//            {
//                frequency = random;
//                harmonic_frequency = frequency * (double)(5.0/4.0);
//                break;
//            }
//
//            case 1:
//            {
//                harmonic_frequency = random;
//                frequency = harmonic_frequency * (double)(5.0/4.0);
//                break;
//            }
//
//            default:
//                break;
//        }
//
//        randomizedFrequencies(frequency, harmonic_frequency);
//    }
//}

static ToneGenerator *sharedGenerator = NULL;
+ (nonnull ToneGenerator *)sharedGenerator
{
    static dispatch_once_t onceSecurePredicate;
    dispatch_once(&onceSecurePredicate,^
                  {
        if (!sharedGenerator)
        {
            sharedGenerator = [[self alloc] init];
        }
    });
    
    return sharedGenerator;
}



- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        srand48(time(0));
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterruption:) name:AVAudioEngineConfigurationChangeNotification object:_audioEngine];
        
    }
    
    [self setupEngine];
    
    return self;
}

+ (double(^)(double, double, double, double, double))scale
{
    return ^double(double value, double min, double max, double new_min, double new_max) {
        return (new_max - new_min) * (value - min) / (max - min) + new_min;
    };
}

+ (double(^)(double, double, double))randomFrequency
{
    return ^double(double min, double max, double weight)
    {
        double random = drand48();
        random = pow(random, weight);
        double frequency = ToneGenerator.scale(random, 0.0, 1.0, min, max);
        
        return frequency;
    };
}

+ (FrequencyBufferData)frequencyGlissando
{
    return ^double(double time, double frequency, double harmonic_frequency)
    {
        return sinf(M_PI * 2.0 * time * frequency); //ToneGenerator.scale(time, 0.0, 1.0, min_frequency, max_frequency));
    };
}

+ (double(^)(double, double))amplitude
{
    return ^double(double time, double slope)
    {
        return pow(sinf(time * M_PI), slope);
    };
}

+ (double (^)(double, double))percentage
{
    return ^double(double numerator, double denominator)
    {
        return (double)(numerator / denominator);
    };
}

+ (FrequencyEnvelopeInterval)frequencyEnvelopeInterval
{
    return ^double(double time, double frequency, double harmonic_frequency)
    {
        return ((max_trill_interval - min_trill_interval) * pow(time, 1.0/3.0)) + min_trill_interval;
    };
};

+ (double (^)(double, double, double, FrequencyEnvelopeInterval))frequencyEnvelope
{
    return ^double(double time, double frequency, double harmonic_frequency, FrequencyEnvelopeInterval frequencyEnvelopeInterval)
    {
        return pow(2.0 * pow(sinf(M_PI * time * frequencyEnvelopeInterval(time, frequency, harmonic_frequency)), 2.0) * 0.5, 4.0);
    };
}

//+ (FrequencyEnvelopeInterval)frequencyEnvelopeGlissando
//{
//    return ^double(double time, double frequency, double harmonic_frequency)
//    {
//        return ToneGenerator.frequencyGlissando(time, ToneGenerator.scale(time, 0.0, 1.0, frequency, harmonic_frequency));
//    };
//}

+ (FrequencyEnvelopeInterval)frequencyEnvelopeDyad
{
    return ^double(double time, double frequency, double harmonic_frequency)
    {
        return ((max_trill_interval - min_trill_interval) * pow(time, 1.0/3.0)) + min_trill_interval;
    };
}

+ (AVAudioPCMBuffer *(^)(double, double, double, AVAudioFormat *, FrequencyEnvelopeInterval, Amplitude, FrequencyBufferData))buffer
{
    return ^AVAudioPCMBuffer *(double frequency, double harmonic_frequency, double duration, AVAudioFormat *audioFormat, FrequencyEnvelopeInterval frequencyEnvelopeInterval, Amplitude amplitude, FrequencyBufferData frequencyBufferData)
    {
        frequency = frequency * duration;
        harmonic_frequency = harmonic_frequency * duration;
        double sampleRate = [audioFormat sampleRate];
        AVAudioFrameCount frameCount = (sampleRate * sum_duration_interval) * duration;
        AVAudioPCMBuffer *pcmBuffer  = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFormat frameCapacity:frameCount];
        pcmBuffer.frameLength        = pcmBuffer.frameCapacity; //(sampleRate * duration_interval)(duration_weight < 1.0) ? frameCount : sampleRate;
        float *l_channel             = pcmBuffer.floatChannelData[0];
        float *r_channel             = ([audioFormat channelCount] == 2) ? pcmBuffer.floatChannelData[1] : nil;
        
        for (int index = 0; index < frameCount; index++)
        {
            double time      = ToneGenerator.percentage(index, frameCount);
            double freq_env  = ToneGenerator.frequencyEnvelope(time, frequency, harmonic_frequency, frequencyEnvelopeInterval);
            double amp_env   = amplitude(time, 1.0);
            
            double f = frequencyBufferData(time,
                                           ToneGenerator.scale(time, 0.0, 1.0, frequency, harmonic_frequency),
                                           ToneGenerator.scale(time, 0.0, 1.0, harmonic_frequency, harmonic_frequency * (double)(5.0/4.0))) * freq_env * amp_env; //frequencyBufferData(time, frequency, harmonic_frequency) * amplitude(time, 1.0);
            if (l_channel) l_channel[index] = f;
            if (r_channel) r_channel[index] = f;
        }
        
        return pcmBuffer;
    };
}

+ (Tones)glissando
{
    return ^(AVAudioFormat *audioFormat, DataRenderedCompletionBlock dataRenderedCompletionBlock) {
        NSUInteger r = arc4random_uniform(2);
        double frequency, harmonic_frequency;
        switch (r) {
            case 0:
            {
                frequency = ToneGenerator.randomFrequency(min_frequency, max_frequency, 1.0);
                harmonic_frequency = frequency * (double)(5.0/4.0);
                break;
            }
                
            case 1:
            {
                harmonic_frequency = ToneGenerator.randomFrequency(min_frequency, max_frequency, 1.0);
                frequency = harmonic_frequency * (double)(5.0/4.0);
                break;
            }
                
            default:
                break;
        }
        
        double duration = RANDOM_NUMF(0.0, 2.0);
        
        dispatch_queue_t dataRendererSerialQueue = dispatch_queue_create("com.blogspot.demonicactivity.dataRendererSerialQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_block_t glissandoBlock = dispatch_block_create(0, ^{
            dataRenderedCompletionBlock(ToneGenerator.buffer(frequency, harmonic_frequency, duration, audioFormat, ToneGenerator.frequencyEnvelopeInterval, ToneGenerator.amplitude, ToneGenerator.frequencyGlissando), ^(NSString *playerNodeID) {
                NSLog(@"%@", playerNodeID);
                
                
            });
            
        });
        dispatch_async(dataRendererSerialQueue, glissandoBlock);
        dispatch_block_t glissandoBlockAux = dispatch_block_create(0, ^{
            dataRenderedCompletionBlock(ToneGenerator.buffer(harmonic_frequency, harmonic_frequency * (double)(5.0/4.0), sum_duration_interval - duration, audioFormat, ToneGenerator.frequencyEnvelopeInterval, ToneGenerator.amplitude, ToneGenerator.frequencyGlissando), ^(NSString *playerNodeID) {
                NSLog(@"%@", playerNodeID);
                ToneGenerator.glissando(audioFormat, dataRenderedCompletionBlock);
            });
        });
        dispatch_block_notify(glissandoBlock, dispatch_get_main_queue(), glissandoBlockAux);
    };
}

//+ (ToneBarrierScore)dyad
//{
//    return ^(AVAudioFormat *audioFormat, DataRenderedCompletionBlock dataRenderedCompletionBlock) {
//        __block double frequency, harmonic_frequency;
//        frequency = ToneGenerator.randomFrequency(min_frequency, max_frequency / 2.0, 1.0/3.0);
//        harmonic_frequency = frequency * (double)(1.1 + drand48());
//
//        double duration = RANDOM_NUMF(0.0, 2.0);
//
//        dispatch_queue_t dataRendererSerialQueue = dispatch_queue_create("com.blogspot.demonicactivity.dataRendererSerialQueue", DISPATCH_QUEUE_SERIAL);
//        dispatch_block_t glissandoBlock = dispatch_block_create(0, ^{
//            dataRenderedCompletionBlock(harmony(frequency, harmonic_frequency, duration,audioFormat), ^(NSString *playerNodeID) {
//
//            });
//        });
//        dispatch_async(dataRendererSerialQueue, glissandoBlock);
//        dispatch_block_t harmonyBlock = dispatch_block_create(0, ^{
//            frequency = ToneGenerator.randomFrequency(min_frequency, max_frequency / 8.0, 1.0/3.0);
//            harmonic_frequency = frequency * (double)(5.0/4.0);
//            dataRenderedCompletionBlock(harmony(frequency, harmonic_frequency, sum_duration_interval - duration, audioFormat), ^(NSString *playerNodeID) {
//                renderDataForToneBarrierScoreWithHarmony(dataRenderedCompletionBlock);
//            });
//        });
//        dispatch_block_notify(glissandoBlock, dispatch_get_main_queue(), harmonyBlock);
//    };
//}

- (void)handleInterruption:(NSNotification *)notification
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    UInt8 interruptionType = [[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] intValue];
    
    if (interruptionType == AVAudioSessionInterruptionTypeBegan)
    {
        NSLog(@"AVAudioSessionInterruptionTypeBegan");
    } else if (interruptionType == AVAudioSessionInterruptionTypeEnded)
    {
        if (_audioEngine.mainMixerNode.volume > 0.0)
        {
            [self.delegate play:nil];
        }
        NSLog(@"AVAudioSessionInterruptionTypeEnded");
    }
    AVAudioSessionInterruptionOptions options = [[notification.userInfo valueForKey:AVAudioSessionInterruptionOptionKey] intValue];
    if (options == AVAudioSessionInterruptionOptionShouldResume)
    {
        //        [self.delegate play:nil];
        NSLog(@"AVAudioSessionInterruptionOptionShouldResume TRUE");
    } else {
        NSLog(@"AVAudioSessionInterruptionOptionShouldResume FALSE");
    }
}


//- (void)handleInterruption:(NSNotification *)notification
//{
//
//    NSLog(@"Session interrupted > --- %s ---\n", theInterruptionType == AVAudioSessionInterruptionTypeBegan ? "Begin Interruption" : "End Interruption");
//
//    if (theInterruptionType == AVAudioSessionInterruptionTypeBegan) {
//        _isSessionInterrupted = YES;
//
//        //stop the playback of the nodes
//        for (int i = 0; i < _collisionPlayerArray.count; i++)
//            [[_collisionPlayerArray objectAtIndex:i] stop];
//
//        if ([self.delegate respondsToSelector:@selector(engineWasInterrupted)]) {
//            [self.delegate engineWasInterrupted];
//        }
//
//    }
//    if (theInterruptionType == AVAudioSessionInterruptionTypeEnded) {
//        // make sure to activate the session
//        NSError *error;
//        bool success = [[AVAudioSession sharedInstance] setActive:YES error:&error];
//        if (!success)
//            NSLog(@"AVAudioSession set active failed with error: %@", [error localizedDescription]);
//        else {
//            _isSessionInterrupted = NO;
//            if (_isConfigChangePending) {
//                //there is a pending config changed notification
//                NSLog(@"Responding to earlier engine config changed notification. Re-wiring connections and starting once again");
//                [self makeEngineConnections];
//                [self startEngine];
//
//                _isConfigChangePending = NO;
//            }
//            else {
//                // start the engine once again
//                [self startEngine];
//            }
//        }
//    }
//}


- (void)setupEngine
{
    _audioEngine = [[AVAudioEngine alloc] init];
    
    _mainNode = _audioEngine.mainMixerNode;
    
    double sampleRate = [_mainNode outputFormatForBus:0].sampleRate;
    AVAudioChannelCount channelCount = [_mainNode outputFormatForBus:0].channelCount;
    _audioFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:sampleRate channels:channelCount];
    
    _playerNode = [[AVAudioPlayerNode alloc] init];
    [_playerNode setRenderingAlgorithm:AVAudio3DMixingRenderingAlgorithmAuto];
    [_playerNode setSourceMode:AVAudio3DMixingSourceModeAmbienceBed];
    [_playerNode setPosition:AVAudioMake3DPoint(0.0, 0.0, 0.0)];
    
    _playerNodeAux = [[AVAudioPlayerNode alloc] init];
    [_playerNodeAux setRenderingAlgorithm:AVAudio3DMixingRenderingAlgorithmAuto];
    [_playerNodeAux setSourceMode:AVAudio3DMixingSourceModeAmbienceBed];
    [_playerNodeAux setPosition:AVAudioMake3DPoint(0.0, 0.0, 0.0)];
    
    _mixerNode = [[AVAudioMixerNode alloc] init];
    
    _reverb = [[AVAudioUnitReverb alloc] init];
    [_reverb loadFactoryPreset:AVAudioUnitReverbPresetLargeChamber];
    [_reverb setWetDryMix:100.0];
    
    [_audioEngine attachNode:_reverb];
    [_audioEngine attachNode:_playerNode];
    [_audioEngine attachNode:_playerNodeAux];
    [_audioEngine attachNode:_mixerNode];
    
    [_audioEngine connect:_playerNode     to:_mixerNode   format:_audioFormat];
    [_audioEngine connect:_playerNodeAux  to:_mixerNode   format:_audioFormat];
    [_audioEngine connect:_mixerNode      to:_reverb      format:_audioFormat];
    [_audioEngine connect:_reverb         to:_mainNode    format:_audioFormat];
}

- (BOOL)startEngine
{
    __autoreleasing NSError *error = nil;
    if ([_audioEngine startAndReturnError:&error])
    {
        [[AVAudioSession sharedInstance] setActive:YES error:&error];
        if (error)
        {
            NSLog(@"%@", [error description]);
        } else {
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
            if (error)
            {
                NSLog(@"%@", [error description]);
            } else {
                _time          = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))];
                _timeAux       = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))];
                CMTime cmtime  = CMTimeAdd(CMTimeMakeWithSeconds([AVAudioTime secondsForHostTime:[self->_timeAux hostTime]], NSEC_PER_SEC), CMTimeMakeWithSeconds(1.0, NSEC_PER_SEC));
                _timeAux = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(cmtime)];
                
            }
        }
    } else {
        if (error)
        {
            NSLog(@"%@", [error description]);
        }
    }
    
    return (error) ? FALSE : TRUE;
}

AVAudio3DPoint GenerateRandomXPosition()
{
    double randomX = arc4random_uniform(40) - 20.0;
    AVAudio3DPoint point = AVAudioMake3DPoint(randomX, 0.0, 0.0);
    
    return point;
}

- (void)play
{
    if ([_audioEngine isRunning])
    {
        // TO-DO: play a "closing" buffer before pausing audio engine
        [_audioEngine pause];
        [_audioEngine.mainMixerNode setOutputVolume:0.0];
    } else {
        if ([self startEngine])
        {
            [_audioEngine.mainMixerNode setOutputVolume:1.0];
            //            dispatch_queue_t buffer_serial_queue = dispatch_queue_create("com.blogspot.demonicactivity.serialqueue", DISPATCH_QUEUE_SERIAL);
            //            dispatch_block_t render_buffer_block = dispatch_block_create(0, ^{
            //                if (![_playerNode isPlaying]) [_playerNode play];
            //                AVAudioTime *time = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))];
            //                renderData(Tone(min_frequency, max_frequency, 10.0), time, ^(TonePlayerNodeData *tonePlayerNodeData, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
            //                    [self->_playerNode scheduleBuffer:tonePlayerNodeData->buffer atTime:tonePlayerNodeData->time options:AVAudioPlayerNodeBufferInterruptsAtLoop completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
            //                        if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
            //                        {
            //                            [self->_playerNode setPosition:GenerateRandomXPosition()];
            //                            double bufferDuration = tonePlayerNodeData->buffer.frameLength / _audioFormat.sampleRate;
            //                            CMTime cmtime  = CMTimeAdd(CMTimeMakeWithSeconds([AVAudioTime secondsForHostTime:[tonePlayerNodeData->time hostTime]], NSEC_PER_SEC), CMTimeMakeWithSeconds(bufferDuration, NSEC_PER_SEC));
            //                            AVAudioTime *endTime = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(cmtime)];
            //
            //                            dataPlayedBackCompletionBlock((!tonePlayerNodeData->time) ? time : endTime, [NSString stringWithFormat:@"playerNode %llu - %llu", time.hostTime, endTime.hostTime]);
            //                            tonePlayerNodeData->buffer = nil;
            //                            free(tonePlayerNodeData);
            //                        }
            //                    }];
            //
            //
            //                });
            //            });
            //            dispatch_async(buffer_serial_queue, render_buffer_block);
            
            // TO-DO: sustain the last frequency of the glissando for the same duration as the glissando
            if (![_playerNode isPlaying]) [_playerNode play];
            ToneGenerator.glissando(self.audioFormat, ^(AVAudioPCMBuffer *buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
                [self->_playerNode scheduleBuffer:buffer completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
                    if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
                    {
                        [self->_playerNode setPosition:GenerateRandomXPosition()];
                        dataPlayedBackCompletionBlock([NSString stringWithFormat:@"AVAudioPlayerNodeCompletionDataPlayedBack"]);
                    }
                }];
            });
            
            //            if (![_playerNodeAux isPlaying]) [_playerNodeAux play];
            //            renderDataForToneBarrierScoreWithHarmony(^(AVAudioPCMBuffer *buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
            //                [self->_playerNodeAux scheduleBuffer:buffer completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
            //                    if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
            //                    {
            //                        [self->_playerNodeAux setPosition:GenerateRandomXPosition()];
            //                        dataPlayedBackCompletionBlock([NSString stringWithFormat:@"AVAudioPlayerNodeAuxCompletionDataPlayedBack"]);
            //                    }
            //                }];
            //            });
            
            //            if (![_playerNodeAux isPlaying]) [_playerNodeAux play];
            //            AVAudioTime *timeAux = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))];
            //            renderData(Tone(min_frequency, max_frequency, 1.0/5.5), timeAux, ^(TonePlayerNodeData *tonePlayerNodeData, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
            //                [self->_playerNodeAux scheduleBuffer:tonePlayerNodeData->buffer atTime:tonePlayerNodeData->time options:AVAudioPlayerNodeBufferInterruptsAtLoop completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
            //                    if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
            //                    {
            //                        [self->_playerNodeAux setPosition:GenerateRandomXPosition()];
            //                        double bufferDuration = tonePlayerNodeData->buffer.frameLength / _audioFormat.sampleRate;
            //                        CMTime cmtime  = CMTimeAdd(CMTimeMakeWithSeconds([AVAudioTime secondsForHostTime:[tonePlayerNodeData->time hostTime]], NSEC_PER_SEC), CMTimeMakeWithSeconds(bufferDuration, NSEC_PER_SEC));
            //                        AVAudioTime *endTime = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(cmtime)];
            //
            //                        dataPlayedBackCompletionBlock((!tonePlayerNodeData->time) ? timeAux : endTime, [NSString stringWithFormat:@"playerNodeAux %llu - %llu", timeAux.hostTime, endTime.hostTime]);
            //                        tonePlayerNodeData->buffer = nil;
            //                        tonePlayerNodeData->time = nil;
            //                        free(tonePlayerNodeData);
            //                    }
            //                }];
            //            });
        }
    }
}



// Elements of an effective tone:
// High-pitched
// Modulating amplitude
// Alternating channel output
// Loud
// Non-natural (no spatialization)
//
// Elements of an effective score:
// Random frequencies
// Random duration
// Random tonality

// To-Do: Multiply the frequency by a random number between 1.01 and 1.1)

double Envelope(double x, TonalEnvelope envelope)
{
    double x_envelope = 1.0;
    switch (envelope) {
        case TonalEnvelopeAverageSustain:
            x_envelope = sinf(x * M_PI) * (sinf((2 * x * M_PI) / 2));
            break;
            
        case TonalEnvelopeLongSustain:
            x_envelope = sinf(x * M_PI) * -sinf(
                                                ((Envelope(x, TonalEnvelopeAverageSustain) - (2.0 * Envelope(x, TonalEnvelopeAverageSustain)))) / 2.0)
            * (M_PI / 2.0) * 2.0;
            break;
            
        case TonalEnvelopeShortSustain:
            x_envelope = sinf(x * M_PI) * -sinf(
                                                ((Envelope(x, TonalEnvelopeAverageSustain) - (-2.0 * Envelope(x, TonalEnvelopeAverageSustain)))) / 2.0)
            * (M_PI / 2.0) * 2.0;
            break;
            
        default:
            break;
    }
    
    return x_envelope;
}

//typedef NS_ENUM(NSUInteger, Trill) {
//    TonalTrillUnsigned,
//    TonalTrillInverse
//};


@end
