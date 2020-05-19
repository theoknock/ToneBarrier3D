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
#include <string.h>

#import <GameplayKit/GameplayKit.h>

#import "ToneGenerator.h"

#define max_frequency      2500.00
#define min_frequency       200.00
#define max_trill_interval   18.00
#define min_trill_interval    2.00
#define sum_duration_interval 2.00
#define max_duration_interval 0.45
#define min_duration_interval 0.20


// Pattern for each struct/union in the tone barrier score model:
// “...a typedef for a struct, a block that takes in named elements and fills the struct, and a function that takes in a single struct as input...”
// (Excerpt From: Ben Klemens. “21st Century C.” Apple Books. https://books.apple.com/us/book/21st-century-c/id950072553)

typedef NS_ENUM(NSUInteger, CalculatorsType) {
    CalculatorsTypeTime,
    CalculatorsTypeFrequency,
    CalculatorsTypeAmplitude
};

typedef void * Argument;

typedef struct arguments
{
    int num_arguments;
//    __unsafe_unretained id flag; // Keeping this previous parameter declaration to remind me that an untyped (uncast) parameter needs to be marked as possibly unsafe and unretained by the supplier of its value
    Argument * arguments;
} Arguments;

// The double value returned by this block should always be between 0 and 1;
// Consider a non-optional validation check by requiring a min and max value produced by third-party suppliers of calculations as parameters

typedef double (^Calculation)(double time,
                              Arguments * arguments);

typedef struct calculator
{
    Argument * arguments;
    __unsafe_unretained typeof(Calculation) calculation;
} Calculator;

typedef struct calculator_stack
{
    CalculatorsType calculators_type;
    int num_calculators;
    Calculator * calculators;
} CalculatorStack;

typedef NS_ENUM(NSUInteger, ChannelAssignment) {
    ChannelAssignmentLeft,
    ChannelAssignmentRight
};

typedef struct channel_bundle
{
    ChannelAssignment channel_bundle_assignment;
    CalculatorStack * time_calculators;
    CalculatorStack * frequency_calculators;
    CalculatorStack * amplitude_calculators;
} ChannelBundle;

typedef struct buffer_package
{
//    AVAudioFormat * audio_format;
    double sample_rate;
    uint32_t num_channels;
    ChannelBundle * channel_bundles;
}  BufferPackage;

typedef struct score
{
    char * title;
    double tone_duration;
    int num_buffer_packages;
    BufferPackage * buffer_packages;
} Score;

typedef void (^DataPlayedBackCompletionBlock)(__unsafe_unretained id flag);
typedef void (^DataRenderedCompletionBlock)(GKGaussianDistribution * _Nullable distributor, AVAudioPCMBuffer * buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock);
typedef void (^Texture)(GKGaussianDistribution * _Nullable distributor, AVAudioFormat * audio_format, DataRenderedCompletionBlock dataRenderedCompletionBlock);

@interface ToneGenerator ()

@property (nonatomic, readonly) double (^normalize)(double, double, double, double, double);
@property (nonatomic, readonly) double (^standardize)(double, double, double, double, double);
@property (nonatomic, readonly) double (^randomize)(double, double, double);
@property (nonatomic, readonly) BOOL   (^validate)(typeof(Calculator));

@property (nonatomic, readonly) union parameters_union     * (^parameters)(int parameters_array_length, double * parameters_array, __unsafe_unretained id flag);
@property (nonatomic, readonly) union calculator_union     * (^calculator)(union parameters_union * parameters, __unsafe_unretained typeof(Calculator) calculator);
@property (nonatomic, readonly) union calculators_union    * (^calculators)(CalculatorsType calculators_type, int calculators_array_length, union calculator_union * calculators_array);
@property (nonatomic, readonly) union channel_bundle_union * (^channel_bundle)(ChannelBundleAssignment channel_bundle_assignment, union calculators_union * time_calculators, union calculators_union * frequency_calculators, union calculators_union * amplitude_calculators);
@property (nonatomic, readonly) union buffer_package_union * (^buffer_package)(AVAudioFormat * audio_format, double duration, int channel_bundles_array_length, union channel_bundle_union * channel_bundles_array);
@property (nonatomic, readonly) Score * (^score)(char * title, int buffer_package_unions_array_length, buffer_package_union * buffer_package_unions);
@property (nonatomic, readonly) float * (^audio_samples)(AVAudioFrameCount samples_count, union channel_bundle_union * channel_bundle, float * samples_array, float * sample_ptrs);
@property (nonatomic, readonly) AVAudioPCMBuffer * (^audio_buffer)(union buffer_package_union * buffer_package);

