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
#define max_duration_interval 0.75
#define min_duration_interval 0.33

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
typedef double (^FrequencyEnvelope)(double time, double frequency, double secondaryFrequency, double minFrequency, double maxFrequency, id var);
typedef double (^AmplitudeEnvelope)(double time, BOOL invert, double mid, double trill, double slope, id var);

typedef struct frequency
{
    double primary;
    double secondary;
    double min;
    double max;
    __unsafe_unretained FrequencyEnvelope frequencyEnvelope;
    __unsafe_unretained id var;
} Frequency;

typedef struct amplitude
{
    BOOL              invert;
    double            mid;
    double            trill;
    double            slope;
    __unsafe_unretained AmplitudeEnvelope amplitudeEnvelope;
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
@property (nonatomic, strong) AmplitudeEnvelope  amplitudeEnvelopeAux;
@property (strong, nonatomic, readonly) Score              dyad;
@property (strong, nonatomic, readonly) Score              glissando;
@property (strong, nonatomic, readonly) AVAudioPCMBuffer * (^buffer)(AVAudioFormat * audioFormat, Tones * tones);
@property (strong, nonatomic, readonly) float * (^channelData)(AVAudioFrameCount, Tone *, float *, float *);

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
    return ^double(double time, double primaryFrequency, double secondaryFrequency, double minFrequency, double maxFrequency, id var)
    {
        return sinf(M_PI * 2.0 * time * primaryFrequency);
    };
}

- (FrequencyEnvelope)frequencyEnvelopeGlissando
{
    return ^double(double time, double primaryFrequency, double secondaryFrequency, double minFrequency, double maxFrequency, id var)
    {
        NSInteger r = [(NSNumber *)var integerValue];
        double new_frequency = (r == 0) ? primaryFrequency + ((secondaryFrequency - primaryFrequency) * time) :
                                          secondaryFrequency - ((secondaryFrequency - primaryFrequency) * time);
        return sinf(M_PI * 2.0 * time * new_frequency);
    };
}

//- (FrequencyEnvelope)frequencyEnvelopeAuxDown
//{
//    return ^double(double time, double primaryFrequency, double secondaryFrequency, double minFrequency, double maxFrequency, id var)
//    {
//        double new_frequency = secondaryFrequency - ((secondaryFrequency - primaryFrequency) * time);
//        return sinf(M_PI * 2.0 * time * new_frequency);
//    };
//}



- (AmplitudeEnvelope)amplitudeEnvelope
{
    return ^double(double time, BOOL invert, double trill, double mid, double slope, id var)
    {
        time = (invert) ? 1.0 - time : time;
        return pow(sinf(pow(time, mid) * M_PI * (9.0 * time)), slope);
    };
}

- (AmplitudeEnvelope)amplitudeEnvelopeAux
{
    return ^double(double time, BOOL invert, double trill, double mid, double slope, id var)
    {
        return sinf(time * 2.0 * M_PI * (trill * time));
    };
}

//+ (FrequencyModifier)frequencyModifier
//{
//    return ^double(double time, double frequencies[4])
//    {
//        return 1.0;//(max_trill_interval - min_trill_interval) * pow(time, 1.0/3.0)) + min_trill_interval;
//    };
//};

//+ (double (^)(double, double[4], FrequencyEnvelope))frequencyEnvelope
//{
//    return ^double(double time, double frequencies[4], FrequencyModifier frequencyModifier)
//    {
//        return sinf(M_PI * 2.0 * time * frequencies[0]);
////        return pow(2.0 * pow(sinf(M_PI * time * frequency), 2.0) * 0.5, 4.0);
//    };
//]

- (Frequency *(^)(double, double, double, double, FrequencyEnvelope, id var))frequencyStruct
{
    return ^Frequency *(double primary, double secondary, double min, double max, FrequencyEnvelope frequencyEnvelope, id var)
    {
        Frequency * frequency_struct        = malloc(sizeof(Frequency));
        frequency_struct->primary           = primary;
        frequency_struct->secondary         = secondary;
        frequency_struct->min               = min;
        frequency_struct->max               = max;
        frequency_struct->frequencyEnvelope = frequencyEnvelope;
        frequency_struct->var               = var;
        
        return frequency_struct;
    };
}

