//
//  ViewController.m
//  ToneBarrier3D
//
//  Created by James Bush on 1/28/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

#import "ViewController.h"
#import "ToneGenerator.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self changeAudioRouteStatus];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionRouteChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        [self changeAudioRouteStatus];
    }];
}

- (IBAction)play:(UIButton *)sender
{
    [[ToneGenerator sharedGenerator] play];
    if ([[[ToneGenerator sharedGenerator] audioEngine] isRunning])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_playButton setImage:[UIImage systemImageNamed:@"stop"] forState:UIControlStateNormal];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_playButton setImage:[UIImage systemImageNamed:@"play"] forState:UIControlStateNormal];
        });
    }
}

- (void)changeAudioRouteStatus
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    for (AVAudioSessionPortDescription *output in [session currentRoute].outputs)
    {
        if ([[output portName] isEqualToString:@"Headphones"])
        {
            [self.headphonesImageView setTintColor:[UIColor systemGreenColor]];
        } else {
            [self.headphonesImageView setTintColor:[UIColor systemRedColor]];
        }
    }
    
}

@end
