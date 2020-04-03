//
//  `ToneGenerator.`m
//  ToneBarrier3D
//
//  Created by Xcode Developer on 2/1/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

// TO-DO: Create moving sound (velocity) to stimulate instinctive sound localizaton; cues for sound source localization: time- and level-differences (or intensity-difference) between both ears
//

// TO-DO: Pattern components to tone barrier textures after basic music theory (https://www.aboutmusictheory.com/music-intervals.html)

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#import "ToneGenerator.h"

#define max_frequency      2500.00
#define min_frequency       200.00
#define max_trill_interval   18.00
#define min_trill_interval    2.00
#define sum_duration_interval 2.00
#define max_duration_interval 0.45
#define min_duration_interval 0.20

// Interface

typedef NS_ENUM(NSUInteger, ParametersType) {
    ParametersTypeTime,
    ParametersTypeFrequency,
    ParametersTypeAmplitude
};

typedef struct parameters_struct
{
    int parameters_array_length;
    double * parameters_array;
    __unsafe_unretained id flag;
} Parameters;

typedef double (^Calculator)(double time,
                             typeof(Parameters) * parameters);

typedef struct envelope_struct
{
    typeof(Parameters) * parameters;
    __unsafe_unretained typeof(Calculator) calculator;
} Envelope;

typedef struct channel_bundle_struct
{
    typeof(Envelope) * time_envelope;
    typeof(Envelope) * frequency_envelope;
    typeof(Envelope) * amplitude_envelope;
} ChannelBundle;

typedef struct buffer_package_struct {
    AVAudioFormat * audio_format;
    double duration;
    ChannelBundle * channel_l_bundle;
    ChannelBundle * channel_r_bundle;
} BufferPackage;

// [[[[[SCORE]]]]]

typedef void (^DataPlayedBackCompletionBlock)(__unsafe_unretained id flag);
typedef void (^DataRenderedCompletionBlock)(AVAudioPCMBuffer * buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock);
typedef void (^Texture)(AVAudioFormat * audio_format, DataRenderedCompletionBlock dataRenderedCompletionBlock);

@interface ToneGenerator ()

@property (nonatomic, readonly) double (^normalize)(double, double, double, double, double);
@property (nonatomic, readonly) double (^standardize)(double, double, double, double, double);
@property (nonatomic, readonly) double (^randomize)(double, double, double);
@property (nonatomic, readonly) BOOL   (^validate)(typeof(Calculator));

@property (nonatomic, readonly) typeof(Parameters) * (^parameters)(int parameters_array_length, double * parameters_array, __unsafe_unretained id flag);
@property (nonatomic, readonly) typeof(Envelope) * (^envelope)(typeof(Parameters) * parameters, __unsafe_unretained typeof(Calculator) calculator);
@property (nonatomic, readonly) ChannelBundle * (^channel_bundle)(typeof(Envelope) * time_envelope, typeof(Envelope) * frequency_envelope, typeof(Envelope) * amplitude_envelope);
@property (nonatomic, readonly) BufferPackage * (^buffer_package)(AVAudioFormat * audio_format, double duration, ChannelBundle * channel_l_bundle, ChannelBundle * channel_r_bundle);
@property (nonatomic, readonly) float * (^audio_samples)(AVAudioFrameCount samples_count, ChannelBundle * channel_bundle, float * samples_array, float * sample_ptrs);
@property (nonatomic, readonly) AVAudioPCMBuffer * (^audio_buffer)(BufferPackage * buffer_package);

@property (nonatomic, readonly) typeof(Calculator) timeCalculator;
@property (nonatomic, readonly) typeof(Calculator) frequencyCalculator;
@property (nonatomic, readonly) typeof(Calculator) frequencyCalculatorPolytone;
@property (nonatomic, readonly) typeof(Calculator) amplitudeCalculator;

@property (nonatomic, readonly) typeof(Texture) standardTexture;

@property (nonatomic, readonly) void (^free_parameters)(typeof(Parameters) * parameters_struct);
@property (nonatomic, readonly) void(^free_envelope)(typeof(Envelope) * envelope_struct);
@property (nonatomic, readonly) void(^free_channel_bundle)(ChannelBundle * channel_bundle);
@property (nonatomic, readonly) void(^free_buffer_package)(BufferPackage * buffer_package);

