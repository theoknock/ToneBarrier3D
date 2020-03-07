//
//  ToneGenerator.m
//  ToneBarrier3D
//
//  Created by Xcode Developer on 2/1/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

// TO-DO: Create moving sound (velocity) to stimulate instinctive sound localizaton; cues for sound source localization: time- and level-differences (or intensity-difference) between both ears
//

#import "ToneGenerator.h"

#define max_frequency      1500.0
#define min_frequency       100.0
#define max_trill_interval   12.0
#define min_trill_interval    2.0
#define duration_interval     2.00
#define duration_maximum      1.75
#define duration_minimum      0.25

static double _maxFrequency = 2000.0;
static double _minFrequency = 500.0;
static double sampleRate = 0;
static double channelCount = 0;

typedef void (^DataPlayedBackCompletionBlock)(NSString *);
typedef void (^DataRenderedCompletionBlock)(AVAudioPCMBuffer * _Nonnull, DataPlayedBackCompletionBlock);

static void (^renderData)(DataRenderedCompletionBlock);


@interface ToneGenerator ()

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

+ (double(^)(void))RandomDurationInterval
{
    return ^double(void)
    {
        double multiplier = (((double)arc4random() / UINT_MAX) * (duration_maximum - duration_minimum) + duration_minimum);
        
        return multiplier;
    };
}

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
            renderData = ^void(DataRenderedCompletionBlock dataRenderedCompletionBlock)
            {
                AVAudioPCMBuffer * (^createAudioBuffer)(AVAudioFrameCount, AVAudioFormat *, double);
                    createAudioBuffer = ^AVAudioPCMBuffer * (AVAudioFrameCount frameCount, AVAudioFormat * audioFormat, double frequency)
                    {
                        AVAudioPCMBuffer *pcmBuffer  = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFormat frameCapacity:frameCount];
                        pcmBuffer.frameLength        = frameCount;
                        float *l_channel             = pcmBuffer.floatChannelData[0];
                        float *r_channel             = ([audioFormat channelCount] == 2) ? pcmBuffer.floatChannelData[1] : nil;
                
                        double harmonized_frequency = Tonality(frequency, TonalIntervalRandom, TonalHarmonyRandom);
                        double trill_interval       = ToneGenerator.TrillInterval(frequency);
                        for (int index = 0; index < frameCount; index++)
                        {
                            double normalized_index = Normalize(index, frameCount);
                            double trill            = ToneGenerator.Trill(normalized_index, trill_interval);
                            double trill_inverse    = ToneGenerator.TrillInverse(normalized_index, trill_interval);
                            double amplitude        = ToneGenerator.Amplitude(normalized_index);
                
                            if (l_channel) l_channel[index] = ToneGenerator.Frequency(normalized_index, frequency) * amplitude * trill;
                            if (r_channel) r_channel[index] = ToneGenerator.Frequency(normalized_index, harmonized_frequency) * amplitude * trill_inverse;
                        }
                
                        return pcmBuffer;
                    };
                AVAudioFrameCount frameCount = [_audioFormat sampleRate] * ToneGenerator.RandomDurationInterval();
                dataRenderedCompletionBlock(createAudioBuffer(frameCount, _audioFormat, (((double)arc4random() / UINT_MAX) * (max_frequency - min_frequency) + min_frequency)), ^(NSString *string)
                {
                    NSLog(@"%@", string);
                    renderData(dataRenderedCompletionBlock);
                });
            };

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterruption:) name:AVAudioEngineConfigurationChangeNotification object:_audioEngine];
        
        [self setupEngine];
    }
    
    return self;
}

+ (double)maxFrequency
{
    return _maxFrequency;
}

+ (double)minFrequency
{
    return _minFrequency;
}

+ (void)setMaxFrequency:(double)maxFrequency
{
    _maxFrequency = maxFrequency;
}

+ (void)setMinFrequency:(double)minFrequency
{
    _minFrequency = minFrequency;
}

