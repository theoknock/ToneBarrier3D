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

#define max_frequency      2000.00
#define min_frequency       500.00
#define max_trill_interval   12.00
#define min_trill_interval    2.00
#define duration_interval     2.00
#define duration_maximum      4.00
#define duration_minimum      1.00

typedef struct {
    AVAudioPCMBuffer * _Nonnull buffer;
    AVAudioTime *startTime;
    double duration;
} TonePlayerNodeData;

typedef void (^DataPlayedBackCompletionBlock)(AVAudioTime *, NSString *);
typedef void (^DataRenderedCompletionBlock)(TonePlayerNodeData *tonePlayerNodeData, DataPlayedBackCompletionBlock);

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

typedef struct {
    double frequency;
    double harmonized_frequency;
} Frequencies;
Frequencies *(^harmonizeFrequencies)(double, TonalInterval, TonalHarmony);
static void (^renderData)(double, AVAudioTime *, DataRenderedCompletionBlock);

@interface ToneGenerator ()
{
    double(^Normalize)(double, double);
    double(^Scale)(double, double, double, double, double);
    double(^Tone)(double, double, double);
    double(^Interval)(double, TonalInterval);
    double(^TrillInterval)(double);
    double(^Amplitude)(double);
    double(^Frequency)(double, double);
    double(^Tonality)(double, TonalInterval, TonalHarmony);
    double(^Trill)(double, double);
    double(^TrillInverse)(double, double);
    double(^RandomDurationInterval)(void);
    AVAudioTime *(^AVAudioTimeWithCMTime)(CMTime);
    CMTime(^CMTimeWithAVAudioTime)(AVAudioTime *);
    AVAudioTime *(^AdjustBufferScheduleTime)(AVAudioTime *);
    AVAudioTime *(^ValidateBufferScheduleTime)(AVAudioTime *);
}

@property (nonatomic, readonly) AVAudioMixerNode * _Nullable mainNode;
@property (nonatomic, readonly) AVAudioMixerNode * _Nullable mixerNode;
@property (nonatomic, readonly) AVAudioFormat * _Nullable audioFormat;

@property (nonatomic, readonly) AVAudioPlayerNode * _Nullable playerNode;
@property (nonatomic, readonly) AVAudioPlayerNode * _Nullable playerNodeAux;
@property (nonatomic, readonly) AVAudioUnitReverb * _Nullable reverb;
@property (nonatomic, readonly) AVAudioTime * _Nullable time;
@property (nonatomic, readonly) AVAudioTime * _Nullable timeAux;


@end

