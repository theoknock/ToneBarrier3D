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
    
    [ToneGenerator.sharedInstance setDelegate:(id<ToneGeneratorDelegate> _Nullable)self];
    
    [self audioRouteStatus];
    [self batteryLevelStatus];
    [self batteryStateStatus];
    [self thermalStateStatus];
    [self proximitySensorStateStatus];
    
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
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceProximityStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        [self proximitySensorStateStatus];
    }];
    
    self->_device = [UIDevice currentDevice];
    [self->_device setBatteryMonitoringEnabled:TRUE];
    [self->_device setProximityMonitoringEnabled:TRUE];
    
    [self activateWatchConnectivitySession];
}

- (IBAction)play:(UIButton *)sender
{
    dispatch_queue_t playSerialQueue = dispatch_queue_create("com.blogspot.demonicactivity.serialqueue", DISPATCH_QUEUE_SERIAL);
    dispatch_block_t playTonesBlock = dispatch_block_create(0, ^{
        [[ToneGenerator sharedInstance] play:nil];
    });
    dispatch_async(playSerialQueue, playTonesBlock);
    dispatch_block_t playButtonBlock = dispatch_block_create(0, ^{
        
        if ([[[ToneGenerator sharedInstance] audioEngine] isRunning])
        {
            [sender setImage:[UIImage systemImageNamed:@"stop"] forState:UIControlStateNormal];
            [self.audioRouteImageView setTintColor:[UIColor systemGreenColor]];
            
        } else {
            [sender setImage:[UIImage systemImageNamed:@"play"] forState:UIControlStateNormal];
            [self.audioRouteImageView setTintColor:[UIColor systemBlueColor]];
            
        }
    });
    dispatch_block_notify(playTonesBlock, dispatch_get_main_queue(), playButtonBlock);
}

- (void)audioRouteStatus
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    for (AVAudioSessionPortDescription *output in [session currentRoute].outputs)
    {
        NSLog(@"portType %@", [output portType]);
        if ([[output portName] isEqualToString:@"Headphones"])
        {
            [self.audioRouteImageView setImage:[UIImage systemImageNamed:@"headphones"]];
        }
        else if ([[output portType] containsString:@"Speaker"])
        {
            [self.audioRouteImageView setImage:[UIImage systemImageNamed:@"speaker"]];
        } else if ([[output portType] containsString:@"Bluetooth"])
        {
            [self.audioRouteImageView setImage:[UIImage systemImageNamed:@"hifispeaker"]];
        } else if ([[output portType] containsString:@"Receiver"])
        {
            if (ToneGenerator.sharedInstance.audioEngine.mainMixerNode.volume > 0.0)
            {
                NSLog(@"Tone barrier was playing.");
            } else {
                NSLog(@"Tone barrier was stopped.");
            }
        }
        
        //        BluetoothHFP;
        //        kAudioSessionOutputRoute_BluetoothA2DP;
        //        kAudioSessionOutputRoute_BuiltInReceiver;
        //        kAudioSessionOutputRoute_BuiltInSpeaker;
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
            [self.batteryStateImageView setImage:[UIImage systemImageNamed:@"bolt.slash"]];
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
            [self.batteryStateImageView setImage:[UIImage systemImageNamed:@"bolt"]];
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

// TO-DO: Read user info dictionary from NSNotification to detect changes to the proximity sensor
- (void)proximitySensorStateStatus
{
//    dispatch_queue_t alarmSerialQueue = dispatch_queue_create("com.blogspot.demonicactivity.serialqueue", DISPATCH_QUEUE_SERIAL);
//    dispatch_block_t stopAudioEngineBlock = dispatch_block_create(0, ^{
//        if (ToneGenerator.sharedInstance.audioEngine.isRunning)
//            [ToneGenerator.sharedInstance play:ToneBarrierScoreNone];
//        [ToneGenerator.sharedInstance play:ToneBarrierScoreAlarm];
//    });
    dispatch_block_t proximityMonitorImageViewAlarmBlock = dispatch_block_create(0, ^{
        [self.proximityMonitorImageView setImage:[UIImage systemImageNamed:@"xmark.shield"]];
        [self.proximityMonitorImageView setTintColor:[UIColor systemRedColor]];
    });
    dispatch_block_t proximityMonitorImageViewStatusBlock = dispatch_block_create(0, ^{
        if ([[UIDevice currentDevice] isProximityMonitoringEnabled]) {
            [self.proximityMonitorImageView setImage:[UIImage systemImageNamed:@"checkmark.shield"]];
            [self.proximityMonitorImageView setTintColor:[UIColor systemGreenColor]];
        } else {
            [self.proximityMonitorImageView setImage:[UIImage systemImageNamed:@"exclamationmark.shield"]];
            [self.proximityMonitorImageView setTintColor:[UIColor systemBlueColor]];
        }
    });
    
    //dispatch_async(alarmSerialQueue, stopAudioEngineBlock);
    //dispatch_block_notify(stopAudioEngineBlock, dispatch_get_main_queue(), playAlarmBlock);
    
    WCSession *wcs = self->_watchConnectivitySession;
        if (wcs.isReachable)
        {
            [wcs sendMessage:@{@"ProximitySensorState" : @{@"proximityState" : @([[UIDevice currentDevice] proximityState]),
                                                           @"isProximityMonitoringEnabled" : @([[UIDevice currentDevice] isProximityMonitoringEnabled])}}
                replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Handle reply
                });
            } errorHandler:^(NSError * _Nonnull error) {
                
            }];
        }
    
    if ([[UIDevice currentDevice] proximityState]) {
        dispatch_async(dispatch_get_main_queue(), proximityMonitorImageViewAlarmBlock);
    } else {
        dispatch_async(dispatch_get_main_queue(), proximityMonitorImageViewStatusBlock);
    }
    
    
    
    
}

