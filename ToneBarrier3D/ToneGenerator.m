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

#define RANDOM_NUMF(MIN, MAX) MIN+arc4random_uniform(MAX-MIN+1)

typedef NS_ENUM(NSUInteger, TonalHarmony) {
    TonalHarmonyConsonance,
    TonalHarmonyDissonance,
    TonalHarmonyRandom
};

typedef NS_ENUM(NSUInteger, HarmonicInterval) {
    HarmonicIntervalUnison,
    HarmonicIntervalOctave,
    HarmonicIntervalMajorSixth,
    HarmonicIntervalPerfectFifth,
    HarmonicIntervalPerfectFourth,
    HarmonicIntervalMajorThird,
    HarmonicIntervalMinorThird,
    HarmonicIntervalRandom
};

typedef NS_ENUM(NSUInteger, HarmonicInversion) {
    HarmonicInversionPerfect,
    HarmonicInversionImperfect
};

typedef NS_ENUM(NSUInteger, TonalEnvelope) {
    TonalEnvelopeAverageSustain,
    TonalEnvelopeLongSustain,
    TonalEnvelopeShortSustain
};

typedef double (^TimeEnvelope)(double numerator, double denominator);
typedef double (^FrequencyEnvelope)(double time, id var, int frequencies_count, double frequencies[]);
typedef double (^AmplitudeEnvelope)(double time, int mid, double trill, double slope, id var);

typedef struct frequency
{
    __unsafe_unretained FrequencyEnvelope frequencyEnvelope;
    __unsafe_unretained id var;
    int frequencies_arr_size;
    double * frequencies;
} Frequency;

typedef struct amplitude
{
    int                    mid;
    double                 trill;
    double                 slope;
    __unsafe_unretained    AmplitudeEnvelope amplitudeEnvelope;
    __unsafe_unretained id var;
} Amplitude;

typedef struct tone
{
    TimeEnvelope       timeEnvelope;
    Frequency *        frequency;
    Amplitude *        amplitude;
} Tone;

typedef struct tones {
    double duration;
    Tone * channel_l_tone;
    Tone * channel_r_tone;
} Tones;

typedef void (^DataPlayedBackCompletionBlock)(NSString *);
typedef void (^DataRenderedCompletionBlock)(AVAudioPCMBuffer *, DataPlayedBackCompletionBlock);
typedef void (^Score)(AVAudioFormat * audioFormat, DataRenderedCompletionBlock dataRenderedCompletionBlock);


@interface ToneGenerator ()

@property (nonatomic, readonly) AVAudioMixerNode * _Nullable  mainNode;
@property (nonatomic, readonly) AVAudioMixerNode * _Nullable  mixerNode;
@property (nonatomic, readonly) AVAudioFormat * _Nullable     audioFormat;
@property (nonatomic, readonly) AVAudioUnitReverb * _Nullable reverb;

@property (strong, nonatomic, readonly) double(^percentage)(double, double);
@property (strong, nonatomic, readonly) double(^scale)(double, double, double, double, double);
@property (strong, nonatomic, readonly) double(^randomFrequency)(double, double, double);
@property (strong, nonatomic, readonly) double(^randomDuration)(double, double, double);
@property (nonatomic, strong) FrequencyEnvelope  frequencyEnvelope;
@property (nonatomic, strong) FrequencyEnvelope  frequencyEnvelopeGlissando;
@property (nonatomic, strong) AmplitudeEnvelope  amplitudeEnvelope;
@property (strong, nonatomic, readonly) Score dyad;
@property (strong, nonatomic, readonly) Score glissando;
@property (strong, nonatomic, readonly) Score alarm;
@property (strong, nonatomic, readonly) AVAudioPCMBuffer * (^buffer)(AVAudioFormat * audioFormat, Tones * tones);
@property (strong, nonatomic, readonly) float * (^channelData)(AVAudioFrameCount, Tone *, float *, float *);

@end

@implementation ToneGenerator