@property (nonatomic, readonly) AVAudioMixerNode * _Nullable  mainNode;
@property (nonatomic, readonly) AVAudioMixerNode * _Nullable  mixerNode;
@property (nonatomic, readonly) AVAudioFormat * _Nullable     audioFormat;
@property (nonatomic, readonly) AVAudioUnitReverb * _Nullable reverb;

@end

@implementation ToneGenerator

static ToneGenerator *sharedInstance = NULL;
+ (nonnull ToneGenerator *)sharedInstance
{
    static dispatch_once_t onceSecurePredicate;
    dispatch_once(&onceSecurePredicate, ^
                  {
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterruption:) name:AVAudioEngineConfigurationChangeNotification object:_audioEngine];
        [self setupEngine];
    }
    
    return self;
}

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
    [_reverb setWetDryMix:50.0];
    
    [_audioEngine attachNode:_reverb];
    [_audioEngine attachNode:_playerNode];
    [_audioEngine attachNode:_playerNodeAux];
    [_audioEngine attachNode:_mixerNode];
    
    [_audioEngine connect:_playerNode     to:_mixerNode   format:_audioFormat];
    [_audioEngine connect:_playerNodeAux  to:_mixerNode   format:_audioFormat];
    [_audioEngine connect:_mixerNode      to:_reverb      format:_audioFormat];
    [_audioEngine connect:_reverb         to:_mainNode    format:_audioFormat];
    
    
}

// [[[[[HELPER BLOCKS]]]]]

- (double(^)(double, double, double, double, double))standardize
{
    return ^double(double value, double min, double max, double new_min, double new_max) {
        return (new_max - new_min) * (value - min) / (max - min) + new_min;
    };
}

/*
 // Rescales 0 to 9 to 0 to 1
 
 int max = 10;
 for (int index = 0; index < max; index++)
 {
     double time = ToneGenerator.sharedInstance.normalize(0.0, 1.0, index, 0.0, max - 1);
     NSLog(@"time == %f", time);
 }
 */

- (double (^)(double, double, double, double, double))normalize
{
    return ^double(double min_new, double max_new, double val_old, double min_old, double max_old)
    {
        double val_new = min_new + ((((val_old - min_old) * (max_new - min_new))) / (max_old - min_old));
        
        return val_new;
    };
}

- (double(^)(double, double, double))randomize
{
    return ^double(double min, double max, double weight)
    {
        double random = drand48();
        double weighted_random = pow(random, weight);
        double frequency = (weighted_random * (max - min)) + min;
        
        return frequency;
    };
}

//- (BOOL(^)(double))validateCalculation
//{
//    return
//}
//// Supplies the time parameter to a calculation with a value of 0 and 1
//// and then tests for a return value of 0
//- (double(^)(typeof(Calculator)))testCalculation
//{
//    return TRUE;
//}

// [[[[[ENVELOPE IMPLEMENTATION]]]]]

- (typeof(Parameters) * (^)(int, double *, __unsafe_unretained id))parameters
{
    return ^Parameters * (int parameters_array_length,
                          double * parameters_array,
                          __unsafe_unretained id flag)
    {
        typeof(Parameters) * parameters_struct     = malloc(sizeof(Parameters));
        parameters_struct->parameters_array_length = parameters_array_length;
        parameters_struct->parameters_array        = malloc(sizeof(double) * parameters_array_length);
        for (int i = 0; i < parameters_array_length; i++)
        {
            parameters_struct->parameters_array[i] = parameters_array[i];
        }
        parameters_struct->flag                    = flag;
        
        return parameters_struct;
    };
}

- (Calculator)timeCalculator
{
    return ^double(double time, typeof(Parameters) * parameters)
    {
        return time;
    };
}

// 2.0, max_frequency, 1.0, 0.0, 1.0, 1.0, 0.0
- (Calculator)frequencyCalculator
{
    return ^double(double time, typeof(Parameters) * parameters)
    {
        double duration = parameters->parameters_array[0];                       // duration
        double A        = parameters->parameters_array[2];                       // amplitude (sinf(time * M_PI))
        double p        = (int)(parameters->parameters_array[3]) * (M_PI / 2.0); // phase
        double v        = parameters->parameters_array[4];                       // velocity (linear speed or speed of propogation)
        double f        = parameters->parameters_array[1] * duration;            // ordinary frequency (adjusted)

        double w        = 2.0 * M_PI * f;                                        // angular frequency
        double l        = f / v;                                                 // wavelength
        double k        = (2.0 * M_PI) / l;                                      // angular wave number
        double x        = parameters->parameters_array[5] * 0.0;                 // spatial position
        double D        = parameters->parameters_array[6];                       // center amplitude
        
        double g        = A * sinf((k * x) + (w * time) + p) + D;
        
        return A * sinf(w * time);
    };
}

