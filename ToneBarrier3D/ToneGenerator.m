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

@interface ToneGenerator ()
{
    bool _multichannelOutputEnabled;

}

@property (nonatomic, readonly) AVAudioFormat * _Nullable audioFormat;
@property (nonatomic, readonly) AVAudioPlayerNode * _Nullable playerNode;
@property (nonatomic, readonly) AVAudioUnitReverb *reverb;
@property (nonatomic, readonly) AVAudioMixerNode * _Nullable mainNode;
@property (nonatomic, readonly) AVAudioTime * _Nullable time;


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
        [self setupEngine];
    }
    
    return self;
}

- (void)setupEngine
{
    _audioEngine = [[AVAudioEngine alloc] init];
    
    _mainNode = _audioEngine.mainMixerNode;
    
    _audioFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:[_mainNode outputFormatForBus:0].sampleRate channels:[_mainNode outputFormatForBus:0].channelCount];
    
    _playerNode = [[AVAudioPlayerNode alloc] init];
    [_playerNode setRenderingAlgorithm:AVAudio3DMixingRenderingAlgorithmAuto];
    [_playerNode setSourceMode:AVAudio3DMixingSourceModeAmbienceBed];
    [_playerNode setPosition:AVAudioMake3DPoint(0.0, 0.0, 0.0)];
    
//    _reverb = [[AVAudioUnitReverb alloc] init];
//    [_reverb loadFactoryPreset:AVAudioUnitReverbPresetLargeHall];
//    [_reverb setWetDryMix:100.0];
    
//    [_audioEngine attachNode:_reverb];
    [_audioEngine attachNode:_playerNode];
    
//    [_audioEngine connect:_playerNode to:_reverb   format:_audioFormat];
//    [_audioEngine connect:_reverb     to:_mainNode format:_audioFormat];
    [_audioEngine connect:_playerNode     to:_mainNode format:_audioFormat];
}

- (BOOL)startEngine
{
//    AVAudioSession *session = [AVAudioSession sharedInstance];
    __autoreleasing NSError *error = nil;
    if ([_audioEngine startAndReturnError:&error])
    {
        [[AVAudioSession sharedInstance] setActive:YES error:&error];
        if (error)
        {
            NSLog(@"%@", [error description]);
        } else {
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault routeSharingPolicy:AVAudioSessionRouteSharingPolicyLongFormAudio options:nil error:&error];
            if (error)
            {
                NSLog(@"%@", [error description]);
            } else {
                _time = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(CMClockGetTime(CMClockGetHostTimeClock()))];
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

typedef void (^DataPlayedBackCompletionBlock)(void);
typedef void (^DataRenderedCompletionBlock)(AVAudioPCMBuffer * _Nonnull buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock);

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
                CMTime cmtime = CMTimeAdd(CMTimeMakeWithSeconds([AVAudioTime secondsForHostTime:[self->_time hostTime]], NSEC_PER_SEC), CMTimeMakeWithSeconds(1.0, NSEC_PER_SEC));
                self->_time   = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(cmtime)];
                [self->_playerNode scheduleBuffer:buffer atTime:self->_time options:AVAudioPlayerNodeBufferInterruptsAtLoop completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
                    if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
                    {
                        dataPlayedBackCompletionBlock();
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

double Frequency(double x, int ordinary_frequency)
{
    return sinf(x * 2 * M_PI * ordinary_frequency);
}

double Amplitude(double x)
{
    return sinf(x * 2 * (M_PI / 2.0));
}

#define high_frequency 2000.0
#define low_frequency  500.0

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

double Interval(double frequency, TonalInterval interval)
{
    double new_frequency = frequency;
    switch (interval) {
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
            new_frequency = Interval(frequency, (TonalInterval)arc4random_uniform(7));
            
        default:
            break;
    }
    
    return new_frequency;
};

double Tonality(double frequency, TonalInterval interval, TonalHarmony harmony)
{
    double new_frequency = frequency;
    switch (harmony) {
        case TonalHarmonyDissonance:
            new_frequency *= (1.01 + drand48());
            break;
            
        case TonalHarmonyConsonance:
            new_frequency = Interval(frequency, interval);
            break;
            
        case TonalHarmonyRandom:
            new_frequency = Tonality(frequency, interval, (TonalHarmony)arc4random_uniform(2));
            
        default:
            break;
    }
    
    return new_frequency;
}

- (void)createAudioBufferWithCompletionBlock:(DataRenderedCompletionBlock)dataRenderedCompletionBlock
{
    AVAudioPCMBuffer * (^createAudioBuffer)(double);
    createAudioBuffer = ^AVAudioPCMBuffer * (double frequency)
    {
        AVAudioFrameCount frameCount = [self->_audioFormat sampleRate];
        AVAudioPCMBuffer *pcmBuffer  = [[AVAudioPCMBuffer alloc] initWithPCMFormat:self->_audioFormat frameCapacity:frameCount];
        pcmBuffer.frameLength        = frameCount;
        float *l_channel             = pcmBuffer.floatChannelData[0];
        float *r_channel             = ([self->_audioFormat channelCount] == 2) ? pcmBuffer.floatChannelData[1] : nil;
        
        double harmonized_frequency = Tonality(frequency, TonalIntervalRandom, TonalHarmonyRandom);
        
        for (int index = 0; index < frameCount; index++)
        {
            double normalized_index         = Normalize(index, frameCount);
            
            if (l_channel) l_channel[index] = Frequency(normalized_index, frequency) * (normalized_index * Amplitude(normalized_index));
            if (r_channel) r_channel[index] = Frequency(normalized_index, harmonized_frequency) * (normalized_index * Amplitude(normalized_index));
        }
        
        return pcmBuffer;
    };
    
    static void (^renderData)(void);
    renderData = ^void(void)
    {
        dataRenderedCompletionBlock(createAudioBuffer((((double)arc4random() / 0x100000000) * (high_frequency - low_frequency) + low_frequency)), ^{
            renderData();
        });
    };
    renderData();
}


@end
