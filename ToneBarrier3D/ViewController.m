//
//  ViewController.m
//  ToneBarrier3D
//
//  Created by James Bush on 1/28/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (nonatomic, readonly) AVAudioEngine * _Nonnull audioEngine;
@property (nonatomic, readonly) AVAudioFormat * _Nullable audioFormat;
@property (nonatomic, readonly) AVAudioPlayerNode * _Nullable playerNode;
@property (nonatomic, readonly) AVAudioEnvironmentNode * _Nullable environmentNode;
@property (nonatomic, readonly) AVAudioMixerNode * _Nullable mainNode;
@property (nonatomic, readonly) AVAudioTime * _Nullable time;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupEngine];
}

- (void)setupEngine
{
    _audioEngine = [[AVAudioEngine alloc] init];
    
    _mainNode = _audioEngine.mainMixerNode;
    
    _audioFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:[_mainNode outputFormatForBus:0].sampleRate channels:2];
    
    _playerNode = [[AVAudioPlayerNode alloc] init];
    [_playerNode setRenderingAlgorithm:AVAudio3DMixingRenderingAlgorithmAuto];
    [_playerNode setSourceMode:AVAudio3DMixingSourceModeAmbienceBed];
    [_playerNode setPosition:AVAudioMake3DPoint(0.0, 0.0, 0.0)];
    
    _environmentNode = [[AVAudioEnvironmentNode alloc] init];
    [_environmentNode setOutputVolume:1.0];
    
    [_audioEngine attachNode:_playerNode];
    [_audioEngine attachNode:_environmentNode];
    
    [_audioEngine connect:_playerNode      to:_environmentNode format:_audioFormat];
    [_audioEngine connect:_environmentNode to:_mainNode        format:_audioFormat];
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

double GenerateRandomXPosition()
{
    double randomNum = arc4random_uniform(40) - 20.0;
    
    return randomNum;
}

double GenerateRandomReverb()
{
    double randomNum = arc4random_uniform(100);
    
    return randomNum / 100;
}

typedef void (^DataPlayedBackCompletionBlock)(void);
typedef void (^DataRenderedCompletionBlock)(AVAudioPCMBuffer * _Nonnull buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock);

- (IBAction)play:(UIButton *)sender
{
    if ([_audioEngine isRunning])
    {
        [_audioEngine pause];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_playButton setImage:[UIImage systemImageNamed:@"play"] forState:UIControlStateNormal];
        });
    } else {
        if ([self startEngine])
        {
            if (![_playerNode isPlaying]) [_playerNode play];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_playButton setImage:[UIImage systemImageNamed:@"stop"] forState:UIControlStateNormal];
            });
            
            [self createAudioBufferWithCompletionBlock:^(AVAudioPCMBuffer * _Nonnull buffer, DataPlayedBackCompletionBlock dataPlayedBackCompletionBlock) {
                
                CMTime cmtime = CMTimeAdd(CMTimeMakeWithSeconds([AVAudioTime secondsForHostTime:[self->_time hostTime]], NSEC_PER_SEC), CMTimeMakeWithSeconds(1.0, NSEC_PER_SEC));
                self->_time   = [[AVAudioTime alloc] initWithHostTime:CMClockConvertHostTimeToSystemUnits(cmtime)];
                [self->_playerNode scheduleBuffer:buffer atTime:self->_time options:AVAudioPlayerNodeBufferInterruptsAtLoop completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
                    if (callbackType == AVAudioPlayerNodeCompletionDataPlayedBack)
                    {
                        [self->_playerNode setPosition:AVAudioMake3DPoint(GenerateRandomXPosition(), 0, 0)];
                        dataPlayedBackCompletionBlock();
                        NSLog(@"dataPlayedBackCompletionBlock()");
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
    return sinf((x * 2 * M_PI) / 2.0);
}

#define high_frequency 2000.0
#define low_frequency  500.0

- (void)createAudioBufferWithCompletionBlock:(DataRenderedCompletionBlock)dataRenderedCompletionBlock
{
    AVAudioPCMBuffer * (^createAudioBuffer)(double);
    createAudioBuffer = ^AVAudioPCMBuffer * (double frequency)
    {
        AVAudioFrameCount frameCount = self->_audioFormat.sampleRate;
        AVAudioPCMBuffer *pcmBuffer  = [[AVAudioPCMBuffer alloc] initWithPCMFormat:self->_audioFormat frameCapacity:frameCount];
        pcmBuffer.frameLength        = frameCount;
        float *l_channel             = pcmBuffer.floatChannelData[0];
        float *r_channel             = (self->_audioFormat.channelCount == 2) ? pcmBuffer.floatChannelData[1] : nil;
        
        for (int index = 0; index < frameCount; index++)
        {
            double normalized_index         = Normalize(index, frameCount);
            if (l_channel) l_channel[index] = Frequency(normalized_index, frequency) * Amplitude(normalized_index);
            if (r_channel) r_channel[index] = Frequency(normalized_index, frequency) * Amplitude(normalized_index);
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