- (Calculator)frequencyCalculatorPolytone
{
    return ^double(double time, typeof(Parameters) * parameters)
    {
        double duration = parameters->parameters_array[0];
        double sinusoids_sum = 0;
        for (int i = 1; i < parameters->parameters_array_length; i++)
        {
            double new_frequency       = (parameters->parameters_array[i] * duration);
            sinusoids_sum             += (1.0 / (parameters->parameters_array_length - 1)) * sinf(M_PI * time * new_frequency);
        }
        
        sinusoids_sum = (double)(sinusoids_sum);
        
        return sinusoids_sum;
    };
}

- (Calculator)frequencyCalculatorDoppler
{
    return ^double(double time, typeof(Parameters) * parameters)
    {
        BOOL shorten_wavelength = (BOOL)[(NSNumber *)parameters->flag boolValue];
        double duration = parameters->parameters_array[0];
        double sinusoids_sum = 0;
        for (int i = 1; i < parameters->parameters_array_length; i++)
        {
            double frequency       = (parameters->parameters_array[i] * duration);
            double frequency_short = ((340) / (340 - 20.0)) * frequency;
            double frequency_long  = ((340) / (340 + 20.0)) * frequency;
            double new_frequency   = frequency_long + ((frequency_short - frequency_long) * sinf(time * M_PI));
            sinusoids_sum += sinf(M_PI * time * new_frequency);
        }
        
        sinusoids_sum = (double)(sinusoids_sum / (double)(parameters->parameters_array_length - 1));
        
        return sinusoids_sum;
    };
}

- (Calculator)amplitudeCalculator
{
    return ^double(double time, typeof(Parameters) * parameters)
    {
        double mid   = parameters->parameters_array[0];
        double trill = parameters->parameters_array[1];
        double slope = parameters->parameters_array[2];
        BOOL invert  = (BOOL)[(NSNumber *)parameters->flag boolValue];

        time = (mid > 1.0) ? pow(time, mid) : time;
        time = (invert) ? 1.0 - time : time;
        time = (trill != 1.0) ? time * (trill * time) : time;
        double w = (M_PI * time);
        w = pow(sinf(w), slope);

        return sinf(w); //signbit(sinf(time * M_PI * 2));
    };
}

float sincf(float x)
{
    double sincf_x = sin(x * M_PI) / (x * M_PI);
    
    return sincf_x;
}

- (typeof(Envelope) * (^)(typeof(Parameters) *, __unsafe_unretained typeof(Calculator)))envelope
{
    return ^typeof(Envelope) * (typeof(Parameters) * parameters,
                                __unsafe_unretained typeof(Calculator) calculator)
    {
        typeof(Envelope) * envelope_struct  = malloc(sizeof(Envelope));
        envelope_struct->parameters = parameters;
        envelope_struct->calculator = calculator;
        
        return envelope_struct;
    };
}

- (ChannelBundle * (^)(typeof(Envelope) *, typeof(Envelope) *, typeof(Envelope) *))channelBundle
{
    return ^ChannelBundle *(typeof(Envelope) * time_envelope,
                            typeof(Envelope) * frequency_envelope,
                            typeof(Envelope) * amplitude_envelope)
    {
        ChannelBundle *channel_bundle_struct = malloc(sizeof(ChannelBundle) + sizeof(time_envelope) + sizeof(frequency_envelope) + sizeof(amplitude_envelope));
        channel_bundle_struct->time_envelope = time_envelope;
        channel_bundle_struct->frequency_envelope = frequency_envelope;
        channel_bundle_struct->amplitude_envelope = amplitude_envelope;
        
        return channel_bundle_struct;
    };
}