- (void)activateWatchConnectivitySession
{
    dispatch_queue_t watchConnectivitySessionSerialQueue = dispatch_queue_create("com.blogspot.demonicactivity.serialqueue", DISPATCH_QUEUE_SERIAL);
    dispatch_block_t watchConnectivitySessionBlock = dispatch_block_create(0, ^{
        WCSession *wcs = self->_watchConnectivitySession;
        if (!wcs && [WCSession isSupported])
        {
            wcs = [WCSession defaultSession];
            [wcs setDelegate:(id<WCSessionDelegate> _Nullable)self];
            self.watchConnectivitySession = wcs;
        }
    });
    dispatch_async(watchConnectivitySessionSerialQueue, watchConnectivitySessionBlock);
    dispatch_block_t activateWatchConnectivitySessionBlock = dispatch_block_create(0, ^{
        [self.watchConnectivitySession activateSession];
    });
    dispatch_block_notify(watchConnectivitySessionBlock, dispatch_get_main_queue(), activateWatchConnectivitySessionBlock);
}

- (void)session:(WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (activationState != WCSessionActivationStateActivated) [self.watchConnectivitySession activateSession];
        switch (activationState) {
            case WCSessionActivationStateInactive:
            {
                [self.watchConnectivitySessionImageView setTintColor:[UIColor systemGrayColor]];
                break;
            }
                
            case WCSessionActivationStateNotActivated:
            {
                [self.watchConnectivitySessionImageView setTintColor:[UIColor systemRedColor]];
                break;
            }
                
            case WCSessionActivationStateActivated:
            {
                [session sendMessage:@{@"" : @""} replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                    NSLog(@"%s", __PRETTY_FUNCTION__);
                } errorHandler:^(NSError * _Nonnull error) {
                    NSLog(@"%s %@", __PRETTY_FUNCTION__, error.description);
                }];
                [self.watchConnectivitySessionImageView setTintColor:[UIColor systemGreenColor]];
                break;
            }
                
            default:
            {
                [self.watchConnectivitySessionImageView setTintColor:[UIColor systemGrayColor]];
                break;
            }
        }
    });
}

