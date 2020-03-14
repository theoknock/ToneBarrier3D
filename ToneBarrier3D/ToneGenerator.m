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

#define max_frequency      2000.0
#define min_frequency       500.0
#define max_trill_interval   12.0
#define min_trill_interval    2.0
#define duration_interval     2.00
#define duration_maximum      1.75
#define duration_minimum      0.25

static double sampleRate = 0;
static double channelCount = 0;

typedef void (^DataPlayedBackCompletionBlock)(NSString *);
typedef void (^DataRenderedCompletionBlock)(AVAudioPCMBuffer * _Nonnull, DataPlayedBackCompletionBlock);

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
static void (^renderData)(double, DataRenderedCompletionBlock);

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
//
            return new_frequency;
        };
        
        Amplitude = ^double(double time)
        {
            return pow(sinf(time * M_PI), 3.0) * 0.5;
        };
        
        Interval = ^double(double frequency, TonalInterval interval)
        {
            double new_frequency = frequency;
            new_frequency *= (interval == TonalIntervalRandom) ? Interval(frequency, (TonalInterval)arc4random_uniform(7)) :
            (interval == TonalIntervalUnison) ? 1.0 :
            (interval == TonalIntervalOctave) ? 2.0 :
            (interval == TonalIntervalMajorSixth) ? 5.0/3.0 :
            (interval == TonalIntervalPerfectFifth) ? 4.0/3.0 :
            (interval == TonalIntervalMajorThird) ? 5.0/4.0 :
            (interval == TonalIntervalMinorThird) ? 6.0/5.0 :
            frequency;
            
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
            return  pow(-(2.0 * pow(sinf(M_PI * time * trill), 2.0) * 0.5) + 1.0, 4.0);
        };
        
        harmonizeFrequencies = ^Frequencies *(double frequency, TonalInterval interval, TonalHarmony harmony) {
            Frequencies *f = (Frequencies *)calloc(sizeof(double), sizeof(Frequencies));
            f->frequency = frequency;
            f->harmonized_frequency = Tonality(frequency, TonalIntervalRandom, TonalHarmonyRandom);
            
            TrillInterval(frequency);
            return f;
        };
        
        Trill = ^double(double time, double trill)
        {
            return pow(2.0 * pow(sinf(M_PI * time * trill), 2.0) * 0.5, 4.0);
        };
        
        renderData = ^void(double frequency, DataRenderedCompletionBlock dataRenderedCompletionBlock)
        {
            AVAudioPCMBuffer * (^createAudioBuffer)(AVAudioFrameCount, AVAudioFormat *);
            createAudioBuffer = ^AVAudioPCMBuffer * (AVAudioFrameCount frameCount, AVAudioFormat * audioFormat)
            {
                AVAudioPCMBuffer *pcmBuffer  = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFormat frameCapacity:frameCount];
                pcmBuffer.frameLength        = frameCount;
                float *l_channel             = pcmBuffer.floatChannelData[0];
                float *r_channel             = ([audioFormat channelCount] == 2) ? pcmBuffer.floatChannelData[1] : nil;
                
                double harmonized_frequency = Tonality(frequency, TonalIntervalRandom, TonalHarmonyRandom);
                double trill_interval       = TrillInterval(frequency);
                for (int index = 0; index < frameCount; index++)
                {
                    double normalized_index = Normalize(index, frameCount);
                    double trill            = Trill(normalized_index, trill_interval);
                    double trill_inverse    = TrillInverse(normalized_index, trill_interval);
                    double amplitude        = Amplitude(normalized_index);
                    
                    if (l_channel) l_channel[index] = Frequency(normalized_index, frequency) * amplitude * trill;
                    if (r_channel) r_channel[index] = Frequency(normalized_index, harmonized_frequency) * amplitude * trill_inverse;
                }
                
                return pcmBuffer;
            };
            
            // Returns audio buffers via DataRenderedCompletionBlock (recursive until STOP)
            AVAudioFrameCount frameCount = [_audioFormat sampleRate] * RandomDurationInterval();
            dataRenderedCompletionBlock(createAudioBuffer(frameCount, _audioFormat), ^(NSString *string)
                                        {
                NSLog(@"%@", string);
                renderData(frequency, dataRenderedCompletionBlock);
            });
        };
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterruption:) name:AVAudioEngineConfigurationChangeNotification object:_audioEngine];
        
        [self setupEngine];
    }
    
    return self;
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
    } else {
        if ([self startEngine])
        {
            if (![_playerNode isPlaying]) [_playerNode play];
            // TO-DO: Normalize randomly generated frequency, apply exponent, and then recalculate frequency
            renderData(Tone(min_frequency, max_frequency, 10.0), ^(AVAudioPCMBuffer * _Nonnull buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
                [self->_playerNode scheduleBuffer:buffer atTime:[[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))] options:AVAudioPlayerNodeBufferInterruptsAtLoop completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
                    if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
                    {
                        [self->_playerNode setPosition:GenerateRandomXPosition()];
                        dataPlayedBackCompletionBlock(@"dataPlayedBackCompletionBlock (_playerNode)");
                    }
                }];
            });
            
            if (![_playerNodeAux isPlaying]) [_playerNodeAux play];
            renderData(Tone(min_frequency, max_frequency, 1.0/10.0), ^(AVAudioPCMBuffer * _Nonnull buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
                [self->_playerNodeAux scheduleBuffer:buffer atTime:[[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))] options:AVAudioPlayerNodeBufferInterruptsAtLoop completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
                    if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
                    {
                        [self->_playerNode setPosition:GenerateRandomXPosition()];
                        dataPlayedBackCompletionBlock(@"dataPlayedBackCompletionBlock (_playerNodeAux)");
                    }
                }];
            });
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