@implementation ToneGenerator

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
        Normalize = ^double(double a, double b)
        {
            return (double)(a / b);
        };
        
        Scale = ^double(double value, double min, double max, double new_min, double new_max)
        {
            return (new_max - new_min) * (value - min) / (max - min) + new_min;
        };
        
        // TO-DO: Rename to "Frequency" and rename current "Frequency" to something related to audio buffer data
        Tone = ^double(double min, double max, double weight)
        {
            double frequency = (((double)arc4random() / UINT_MAX) * (max - min) + min);
            frequency = pow(Scale(frequency, min_frequency, max_frequency, 0.0, 1.0), weight);
            frequency = Scale(frequency, 0.0, 1.0, min_frequency, max_frequency);
            
            return frequency;
        };
        
        Frequency = ^double(double time, double frequency)
        {
            return pow(sinf(M_PI * time * frequency), 2.0);
        };
        
        Tonality = ^double(double frequency, TonalInterval interval, TonalHarmony harmony)
        {
            double new_frequency = frequency;
            new_frequency *= (harmony == TonalHarmonyDissonance) ? (1.1 + drand48()) :
            (harmony == TonalHarmonyConsonance) ? Interval(frequency, interval) :
            (harmony == TonalHarmonyRandom) ? Tonality(frequency, interval, (TonalHarmony)arc4random_uniform(2)) :
            frequency;
            
            return new_frequency;
        };
        
        Amplitude = ^double(double time)
        {
            return pow(sinf(time * M_PI), 3.0) * 0.5;
        };
        
        Interval = ^double(double frequency, TonalInterval interval)
        {
            double factorialx = (interval == TonalIntervalRandom)       ? Interval(frequency, (TonalInterval)arc4random_uniform(7)) :
                                (interval == TonalIntervalUnison)       ? 1.0     :
                                (interval == TonalIntervalOctave)       ? 2.0     :
                                (interval == TonalIntervalMajorSixth)   ? 5.0/3.0 :
                                (interval == TonalIntervalPerfectFifth) ? 4.0/3.0 :
                                (interval == TonalIntervalMajorThird)   ? 5.0/4.0 :
                                (interval == TonalIntervalMinorThird)   ? 6.0/5.0 :
                                frequency;
            
            double new_frequency = frequency * factorialx;
            
            return new_frequency;
        };
        
        RandomDurationInterval = ^double()
        {
            double multiplier = (((double)arc4random() / UINT_MAX) * (duration_maximum - duration_minimum) + duration_minimum);
            
            return multiplier;
        };
        
        TrillInterval = ^double(double frequency)
        {
            return ((frequency / (max_frequency - min_frequency) * (max_trill_interval - min_trill_interval)) + min_trill_interval);
        };
        
        TrillInverse = ^double(double time, double trill)
        {
            return pow(-(2.0 * pow(sinf(M_PI * time * trill), 2.0) * 0.5) + 1.0, 4.0);
        };
        
        harmonizeFrequencies = ^Frequencies *(double frequency, TonalInterval interval, TonalHarmony harmony) {
            Frequencies *f = (Frequencies *)calloc(2, sizeof(Frequencies));
            f->frequency = frequency;
            f->harmonized_frequency = Tonality(frequency, TonalIntervalRandom, TonalHarmonyRandom);
            
            TrillInterval(frequency);
            return f;
        };
        
        Trill = ^double(double time, double trill)
        {
            return pow(2.0 * pow(sinf(M_PI * time * trill), 2.0) * 0.5, 4.0);
        };
        
        CMTimeWithAVAudioTime = ^CMTime(AVAudioTime *time)
        {
            CMTime cm_time  = CMTimeMakeWithSeconds([AVAudioTime secondsForHostTime:[time hostTime]], NSEC_PER_SEC);
            
            return cm_time;
        };
        
        AVAudioTimeWithCMTime = ^AVAudioTime *(CMTime cm_time)
        {
            AVAudioTime *time = [[AVAudioTime alloc] initWithHostTime:CMTimeGetSeconds(cm_time)];
                                            
            return time;
        };
        
        AdjustBufferScheduleTime = ^AVAudioTime *(AVAudioTime *time)
        {
            CMTime difference = CMTimeSubtract(CMClockGetTime(CMClockGetHostTimeClock()), CMTimeWithAVAudioTime(time));
            CMTime new_time = CMTimeAdd(CMClockGetTime(CMClockGetHostTimeClock()), difference);
            AVAudioTime *offsetTime = AVAudioTimeWithCMTime(new_time);
            
            return offsetTime;
        };
        
        ValidateBufferScheduleTime = ^AVAudioTime *(AVAudioTime *time)
        {
            // If the buffer schedule time is less than the current time,
            // subtract the difference between the two times,
            // multiply the product by two,
            // convert the product to seconds,
            // add the product to the current time and
            // return the new time;
            // otherwise, return the buffer schedule time

            uint64_t current_host_time = CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()));
            uint64_t host_time       = [time hostTime];
            AVAudioTime *new_time = (host_time > current_host_time) ? time : [[AVAudioTime alloc] initWithHostTime:current_host_time + (current_host_time - host_time)];
            
            return new_time;
        };
        
        renderData = ^void(double frequency, AVAudioTime *lastEndTime, DataRenderedCompletionBlock dataRenderedCompletionBlock)
        {
            TonePlayerNodeData * (^createTonePlayerNodeData)(AVAudioFormat *, AVAudioTime *);
            createTonePlayerNodeData = ^TonePlayerNodeData * (AVAudioFormat * audioFormat, AVAudioTime *startTime)
            {
                double sampleRate = [audioFormat sampleRate];
                double duration_weight = RandomDurationInterval();
                AVAudioFrameCount frameCount = sampleRate * duration_weight;
                AVAudioPCMBuffer *pcmBuffer  = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFormat frameCapacity:frameCount];
                pcmBuffer.frameLength        = frameCount / duration_weight;
                float *l_channel             = pcmBuffer.floatChannelData[0];
                float *r_channel             = pcmBuffer.floatChannelData[1]; //([audioFormat channelCount] == 2) ? pcmBuffer.floatChannelData[1] : nil;
                
                double harmonized_frequency = Tonality(frequency, TonalIntervalRandom, TonalHarmonyRandom);
                double trill_interval       = TrillInterval(frequency);
                for (int index = 0; index < frameCount; index++)
                {
                    double normalized_index = Normalize(index, frameCount);
                    double trill            = Trill(normalized_index, trill_interval);
                    double trill_inverse    = TrillInverse(normalized_index, trill_interval);
                    double amplitude        = Amplitude(normalized_index);
                    
                    double f = Frequency(normalized_index, frequency) * amplitude * trill;
                    double h = Frequency(normalized_index, harmonized_frequency) * amplitude * trill_inverse;
                    
                    if (l_channel) l_channel[index] = f;
                    if (r_channel) r_channel[index] = f;
                }
                
                TonePlayerNodeData *tonePlayerNodeData = calloc(1, sizeof(TonePlayerNodeData));
                tonePlayerNodeData->buffer    = pcmBuffer;
                tonePlayerNodeData->startTime = startTime;
                
//                NSTimeInterval difference = frameCount / sampleRate;
//                CMTime newStartTime = CMTimeAdd(CMTimeMakeWithSeconds(0.25, NSEC_PER_SEC), CMTimeWithAVAudioTime(startTime));
//                tonePlayerNodeData->duration  = [AVAudioTime hostTimeForSeconds:CMTimeGetSeconds(newStartTime)];
                
                return tonePlayerNodeData;
            };
            
            // Returns audio buffers via DataRenderedCompletionBlock (recursive until STOP)
            dataRenderedCompletionBlock(createTonePlayerNodeData(_audioFormat, lastEndTime), ^(AVAudioTime *lastEndTime, NSString *playerNodeID)
                                        {
                NSLog(playerNodeID);
                
                renderData(frequency, lastEndTime, dataRenderedCompletionBlock);
            });
        };
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterruption:) name:AVAudioEngineConfigurationChangeNotification object:_audioEngine];

    }
    
    [self setupEngine];
    
    return self;
}