- (Amplitude *(^)(BOOL, double, double, double, AmplitudeEnvelope, id))amplitudeStruct
{
    return ^Amplitude *(BOOL invert, double mid, double trill, double slope, AmplitudeEnvelope amplitudeEnvelope, id var)
    {
        Amplitude * amplitude_struct        = malloc(sizeof(Amplitude));
        amplitude_struct->invert            = invert;
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
        Tones *tones_struct = malloc(sizeof(Tones));
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
            double freq = tone->frequency->frequencyEnvelope(time, tone->frequency->primary, tone->frequency->secondary, tone->frequency->min, tone->frequency->max, tone->frequency->var);
            double amp  = tone->amplitude->amplitudeEnvelope(time, tone->amplitude->invert, tone->amplitude->mid, tone->amplitude->trill, tone->amplitude->slope, tone->amplitude->var);
            
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
        // Glissando plays two tones, the first with a short duration, and the second with a long one; the total duration of both tones is two seconds
        // When playing multiple tones in a single score call...
        double randDuration = ToneGenerator.sharedGenerator.randomDuration(min_duration_interval, max_duration_interval, 3.0);
        double diffDuration = sum_duration_interval - randDuration;
        double durationMin  = MIN(randDuration, diffDuration);
        double durationMax  = MAX(randDuration, diffDuration);
        double frequency    = ToneGenerator.sharedGenerator.randomFrequency(min_frequency, max_frequency / 2.0, 3.0);
        double harmonic_frequency = (frequency * (5.0/4.0));
        double frequencyAux = (harmonic_frequency * (5.0/4.0));
        double harmonic_frequencyAux = (frequencyAux * (5.0/4.0));
        
        // The amplitude calculation is the same for both channels
        Amplitude * amplitude = ToneGenerator.sharedGenerator.amplitudeStruct(FALSE,                            // The amplitude peaks in the middle, so an inversion would render the same result
                                                                              2.0,                              // Peak the amplitude in the middle (i.e., even attack, even release)
                                                                              2.0,                              // Smooth the transition from/to 0.0 during/after the attack/release
                                                                              1.0,                              // The trill value must always be an odd number
                                                                              ToneGenerator.sharedGenerator.amplitudeEnvelope,
                                                                              nil); // The block that calculates the amplitude using the parameter values supplied in this struct
        
        Frequency * frequencyL = ToneGenerator.sharedGenerator.frequencyStruct(frequency * durationMin,
                                                                               harmonic_frequency * durationMin,
                                                                               0.0,
                                                                               0.0,
                                                                               ToneGenerator.sharedGenerator.frequencyEnvelope,
                                                                               nil);
        Tone * toneL           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
                                                                          frequencyL,
                                                                          amplitude);
        
        Frequency * frequencyR = ToneGenerator.sharedGenerator.frequencyStruct(harmonic_frequency * durationMin,
                                                                               frequencyAux * durationMin,
                                                                               0.0,
                                                                               0.0,
                                                                               ToneGenerator.sharedGenerator.frequencyEnvelope,
                                                                               nil);
        Tone * toneR           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
                                                                          frequencyR,
                                                                          amplitude);
                        
        Tones * tones          = ToneGenerator.sharedGenerator.tonesStruct(durationMin,
                                                                           toneL,
                                                                           toneR);
        
        Amplitude * amplitudeAux = ToneGenerator.sharedGenerator.amplitudeStruct(FALSE,
                                                                                 8.0,
                                                                                 8.0,
                                                                                 8.0,
                                                                                 ToneGenerator.sharedGenerator.amplitudeEnvelopeAux,
                                                                                 nil);
        
        Frequency * frequencyLAux = ToneGenerator.sharedGenerator.frequencyStruct(harmonic_frequency * durationMax,
                                                                                  frequencyAux * durationMax,
                                                                                  0.0,
                                                                                  0.0,
                                                                                  ToneGenerator.sharedGenerator.frequencyEnvelope,
                                                                                  nil);
        Tone * toneLAux           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
                                                                             frequencyLAux,
                                                                             amplitudeAux);
        
        Frequency * frequencyRAux = ToneGenerator.sharedGenerator.frequencyStruct(frequencyAux * durationMax,
                                                                                  harmonic_frequencyAux * durationMax,
                                                                                  0.0,
                                                                                  0.0,
                                                                                  ToneGenerator.sharedGenerator.frequencyEnvelope,
                                                                                  nil);
        Tone * toneRAux           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
                                                                             frequencyRAux,
                                                                             amplitudeAux);
        
        Tones * tonesAux = ToneGenerator.sharedGenerator.tonesStruct(durationMax,
                                                                     toneLAux,
                                                                     toneRAux);
        
        NSLog(@"Dyad: Frequency * duration\t%f, %f", tones->channel_l_tone->frequency->primary, durationMin);
        dataRenderedCompletionBlock(ToneGenerator.sharedGenerator.buffer(audioFormat, tones), ^(NSString *playerNodeID) {
            free(amplitude);
            free(frequencyL);
            free(frequencyR);
            free(toneL);
            free(toneR);
            free(tones);
            NSLog(@"Dyad: FrequencyAux * duration\t%f, %f", tonesAux->channel_l_tone->frequency->primary, durationMax);
            dataRenderedCompletionBlock(ToneGenerator.sharedGenerator.buffer(audioFormat, tonesAux), ^(NSString *playerNodeID) {
                free(amplitudeAux);
                free(frequencyLAux);
                free(frequencyRAux);
                free(toneLAux);
                free(toneRAux);
                free(tonesAux);
                ToneGenerator.sharedGenerator.dyad(audioFormat, dataRenderedCompletionBlock);
            });
        });
    };
}