- (void)handleInterruption:(NSNotification *)notification
{
    NSDictionary *info = notification.userInfo;
    
    AVAudioSessionInterruptionType type = [info[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (type == AVAudioSessionInterruptionTypeBegan)
    {
        NSLog(@"AVAudioSessionInterruptionTypeBegan");
    } else if (type == AVAudioSessionInterruptionTypeEnded){
        NSLog(@"AVAudioSessionInterruptionTypeEnded");
        AVAudioSessionInterruptionOptions options = [info[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
        if (options == AVAudioSessionInterruptionOptionShouldResume)
        {
            NSLog(@"AVAudioSessionInterruptionOptionShouldResume TRUE");
        } else {
            NSLog(@"AVAudioSessionInterruptionOptionShouldResume FALSE");
        }
    } else {
        NSLog(@"AVAudioSessionInterruptionType UNKNOWN");
    }
}

- (void)setupEngine
{
    _audioEngine = [[AVAudioEngine alloc] init];
    
    _mainNode = _audioEngine.mainMixerNode;
    
    sampleRate = [_mainNode outputFormatForBus:0].sampleRate;
    channelCount = [_mainNode outputFormatForBus:0].channelCount;
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
    [_reverb loadFactoryPreset:AVAudioUnitReverbPresetLargeHall];
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

AVAudioFormat * AudioFormat()
{
    return [[AVAudioFormat alloc] initStandardFormatWithSampleRate:sampleRate channels:channelCount];
}


- (void)createAudioBufferWithCompletionBlock:(DataRenderedCompletionBlock)dataRenderedCompletionBlock
{
    AVAudioPCMBuffer * (^createAudioBuffer)(AVAudioFrameCount, double);
    createAudioBuffer = ^AVAudioPCMBuffer * (AVAudioFrameCount frameCount, double frequency)
    {
        AVAudioPCMBuffer *pcmBuffer  = [[AVAudioPCMBuffer alloc] initWithPCMFormat:AudioFormat() frameCapacity:frameCount];
        pcmBuffer.frameLength        = frameCount;
        float *l_channel             = pcmBuffer.floatChannelData[0];
        float *r_channel             = ([AudioFormat() channelCount] == 2) ? pcmBuffer.floatChannelData[1] : nil;

        double harmonized_frequency = Tonality(frequency, TonalIntervalRandom, TonalHarmonyRandom);
        double trill_interval       = ToneGenerator.TrillInterval(frequency);
        for (int index = 0; index < frameCount; index++)
        {
            double normalized_index = Normalize(index, frameCount);
            double trill            = ToneGenerator.Trill(normalized_index, trill_interval);
            double trill_inverse    = ToneGenerator.TrillInverse(normalized_index, trill_interval);
            double amplitude        = ToneGenerator.Amplitude(normalized_index);

            if (l_channel) l_channel[index] = ToneGenerator.Frequency(normalized_index, frequency) * amplitude * trill;
            if (r_channel) r_channel[index] = ToneGenerator.Frequency(normalized_index, harmonized_frequency) * amplitude * trill_inverse;
        }

        return pcmBuffer;
    };

    static void (^renderData)(NSUInteger);
    renderData = ^void(NSUInteger interval_divisor)
    {
//        NSUInteger next_divisor = (interval_divisor == duration_interval) ? 0 : interval_divisor++;
        AVAudioFrameCount frameCount = [AudioFormat() sampleRate] * ToneGenerator.RandomDurationInterval();
        dataRenderedCompletionBlock(createAudioBuffer(frameCount, (((double)arc4random() / UINT_MAX) * (max_frequency - min_frequency) + min_frequency)), ^(NSString *string){
            NSLog(@"%@", string);
            renderData(0);
        });
    };
    renderData(1);
}

- (void)play
{
    if ([_audioEngine isRunning])
    {
        [_audioEngine pause];
    } else {
        if ([self startEngine])
        {
            if (![_playerNode isPlaying]) [_playerNode play];
            [self createAudioBufferWithCompletionBlock:^(AVAudioPCMBuffer * _Nonnull buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
//                CMTime cmtime = CMTimeAdd(CMTimeMakeWithSeconds([AVAudioTime secondsForHostTime:[self->_time hostTime]], NSEC_PER_SEC), CMTimeMakeWithSeconds(1.0, NSEC_PER_SEC));
//                self->_time   = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(cmtime)];
                [self->_playerNode scheduleBuffer:buffer atTime:[[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))] options:AVAudioPlayerNodeBufferInterruptsAtLoop completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
                    if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
                    {
                        dataPlayedBackCompletionBlock(@"dataPlayedBackCompletionBlock (_playerNode)");
                    }
                }];
            }];

            if (![_playerNodeAux isPlaying]) [_playerNodeAux play];
            [self createAudioBufferWithCompletionBlock:^(AVAudioPCMBuffer * _Nonnull buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
//                CMTime cmtime  = CMTimeAdd(CMTimeMakeWithSeconds([AVAudioTime secondsForHostTime:[self->_timeAux hostTime]], NSEC_PER_SEC), CMTimeMakeWithSeconds(1.0, NSEC_PER_SEC));
//                self->_timeAux = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(cmtime)];
                [self->_playerNodeAux scheduleBuffer:buffer atTime:[[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))] options:AVAudioPlayerNodeBufferInterruptsAtLoop completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
                    if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
                    {
                        dataPlayedBackCompletionBlock(@"dataPlayedBackCompletionBlock (_playerNodeAux)");
                    }
                }];
            }];
        }
    }
}

double Normalize(double a, double b)
{
    return (double)(a / b);
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

double Tonality(double frequency, TonalInterval interval, TonalHarmony harmony)
{
    double new_frequency = frequency;
    switch (harmony) {
        case TonalHarmonyDissonance:
            new_frequency *= (1.1 + drand48());
            break;
            
        case TonalHarmonyConsonance:
            new_frequency = ToneGenerator.Interval(frequency, interval);
            break;
            
        case TonalHarmonyRandom:
            new_frequency = Tonality(frequency, interval, (TonalHarmony)arc4random_uniform(2));
            break;
            
        default:
            break;
    }
    
    return new_frequency;
}

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

typedef NS_ENUM(NSUInteger, Trill) {
    TonalTrillUnsigned,
    TonalTrillInverse
};

+ (double(^)(double, double))Frequency
{
    return ^double(double time, double frequency)
    {
        return pow(sinf(M_PI * time * frequency), 2.0);
    };
}

+ (double(^)(double))TrillInterval
{
    return ^double(double frequency)
    {
        return ((frequency / (max_frequency - min_frequency) * (max_trill_interval - min_trill_interval)) + min_trill_interval);
    };
}

+ (double(^)(double, double))Trill
{
    return ^double(double time, double trill)
    {
        return pow(2.0 * pow(sinf(M_PI * time * trill), 2.0) * 0.5, 4.0);
    };
}

+ (double(^)(double, double))TrillInverse
{
    return ^double(double time, double trill)
    {
        return pow(-(2.0 * pow(sinf(M_PI * time * trill), 2.0) * 0.5) + 1.0, 4.0);
    };
}

+ (double(^)(double))Amplitude
{
    return ^double(double time)
    {
        return pow(sinf(time * M_PI), 3.0) * 0.5;
    };
}

+ (double(^)(double, TonalInterval))Interval
{
    return ^double(double frequency, TonalInterval interval)
    {
        double new_frequency = frequency;
        switch (interval)
        {
            case TonalIntervalUnison:
                new_frequency *= 1.0;
                break;
                
            case TonalIntervalOctave:
                new_frequency *= 2.0;
                break;
                
            case TonalIntervalMajorSixth:
                new_frequency *= 5.0/3.0;
                break;
                
            case TonalIntervalPerfectFifth:
                new_frequency *= 4.0/3.0;
                break;
                
            case TonalIntervalMajorThird:
                new_frequency *= 5.0/4.0;
                break;
                
            case TonalIntervalMinorThird:
                new_frequency *= 6.0/5.0;
                break;
                
            case TonalIntervalRandom:
                new_frequency = ToneGenerator.Interval(frequency, (TonalInterval)arc4random_uniform(7));
                
            default:
                break;
        }
        
        return new_frequency;
    };
};


// ------------------------------------------------------------------------------------------------------------------------

+ (AVAudioPCMBuffer * (^)(AVAudioFormat *, AVAudioFrameCount, double))RenderData
{
    return ^AVAudioPCMBuffer * (AVAudioFormat *audioFormat, AVAudioFrameCount frameCount, double frequency)
    {
        AVAudioPCMBuffer *pcmBuffer  = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFormat frameCapacity:frameCount];
        pcmBuffer.frameLength        = frameCount;
        float *l_channel             = pcmBuffer.floatChannelData[0];
        float *r_channel             = ([audioFormat channelCount] == 2) ? pcmBuffer.floatChannelData[1] : nil;

        double harmonized_frequency = Tonality(frequency, TonalIntervalRandom, TonalHarmonyRandom);
        double trill_interval       = ToneGenerator.TrillInterval(frequency);
        for (int index = 0; index < frameCount; index++)
        {
            double normalized_index = Normalize(index, frameCount);
            double trill            = ToneGenerator.Trill(normalized_index, trill_interval);
            double trill_inverse    = ToneGenerator.TrillInverse(normalized_index, trill_interval);
            double amplitude        = ToneGenerator.Amplitude(normalized_index);

            if (l_channel) l_channel[index] = ToneGenerator.Frequency(normalized_index, frequency) * amplitude * trill;
               if (r_channel) r_channel[index] = ToneGenerator.Frequency(normalized_index, harmonized_frequency) * amplitude * trill_inverse;
        }

        return pcmBuffer;
    };
}

+ (void(^)(AVAudioFormat *, DataRenderedCompletionBlock))RequestData
{
    return ^(AVAudioFormat *audioFormat, DataRenderedCompletionBlock dataRenderedCompletionBlock)
    {
        AVAudioFrameCount frameCount = [audioFormat sampleRate] * ToneGenerator.RandomDurationInterval();
        
        dataRenderedCompletionBlock([ToneGenerator RenderData](audioFormat, frameCount, (((double)arc4random() / UINT_MAX) * (max_frequency - min_frequency) + min_frequency)), ^(NSString *string){
            NSLog(@"%@", string);
            [ToneGenerator RequestData](audioFormat, dataRenderedCompletionBlock);
        });
    };
}

typedef void (^DataPlayedBackCompletionBlock)(NSString *);
typedef void (^DataRenderedCompletionBlock)(AVAudioPCMBuffer * _Nonnull, DataPlayedBackCompletionBlock);

+ (void (^)(void))DataPlayedBack
{
    return ^{
        
    };
    
}

+ (void (^)(AVAudioFormat *, DataRenderedCompletionBlock))AudioBufferWithCompletionBlock
{
    return ^(AVAudioFormat *audioFormat, DataRenderedCompletionBlock dataRenderedCompletionBlock)
    {
        AVAudioFrameCount frameCount = [audioFormat sampleRate] * ToneGenerator.RandomDurationInterval();
        dataRenderedCompletionBlock([ToneGenerator RenderData](audioFormat, frameCount, (((double)arc4random() / UINT_MAX) * (max_frequency - min_frequency) + min_frequency)), ^(NSString *string)
        {
            NSLog(@"%@", string);
        });
    };
}

// AudioBufferWithCompletionBlock calls the block sent to it, repeatedly, which returns a buffer and plays it
// It also returns a block that is called when the buffer is played
// This lets AudioBufferWithCompletionBlock know when to call the block sent to it again



//- (void)play
//{
//    if ([_audioEngine isRunning])
//    {
//        [_audioEngine pause];
//    } else {
//        if ([self startEngine])
//        {
//            if (![_playerNode isPlaying]) [_playerNode play];
//            [ToneGenerator AudioBufferWithCompletionBlock](_audioFormat, ^(AVAudioPCMBuffer * _Nonnull buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
//                [self->_playerNode scheduleBuffer:buffer atTime:[[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))] options:AVAudioPlayerNodeBufferInterruptsAtLoop completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
//                    if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
//                    {
//                        NSLog(@"dataPlayedBackCompletionBlock (_playerNode)");
//                        dataPlayedBackCompletionBlock();
//                    }
//                }];
//            });
//
//            if (![_playerNodeAux isPlaying]) [_playerNodeAux play];
//            [ToneGenerator AudioBufferWithCompletionBlock](_audioFormat, ^(AVAudioPCMBuffer * _Nonnull buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
//                [self->_playerNodeAux scheduleBuffer:buffer atTime:[[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))] options:AVAudioPlayerNodeBufferInterruptsAtLoop completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
//                    if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
//                    {
//                        NSLog(@"dataPlayedBackCompletionBlock (_playerNodeAux)");
//                        dataPlayedBackCompletionBlock();
//                    }
//                }];
//            });
//        }
//    }
//}

// ------------------------------------------------------------------------------------------------------------------------


@end