- (BufferPackage * (^)(AVAudioFormat *, double duration, ChannelBundle *, ChannelBundle *))bufferPackage
{
    return ^BufferPackage *(AVAudioFormat * audio_format,
                            double duration,
                            ChannelBundle * channel_l_bundle,
                            ChannelBundle * channel_r_bundle)
    {
        BufferPackage *buffer_package_struct    = malloc(sizeof(BufferPackage) + sizeof(channel_l_bundle) + sizeof(channel_r_bundle));
        buffer_package_struct->audio_format     = audio_format;
        buffer_package_struct->duration         = duration;
        buffer_package_struct->channel_l_bundle = channel_l_bundle;
        buffer_package_struct->channel_r_bundle = channel_r_bundle;
        
        return buffer_package_struct;
    };
}

- (void(^)(typeof(Parameters) *))freeParameters
{
    return ^void(typeof(Parameters) * parameters)
    {
        free((void *)parameters->parameters_array);
        parameters->flag = nil;
        free((void *)parameters);
    };
}

- (void(^)(typeof(Envelope) *))freeEnvelope
{
    return ^void(typeof(Envelope) * envelope)
    {
        ToneGenerator.sharedInstance.freeParameters(envelope->parameters);
        envelope->calculator= nil;
        free((void *)envelope);
    };
}

- (void(^)(ChannelBundle *))freeChannelBundle
{
    return ^void(ChannelBundle * channel_bundle_struct)
    {
        ToneGenerator.sharedInstance.freeEnvelope(channel_bundle_struct->time_envelope);
        ToneGenerator.sharedInstance.freeEnvelope(channel_bundle_struct->frequency_envelope);
        ToneGenerator.sharedInstance.freeEnvelope(channel_bundle_struct->amplitude_envelope);
        
        free((void *)channel_bundle_struct);
        
    };
}

- (void(^)(BufferPackage *))freeBufferPackage
{
    return ^void(BufferPackage * buffer_package_struct)
    {
        ToneGenerator.sharedInstance.freeChannelBundle(buffer_package_struct->channel_l_bundle);
        ToneGenerator.sharedInstance.freeChannelBundle(buffer_package_struct->channel_r_bundle);
        
        free((void *)buffer_package_struct);
    };
}

- (float * (^)(AVAudioFrameCount, ChannelBundle *, float *, float *))channelDataCalculator
{
    return ^float *(AVAudioFrameCount samples_count,
                    ChannelBundle * channel_bundle,
                    float * floatChannelDataPtrsArray,
                    float * floatChannelDataPtrs)
    {
        floatChannelDataPtrsArray = floatChannelDataPtrs;
        for (int index = 0; index < samples_count; index++)
        {
            double time = channel_bundle->time_envelope->calculator(ToneGenerator.sharedInstance.normalize(0.0, 1.0, index, 0.0, samples_count - 1.0), channel_bundle->time_envelope->parameters);
            double freq = channel_bundle->frequency_envelope->calculator(time, channel_bundle->frequency_envelope->parameters);
            double amp  = channel_bundle->amplitude_envelope->calculator(time, channel_bundle->amplitude_envelope->parameters);
            
            double f = freq * amp;
            if (floatChannelDataPtrsArray) floatChannelDataPtrsArray[index] = f;
        }
        
        return floatChannelDataPtrsArray;
    };
}

- (AVAudioPCMBuffer *(^)(BufferPackage *))bufferDataCalculator
{
    return ^AVAudioPCMBuffer *(BufferPackage * buffer_package)
    {
        double sampleRate            = [buffer_package->audio_format sampleRate];
        AVAudioFrameCount frameCount = (sampleRate * sum_duration_interval) * buffer_package->duration;
        AVAudioPCMBuffer *pcmBuffer  = [[AVAudioPCMBuffer alloc] initWithPCMFormat:buffer_package->audio_format frameCapacity:frameCount];
        pcmBuffer.frameLength        = sampleRate * buffer_package->duration;
        float * channelL, * channelR;
        channelL = ToneGenerator.sharedInstance.channelDataCalculator(pcmBuffer.frameLength,
                                                                      buffer_package->channel_l_bundle,
                                                                      channelL,
                                                                      pcmBuffer.floatChannelData[0]);
        channelR = ToneGenerator.sharedInstance.channelDataCalculator(pcmBuffer.frameLength,
                                                                      buffer_package->channel_r_bundle,
                                                                      channelR,
                                                                      ([buffer_package->audio_format channelCount] == 2) ? pcmBuffer.floatChannelData[1] : nil);
        
        return pcmBuffer;
    };
}

// Random Frequencies (returns two Frequency structs
// texture: unison, polyphony, homophony