- (Score)glissando
{
    return ^(AVAudioFormat *audioFormat, DataRenderedCompletionBlock dataRenderedCompletionBlock) {
        // Glissando plays two tones, the first with a short duration, and the second with a long one; the total duration of both tones is two seconds
        // When playing multiple tones in a single score call...
        double randDuration = ToneGenerator.sharedGenerator.randomDuration(min_duration_interval, max_duration_interval, 3.0);
        double diffDuration = sum_duration_interval - randDuration;
        double durationMin  = MIN(randDuration, diffDuration);
        double durationMax  = MAX(randDuration, diffDuration);
        double frequency    = ToneGenerator.sharedGenerator.randomFrequency(min_frequency, max_frequency / 2.0, 3.0);
        double harmonic_frequency = (frequency * (5.0/4.0));
        double frequencyAux = (harmonic_frequency * (5.0/4.0));
        
        // The amplitude calculation is the same for both channels
        Amplitude * amplitude = ToneGenerator.sharedGenerator.amplitudeStruct(FALSE,                            // The amplitude peaks in the middle, so an inversion would render the same result
                                                                              2.0,                              // Peak the amplitude in the middle (i.e., even attack, even release)
                                                                              2.0,                              // Smooth the transition from/to 0.0 during/after the attack/release
                                                                              1.0,                              // The trill value must always be an odd number
                                                                              ToneGenerator.sharedGenerator.amplitudeEnvelope,
                                                                              nil); // The block that calculates the amplitude using the parameter values supplied in this struct
        
        Frequency * frequencyL = ToneGenerator.sharedGenerator.frequencyStruct(frequency * durationMax,
                                                                               harmonic_frequency * durationMax,
                                                                               0.0,
                                                                               0.0,
                                                                               ToneGenerator.sharedGenerator.frequencyEnvelopeGlissando,
                                                                               @(0));
        Tone * toneL           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
                                                                          frequencyL,
                                                                          amplitude);
        
        Frequency * frequencyR = ToneGenerator.sharedGenerator.frequencyStruct(harmonic_frequency * durationMax,
                                                                               frequencyAux * durationMax,
                                                                               0.0,
                                                                               0.0,
                                                                               ToneGenerator.sharedGenerator.frequencyEnvelopeGlissando,
                                                                               @(0));
        Tone * toneR           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
                                                                          frequencyR,
                                                                          amplitude);
        
        Tones * tones          = ToneGenerator.sharedGenerator.tonesStruct(durationMax,
                                                                           toneL,
                                                                           toneR);
        
        NSLog(@"Glissando: Frequency * duration\t%f, %f", tones->channel_l_tone->frequency->primary, durationMax);
        dataRenderedCompletionBlock(ToneGenerator.sharedGenerator.buffer(audioFormat, tones), ^(NSString *playerNodeID) {
            free(amplitude);
            free(frequencyL);
            free(frequencyR);
            free(toneL);
            free(toneR);
            free(tones);
            double frequency    = ToneGenerator.sharedGenerator.randomFrequency(min_frequency, max_frequency / 2.0, 3.0);
            double harmonic_frequency = (frequency * (5.0/4.0));
            double frequencyAux = (harmonic_frequency * (5.0/4.0));
            double harmonic_frequencyAux = (frequencyAux * (5.0/4.0));
            Amplitude * amplitudeAux = ToneGenerator.sharedGenerator.amplitudeStruct(FALSE,
                                                                     8.0,
                                                                     8.0,
                                                                     8.0,
                                                                     ToneGenerator.sharedGenerator.amplitudeEnvelopeAux,
                                                                     nil);
            
            Frequency * frequencyLAux = ToneGenerator.sharedGenerator.frequencyStruct(frequency * durationMin,
                                                                                      harmonic_frequency * durationMin,
                                                                                      0.0,
                                                                                      0.0,
                                                                                      ToneGenerator.sharedGenerator.frequencyEnvelopeGlissando,
                                                                                      @(1));
            Tone * toneLAux           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
                                                                                 frequencyLAux,
                                                                                 amplitudeAux);
            
            Frequency * frequencyRAux = ToneGenerator.sharedGenerator.frequencyStruct(harmonic_frequency * durationMin,
                                                                                      frequencyAux * durationMin,
                                                                                      0.0,
                                                                                      0.0,
                                                                                      ToneGenerator.sharedGenerator.frequencyEnvelopeGlissando,
                                                                                      @(1));
            Tone * toneRAux           = ToneGenerator.sharedGenerator.toneStruct(ToneGenerator.sharedGenerator.timeEnvelope,
                                                                                 frequencyRAux,
                                                                                 amplitudeAux);
            
            Tones * tonesAux = ToneGenerator.sharedGenerator.tonesStruct(durationMin,
                                                         toneLAux,
                                                         toneRAux);
            NSLog(@"Glissando: FrequencyAux * duration\t%f, %f", tonesAux->channel_l_tone->frequency->primary, durationMin);
            dataRenderedCompletionBlock(ToneGenerator.sharedGenerator.buffer(audioFormat, tonesAux), ^(NSString *playerNodeID) {
//                NSLog(@"Total duration\t%f", durationMin + durationMax);
                free(amplitudeAux);
                free(frequencyLAux);
                free(frequencyRAux);
                free(toneLAux);
                free(toneRAux);
                free(tonesAux);
                ToneGenerator.sharedGenerator.glissando(audioFormat, dataRenderedCompletionBlock);
            });
        });
    };
}