static ToneGenerator *sharedGenerator = NULL;
+ (nonnull ToneGenerator *)sharedGenerator
{
    static dispatch_once_t onceSecurePredicate;
    dispatch_once(&onceSecurePredicate, ^
    {
       sharedGenerator = [[self alloc] init];
    });
    
    return sharedGenerator;
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

- (double (^)(double, double))percentage
{
    return ^double(double numerator, double denominator)
    {
        return (double)(numerator / denominator);
    };
}

- (double(^)(double, double, double, double, double))scale
{
    return ^double(double value, double min, double max, double new_min, double new_max) {
        return (new_max - new_min) * (value - min) / (max - min) + new_min;
    };
}

- (double(^)(double, double, double))randomFrequency
{
    return ^double(double min, double max, double weight)
    {
        srand48(time(0));
        double random = drand48();
        random = pow(random, weight);
        double frequency = ToneGenerator.sharedGenerator.scale(random, 0.0, 1.0, min, max);
        
        return frequency;
    };
}

- (double(^)(double, double, double))randomDuration
{
    return ^double(double min, double max, double weight)
    {
        srand48(time(0));
        double random = drand48();
        random = pow(random, weight);
        double duration = ToneGenerator.sharedGenerator.scale(random, 0.0, 1.0, min, max);
        
        return duration;
    };
}

- (TimeEnvelope)timeEnvelope
{
    return ^double(double numerator, double denominator)
    {
        return numerator / denominator;
    };
}

- (FrequencyEnvelope)frequencyEnvelope
{
    return ^double(double time, id var, int frequencies_count, double frequencies[])
    {
        double sinusoids_sum = 0;
        for (int i = 0; i < frequencies_count; i++)
        {
            sinusoids_sum += sinf(M_PI * time * frequencies[i]);
        }
        
        sinusoids_sum = (double)(sinusoids_sum / (double)frequencies_count);
        
        return sinusoids_sum;
    };
}

//- (FrequencyEnvelope)frequencyEnvelopeDyad
//{
//    return ^double(double time, double primaryFrequency, double secondaryFrequency, double minFrequency, double maxFrequency, id var)
//    {
//        return (sinf(M_PI * time * primaryFrequency) * time) + (sinf(M_PI * time * secondaryFrequency) * (1.0 - time));
//    };
//}
//
//- (FrequencyEnvelope)frequencyEnvelopeTriad
//{
//    return ^double(double time, double primaryFrequency, double secondaryFrequency, double minFrequency, double maxFrequency, id var)
//    {
//        return (sinf(M_PI * time * primaryFrequency) * time) + (sinf(M_PI * time * secondaryFrequency) * (1.0 - time));
//    };
//}
//
//- (FrequencyEnvelope)frequencyEnvelopeGlissando
//{
//    return ^double(double time, double primaryFrequency, double secondaryFrequency, double minFrequency, double maxFrequency, id var)
//    {
//        NSInteger r = [(NSNumber *)var integerValue];
//        double new_frequency = (r == 0) ? primaryFrequency + ((secondaryFrequency - primaryFrequency) * time) :
//                                          secondaryFrequency - ((secondaryFrequency - primaryFrequency) * time);
//        return sinf(M_PI * 2.0 * time * new_frequency);
//    };
//}

- (AmplitudeEnvelope)amplitudeEnvelope
{
    return ^double(double time, int mid, double trill, double slope, id var)
    {
        time = pow(time, mid);
        BOOL invert_sinusoid = (BOOL)[(NSNumber *)var boolValue];
        time = (invert_sinusoid) ? 1.0 - time /*attack*/ : time /*release*/; // if mid is greater than 1
        double w = (2.0 * M_PI * time * (trill * time));
        
        return pow(sinf(w), slope);// pow(sinf(pow(time, mid) * M_PI * (trill * time)), slope);
    };
}

- (Frequency *(^)(FrequencyEnvelope, id, int, double *))frequencyStruct
{
    return ^Frequency *(FrequencyEnvelope frequencyEnvelope, id var, int frequencies_arr_size, double * frequencies)
    {
        Frequency * frequency_struct           = malloc(sizeof(Frequency));
        frequency_struct->frequencyEnvelope    = frequencyEnvelope;
        frequency_struct->var                  = var;
        frequency_struct->frequencies_arr_size = frequencies_arr_size;
        frequency_struct->frequencies          = frequencies;

        return frequency_struct;
    };
}

- (Amplitude *(^)(int, double, double, AmplitudeEnvelope, id))amplitudeStruct
{
    return ^Amplitude *(int mid, double trill, double slope, AmplitudeEnvelope amplitudeEnvelope, id var)
    {
        Amplitude * amplitude_struct        = malloc(sizeof(Amplitude));
        amplitude_struct->mid               = mid;
        amplitude_struct->trill             = trill;
        amplitude_struct->slope             = slope;
        amplitude_struct->amplitudeEnvelope = amplitudeEnvelope;
        amplitude_struct->var               = var;
        
        return amplitude_struct;
    };
}

- (Tone *(^)(TimeEnvelope, Frequency *, Amplitude *))toneStruct
{
    return ^Tone *(TimeEnvelope timeEnvelope, Frequency * frequency, Amplitude * amplitude)
    {
        Tone * tone_struct = malloc(sizeof(Tone));
        tone_struct->timeEnvelope       = timeEnvelope;
        tone_struct->frequency          = frequency;
        tone_struct->amplitude          = amplitude;
        
        return tone_struct;
    };
}

- (Tones *(^)(double, Tone *, Tone *))tonesStruct
{
    return ^Tones *(double duration, Tone * channel_l_tone, Tone * channel_r_tone)
    {
        Tones *tones_struct = calloc(3, sizeof(Tones));
        tones_struct->duration = duration;
        tones_struct->channel_l_tone = channel_l_tone;
        tones_struct->channel_r_tone = channel_r_tone;
        
        return tones_struct;
    };
}

- (float * (^)(AVAudioFrameCount, Tone *, float *, float *))channelData
{
    return ^float *(AVAudioFrameCount frameLength, Tone * tone, float * channel, float * channelData)
    {
        channel = channelData;
        for (int index = 0; index < frameLength; index++)
        {
            double time = tone->timeEnvelope(index, frameLength);
            double freq = tone->frequency->frequencyEnvelope(time, tone->frequency->var, tone->frequency->frequencies_arr_size, tone->frequency->frequencies);
            double amp  = tone->amplitude->amplitudeEnvelope(time, tone->amplitude->mid, tone->amplitude->trill, tone->amplitude->slope, tone->amplitude->var);
            
            double f = freq * amp;
            if (channel) channel[index] = f;
        }
        
        return channel;
    };
}

- (AVAudioPCMBuffer *(^)(AVAudioFormat *, Tones *))buffer
{
    return ^AVAudioPCMBuffer *(AVAudioFormat *audioFormat, Tones * tones)
    {
        double sampleRate            = [audioFormat sampleRate];
        AVAudioFrameCount frameCount = (sampleRate * sum_duration_interval) * tones->duration;
        AVAudioPCMBuffer *pcmBuffer  = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFormat frameCapacity:frameCount];
        pcmBuffer.frameLength        = sampleRate * tones->duration;
        float * channelL, * channelR;
        channelL = ToneGenerator.sharedGenerator.channelData(pcmBuffer.frameLength,
                                             tones->channel_l_tone,
                                             channelL,
                                             pcmBuffer.floatChannelData[0]);
        channelR = ToneGenerator.sharedGenerator.channelData(pcmBuffer.frameLength,
                                             tones->channel_r_tone,
                                             channelR,
                                             ([audioFormat channelCount] == 2) ? pcmBuffer.floatChannelData[1] : nil);
        
        return pcmBuffer;
    };
}