@property (nonatomic, readonly) typeof(Calculator) timeCalculator;
@property (nonatomic, readonly) typeof(Calculator) frequencyCalculator;
@property (nonatomic, readonly) typeof(Calculator) frequencyCalculatorPolytone;
@property (nonatomic, readonly) typeof(Calculator) amplitudeCalculator;

@property (nonatomic, readonly) typeof(Texture) standardTexture;

@property (nonatomic, readonly) void(^free_parameters)(union parameters_union *);
@property (nonatomic, readonly) void(^free_calculator)(union calculator_union *);
@property (nonatomic, readonly) void(^free_calculators)(union calculators_union *);
@property (nonatomic, readonly) void(^free_channel_bundle)(union channel_bundle_union *);
@property (nonatomic, readonly) void(^free_buffer_package)(union buffer_package_union *);
@property (nonatomic, readonly) void(^free_score)(union score_union *);

@property (nonatomic, readonly) GKMersenneTwisterRandomSource * _Nullable randomizer;
@property (nonatomic, readonly) GKGaussianDistribution * _Nullable distributor;

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

- (union parameters_union * (^)(int, double *, __unsafe_unretained id))parameters
{
   return ^union parameters_union * (int parameters_array_length,
                                       double * parameters_array,
                                       __unsafe_unretained id flag)
    {
        union parameters_union * parameters = malloc(sizeof(union parameters_union));
        parameters->parameters_array_length = parameters_array_length;
        parameters->parameters_array = malloc(sizeof(double) * parameters_array_length);
        for (int i = 0; i < parameters_array_length; i++)
        {
            parameters->parameters_array[i] = parameters_array[i];
        }
        parameters->flag = flag;
        
        return parameters;
    };
}

- (Calculator)timeCalculator
{
    return ^double(double time, union parameters_union * parameters)
    {
        return time;
    };
}

// 2.0, max_frequency, 1.0, 0.0, 1.0, 1.0, 0.0
- (Calculator)frequencyCalculator
{
    return ^double(double time, union parameters_union * parameters)
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
        
//        double g        = A * sinf((k * x) + (w * time) + p) + D;
        
        return A * sinf(w * time);
    };
}

