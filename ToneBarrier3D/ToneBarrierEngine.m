//
//  ToneBarrierEngine.m
//  ToneBarrier3D
//
//  Created by Xcode Developer on 3/26/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

#import "ToneBarrierEngine.h"

#define max_frequency      2500.00
#define min_frequency       200.00
#define max_trill_interval   18.00
#define min_trill_interval    2.00
#define sum_duration_interval 2.00
#define max_duration_interval 1.25
#define min_duration_interval 0.25

typedef double(^TimeCalculation)(double numerator, double denominator);
typedef double(^FrequencyCalculation)(double time, double frequency);
typedef double(^AmplitudeCalculation)(double time, double slope);
typedef double(^FrequencyModifier)(double time, FrequencyCalculation frequency_calculation);
typedef double(^BufferDataVariables)(double time, double frequency, double amplitude, double frequency_modifier);
typedef double(^BufferDataCalculations)(TimeCalculation time_calculation, FrequencyCalculation frequency_calculation, AmplitudeCalculation amplitude_calculation, FrequencyModifier frequency_modifier);

@interface ToneBarrierEngine ()

@property (nonatomic, readonly) TimeCalculation time_calculation;
@property (nonatomic, readonly) FrequencyCalculation frequency_calculation;
@property (nonatomic, readonly) AmplitudeCalculation amplitude_calculation;
@property (nonatomic, readonly) FrequencyModifier frequency_modifier;
@property (nonatomic, readonly) BufferDataCalculations buffer_data_calculations;
@property (nonatomic, readonly) InternalBufferDataCalculation internal_buffer_data_calculation;

@end

@implementation ToneBarrierEngine

+ (TimeCalculation)time_calculation
{
    return ^double(double numerator, double denominator)
    {
        return (double)numerator/denominator;
    };
}

+ (FrequencyCalculation)frequency_calculation
{
    return ^double(double time, double frequency)
    {
        return sinf(M_PI * 2.0 * time * frequency);
    };
}

+ (AmplitudeCalculation)amplitude_calculation
{
    return ^double(double time, double slope)
    {
        return pow(sinf(time * M_PI), slope);
    };
}

+ (FrequencyModifier)frequency_modifier
{
    return ^double(double time, double frequency)
    {
        return ((max_trill_interval - min_trill_interval) * pow(time, 1.0/3.0)) + min_trill_interval;
    };
}

+ (BufferDataCalculations)buffer_data_calculations
{
    return ^(TimeCalculation time_calculation, FrequencyCalculation frequency_calculation, AmplitudeCalculation amplitude_calculation, FrequencyModifier frequency_modifier)
    {
        double time  = time_calculation()
    };
}

+ (BufferDataVariables)buffer_data_variables
{
    return ^(double time, double frequency, double amplitude, double frequency_modifier)
    {
        double time      = ToneGenerator.percentage(index, frameCount);
        double freq_env  = ToneGenerator.frequencyEnvelope(time, frequency, harmonic_frequency, frequencyEnvelopeInterval);
        double amp_env   = amplitude(time, 1.0);
        
        double f = frequencyBufferData(time,
                                       ToneGenerator.scale(time, 0.0, 1.0, frequency, ToneGenerator.harmonicInterval(frequency, HarmonicIntervalPerfectFifth, HarmonicInversionPerfect)),
                                       harmonic_frequency) * freq_env * amp_env; //frequencyBufferData(time, frequency, harmonic_frequency) * amplitude(time, 1.0);
        double g = frequencyBufferData(time,
                                       ToneGenerator.scale(time, 0.0, 1.0, harmonic_frequency, ToneGenerator.harmonicInterval(harmonic_frequency, HarmonicIntervalPerfectFifth, HarmonicInversionPerfect)),
                                       harmonic_frequency) * freq_env * amp_env;
        if (l_channel) l_channel[index] = f;
        if (r_channel) r_channel[index] = g;
        double time  = (frequency * frequency_modifier) * amplitude
    };
}


@end