- (Score)dyad
{
    return ^(AVAudioFormat *audioFormat, DataRenderedCompletionBlock dataRenderedCompletionBlock) {
        double randDuration = ToneGenerator.sharedGenerator.randomDuration(min_duration_interval, max_duration_interval, 3.0);
        double diffDuration = sum_duration_interval - randDuration;
        double durationMin  = MIN(randDuration, diffDuration);
        double durationMax  = MAX(randDuration, diffDuration);
        
        double frequencyLow           = ToneGenerator.sharedGenerator.randomFrequency(min_frequency, max_frequency, 1.0/2.0);
        double harmonic_frequencyLow  = (frequencyLow * (4.0/3.0));
        double frequencyMid           = (harmonic_frequencyLow * (4.0/3.0));
        
        double frequenciesL[3] = {frequencyLow * durationMin, harmonic_frequencyLow * durationMin, frequencyMid * durationMin};
        
        double harmonic_frequencyMid  = (frequencyMid * (4.0/3.0));
        double frequencyHigh          = (harmonic_frequencyMid * (4.0/3.0));
        double harmonic_frequencyHigh = (frequencyHigh * (4.0/3.0));
        
        double frequenciesR[3] = {harmonic_frequencyMid * durationMin, frequencyHigh * durationMin, harmonic_frequencyHigh * durationMin};
        
        __block Amplitude * amplitude = ToneGenerator.sharedGenerator.amplitudeStruct(2,
                                                                                      0.5,
                                                                                      1.0,
                                                                                      ToneGenerator.sharedGenerator.amplitudeEnvelope,
                                                                                      @(TRUE));
        
        __block Frequency * frequencyL = ToneGenerator.sharedGenerator.frequencyStruct(ToneGenerator.sharedGenerator.frequencyEnvelope,
                                                                                       nil,
                                                                                       3,
                                                                                       frequenciesL);
        __block Tone * toneL           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
                                                                                  frequencyL,
                                                                                  amplitude);
        
        __block Frequency * frequencyR = ToneGenerator.sharedGenerator.frequencyStruct(ToneGenerator.sharedGenerator.frequencyEnvelope,
                                                                                       nil,
                                                                                       3,
                                                                                       frequenciesR);
        __block Tone * toneR           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
                                                                                  frequencyR,
                                                                                  amplitude);
                        
        __block Tones * tones          = ToneGenerator.sharedGenerator.tonesStruct(durationMin,
                                                                                   toneL,
                                                                                   toneR);
        
        dataRenderedCompletionBlock(ToneGenerator.sharedGenerator.buffer(audioFormat, tones), ^(NSString *playerNodeID) {
            if (playerNodeID) NSLog(playerNodeID);
            
            amplitude = nil;
            frequencyL = nil;
            frequencyR = nil;
            toneL = nil;
            toneR = nil;
            tones = nil;
        
            free(amplitude);
            free(frequencyL);
            free(frequencyR);
            free(toneL);
            free(toneR);
            free(tones);
            
            double frequencyLow           = ToneGenerator.sharedGenerator.randomFrequency(min_frequency, max_frequency, 1.0/2.0);
            double harmonic_frequencyLow  = (frequencyLow * (4.0/3.0));
            double frequencyMid           = (harmonic_frequencyLow * (4.0/3.0));
            
            double frequenciesLAux[3] = {frequencyLow * durationMax, harmonic_frequencyLow * durationMax, frequencyMid * durationMax};
            
            double harmonic_frequencyMid  = (frequencyMid * (4.0/3.0));
            double frequencyHigh          = (harmonic_frequencyMid * (4.0/3.0));
            double harmonic_frequencyHigh = (frequencyHigh * (4.0/3.0));
            
            double frequenciesRAux[3] = {harmonic_frequencyMid * durationMax, frequencyHigh * durationMax, harmonic_frequencyHigh * durationMax};
            
            __block Amplitude * amplitudeAux = ToneGenerator.sharedGenerator.amplitudeStruct(2,
                                                                                             3.5,
                                                                                             1.0,
                                                                                             ToneGenerator.sharedGenerator.amplitudeEnvelope,
                                                                                             @(FALSE));
            
            __block Frequency * frequencyLAux = ToneGenerator.sharedGenerator.frequencyStruct(ToneGenerator.sharedGenerator.frequencyEnvelope,
                                                                                              nil,
                                                                                              3,
                                                                                              frequenciesLAux);
            __block Tone * toneLAux           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
                                                                                 frequencyLAux,
                                                                                 amplitudeAux);
            
            __block Frequency * frequencyRAux = ToneGenerator.sharedGenerator.frequencyStruct(ToneGenerator.sharedGenerator.frequencyEnvelope,
                                                                                              nil,
                                                                                              3,
                                                                                              frequenciesRAux);
            __block Tone * toneRAux           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
                                                                                 frequencyRAux,
                                                                                 amplitudeAux);
            
            __block Tones * tonesAux = ToneGenerator.sharedGenerator.tonesStruct(durationMax,
                                                                         toneLAux,
                                                                         toneRAux);
            dataRenderedCompletionBlock(ToneGenerator.sharedGenerator.buffer(audioFormat, tonesAux), ^(NSString *playerNodeID) {
                if (playerNodeID) NSLog(playerNodeID);
                
                amplitudeAux = nil;
                frequencyLAux = nil;
                frequencyRAux = nil;
                toneLAux = nil;
                toneRAux = nil;
                tonesAux = nil;
                
                free(amplitudeAux);
                free(frequencyLAux);
                free(frequencyRAux);
                free(toneLAux);
                free(toneRAux);
                free(tonesAux);
                
                if (ToneGenerator.sharedGenerator.audioEngine.isRunning)
                    ToneGenerator.sharedGenerator.dyad(audioFormat, dataRenderedCompletionBlock);
            });
        });
    };
}