//+ (AVAudioPCMBuffer *(^)(AVAudioFormat *, Tones *))buffer
//{
//    return ^AVAudioPCMBuffer *(AVAudioFormat *audioFormat, Tones * tones)
//    {
//        frequency = frequency * duration;
//        harmonic_frequency = harmonic_frequency * duration;
//        double sampleRate = [audioFormat sampleRate];
//        AVAudioFrameCount frameCount = (sampleRate * sum_duration_interval) * duration;
//        AVAudioPCMBuffer *pcmBuffer  = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFormat frameCapacity:frameCount];
//        pcmBuffer.frameLength        = sampleRate * duration; //pcmBuffer.frameCapacity; //(sampleRate * duration_interval)(duration_weight < 1.0) ? frameCount : sampleRate;
//        float *l_channel             = pcmBuffer.floatChannelData[0];
//        float *r_channel             = ([audioFormat channelCount] == 2) ? pcmBuffer.floatChannelData[1] : nil;
//
//        for (int index = 0; index < pcmBuffer.frameLength; index++)
//        {
//            double time      = ToneGenerator.percentage(index, pcmBuffer.frameLength);
//            double freq_env_l  = ToneGenerator.frequencyEnvelope(time, frequency, frequencyEnvelopeInterval);
//            double freq_env_r  = ToneGenerator.frequencyEnvelope(time, harmonic_frequency, frequencyEnvelopeInterval);
//            double amp_env   = amplitude(time, 1.0);
//
//            double f = freq_env_l * amp_env; /*frequencyEnvelope(time,
//                                           ToneGenerator.scale(time, 0.0, 1.0, frequency, ToneGenerator.harmonicInterval(frequency, HarmonicIntervalPerfectFifth, HarmonicInversionPerfect)),
//                                           harmonic_frequency, frequencyEnvelopeInterval) * freq_env * amp_env; //frequencyBufferData(time, frequency, harmonic_frequency) * amplitude(time, 1.0); */
//            double g = freq_env_r * amp_env; /*frequencyEnvelope(time,
//                                           ToneGenerator.scale(time, 0.0, 1.0, harmonic_frequency, ToneGenerator.harmonicInterval(harmonic_frequency, HarmonicIntervalPerfectFifth, HarmonicInversionPerfect)),
//                                           harmonic_frequency) * freq_env * amp_env;*/
//            if (l_channel) l_channel[index] = f;
//            if (r_channel) r_channel[index] = g;
//        }
//
//        return pcmBuffer;
//    };
//}


