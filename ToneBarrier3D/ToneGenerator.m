//
//  `ToneGenerator.`m
//  ToneBarrier3D
//
//  Created by Xcode Developer on 2/1/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

// TO-DO: Create moving sound (velocity) to stimulate instinctive sound localizaton; cues for sound source localization: time- and level-differences (or intensity-difference) between both ears
//

// TO-DO: Pattern components to tone barrier scores after basic music theory (https://www.aboutmusictheory.com/music-intervals.html)

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
typedef void (^Score)(AVAudioFormat * audio_format, DataRenderedCompletionBlock dataRenderedCompletionBlock);

@interface ToneGenerator ()

@property (nonatomic, readonly) double (^normalize)(double, double);
@property (nonatomic, readonly) double (^standardize)(double, double, double, double, double);
@property (nonatomic, readonly) double (^randomize)(double, double, double);

@property (nonatomic, readonly) typeof(Parameters) * (^parameters)(int parameters_array_length, double * parameters_array, __unsafe_unretained id flag);
@property (nonatomic, readonly) typeof(Envelope) * (^envelope)(typeof(Parameters) * parameters, __unsafe_unretained typeof(Calculator) calculator);
@property (nonatomic, readonly) ChannelBundle * (^channel_bundle)(typeof(Envelope) * time_envelope, typeof(Envelope) * frequency_envelope, typeof(Envelope) * amplitude_envelope);
@property (nonatomic, readonly) BufferPackage * (^buffer_package)(AVAudioFormat * audio_format, double duration, ChannelBundle * channel_l_bundle, ChannelBundle * channel_r_bundle);
@property (nonatomic, readonly) float * (^audio_samples)(AVAudioFrameCount samples_count, ChannelBundle * channel_bundle, float * samples_array, float * sample_ptrs);
@property (nonatomic, readonly) AVAudioPCMBuffer * (^audio_buffer)(BufferPackage * buffer_package);

@property (nonatomic, readonly) typeof(Calculator) timeCalculator;
@property (nonatomic, readonly) typeof(Calculator) frequencyCalculator;
@property (nonatomic, readonly) typeof(Calculator) amplitudeCalculator;

@property (nonatomic, readonly) typeof(Score) standardScore;

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

- (double (^)(double, double))normalize
{
    return ^double(double numerator, double denominator)
    {
        return (double)(numerator / denominator);
    };
}