- (void)sessionWatchStateDidChange:(WCSession *)session
{
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL paired = [session isPaired];
        BOOL reachable = [session isReachable];
        [self.sessionWatchStateImageView setTintColor:(paired) ? [UIColor systemGreenColor] : (reachable) ? [UIColor systemBlueColor] : [UIColor systemRedColor]];
    });
}

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *,id> *)message replyHandler:(nonnull void (^)(NSDictionary<NSString *,id> * _Nonnull))replyHandler
{
    dispatch_queue_t messageSerialQueue = dispatch_queue_create("com.blogspot.demonicactivity.message.serialqueue", DISPATCH_QUEUE_SERIAL);
    dispatch_block_t messageBlock = dispatch_block_create(0, ^{
        ([message enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            if ([key isEqualToString:@"RemoteStatus"])
            {
                replyHandler(@{@"RemoteStatus" : @((BOOL)[[[ToneGenerator sharedInstance] audioEngine] isRunning])});
            } else if ([key isEqualToString:@"RemoteAction"])
            {
                NSString *remoteAction = [(NSDictionary<NSString *, NSString *> *)message objectForKey:@"RemoteAction"];
                [self play:self.playButton];
                replyHandler(@{@"RemoteAction" : @{@"action" : @([[[ToneGenerator sharedInstance] audioEngine] isRunning])}});
            }
        }]);
    });
    dispatch_async(messageSerialQueue, messageBlock);
    
//    dispatch_block_t activateWatchConnectivitySessionBlock = dispatch_block_create(0, ^{
//        
//    });
//    dispatch_block_notify(watchConnectivitySessionBlock, dispatch_get_main_queue(), activateWatchConnectivitySessionBlock);
//    
//    
//                    if (statusDict)
//                    {
//                        isToneBarrierPlaying = [(NSNumber *)[statusDict objectForKey:@"status"] boolValue];
//                        
//                    }
//                });
//            } errorHandler:^(NSError * _Nonnull error) {
//                
//            }];
//        }
//    });
//    dispatch_async(playSerialQueue, playTonesBlock);
//    
//    dispatch_queue_t playConcurrentQueue = dispatch_queue_create("com.blogspot.demonicactivity.concurrentqueue", DISPATCH_QUEUE_CONCURRENT);
//    dispatch_block_t playButtonBlock = dispatch_block_create(0, ^{
//        WCSession *wcs = self->_watchConnectivitySession;
//        if (wcs.isReachable)
//        {
//            [wcs sendMessage:@{@"RemoteAction" : @{@"action" : @(!isToneBarrierPlaying)}}
//                replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    NSDictionary<NSString *, NSNumber *> *remoteActionDict = (NSDictionary<NSString *, NSNumber *> *)[[NSDictionary alloc] initWithDictionary:(NSDictionary<NSString *, NSDictionary *> *)[replyMessage objectForKey:@"RemoteAction"]];
//                    if (isToneBarrierPlaying)
}

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *,id> *)message
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)session:(WCSession *)session didReceiveMessageData:(NSData *)messageData replyHandler:(void (^)(NSData * _Nonnull))replyHandler
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)sessionReachabilityDidChange:(WCSession *)session
{
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL reachable = session.isReachable;
        [self.sessionWatchStateImageView setTintColor:(reachable) ? [UIColor systemGrayColor] : [UIColor systemRedColor]];
    });
}

- (void)sessionDidDeactivate:(WCSession *)session
{
    [session activateSession]; // To-Do: Verify whether session should be activated
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.watchConnectivitySessionImageView setTintColor:[UIColor systemRedColor]];
    });
}

- (void)sessionDidBecomeInactive:(WCSession *)session
{
    [session activateSession]; // To-Do: Verify whether session should be activated
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.watchConnectivitySessionImageView setTintColor:[UIColor systemGrayColor]];
    });
}

@end