// Quantity: You determine an interval’s quantity by simply adding the lines and spaces included in the interval on the music staff. Accidentals (sharps and flats), which raise or lower a pitch by a half step, don’t matter when counting interval quantity. Interval quantity may be
//
//    Unison (or prime)
//
//    Second
//
//    Third
//
//    Fourth
//
//    Fifth
//
//    Sixth
//
//    Seventh
//
//    Octave
//
// Quality: Interval quality is based on the number of half steps from one note to another. Unlike in interval quantity, accidentals do matter in interval quality. The terms used to describe quality, and their abbreviations, are as follows:
//
//    Major (M): Contains two half steps between notes
//
//    Minor (m): Contains a half step less than a major interval, or one half step between notes
//
//    Perfect (P): Refers to the harmonic quality of primes, octaves, fourths, and fifths
//
//    Diminished (dim): Contains a half step less than a minor or perfect interval
//
//    Augmented (aug): Contains a half step more than a major or perfect interval



// Interval = Inversion
// Minor seconds = major sevenths
//Major seconds = minor sevenths
//Minor thirds = major sixths
//Major thirds = minor sixths
//Perfect fourths = perfect fifths
//@property (class, readonly) double(^tonality)(double frequency, TonalHarmony, HarmonicInterval);

//+ (double (^)(double, HarmonicInterval, HarmonicInversion))harmonicInterval
//{
//    return ^double(double frequency, HarmonicInterval harmonicInterval, HarmonicInversion harmonicInversion)
//    {
//        double harmonic_interval;
//        switch (harmonicInterval)
//        {
//            case HarmonicIntervalUnison:
//                harmonic_interval = 1.0;
//                break;
//
//            case HarmonicIntervalOctave:
//                harmonic_interval = 2.0;
//                break;
//
//            case HarmonicIntervalMajorSixth:
//                harmonic_interval = 5.0/3.0;
//                break;
//
//            case HarmonicIntervalPerfectFifth:
//                harmonic_interval = 3.0/2.0;
//                break;
//
//            case HarmonicIntervalPerfectFourth:
//                harmonic_interval = 4.0/3.0;
//                break;
//
//            case HarmonicIntervalMinorThird:
//                harmonic_interval = 6.0/5.0;
//                break;
//
//            case HarmonicIntervalMajorThird:
//                harmonic_interval = 5.0/4.0;
//                break;
//
//            default:
//                harmonic_interval = 1.0;
//                break;
//        }
//
//        double new_frequency = (harmonicInversion == HarmonicInversionPerfect) ? frequency * harmonic_interval : frequency / harmonic_interval;
//
//        return new_frequency;
//    };
//}

