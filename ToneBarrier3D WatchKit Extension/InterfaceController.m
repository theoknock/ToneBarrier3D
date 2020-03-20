//
//  InterfaceController.m
//  ToneBarrier3D WatchKit Extension
//
//  Created by James Bush on 1/28/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

#import "InterfaceController.h"
#import "ToneGenerator.h"

@interface InterfaceController ()
{
    dispatch_block_t playButtonBlock_;
}

@end


@implementation InterfaceController

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    
    playButtonBlock_ = dispatch_block_create(0, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([[[ToneGenerator sharedGenerator] audioEngine] isRunning])
            {
                [self.playButton setBackgroundImageNamed:@"stop"];
                // send message to play
                
                
            } else {
                [self.playButton setBackgroundImageNamed:@"play"];
                // send a message to stop
            }
        });
    });
    
    // Configure interface objects here.
    [self activateWatchConnectivitySession];
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
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
        if (activationState != WCSessionActivationStateActivated) [session activateSession];
        switch (activationState) {
            case WCSessionActivationStateInactive:
            {
                [self.watchConnectivitySessionImageView setTintColor:[UIColor grayColor]];
                break;
            }
                
            case WCSessionActivationStateNotActivated:
            {
                [self.watchConnectivitySessionImageView setTintColor:[UIColor redColor]];
                break;
            }
                
            case WCSessionActivationStateActivated:
            {
                [session sendMessage:@{@"" : @""} replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                    NSLog(@"%s", __PRETTY_FUNCTION__);
                } errorHandler:^(NSError * _Nonnull error) {
                    NSLog(@"%s %@", __PRETTY_FUNCTION__, error.description);
                }];
                [self.watchConnectivitySessionImageView setTintColor:[UIColor greenColor]];
                break;
            }
                
            default:
            {
                [self.watchConnectivitySessionImageView setTintColor:[UIColor grayColor]];
                break;
            }
        }
    });
}

- (void)proximityStatus:(NSDictionary<NSString *, NSNumber *> *)proximitySensorState
{
    BOOL proximityState               = [(NSNumber *)[proximitySensorState objectForKey:@"proximityState"] boolValue];
    BOOL isProximityMonitoringEnabled = [(NSNumber *)[proximitySensorState objectForKey:@"isProximityMonitoringEnabled"] boolValue];
    
    if (proximityState)
    {
        [self.proximitySensorStateImageView setImage:[UIImage systemImageNamed:@"xmark.shield.fill"]];
        [self.proximitySensorStateImageView setTintColor:[UIColor redColor]];
    } else {
        [self.proximitySensorStateImageView setImage:[UIImage systemImageNamed:@"checkmark.shield.fill"]];
        [self.proximitySensorStateImageView setTintColor:[UIColor greenColor]];
        if (isProximityMonitoringEnabled)
        {
            [self.proximitySensorStateImageView setImage:[UIImage systemImageNamed:@"checkmark.shield.fill"]];
            [self.proximitySensorStateImageView setTintColor:[UIColor greenColor]];
        } else {
            [self.proximitySensorStateImageView setImage:[UIImage systemImageNamed:@"exclamationmark.shield"]];
            [self.proximitySensorStateImageView setTintColor:[UIColor blueColor]];
        }
    }
}

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *,id> *)message replyHandler:(void (^)(NSDictionary<NSString *,id> * _Nonnull))replyHandler
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    // message NSDictionary structure
    //
    //      KEY: ProximitySensorState           OBJ: (NSDictionary *)
    //                                          KEY: (NSString *)proximityState                     OBJ: (BOOL)
    //                                          KEY: (NSString *)isProximityMonitoringEnabled       OBJ: (BOOL)
    NSDictionary<NSString *, NSNumber *> *proximityStateDict = (NSDictionary<NSString *, NSNumber *> *)[[NSDictionary alloc] initWithDictionary:(NSDictionary<NSString *, NSNumber *> *)[message objectForKey:@"ProximitySensorState"]];
    if (proximityStateDict) [self proximityStatus:proximityStateDict];
}

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *,id> *)message
{
    
}

- (void)sessionReachabilityDidChange:(WCSession *)session
{
    BOOL reachable = session.isReachable;
    [self.sessionWatchStateImageView setTintColor:(reachable) ? [UIColor grayColor] : [UIColor redColor]];
}

- (IBAction)play
{
    dispatch_queue_t playSerialQueue = dispatch_queue_create("com.blogspot.demonicactivity.serialqueue", DISPATCH_QUEUE_SERIAL);
    dispatch_block_t playTonesBlock = dispatch_block_create(0, ^{
        WCSession *wcs = self->_watchConnectivitySession;
        if (wcs.isReachable)
        {
            [wcs sendMessage:@{@"RemoteAction" : @{@"play" : @(TRUE)}}
                replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Handle reply
                    NSDictionary<NSString *, NSNumber *> *remoteActionDict = (NSDictionary<NSString *, NSNumber *> *)[[NSDictionary alloc] initWithDictionary:(NSDictionary<NSString *, NSDictionary *> *)[replyMessage objectForKey:@"RemoteAction"]];
                    if (remoteActionDict)
                    {
                        BOOL isPlaying = [(NSNumber *)[remoteActionDict objectForKey:@"play"] boolValue];
                    if (isPlaying)
                    {
                        [self.playButton setBackgroundImageNamed:@"stop"];
                        // send message to play
                        
                        
                    } else {
                        [self.playButton setBackgroundImageNamed:@"play"];
                        // send a message to stop
                    }
                }
                               });
            } errorHandler:^(NSError * _Nonnull error) {
                
            }];
        }
    });
    dispatch_async(playSerialQueue, playTonesBlock);
    
    dispatch_block_notify(playTonesBlock, dispatch_get_main_queue(), playButtonBlock_);
}

//- (IBAction)play
//{
//    dispatch_queue_t playSerialQueue = dispatch_queue_create("com.blogspot.demonicactivity.serialqueue", DISPATCH_QUEUE_SERIAL);
//    dispatch_block_t playTonesBlock = dispatch_block_create(0, ^{
//        [[ToneGenerator sharedGenerator] play];
//    });
//    dispatch_async(playSerialQueue, playTonesBlock);
//    dispatch_block_t playButtonBlock = dispatch_block_create(0, ^{
//        dispatch_async(dispatch_get_main_queue(), ^{
//            if ([[[ToneGenerator sharedGenerator] audioEngine] isRunning])
//            {
//                [self.playButton setBackgroundImageNamed:@"stop"];
//            } else {
//                [self.playButton setBackgroundImageNamed:@"play"];
//            }
//        });
//    });
//    dispatch_block_notify(playTonesBlock, dispatch_get_main_queue(), playButtonBlock);
//}



@end