- (void)handleInterruption:(NSNotification *)notification
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    UInt8 interruptionType = [[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] intValue];
    
    if (interruptionType == AVAudioSessionInterruptionTypeBegan)
    {
        NSLog(@"AVAudioSessionInterruptionTypeBegan");
    } else if (interruptionType == AVAudioSessionInterruptionTypeEnded){
        NSLog(@"AVAudioSessionInterruptionTypeEnded");
    }
    AVAudioSessionInterruptionOptions options = [[notification.userInfo valueForKey:AVAudioSessionInterruptionOptionKey] intValue];
    if (options == AVAudioSessionInterruptionOptionShouldResume)
    {
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
        
//
    } else {
        if ([self startEngine])
        {
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
            
            AVAudioTime *(^currentAVAudioTime)(void) = ^AVAudioTime *(void)
            {
//                CMTime newStartTime = CMTimeAdd(CMTimeMakeWithSeconds(1.0, NSEC_PER_SEC), CMClockGetTime(CMClockGetHostTimeClock()));
//                AVAudioTime *startTime = [AVAudioTime timeWithHostTime:[AVAudioTime hostTimeForSeconds:CMTimeGetSeconds(newStartTime)]];
                
                AVAudioTime *currentTime = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))];
                
                return currentTime;
            };
        
            if (![_playerNode isPlaying]) [_playerNode play];
            renderData(Tone(min_frequency, max_frequency, 5.0), currentAVAudioTime(), ^(TonePlayerNodeData *tonePlayerNodeData, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
                [self->_playerNode scheduleBuffer:tonePlayerNodeData->buffer completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
                    if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
                    {
                        [self->_playerNode setPosition:GenerateRandomXPosition()];
//                        AVAudioTime *newStartTime = [[AVAudioTime alloc] initWithHostTime:(time.hostTime + tonePlayerNodeData->duration)];

                        dataPlayedBackCompletionBlock(currentAVAudioTime(), [NSString stringWithFormat:@"AVAudioPlayerNodeCompletionDataPlayedBack"]);
                        tonePlayerNodeData->buffer    = nil;
                        tonePlayerNodeData->startTime = nil;
                        free(tonePlayerNodeData);
                    }
                }];
            });
            
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