//typedef void (^RandomizedFrequenciesCompletionBlock)(double, double);
//typedef void (^RandomFrequencies)(double, double, double, HarmonicInterval, HarmonicInversion, RandomizedFrequenciesCompletionBlock);

//+ (RandomFrequencies)randomFrequencies
//{
//    return ^void(double min, double max, double weight, HarmonicInterval harmonic_interval, HarmonicInversion harmonic_inversion, RandomizedFrequenciesCompletionBlock randomFrequenciesCompletionBlock)
//    {
//        NSUInteger r = arc4random_uniform(2);
//        double frequency, harmonic_frequency;
//        frequency = ToneGenerator.randomFrequency(min, max, weight);
//        harmonic_frequency = ToneGenerator.harmonicInterval(frequency, harmonic_interval,  harmonic_inversion);
//
//        randomFrequenciesCompletionBlock(frequency, harmonic_frequency);
//    };
//
//}
//
//+ (FrequencyBufferData)frequencyGlissando
//{
//    return ^double(double time, double frequency, double harmonic_frequency)
//    {
//        return sinf(M_PI * 2.0 * time * frequency); //ToneGenerator.scale(time, 0.0, 1.0, min_frequency, max_frequency));
//    };
//}


//+ (FrequencyEnvelopeInterval)frequencyEnvelopeGlissando
//{
//    return ^double(double time, double frequency, double harmonic_frequency)
//    {
//        return ToneGenerator.frequencyGlissando(time, ToneGenerator.scale(time, 0.0, 1.0, frequency, harmonic_frequency));
//    };
//}

//+ (FrequencyEnvelopeInterval)frequencyEnvelopeDyad
//{
//    return ^double(double time, double frequency, double harmonic_frequency)
//    {
//        return ((max_trill_interval - min_trill_interval) * pow(time, 1.0/3.0)) + min_trill_interval;
//    };
//}