-(void(^)(AVAudioFormat *, DataRenderedCompletionBlock))standardTexture
{
    return ^(AVAudioFormat *audioFormat, DataRenderedCompletionBlock dataRenderedCompletionBlock)
    {
        ToneGenerator *tg = [ToneGenerator sharedInstance];

        double frequencies_params[] = {sum_duration_interval, max_frequency, max_frequency * (4.0/5.0), (max_frequency * (4.0/5.0)) / (4.0/5.0)}; // frequencyCalculatorPolytone
        double amplitude_params[] = {1.0, 1.0, 3.0};
        BufferPackage * buffer_package = tg.bufferPackage(audioFormat,
                                                          sum_duration_interval,
                                                          tg.channelBundle(tg.envelope(tg.parameters(0,
                                                                                                     nil,
                                                                                                     nil),
                                                                                       tg.timeCalculator),
                                                                           tg.envelope(tg.parameters(4,
                                                                                                     frequencies_params,
                                                                                                     nil),
                                                                                       tg.frequencyCalculatorPolytone),
                                                                           tg.envelope(tg.parameters(3,
                                                                                                     amplitude_params,
                                                                                                     @(FALSE)),
                                                                                       tg.amplitudeCalculator)),
                                                          tg.channelBundle(tg.envelope(tg.parameters(0,
                                                                                                     nil,
                                                                                                     nil),
                                                                                       tg.timeCalculator),
                                                                           tg.envelope(tg.parameters(4,
                                                                                                     frequencies_params,
                                                                                                     nil),
                                                                                       tg.frequencyCalculatorPolytone),
                                                                           tg.envelope(tg.parameters(3,
                                                                                                     amplitude_params,
                                                                                                     @(TRUE)),
                                                                                       tg.amplitudeCalculator)));
        
        dataRenderedCompletionBlock(tg.bufferDataCalculator(buffer_package), ^(__unsafe_unretained id flag) {
            //            NSString *str = (NSString *)flag;
            //            NSLog(NSStringFromSelector(@selector(standardTexture)));
            
            tg.freeBufferPackage(buffer_package);
            tg.standardTexture(audioFormat, dataRenderedCompletionBlock);
        });
        
        return;
    };
}

//- (AmplitudeEnvelope)amplitudeEnvelope
//{
//    return ^double(double time, int mid, double trill, double slope, id var)
//    {
//        time = pow(time, mid);
//        BOOL invert_sinusoid = (BOOL)[(NSNumber *)var boolValue];
//        time = (invert_sinusoid) ? 1.0 - time /*attack*/ : time /*release*/; // if mid is greater than 1
//        double w = (M_PI * time * (trill * time));
//
//        return pow(sinf(w), slope);// pow(sinf(pow(time, mid) * M_PI * (trill * time)), slope);
//    };
//}


//- (void)handleInterruption:(NSNotification *)notification
//{
//    NSLog(@"%s", __PRETTY_FUNCTION__);
//    UInt8 interruptionType = [[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] intValue];
//
//    if (interruptionType == AVAudioSessionInterruptionTypeBegan && _audioEngine.mainMixerNode.outputVolume > 0.0 && _audioEngine.isRunning == TRUE)
//    {
//        NSLog(@"AVAudioSessionInterruptionTypeBegan");
//        // if playing, stop audio engine and then set the volume to 1.0
//        [self.delegate play:[self.delegate playButton]];
//        [ToneGenerator.sharedInstance.audioEngine.mainMixerNode setOutputVolume:1.0];
//    } else if (interruptionType == AVAudioSessionInterruptionTypeEnded)
//    {
//        if (_audioEngine.mainMixerNode.outputVolume > 0.0 && _audioEngine.isRunning == FALSE)
//        {
//            NSLog(@"Resuming playback...");
//            [self.delegate play:[self.delegate playButton]];
//        }
//        NSLog(@"AVAudioSessionInterruptionTypeEnded");
//    }
//    AVAudioSessionInterruptionOptions options = [[notification.userInfo valueForKey:AVAudioSessionInterruptionOptionKey] intValue];
//    if (options == AVAudioSessionInterruptionOptionShouldResume)
//    {
//        if (_audioEngine.mainMixerNode.outputVolume > 0.0 && _audioEngine.isRunning == FALSE)
//        {
//            NSLog(@"Resuming playback...");
//            [self.delegate play:[self.delegate playButton]];
//        }
//        NSLog(@"AVAudioSessionInterruptionOptionShouldResume TRUE");
//    } else {
//        NSLog(@"AVAudioSessionInterruptionOptionShouldResume FALSE");
//    }
//}
//