//- (Score)glissando
//{
//    return ^(AVAudioFormat *audioFormat, DataRenderedCompletionBlock dataRenderedCompletionBlock) {
//        double randDuration = ToneGenerator.sharedGenerator.randomDuration(min_duration_interval, max_duration_interval, 3.0);
//        double diffDuration = sum_duration_interval - randDuration;
//        double durationMin  = MIN(randDuration, diffDuration);
//        double durationMax  = MAX(randDuration, diffDuration);
//        double frequency    = ToneGenerator.sharedGenerator.randomFrequency(min_frequency, max_frequency / 2.0, 3.0);
//        double harmonic_frequency = (frequency * (5.0/4.0));
//        double frequencyAux = (harmonic_frequency * (5.0/4.0));
//
//        Amplitude * amplitude = ToneGenerator.sharedGenerator.amplitudeStruct(2.0,
//                                                                              2.0,
//                                                                              1.0,
//                                                                              ToneGenerator.sharedGenerator.amplitudeEnvelope,
//                                                                              @(TRUE));
//
//        Frequency * frequencyL = ToneGenerator.sharedGenerator.frequencyStruct(frequency * durationMax,
//                                                                               harmonic_frequency * durationMax,
//                                                                               0.0,
//                                                                               0.0,
//                                                                               ToneGenerator.sharedGenerator.frequencyEnvelopeGlissando,
//                                                                               @(0));
//        Tone * toneL           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
//                                                                          frequencyL,
//                                                                          amplitude);
//
//        Frequency * frequencyR = ToneGenerator.sharedGenerator.frequencyStruct(harmonic_frequency * durationMax,
//                                                                               frequencyAux * durationMax,
//                                                                               0.0,
//                                                                               0.0,
//                                                                               ToneGenerator.sharedGenerator.frequencyEnvelopeGlissando,
//                                                                               @(0));
//        Tone * toneR           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
//                                                                          frequencyR,
//                                                                          amplitude);
//
//        Tones * tones          = ToneGenerator.sharedGenerator.tonesStruct(durationMax,
//                                                                           toneL,
//                                                                           toneR);
//
//
//        dataRenderedCompletionBlock(ToneGenerator.sharedGenerator.buffer(audioFormat, tones), ^(NSString *playerNodeID) {
//            if (playerNodeID) NSLog(playerNodeID);
//            free(amplitude);
//            free(frequencyL);
//            free(frequencyR);
//            free(toneL);
//            free(toneR);
//            free(tones);
//            double frequency    = ToneGenerator.sharedGenerator.randomFrequency(min_frequency, max_frequency / 2.0, 3.0);
//            double harmonic_frequency = (frequency * (5.0/4.0));
//            double frequencyAux = (harmonic_frequency * (5.0/4.0));
//            double harmonic_frequencyAux = (frequencyAux * (5.0/4.0));
//            Amplitude * amplitudeAux = ToneGenerator.sharedGenerator.amplitudeStruct(8.0,
//                                                                                     8.0,
//                                                                                     8.0,
//                                                                                     ToneGenerator.sharedGenerator.amplitudeEnvelope,
//                                                                                     @(FALSE));
//
//            Frequency * frequencyLAux = ToneGenerator.sharedGenerator.frequencyStruct(frequency * durationMin,
//                                                                                      harmonic_frequency * durationMin,
//                                                                                      0.0,
//                                                                                      0.0,
//                                                                                      ToneGenerator.sharedGenerator.frequencyEnvelopeGlissando,
//                                                                                      @(1));
//            Tone * toneLAux           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
//                                                                                 frequencyLAux,
//                                                                                 amplitudeAux);
//
//            Frequency * frequencyRAux = ToneGenerator.sharedGenerator.frequencyStruct(harmonic_frequency * durationMin,
//                                                                                      frequencyAux * durationMin,
//                                                                                      0.0,
//                                                                                      0.0,
//                                                                                      ToneGenerator.sharedGenerator.frequencyEnvelopeGlissando,
//                                                                                      @(1));
//            Tone * toneRAux           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
//                                                                                 frequencyRAux,
//                                                                                 amplitudeAux);
//
//            Tones * tonesAux = ToneGenerator.sharedGenerator.tonesStruct(durationMin,
//                                                                         toneLAux,
//                                                                         toneRAux);
//            dataRenderedCompletionBlock(ToneGenerator.sharedGenerator.buffer(audioFormat, tonesAux), ^(NSString *playerNodeID) {
//                if (playerNodeID) NSLog(playerNodeID);
//                free(amplitudeAux);
//                free(frequencyLAux);
//                free(frequencyRAux);
//                free(toneLAux);
//                free(toneRAux);
//                free(tonesAux);
//                ToneGenerator.sharedGenerator.glissando(audioFormat, dataRenderedCompletionBlock);
//            });
//        });
//    };
//}
//
//- (Score)alarm
//{
//    return ^(AVAudioFormat *audioFormat, DataRenderedCompletionBlock dataRenderedCompletionBlock) {
//        NSLog(@"%s", __PRETTY_FUNCTION__);
//
//        double duration     = sum_duration_interval / 4.0;
//        double frequency    = ((max_frequency + min_frequency) / 4.0) * (5.0/4.0);
//        double harmonic_frequency = ((max_frequency + min_frequency) / 4.0);
//
//        Amplitude * amplitudeL = ToneGenerator.sharedGenerator.amplitudeStruct(2.0,
//                                                                               0.125,
//                                                                               2.0,
//                                                                               ToneGenerator.sharedGenerator.amplitudeEnvelope,
//                                                                               @(TRUE));
//
//        Frequency * frequencyL = ToneGenerator.sharedGenerator.frequencyStruct(frequency * duration,
//                                                                               harmonic_frequency * duration,
//                                                                               0.0,
//                                                                               0.0,
//                                                                               ToneGenerator.sharedGenerator.frequencyEnvelope,
//                                                                               nil);
//        Tone * toneL           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
//                                                                          frequencyL,
//                                                                          amplitudeL);
//
//        Amplitude * amplitudeR = ToneGenerator.sharedGenerator.amplitudeStruct(2.0,
//                                                                               0.125,
//                                                                               2.0,
//                                                                               ToneGenerator.sharedGenerator.amplitudeEnvelope,
//                                                                               @(FALSE));
//
//        Frequency * frequencyR = ToneGenerator.sharedGenerator.frequencyStruct((harmonic_frequency * (5.0/4.0)) * duration,
//                                                                               frequency * duration,
//                                                                               0.0,
//                                                                               0.0,
//                                                                               ToneGenerator.sharedGenerator.frequencyEnvelope,
//                                                                               nil);
//        Tone * toneR           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
//                                                                          frequencyR,
//                                                                          amplitudeR);
//
//        Tones * tones          = ToneGenerator.sharedGenerator.tonesStruct(duration,
//                                                                           toneL,
//                                                                           toneR);
//
//        dataRenderedCompletionBlock(ToneGenerator.sharedGenerator.buffer(audioFormat, tones), ^(NSString *playerNodeID) {
//            if (playerNodeID) NSLog(playerNodeID);
//            free(amplitudeL);
//            free(amplitudeR);
//            free(frequencyL);
//            free(frequencyR);
//            free(toneL);
//            free(toneR);
//            free(tones);
//            ToneGenerator.sharedGenerator.alarm(audioFormat, dataRenderedCompletionBlock);
//        });
//    };
//}