- (double(^)(double, double, double, double, double))standardize
{
    return ^double(double value, double min, double max, double new_min, double new_max) {
        return (new_max - new_min) * (value - min) / (max - min) + new_min;
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

- (Calculator)frequencyCalculator
{
    return ^double(double time, typeof(Parameters) * parameters)
    {
        BOOL shorten_wavelength = (BOOL)[(NSNumber *)parameters->flag boolValue];
        double duration = parameters->parameters_array[0];
        double sinusoids_sum = 0;
        for (int i = 1; i < parameters->parameters_array_length; i++)
        {
            double frequency = (parameters->parameters_array[i] * duration);
            frequency        = (shorten_wavelength) ? ((340) / (340 - (pow(time, 3.0) * 20.0))) * frequency :
                                                      ((340) / (340 + (pow(time, 1.0/3.0) * 20.0))) * frequency;
            sinusoids_sum += sinf(M_PI * time * frequency);
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
        double w = (M_PI * time * (trill * time));
        w = (slope > 0.1) ? pow(sinf(w), slope) : w;

        return pow(w, 2.0);
    };
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
            double time = channel_bundle->time_envelope->calculator(ToneGenerator.sharedInstance.normalize(index, samples_count), channel_bundle->time_envelope->parameters);
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

-(void(^)(AVAudioFormat *, DataRenderedCompletionBlock))standardScore
{
    return ^(AVAudioFormat *audioFormat, DataRenderedCompletionBlock dataRenderedCompletionBlock)
    {
        double duration = sum_duration_interval;
        double frequencies[] = {duration, max_frequency};
        double amplitude_params[] = {1.0, 1.0, 1.0};

        ToneGenerator *tg = [ToneGenerator sharedInstance];

        BufferPackage * buffer_package = tg.bufferPackage(audioFormat,
                                                          duration,
                                                          tg.channelBundle(tg.envelope(tg.parameters(0,
                                                                                                     nil,
                                                                                                     nil),
                                                                                       tg.timeCalculator),
                                                                           tg.envelope(tg.parameters(2,
                                                                                                     frequencies,
                                                                                                     @(TRUE)),
                                                                                       tg.frequencyCalculator),
                                                                           tg.envelope(tg.parameters(3,
                                                                                                     amplitude_params,
                                                                                                     @(FALSE)),
                                                                                       tg.amplitudeCalculator)),
                                                          tg.channelBundle(tg.envelope(tg.parameters(0,
                                                                                                     nil,
                                                                                                     nil),
                                                                                       tg.timeCalculator),
                                                                           tg.envelope(tg.parameters(0,
                                                                                                     nil,
                                                                                                     nil),
                                                                                       tg.frequencyCalculator),
                                                                           tg.envelope(tg.parameters(3,
                                                                                                  amplitude_params,
                                                                                                  @(FALSE)),
                                                                                       tg.amplitudeCalculator)));

        dataRenderedCompletionBlock(tg.bufferDataCalculator(buffer_package), ^(__unsafe_unretained id flag) {
//            NSString *str = (NSString *)flag;
            NSLog(NSStringFromSelector(@selector(standardScore)));

            tg.freeBufferPackage(buffer_package);
            tg.standardScore(audioFormat, dataRenderedCompletionBlock);
        });
                                    
        return;
    };
}

//
//
//
//- (FrequencyEnvelope)frequencyEnvelope
//{
//    return ^double(double time, id var, int frequencies_count, double frequencies[])
//    {
//        double sinusoids_sum = 0;
//        for (int i = 0; i < frequencies_count; i++)
//        {
//            sinusoids_sum += sinf(M_PI * time * frequencies[i]);
//        }
//
//        sinusoids_sum = (double)(sinusoids_sum / (double)frequencies_count);
//
//        return sinusoids_sum;
//    };
//}
//
////- (FrequencyEnvelope)frequencyEnvelopeDyad
////{
////    return ^double(double time, double primaryFrequency, double secondaryFrequency, double minFrequency, double maxFrequency, id var)
////    {
////        return (sinf(M_PI * time * primaryFrequency) * time) + (sinf(M_PI * time * secondaryFrequency) * (1.0 - time));
////    };
////}
////
////- (FrequencyEnvelope)frequencyEnvelopeTriad
////{
////    return ^double(double time, double primaryFrequency, double secondaryFrequency, double minFrequency, double maxFrequency, id var)
////    {
////        return (sinf(M_PI * time * primaryFrequency) * time) + (sinf(M_PI * time * secondaryFrequency) * (1.0 - time));
////    };
////}
////
////- (FrequencyEnvelope)frequencyEnvelopeGlissando
////{
////    return ^double(double time, double primaryFrequency, double secondaryFrequency, double minFrequency, double maxFrequency, id var)
////    {
////        NSInteger r = [(NSNumber *)var integerValue];
////        double new_frequency = (r == 0) ? primaryFrequency + ((secondaryFrequency - primaryFrequency) * time) :
////                                          secondaryFrequency - ((secondaryFrequency - primaryFrequency) * time);
////        return sinf(M_PI * 2.0 * time * new_frequency);
////    };
////}
//
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
//
//- (Frequency *(^)(FrequencyEnvelope, id, int, double *))frequencyStruct
//{
//    return ^Frequency *(FrequencyEnvelope frequencyEnvelope, id var, int frequencies_arr_size, double * frequencies)
//    {
//        Frequency * frequency_struct           = malloc(sizeof(Frequency));
//        frequency_struct->frequencyEnvelope    = frequencyEnvelope;
//        frequency_struct->var                  = var;
//        frequency_struct->frequencies_arr_size = frequencies_arr_size;
//        frequency_struct->frequencies          = malloc(sizeof(double) * sizeof(frequencies_arr_size));
//        frequencies;
//
//        return frequency_struct;
//    };
//}
//
//- (Amplitude *(^)(int, double, double, AmplitudeEnvelope, id))amplitudeStruct
//{
//    return ^Amplitude *(int mid, double trill, double slope, AmplitudeEnvelope amplitudeEnvelope, id var)
//    {
//        Amplitude * amplitude_struct        = malloc(sizeof(Amplitude));
//        amplitude_struct->mid               = mid;
//        amplitude_struct->trill             = trill;
//        amplitude_struct->slope             = slope;
//        amplitude_struct->amplitudeEnvelope = amplitudeEnvelope;
//        amplitude_struct->var               = var;
//
//        return amplitude_struct;
//    };
//}
//
//- (Tone *(^)(TimeEnvelope, Frequency *, Amplitude *))toneStruct
//{
//    return ^Tone *(TimeEnvelope timeEnvelope, Frequency * frequency, Amplitude * amplitude)
//    {
//        Tone * tone_struct = malloc(sizeof(Tone));
//        tone_struct->timeEnvelope       = timeEnvelope;
//        tone_struct->frequency          = frequency;
//        tone_struct->amplitude          = amplitude;
//
//        return tone_struct;
//    };
//}
//
//- (Tones *(^)(double, Tone *, Tone *))tonesStruct
//{
//    return ^Tones *(double duration, Tone * channel_l_tone, Tone * channel_r_tone)
//    {
//        Tones *tones_struct = calloc(3, sizeof(Tones));
//        tones_struct->duration = duration;
//        tones_struct->channel_l_tone = channel_l_tone;
//        tones_struct->channel_r_tone = channel_r_tone;
//
//        return tones_struct;
//    };
//}
//
//- (float * (^)(AVAudioFrameCount, Tone *, float *, float *))channelData
//{
//    return ^float *(AVAudioFrameCount frameLength, Tone * tone, float * channel, float * channelData)
//    {
//        channel = channelData;
//        for (int index = 0; index < frameLength; index++)
//        {
//            double time = tone->timeEnvelope(index, frameLength);
//            double freq = tone->frequency->frequencyEnvelope(time, tone->frequency->var, tone->frequency->frequencies_arr_size, tone->frequency->frequencies);
//            double amp  = tone->amplitude->amplitudeEnvelope(time, tone->amplitude->mid, tone->amplitude->trill, tone->amplitude->slope, tone->amplitude->var);
//
//            double f = freq * amp;
//            if (channel) channel[index] = f;
//        }
//
//        return channel;
//    };
//}
//
//- (AVAudioPCMBuffer *(^)(AVAudioFormat *, Tones *))buffer
//{
//    return ^AVAudioPCMBuffer *(AVAudioFormat *audioFormat, Tones * tones)
//    {
//        double sampleRate            = [audioFormat sampleRate];
//        AVAudioFrameCount frameCount = (sampleRate * sum_duration_interval) * tones->duration;
//        AVAudioPCMBuffer *pcmBuffer  = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFormat frameCapacity:frameCount];
//        pcmBuffer.frameLength        = sampleRate * tones->duration;
//        float * channelL, * channelR;
//        channelL = ToneGenerator.sharedInstance.channelData(pcmBuffer.frameLength,
//                                             tones->channel_l_tone,
//                                             channelL,
//                                             pcmBuffer.floatChannelData[0]);
//        channelR = ToneGenerator.sharedInstance.channelData(pcmBuffer.frameLength,
//                                             tones->channel_r_tone,
//                                             channelR,
//                                             ([audioFormat channelCount] == 2) ? pcmBuffer.floatChannelData[1] : nil);
//
//        return pcmBuffer;
//    };
//}
//
//- (Score)dyad
//{
//    return ^(AVAudioFormat *audioFormat, DataRenderedCompletionBlock dataRenderedCompletionBlock) {
//        double randDuration = ToneGenerator.sharedInstance.randomDuration(min_duration_interval, sum_duration_interval, 1.0);
//        double diffDuration = sum_duration_interval - randDuration;
//        double durationMin  = randDuration; //MIN(randDuration, diffDuration);
//        double durationMax  = diffDuration; //MAX(randDuration, diffDuration);
//
//        double frequencyLow           = ToneGenerator.sharedInstance.randomFrequency(min_frequency, max_frequency, durationMin/sum_duration_interval);
//        double harmonic_frequencyLow  = (frequencyLow * (4.0/3.0));
//        double frequencyMid           = (harmonic_frequencyLow * (4.0/3.0));
//
//        double frequenciesL[3] = {frequencyLow * durationMin, harmonic_frequencyLow * durationMin, frequencyMid * durationMin};
//
//        double harmonic_frequencyMid  = (frequencyMid * (4.0/3.0));
//        double frequencyHigh          = (harmonic_frequencyMid * (4.0/3.0));
//        double harmonic_frequencyHigh = (frequencyHigh * (4.0/3.0));
//
//        double frequenciesR[3] = {harmonic_frequencyMid * durationMin, frequencyHigh * durationMin, harmonic_frequencyHigh * durationMin};
//
//        Amplitude * amplitude = ToneGenerator.sharedInstance.amplitudeStruct(1,
//                                                                                      1,
//                                                                                      1.0,
//                                                                                      ToneGenerator.sharedInstance.amplitudeEnvelope,
//                                                                                      @(FALSE));
//
//        Frequency * frequencyL = ToneGenerator.sharedInstance.frequencyStruct(ToneGenerator.sharedInstance.frequencyEnvelope,
//                                                                                       nil,
//                                                                                       3,
//                                                                                       frequenciesL);
//        Tone * toneL           = ToneGenerator.sharedInstance.toneStruct(ToneGenerator.sharedInstance.timeEnvelope,
//                                                                                  frequencyL,
//                                                                                  amplitude);
//
//        Frequency * frequencyR = ToneGenerator.sharedInstance.frequencyStruct(ToneGenerator.sharedInstance.frequencyEnvelope,
//                                                                                       nil,
//                                                                                       3,
//                                                                                       frequenciesR);
//        Tone * toneR           = ToneGenerator.sharedInstance.toneStruct(ToneGenerator.sharedInstance.timeEnvelope,
//                                                                                  frequencyR,
//                                                                                  amplitude);
//
//        Tones * tones          = ToneGenerator.sharedInstance.tonesStruct(durationMin,
//                                                                                   toneL,
//                                                                                   toneR);
//
//        dataRenderedCompletionBlock(ToneGenerator.sharedInstance.buffer(audioFormat, tones), ^(NSString *playerNodeID) {
//            if (playerNodeID) NSLog(playerNodeID);
//
//            amplitude = nil;
//            frequencyL = nil;
//            frequencyR = nil;
//            toneL = nil;
//            toneR = nil;
//            tones = nil;
//
//            free(amplitude);
//            free(frequencyL);
//            free(frequencyR);
//            free(toneL);
//            free(toneR);
//            free(tones);
//
//            double frequencyLow           = ToneGenerator.sharedInstance.randomFrequency(min_frequency, max_frequency, durationMax/sum_duration_interval);
//            double harmonic_frequencyLow  = (frequencyLow * (5.0/4.0));
//            double frequencyMid           = (harmonic_frequencyLow * (5.0/4.0));
//
//            double frequenciesLAux[3] = {frequencyLow * durationMax, harmonic_frequencyLow * durationMax, frequencyMid * durationMax};
//
//            double harmonic_frequencyMid  = (frequencyMid * (5.0/4.0));
//            double frequencyHigh          = (harmonic_frequencyMid * (5.0/4.0));
//            double harmonic_frequencyHigh = (frequencyHigh * (5.0/4.0));
//
//            double frequenciesRAux[3] = {harmonic_frequencyMid * durationMax, frequencyHigh * durationMax, harmonic_frequencyHigh * durationMax};
//
//            __block Amplitude * amplitudeAux = ToneGenerator.sharedInstance.amplitudeStruct(3,
//                                                                                             7.0,
//                                                                                             1.0,
//                                                                                             ToneGenerator.sharedInstance.amplitudeEnvelope,
//                                                                                             @(TRUE));
//
//            __block Frequency * frequencyLAux = ToneGenerator.sharedInstance.frequencyStruct(ToneGenerator.sharedInstance.frequencyEnvelope,
//                                                                                              nil,
//                                                                                              3,
//                                                                                              frequenciesLAux);
//            __block Tone * toneLAux           = ToneGenerator.sharedInstance.toneStruct(ToneGenerator.sharedInstance.timeEnvelope,
//                                                                                 frequencyLAux,
//                                                                                 amplitudeAux);
//
//            __block Frequency * frequencyRAux = ToneGenerator.sharedInstance.frequencyStruct(ToneGenerator.sharedInstance.frequencyEnvelope,
//                                                                                              nil,
//                                                                                              3,
//                                                                                              frequenciesRAux);
//            __block Tone * toneRAux           = ToneGenerator.sharedInstance.toneStruct(ToneGenerator.sharedInstance.timeEnvelope,
//                                                                                 frequencyRAux,
//                                                                                 amplitudeAux);
//
//            __block Tones * tonesAux = ToneGenerator.sharedInstance.tonesStruct(durationMax,
//                                                                         toneLAux,
//                                                                         toneRAux);
//            dataRenderedCompletionBlock(ToneGenerator.sharedInstance.buffer(audioFormat, tonesAux), ^(NSString *playerNodeID) {
//                if (playerNodeID) NSLog(playerNodeID);
//
//                amplitudeAux = nil;
//                frequencyLAux = nil;
//                frequencyRAux = nil;
//                toneLAux = nil;
//                toneRAux = nil;
//                tonesAux = nil;
//
//                free(amplitudeAux);
//                free(frequencyLAux);
//                free(frequencyRAux);
//                free(toneLAux);
//                free(toneRAux);
//                free(tonesAux);
//
//                if (ToneGenerator.sharedInstance.audioEngine.isRunning)
//                    ToneGenerator.sharedInstance.dyad(audioFormat, dataRenderedCompletionBlock);
//            });
//        });
//    };
//}
//
////- (Score)glissando
////{
////    return ^(AVAudioFormat *audioFormat, DataRenderedCompletionBlock dataRenderedCompletionBlock) {
////        double randDuration = ToneGenerator.sharedInstance.randomDuration(min_duration_interval, max_duration_interval, 3.0);
////        double diffDuration = sum_duration_interval - randDuration;
////        double durationMin  = MIN(randDuration, diffDuration);
////        double durationMax  = MAX(randDuration, diffDuration);
////        double frequency    = ToneGenerator.sharedInstance.randomFrequency(min_frequency, max_frequency / 2.0, 3.0);
////        double harmonic_frequency = (frequency * (5.0/4.0));
////        double frequencyAux = (harmonic_frequency * (5.0/4.0));
////
////        Amplitude * amplitude = ToneGenerator.sharedInstance.amplitudeStruct(2.0,
////                                                                              2.0,
////                                                                              1.0,
////                                                                              ToneGenerator.sharedInstance.amplitudeEnvelope,
////                                                                              @(TRUE));
////
////        Frequency * frequencyL = ToneGenerator.sharedInstance.frequencyStruct(frequency * durationMax,
////                                                                               harmonic_frequency * durationMax,
////                                                                               0.0,
////                                                                               0.0,
////                                                                               ToneGenerator.sharedInstance.frequencyEnvelopeGlissando,
////                                                                               @(0));
////        Tone * toneL           = ToneGenerator.sharedInstance.toneStruct(ToneGenerator.sharedInstance.timeEnvelope,
////                                                                          frequencyL,
////                                                                          amplitude);
////
////        Frequency * frequencyR = ToneGenerator.sharedInstance.frequencyStruct(harmonic_frequency * durationMax,
////                                                                               frequencyAux * durationMax,
////                                                                               0.0,
////                                                                               0.0,
////                                                                               ToneGenerator.sharedInstance.frequencyEnvelopeGlissando,
////                                                                               @(0));
////        Tone * toneR           = ToneGenerator.sharedInstance.toneStruct(ToneGenerator.sharedInstance.timeEnvelope,
////                                                                          frequencyR,
////                                                                          amplitude);
////
////        Tones * tones          = ToneGenerator.sharedInstance.tonesStruct(durationMax,
////                                                                           toneL,
////                                                                           toneR);
////
////
////        dataRenderedCompletionBlock(ToneGenerator.sharedInstance.buffer(audioFormat, tones), ^(NSString *playerNodeID) {
////            if (playerNodeID) NSLog(playerNodeID);
////            free(amplitude);
////            free(frequencyL);
////            free(frequencyR);
////            free(toneL);
////            free(toneR);
////            free(tones);
////            double frequency    = ToneGenerator.sharedInstance.randomFrequency(min_frequency, max_frequency / 2.0, 3.0);
////            double harmonic_frequency = (frequency * (5.0/4.0));
////            double frequencyAux = (harmonic_frequency * (5.0/4.0));
////            double harmonic_frequencyAux = (frequencyAux * (5.0/4.0));
////            Amplitude * amplitudeAux = ToneGenerator.sharedInstance.amplitudeStruct(8.0,
////                                                                                     8.0,
////                                                                                     8.0,
////                                                                                     ToneGenerator.sharedInstance.amplitudeEnvelope,
////                                                                                     @(FALSE));
////
////            Frequency * frequencyLAux = ToneGenerator.sharedInstance.frequencyStruct(frequency * durationMin,
////                                                                                      harmonic_frequency * durationMin,
////                                                                                      0.0,
////                                                                                      0.0,
////                                                                                      ToneGenerator.sharedInstance.frequencyEnvelopeGlissando,
////                                                                                      @(1));
////            Tone * toneLAux           = ToneGenerator.sharedInstance.toneStruct(ToneGenerator.sharedInstance.timeEnvelope,
////                                                                                 frequencyLAux,
////                                                                                 amplitudeAux);
////
////            Frequency * frequencyRAux = ToneGenerator.sharedInstance.frequencyStruct(harmonic_frequency * durationMin,
////                                                                                      frequencyAux * durationMin,
////                                                                                      0.0,
////                                                                                      0.0,
////                                                                                      ToneGenerator.sharedInstance.frequencyEnvelopeGlissando,
////                                                                                      @(1));
////            Tone * toneRAux           = ToneGenerator.sharedInstance.toneStruct(ToneGenerator.sharedInstance.timeEnvelope,
////                                                                                 frequencyRAux,
////                                                                                 amplitudeAux);
////
////            Tones * tonesAux = ToneGenerator.sharedInstance.tonesStruct(durationMin,
////                                                                         toneLAux,
////                                                                         toneRAux);
////            dataRenderedCompletionBlock(ToneGenerator.sharedInstance.buffer(audioFormat, tonesAux), ^(NSString *playerNodeID) {
////                if (playerNodeID) NSLog(playerNodeID);
////                free(amplitudeAux);
////                free(frequencyLAux);
////                free(frequencyRAux);
////                free(toneLAux);
////                free(toneRAux);
////                free(tonesAux);
////                ToneGenerator.sharedInstance.glissando(audioFormat, dataRenderedCompletionBlock);
////            });
////        });
////    };
////}
////
////- (Score)alarm
////{
////    return ^(AVAudioFormat *audioFormat, DataRenderedCompletionBlock dataRenderedCompletionBlock) {
////        NSLog(@"%s", __PRETTY_FUNCTION__);
////
////        double duration     = sum_duration_interval / 4.0;
////        double frequency    = ((max_frequency + min_frequency) / 4.0) * (5.0/4.0);
////        double harmonic_frequency = ((max_frequency + min_frequency) / 4.0);
////
////        Amplitude * amplitudeL = ToneGenerator.sharedInstance.amplitudeStruct(2.0,
////                                                                               0.125,
////                                                                               2.0,
////                                                                               ToneGenerator.sharedInstance.amplitudeEnvelope,
////                                                                               @(TRUE));
////
////        Frequency * frequencyL = ToneGenerator.sharedInstance.frequencyStruct(frequency * duration,
////                                                                               harmonic_frequency * duration,
////                                                                               0.0,
////                                                                               0.0,
////                                                                               ToneGenerator.sharedInstance.frequencyEnvelope,
////                                                                               nil);
////        Tone * toneL           = ToneGenerator.sharedInstance.toneStruct(ToneGenerator.sharedInstance.timeEnvelope,
////                                                                          frequencyL,
////                                                                          amplitudeL);
////
////        Amplitude * amplitudeR = ToneGenerator.sharedInstance.amplitudeStruct(2.0,
////                                                                               0.125,
////                                                                               2.0,
////                                                                               ToneGenerator.sharedInstance.amplitudeEnvelope,
////                                                                               @(FALSE));
////
////        Frequency * frequencyR = ToneGenerator.sharedInstance.frequencyStruct((harmonic_frequency * (5.0/4.0)) * duration,
////                                                                               frequency * duration,
////                                                                               0.0,
////                                                                               0.0,
////                                                                               ToneGenerator.sharedInstance.frequencyEnvelope,
////                                                                               nil);
////        Tone * toneR           = ToneGenerator.sharedInstance.toneStruct(ToneGenerator.sharedInstance.timeEnvelope,
////                                                                          frequencyR,
////                                                                          amplitudeR);
////
////        Tones * tones          = ToneGenerator.sharedInstance.tonesStruct(duration,
////                                                                           toneL,
////                                                                           toneR);
////
////        dataRenderedCompletionBlock(ToneGenerator.sharedInstance.buffer(audioFormat, tones), ^(NSString *playerNodeID) {
////            if (playerNodeID) NSLog(playerNodeID);
////            free(amplitudeL);
////            free(amplitudeR);
////            free(frequencyL);
////            free(frequencyR);
////            free(toneL);
////            free(toneR);
////            free(tones);
////            ToneGenerator.sharedInstance.alarm(audioFormat, dataRenderedCompletionBlock);
////        });
////    };
////}
//
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

- (void)play:(ToneBarrierScore)toneBarrierScore
{
    if (toneBarrierScore == ToneBarrierScoreNone || [_audioEngine isRunning])
    {
        [_audioEngine pause];
        [_audioEngine.mainMixerNode setOutputVolume:0.0];
        [_audioEngine detachNode:_playerNode];
    } else {
        if ([self startEngine])
        {
            [_audioEngine.mainMixerNode setOutputVolume:1.0];

//            if (toneBarrierScore == ToneBarrierScoreAlarm)
//            {
//                [self playScore:ToneGenerator.sharedInstance.alarm onNode:_playerNode];
//                [self playScore:ToneGenerator.sharedInstance.alarm onNode:_playerNodeAux];
//            } else {
                
                _playerNode = [[AVAudioPlayerNode alloc] init];
                [_playerNode setRenderingAlgorithm:AVAudio3DMixingRenderingAlgorithmAuto];
                [_playerNode setSourceMode:AVAudio3DMixingSourceModeAmbienceBed];
                [_playerNode setPosition:AVAudioMake3DPoint(0.0, 0.0, 0.0)];

                [_audioEngine attachNode:_playerNode];
                [_audioEngine connect:_playerNode to:_mixerNode format:_audioFormat];

//                [self playScore:ToneGenerator.sharedInstance.glissando onNode:_playerNode];
            [self playScore:ToneGenerator.sharedInstance.standardScore onNode:_playerNode];
//            }
        }
    }
}

- (void)playScore:(typeof(Score))score onNode:(AVAudioPlayerNode *)node
{
    __block NSInteger call_count = 0;
    __block NSInteger call_back  = 0;
    if (![node isPlaying]) [node play];
    ToneGenerator.sharedInstance.standardScore(self.audioFormat, ^(AVAudioPCMBuffer *buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
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
//// Elements of an effective score:
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