//

- (BOOL)startEngine
{
    __autoreleasing NSError *error = nil;
    if ([_audioEngine startAndReturnError:&error])
    {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
        if (error)
        {
            NSLog(@"%@", [error description]);
        } else {
            [[AVAudioSession sharedInstance] setActive:YES error:&error];
            if (error)
            {
                NSLog(@"%@", [error description]);
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

- (void)play:(Score)score
{

//    double max = 10.0;
//    double low = 1000.0;
//    double hgh = 2000.0;
//    for (int index = 0; index < 10; index++)
//    {
//        double time = ToneGenerator.sharedInstance.normalize(0.0, 1.0, index, 0.0, max - 1.0);
//        NSLog(@"time == %f", low + ((hgh-low) * sinf(time * M_PI)));
//    }
    
  
    if ([_audioEngine isRunning])
    {
        [_audioEngine pause];
        [_audioEngine.mainMixerNode setOutputVolume:0.0];
        [_audioEngine detachNode:_playerNode];
    } else {
        if ([self startEngine])
        {
            [_audioEngine.mainMixerNode setOutputVolume:1.0];
            _playerNode = [[AVAudioPlayerNode alloc] init];
            [_playerNode setRenderingAlgorithm:AVAudio3DMixingRenderingAlgorithmAuto];
            [_playerNode setSourceMode:AVAudio3DMixingSourceModeAmbienceBed];
            [_playerNode setPosition:AVAudioMake3DPoint(0.0, 0.0, 0.0)];
            
            [_audioEngine attachNode:_playerNode];
            [_audioEngine connect:_playerNode to:_mixerNode format:_audioFormat];
            
            [self playTexture:ToneGenerator.sharedInstance.standardTexture onNode:_playerNode];
        }
    }
}

- (void)playTexture:(typeof(Texture))texture onNode:(AVAudioPlayerNode *)node
{
    __block NSInteger call_count = 0;
    __block NSInteger call_back  = 0;
    if (![node isPlaying]) [node play];
    ToneGenerator.sharedInstance.standardTexture(self.audioFormat, ^(AVAudioPCMBuffer *buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
        NSLog(@"%lu\tReturned", call_count++);
        //        [node prepareWithFrameCount:buffer.frameCapacity];
        [node scheduleBuffer:buffer completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
            if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
            {
                NSLog(@"%lu\tCalled", call_back++);
                dataPlayedBackCompletionBlock(nil);
            }
        }];
    });
}

//
//
//// Elements of an effective tone:
//// High-pitched
//// Modulating amplitude
//// Alternating channel output
//// Loud
//// Non-natural (no spatialization)
////
//// Elements of an effective texture:
//// Random frequencies
//// Random duration
//// Random tonality
//
//// To-Do: Multiply the frequency by a random number between 1.01 and 1.1)
//
//double Envelope(double x, TonalEnvelope envelope)
//{
//    double x_envelope = 1.0;
//    switch (envelope) {
//        case TonalEnvelopeAverageSustain:
//            x_envelope = sinf(x * M_PI) * (sinf((2 * x * M_PI) / 2));
//            break;
//
//        case TonalEnvelopeLongSustain:
//            x_envelope = sinf(x * M_PI) * -sinf(
//                                                ((Envelope(x, TonalEnvelopeAverageSustain) - (2.0 * Envelope(x, TonalEnvelopeAverageSustain)))) / 2.0)
//            * (M_PI / 2.0) * 2.0;
//            break;
//
//        case TonalEnvelopeShortSustain:
//            x_envelope = sinf(x * M_PI) * -sinf(
//                                                ((Envelope(x, TonalEnvelopeAverageSustain) - (-2.0 * Envelope(x, TonalEnvelopeAverageSustain)))) / 2.0)
//            * (M_PI / 2.0) * 2.0;
//            break;
//
//        default:
//            break;
//    }
//
//    return x_envelope;
//}
//
////typedef NS_ENUM(NSUInteger, Trill) {
////    TonalTrillUnsigned,
////    TonalTrillInverse
////};


@end