- (Calculator)frequencyCalculatorPolytone
{
    return ^double(double time, union parameters_union * parameters)
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
    return ^double(double time, union parameters_union * parameters)
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
    return ^double(double time, union parameters_union * parameters)
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

- (union calculator_union * (^)(union parameters_union *, __unsafe_unretained typeof(Calculator)))calculator_envelope
{
    return ^union calculator_union * (union parameters_union * parameters,
                                        __unsafe_unretained typeof(Calculator) calculator)
    {
        union calculator_union * envelope_union  = malloc(sizeof(union calculator_union) + sizeof(parameters));
        envelope_union->parameters = parameters;
        envelope_union->calculator = calculator;
        
        return envelope_union;
    };
}

- (union calculators_union * (^)(CalculatorsType, int, union calculator_union *))calculators
{
    return ^union calculators_union * (CalculatorsType calculators_type, int calculators_array_length, union calculator_union * calculators_array)
    {
        union calculators_union * calculators_union  = malloc(sizeof(union calculators_union) + (sizeof(union calculator_union) * calculators_array_length));
        calculators_union->calculators_type = calculators_type;
        calculators_union->calculators_array = malloc((sizeof(union calculator_union) * calculators_array_length));
        for (int i = 0; i < calculators_array_length; i++)
        {
            calculators_union->calculators_array[i] = calculators_array[i];
        }

        return calculators_union;
    };
}

- (union channel_bundle_union * (^)(union calculators_union *, union calculators_union *, union calculators_union *))channelBundle
{
    return ^union channel_bundle_union * (union calculators_union * time_calculators,
                                            union calculators_union * frequency_calculators,
                                            union calculators_union * amplitude_calculators)
    {
        union channel_bundle_union * channel_bundle_union = malloc(sizeof(union channel_bundle_union) + sizeof(time_calculators) + sizeof(frequency_calculators) + sizeof(amplitude_calculators));
        channel_bundle_union->time_calculators = time_calculators;
        channel_bundle_union->frequency_calculators = frequency_calculators;
        channel_bundle_union->amplitude_calculators = amplitude_calculators;
        
        return channel_bundle_union;
    };
}

// TO-DO: Move duration multiplication operation to a separate block and perform operation here (NOT anywhere else)
- (union buffer_package_union * (^)(AVAudioFormat *, double duration, int channel_bundles_array_length, union channel_bundle_union *))bufferPackage
{
    return ^union buffer_package_union *(AVAudioFormat * audio_format,
                            double duration,
                            int channel_bundles_array_length,
                            union channel_bundle_union * channel_bundles_array)
    {
        union buffer_package_union * buffer_package = malloc(sizeof(union buffer_package_union) + (sizeof(channel_bundles_array) + sizeof(channel_bundles_array_length)));
        buffer_package->audio_format     = audio_format;
        buffer_package->duration         = duration;
        buffer_package->channel_bundles_array_length = channel_bundles_array_length;
        buffer_package->channel_bundles_array = malloc((sizeof(union channel_bundle_union) * channel_bundles_array_length));
        for (int i = 0; i < channel_bundles_array_length; i++)
        {
            buffer_package->channel_bundles_array[i] = channel_bundles_array[i];
        }
        
        return buffer_package;
    };
}

// Actual array
- (Score *(^)(char *, int, buffer_package_union *))score
{
    return ^Score *(char * title, int buffer_package_unions_array_length, buffer_package_union * buffer_package_unions)
    {
        Score * score = malloc(sizeof(union score_union));
        score->buffer_package_unions_array_length = buffer_package_unions_array_length;
        score->buffer_package_unions = calloc(buffer_package_unions_array_length, sizeof(union buffer_package_union));
        score->buffer_package_unions = buffer_package_unions;
        score->title = malloc(sizeof(title));
        score->title = strcpy(score->title, title);
//        score_union->buffer_packages_array_length = buffer_package_union_array_length;
//        memmove(score_union->buffer_packages_array, buffer_packages_array, sizeof(buffer_package_union_array_length * sizeof(union buffer_package_union));
//
        
        return score;
    };
}

- (void (^)(union parameters_union *))free_parameters
{
    return ^void(union parameters_union * parameters_union)
    {
        free((void *)parameters_union->parameters_array);
        parameters_union->flag = nil;
        free((void *)parameters_union);
    };
}

- (void (^)(union calculator_union *))free_calculator
{
    return ^void(union calculator_union * calculator_union)
    {
        // TO-DO: Loop number of CalculatorEnvelopes in Calculators array and then free each CalculatorEnvelope
        ToneGenerator.sharedInstance.free_parameters(calculator_union->parameters);
        calculator_union->calculator= nil;
        free((void *)calculator_union);
    };
}

- (void (^)(union calculators_union *))free_calculators
{
    return ^void(union calculators_union * calculators_array)
    {
        for (int i = 0; i < 3; i++)
        {
            union calculators_union * calculator_union = &calculators_array[i];
            
            for (int j = 0; j < calculator_union->calculators_array_length; j++)
            {
                ToneGenerator.sharedInstance.free_calculator(&calculator_union->calculators_array[j]);
            }
        }
    };
}

- (void (^)(union channel_bundle_union *))free_channel_bundle
{
    return ^void(union channel_bundle_union * channel_bundle_union)
    {
        ToneGenerator.sharedInstance.free_calculators(channel_bundle_union->time_calculators);
        ToneGenerator.sharedInstance.free_calculators(channel_bundle_union->frequency_calculators);
        ToneGenerator.sharedInstance.free_calculators(channel_bundle_union->amplitude_calculators);
        
        free((void *)channel_bundle_union);
    };
}

- (void (^)(union buffer_package_union *))free_buffer_package
{
    return ^void(union buffer_package_union * buffer_package_union)
    {
        buffer_package_union->audio_format = nil;
        
        for (int i = 0; i < 3; i++)
        {
            union channel_bundle_union * channel_bundle_union = &buffer_package_union->channel_bundles_array[i];
            ToneGenerator.sharedInstance.free_channel_bundle(channel_bundle_union);
        }
        
        free((void *)buffer_package_union);
    };
}

- (float * (^)(AVAudioFrameCount, union channel_bundle_union *, float *, float *))channelDataCalculator
{
    return ^float *(AVAudioFrameCount samples_count,
                    union channel_bundle_union * channel_bundle_union,
                    float * floatChannelDataPtrsArray,
                    float * floatChannelDataPtrs)
    {
        floatChannelDataPtrsArray = floatChannelDataPtrs;
        for (int index = 0; index < samples_count; index++)
        {
            double time = ToneGenerator.sharedInstance.normalize(0.0, 1.0, index, 0.0, samples_count - 1.0);
            for (int time_calculator_index = 0; time_calculator_index < channel_bundle_union->time_calculators->calculators_array_length; time_calculator_index++)
            {
                union calculator_union * time_calculator_envelope = &channel_bundle_union->time_calculators->calculators_array[time_calculator_index];
                time = time_calculator_envelope->calculator(time, time_calculator_envelope->parameters);
            }
            
            double frequency = max_frequency;
            for (int frequency_calculator_index = 0; frequency_calculator_index < channel_bundle_union->frequency_calculators->calculators_array_length; frequency_calculator_index++)
            {
                union calculator_union * frequency_calculator_envelope = &channel_bundle_union->frequency_calculators->calculators_array[frequency_calculator_index];
                frequency = frequency_calculator_envelope->calculator(time, frequency_calculator_envelope->parameters);
            }
            
            double amplitude = 1.0;
            for (int amplitude_calculator_index = 0; amplitude_calculator_index < channel_bundle_union->amplitude_calculators->calculators_array_length; amplitude_calculator_index++)
            {
                union calculator_union * amplitude_calculator_envelope = &channel_bundle_union->amplitude_calculators->calculators_array[amplitude_calculator_index];
                amplitude = amplitude_calculator_envelope->calculator(time, amplitude_calculator_envelope->parameters);
            }
            
            double f = frequency * amplitude;
            if (floatChannelDataPtrsArray) floatChannelDataPtrsArray[index] = f;
        }
        
        return floatChannelDataPtrsArray;
    };
}

- (AVAudioPCMBuffer *(^)(union buffer_package_union *))bufferDataCalculator
{
    return ^AVAudioPCMBuffer *(union buffer_package_union * buffer_package_union)
    {
        double sampleRate            = [buffer_package_union->audio_format sampleRate];
        AVAudioFrameCount frameCount = (sampleRate * sum_duration_interval) * buffer_package_union->duration;
        AVAudioPCMBuffer *pcmBuffer  = [[AVAudioPCMBuffer alloc] initWithPCMFormat:buffer_package_union->audio_format frameCapacity:frameCount];
        pcmBuffer.frameLength        = sampleRate * buffer_package_union->duration;
        float * channelL, * channelR;
        
        // TO-DO: Create a for loop to iterate the channel bundle array; but...
        //        for now, get the first two (the left and right channels) in the array only
        channelL = ToneGenerator.sharedInstance.channelDataCalculator(pcmBuffer.frameLength,
                                                                      &buffer_package_union->channel_bundles_array[0],
                                                                      channelL,
                                                                      pcmBuffer.floatChannelData[0]);
        channelR = ToneGenerator.sharedInstance.channelDataCalculator(pcmBuffer.frameLength,
                                                                      &buffer_package_union->channel_bundles_array[1],
                                                                      channelR,
                                                                      ([buffer_package_union->audio_format channelCount] == 2) ? pcmBuffer.floatChannelData[1] : nil);
        
        return pcmBuffer;
    };
}

//// Random Frequencies (returns two Frequency unions
//- (double *(^)(int length))randomFrequencies
//{
//
//}

// TO-DO: Create a block that returns an array of frequency values, specifically, a randomly generated root frequency, plus its harmonic equivalent(s)
//        and which accepts as parameters:
//        1) an instance of GKRandomDistribution
//        2) a block that creates one or more harmonic complements based on the root frequency passed to it as a parameter

- (void(^)(GKGaussianDistribution * _Nullable, AVAudioFormat *, DataRenderedCompletionBlock))standardTexture
{
    return ^(GKGaussianDistribution * _Nullable distributor, AVAudioFormat *audioFormat, DataRenderedCompletionBlock dataRenderedCompletionBlock)
    {
        ToneGenerator *tg = [ToneGenerator sharedInstance];
        
        double frequency_root       = [_distributor nextInt];
        double frequencies_params[] = {sum_duration_interval, frequency_root, frequency_root * (4.0/5.0), (frequency_root * (4.0/5.0)) / (4.0/5.0)}; // frequencyCalculatorPolytone
        double amplitude_params[]   = {2.0, 8.0, 2.0};
        
        union parameters_union * time_parameters_union = tg.parameters(0, nil, nil);
        
        union calculator_union * time_calculator = tg.calculator(time_parameters_union, tg.timeCalculator);
        
        union calculator_union time_calculators_array[] = malloc(sizeof(time_calculator));
        \
        {time_calculator};
        union calculator_union * time_calculators_array_ptr = &time_calculators_array;
        
        union calculators_union * time_calculators = tg.calculators(CalculatorsTypeTime,
                                                                      1,
                                                                      time_calculators_array);
        
        
        union parameters_union * frequency_parameters_union = tg.parameters(4, frequencies_params, nil);
        
        union calculator_union * frequency_calculator = tg.calculator(frequency_parameters_union, tg.frequencyCalculatorPolytone);
        
        union calculator_union * frequency_calculators_array[1] = {frequency_calculator};
        
        union calculators_union * frequency_calculators = tg.calculators(CalculatorsTypeFrequency,
                                                                           1,
                                                                           frequency_calculators_array);
        
        
        union parameters_union * amplitude_parameters_union = tg.parameters(3, amplitude_params, nil);
        
        union calculator_union * amplitude_calculator = tg.calculator(amplitude_parameters_union, tg.amplitudeCalculator);
        
        union calculator_union * amplitude_calculators_array = {amplitude_calculator};
        
        union calculators_union * amplitude_calculators = tg.calculators(CalculatorsTypeAmplitude,
                                                                           1,
                                                                           amplitude_calculators_array);
        
        
        union channel_bundle_union *channel_bundle_union_left = tg.channel_bundle(ChannelBundleAssignmentLeft,
                                                                                     time_calculators,
                                                                                     frequency_calculators,
                                                                                     amplitude_calculators);
        
        union channel_bundle_union *channel_bundle_union_right = tg.channel_bundle(ChannelBundleAssignmentRight,
                                                                                      time_calculators,
                                                                                      frequency_calculators,
                                                                                      amplitude_calculators);
        
        union channel_bundle_union * channel_bundles_array[2] = {channel_bundle_union_left, channel_bundle_union_right};
        
        union buffer_package_union * buffer_package_union = tg.buffer_package(audioFormat,
                                                                                 sum_duration_interval,
                                                                                 2,
                                                                                 
                                                                                 
                                                                                 BufferPackage * buffer_package = tg.bufferPackage(audioFormat,
                                                                                                                                   sum_duration_interval,
                                                                                                                                   tg.channelBundle(tg.calculators(CalculatorsTypeTime, 1, )
                                                                                                                                                    
                                                                                                                                                    t,
                                                                                                                                                    tg.calculatorEnvelope(tg.parameters(4,
                                                                                                                                                                                        frequencies_params,
                                                                                                                                                                                        nil),
                                                                                                                                                                          tg.frequencyCalculatorPolytone),
                                                                                                                                                    tg.calculatorEnvelope(tg.parameters(3,
                                                                                                                                                                                        amplitude_params,
                                                                                                                                                                                        @(FALSE)),
                                                                                                                                                                          tg.amplitudeCalculator)),
                                                                                                                                   tg.channelBundle(tg.calculatorEnvelope(tg.parameters(0,
                                                                                                                                                                                        nil,
                                                                                                                                                                                        nil),
                                                                                                                                                                          tg.timeCalculator),
                                                                                                                                                    tg.calculatorEnvelope(tg.parameters(4,
                                                                                                                                                                                        frequencies_params,
                                                                                                                                                                                        nil),
                                                                                                                                                                          tg.frequencyCalculatorPolytone),
                                                                                                                                                    tg.calculatorEnvelope(tg.parameters(3,
                                                                                                                                                                                        amplitude_params,
                                                                                                                                                                                        @(FALSE)),
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
        _playerNode  = nil;
        
        _randomizer  = nil;
        _distributor = nil;
    } else {
        if ([self startEngine])
        {
            _randomizer  = [[GKMersenneTwisterRandomSource alloc] initWithSeed:time(NULL)];
            _distributor = [[GKGaussianDistribution alloc] initWithRandomSource:_randomizer mean:(max_frequency / 1.25) deviation:min_frequency];
            
            _playerNode = [[AVAudioPlayerNode alloc] init];
            [_playerNode setRenderingAlgorithm:AVAudio3DMixingRenderingAlgorithmAuto];
            [_playerNode setSourceMode:AVAudio3DMixingSourceModeAmbienceBed];
            [_playerNode setPosition:AVAudioMake3DPoint(0.0, 0.0, 0.0)];
            
            [_audioEngine attachNode:_playerNode];
            [_audioEngine connect:_playerNode to:_mixerNode format:_audioFormat];
            
            [_audioEngine.mainMixerNode setOutputVolume:1.0];
            
            [self playTexture:ToneGenerator.sharedInstance.standardTexture onNode:_playerNode];
        }
    }
}

- (void)playTexture:(typeof(Texture))texture onNode:(AVAudioPlayerNode *)node
{
    if (![node isPlaying]) [node play];
    ToneGenerator.sharedInstance.standardTexture(self.audioFormat, ^(AVAudioPCMBuffer *buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
        [node prepareWithFrameCount:buffer.frameCapacity];
        [node scheduleBuffer:buffer completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
            if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
            {
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