- (void)handleInterruption:(NSNotification *)notification
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    UInt8 interruptionType = [[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] intValue];
    
    if (interruptionType == AVAudioSessionInterruptionTypeBegan && _audioEngine.mainMixerNode.outputVolume > 0.0 && _audioEngine.isRunning == TRUE)
    {
        NSLog(@"AVAudioSessionInterruptionTypeBegan");
        // if playing, stop audio engine and then set the volume to 1.0
        [self.delegate play:[self.delegate playButton]];
        [ToneGenerator.sharedGenerator.audioEngine.mainMixerNode setOutputVolume:1.0];
    } else if (interruptionType == AVAudioSessionInterruptionTypeEnded)
    {
        if (_audioEngine.mainMixerNode.outputVolume > 0.0 && _audioEngine.isRunning == FALSE)
        {
            NSLog(@"Resuming playback...");
            [self.delegate play:[self.delegate playButton]];
        }
        NSLog(@"AVAudioSessionInterruptionTypeEnded");
    }
    AVAudioSessionInterruptionOptions options = [[notification.userInfo valueForKey:AVAudioSessionInterruptionOptionKey] intValue];
    if (options == AVAudioSessionInterruptionOptionShouldResume)
    {
        if (_audioEngine.mainMixerNode.outputVolume > 0.0 && _audioEngine.isRunning == FALSE)
        {
            NSLog(@"Resuming playback...");
            [self.delegate play:[self.delegate playButton]];
        }
        NSLog(@"AVAudioSessionInterruptionOptionShouldResume TRUE");
    } else {
        NSLog(@"AVAudioSessionInterruptionOptionShouldResume FALSE");
    }
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

