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

@property (strong, nonatomic) UIDevice *device;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self audioRouteStatus];
    [self batteryLevelStatus];
    [self batteryStateStatus];
    [self thermalStateStatus];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionRouteChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        [self audioRouteStatus];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:NSProcessInfoThermalStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        [self thermalStateStatus];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryLevelDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        [self batteryLevelStatus];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        [self batteryStateStatus];
    }];
    
    self->_device = [UIDevice currentDevice];
    [self->_device setBatteryMonitoringEnabled:TRUE];
    
    // TO-DO: Request permission for access to app controls on Watch when touch is attempted;
    //        Sound an alarm on Watch when activated
//    [self->_device setProximityMonitoringEnabled:TRUE];
}

- (IBAction)play:(UIButton *)sender
{
    dispatch_queue_t playSerialQueue = dispatch_queue_create("com.blogspot.demonicactivity.serialqueue", DISPATCH_QUEUE_SERIAL);
    dispatch_block_t playTonesBlock = dispatch_block_create(0, ^{
        [[ToneGenerator sharedGenerator] play];
    });
    dispatch_async(playSerialQueue, playTonesBlock);
    dispatch_block_t playButtonBlock = dispatch_block_create(0, ^{
        if ([[[ToneGenerator sharedGenerator] audioEngine] isRunning])
        {
            [self->_playButton setImage:[UIImage systemImageNamed:@"stop"] forState:UIControlStateNormal];
        } else {
            [self->_playButton setImage:[UIImage systemImageNamed:@"play"] forState:UIControlStateNormal];
        }
    });
    dispatch_block_notify(playTonesBlock, dispatch_get_main_queue(), playButtonBlock);
}

- (void)audioRouteStatus
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

- (void)batteryLevelStatus
{
    float batteryLevel = [self->_device batteryLevel];
    if (batteryLevel <= 1.0 || batteryLevel > .66)
    {
        [self.batteryLevelImageView setImage:[UIImage systemImageNamed:@"battery.100"]];
        [self.batteryLevelImageView setTintColor:[UIColor systemGreenColor]];
    } else if (batteryLevel <= .66 || batteryLevel > .33) {
        [self.batteryLevelImageView setImage:[UIImage systemImageNamed:@"battery.25"]];
        [self.batteryLevelImageView setTintColor:[UIColor systemYellowColor]];
    } else if (batteryLevel <= .33) {
        [self.batteryLevelImageView setImage:[UIImage systemImageNamed:@"battery.0"]];
        [self.batteryLevelImageView setTintColor:[UIColor systemRedColor]];
    } else if (batteryLevel <= .125) {
        [self.batteryLevelImageView setImage:[UIImage systemImageNamed:@"battery.0"]];
        [self.batteryLevelImageView setTintColor:[UIColor systemRedColor]];
    }
}

- (void)batteryStateStatus
{
    switch ([self->_device batteryState]) {
        case UIDeviceBatteryStateUnknown:
        {
            [self.batteryStateImageView setImage:[UIImage systemImageNamed:@"bolt.slash"]];
            [self.batteryStateImageView setTintColor:[UIColor systemGrayColor]];
            break;
        }
            
        case UIDeviceBatteryStateUnplugged:
        {
            [self.batteryStateImageView setImage:[UIImage systemImageNamed:@"bolt.slash.fill"]];
            [self.batteryStateImageView setTintColor:[UIColor systemRedColor]];
            break;
        }
            
        case UIDeviceBatteryStateCharging:
        {
            [self.batteryStateImageView setImage:[UIImage systemImageNamed:@"bolt"]];
            [self.batteryStateImageView setTintColor:[UIColor systemGreenColor]];
            break;
        }
            
        case UIDeviceBatteryStateFull:
        {
            [self.batteryStateImageView setImage:[UIImage systemImageNamed:@"bolt.fill"]];
            [self.batteryStateImageView setTintColor:[UIColor systemGreenColor]];
            break;
        }
            
        default:
        {
            [self.batteryStateImageView setImage:[UIImage systemImageNamed:@"bolt.slash"]];
            [self.batteryStateImageView setTintColor:[UIColor systemGrayColor]];
            break;
        }
    }
}

- (void)thermalStateStatus
{
    switch ([[NSProcessInfo processInfo] thermalState]) {
        case NSProcessInfoThermalStateNominal:
        {
            [self.thermalStateImageView setTintColor:[UIColor systemGreenColor]];
            break;
        }
            
        case NSProcessInfoThermalStateFair:
        {
            [self.thermalStateImageView setTintColor:[UIColor systemYellowColor]];
            break;
        }
            
        case NSProcessInfoThermalStateSerious:
        {
            [self.thermalStateImageView setTintColor:[UIColor systemRedColor]];
            break;
        }
            
        case NSProcessInfoThermalStateCritical:
        {
            [self.thermalStateImageView setTintColor:[UIColor whiteColor]];
            break;
        }
            
        default:
        {
            [self.thermalStateImageView setTintColor:[UIColor systemGrayColor]];
        }
            break;
    }
}

@end