//+ (Score)glissando
//{
//    return ^(AVAudioFormat *audioFormat, DataRenderedCompletionBlock dataRenderedCompletionBlock) {
//
//
//
//
//        NSUInteger q = arc4random_uniform(2);
//        ToneGenerator.randomFrequencies(min_frequency, max_frequency, 2.0, HarmonicIntervalPerfectFifth, q, ^(double frequency, double harmonic_frequency) {
//            double duration = ToneGenerator.randomDuration(min_duration_interval, max_duration_interval, 3.0);
//            NSLog(@"duration (1) == %f (harmonic inversion == %lu)", MIN(duration, sum_duration_interval - duration), q);
//
//            dataRenderedCompletionBlock(ToneGenerator.buffer(frequency, harmonic_frequency, MIN(duration, sum_duration_interval - duration), audioFormat, ToneGenerator.frequencyEnvelopeInterval, ToneGenerator.amplitude, ToneGenerator.frequencyEnvelope), ^(NSString *playerNodeID) {
//                NSUInteger r = arc4random_uniform(2);
//                NSLog(@"duration (2) == %f (harmonic inversion == %lu", MAX(duration, sum_duration_interval - duration), r);
//                dataRenderedCompletionBlock(ToneGenerator.buffer(harmonic_frequency, ToneGenerator.harmonicInterval(frequency, HarmonicIntervalPerfectFifth, (HarmonicInversion)(r)), MAX(duration, sum_duration_interval - duration), audioFormat, ToneGenerator.frequencyEnvelopeInterval, ToneGenerator.amplitude, ToneGenerator.frequencyEnvelope), ^(NSString *playerNodeID) {
//                    ToneGenerator.glissando(audioFormat, dataRenderedCompletionBlock);
//                });
//            });
//
//        });
//
//        //        ToneGenerator.randomFrequencies(min_frequency, max_frequency, 2.0, HarmonicIntervalMajorThird, ^(double frequency, double harmonic_frequency) {
//        //            double duration = RANDOM_NUMF(0.0, 2.0);
//        //            dispatch_queue_t dataRendererSerialQueue = dispatch_queue_create("com.blogspot.demonicactivity.dataRendererSerialQueue", DISPATCH_QUEUE_SERIAL);
//        //            dispatch_block_t glissandoBlock = dispatch_block_create(0, ^{
//        //                dataRenderedCompletionBlock(ToneGenerator.buffer(frequency, harmonic_frequency, duration, audioFormat, ToneGenerator.frequencyEnvelopeInterval, ToneGenerator.amplitude, ToneGenerator.frequencyEnvelope), ^(NSString *playerNodeID) {
//        //
//        //                });
//        //            });
//        //            dispatch_async(dataRendererSerialQueue, glissandoBlock);
//        //            dispatch_block_t glissandoBlockAux = dispatch_block_create(0, ^{
//        //                dataRenderedCompletionBlock(ToneGenerator.buffer(harmonic_frequency, ToneGenerator.harmonicInterval(harmonic_frequency, HarmonicIntervalPerfectFifth, HarmonicInversionPerfect), sum_duration_interval - duration, audioFormat, ToneGenerator.frequencyEnvelopeInterval, ToneGenerator.amplitude, ToneGenerator.frequencyEnvelope), ^(NSString *playerNodeID) {
//        //                    ToneGenerator.glissando(audioFormat, dataRenderedCompletionBlock);
//        //                });
//        //            });
//        //            dispatch_block_notify(glissandoBlock, dispatch_get_main_queue(), glissandoBlockAux);
//        //        });
//    };
//}

- (void)handleInterruption:(NSNotification *)notification
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    UInt8 interruptionType = [[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] intValue];
    
    if (interruptionType == AVAudioSessionInterruptionTypeBegan)
    {
        NSLog(@"AVAudioSessionInterruptionTypeBegan");
        // if playing, stop audio engine and then set the volume to 1,0
        [self.delegate play:nil];
        [ToneGenerator.sharedGenerator.audioEngine.mainMixerNode setOutputVolume:1.0];
    } else if (interruptionType == AVAudioSessionInterruptionTypeEnded)
    {
        if (_audioEngine.mainMixerNode.outputVolume > 0.0)
        {
            NSLog(@"Resuming playback...");
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
            ToneGenerator.sharedGenerator.glissando(self.audioFormat, ^(AVAudioPCMBuffer *buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
                [self->_playerNode scheduleBuffer:buffer completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
                    if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
                    {
                        [self->_playerNode setPosition:GenerateRandomXPosition()];
                        dataPlayedBackCompletionBlock([NSString stringWithFormat:@"AVAudioPlayerNodeCompletionDataPlayedBack"]);
                    }
                }];
            });
            
            if (![_playerNodeAux isPlaying]) [_playerNodeAux play];
            ToneGenerator.sharedGenerator.dyad(self.audioFormat, ^(AVAudioPCMBuffer *buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
                [self->_playerNodeAux scheduleBuffer:buffer completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
                    if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
                    {
                        [self->_playerNodeAux setPosition:GenerateRandomXPosition()];
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