AVAudio3DPoint GenerateRandomXPosition()
{
    double randomX = arc4random_uniform(40) - 20.0;
    AVAudio3DPoint point = AVAudioMake3DPoint(randomX, 0.0, 0.0);
    
    return point;
}

- (void)play:(ToneBarrierScore)toneBarrierScore
{
    if (toneBarrierScore == ToneBarrierScoreNone || [_audioEngine isRunning])
    {
        [_audioEngine pause];
        [_audioEngine.mainMixerNode setOutputVolume:0.0];
    } else {
        if ([self startEngine])
        {
            [_audioEngine.mainMixerNode setOutputVolume:1.0];
            
            if (toneBarrierScore == ToneBarrierScoreAlarm)
            {
                [self playScore:ToneGenerator.sharedGenerator.alarm onNode:_playerNode];
                [self playScore:ToneGenerator.sharedGenerator.alarm onNode:_playerNodeAux];
            } else {
                [_audioEngine detachNode:_playerNode];
                
                _playerNode = [[AVAudioPlayerNode alloc] init];
                [_playerNode setRenderingAlgorithm:AVAudio3DMixingRenderingAlgorithmAuto];
                [_playerNode setSourceMode:AVAudio3DMixingSourceModeAmbienceBed];
                [_playerNode setPosition:AVAudioMake3DPoint(0.0, 0.0, 0.0)];
                
                [_audioEngine attachNode:_playerNode];
                [_audioEngine connect:_playerNode to:_mixerNode format:_audioFormat];
                
//                [self playScore:ToneGenerator.sharedGenerator.glissando onNode:_playerNode];
                [self playScore:ToneGenerator.sharedGenerator.dyad onNode:_playerNode];
            }
        }
    }
}

- (void)playScore:(Score)score onNode:(AVAudioPlayerNode *)node
{
    __block NSInteger call_count = 0;
    __block NSInteger call_back  = 0;
    if (![node isPlaying]) [node play];
    score(self.audioFormat, ^(AVAudioPCMBuffer *buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
        NSLog(@"%lu\tReturned", call_count++);
//        [node prepareWithFrameCount:buffer.frameCapacity];
//        [node setPosition:GenerateRandomXPosition()];
        [node scheduleBuffer:buffer completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
            if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
            {
                NSLog(@"%lu\tCalled", call_back++);
                dataPlayedBackCompletionBlock(nil);
            }
        }];
    });
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
