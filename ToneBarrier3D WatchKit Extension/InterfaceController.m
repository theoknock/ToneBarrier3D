//
//  InterfaceController.m
//  ToneBarrier3D WatchKit Extension
//
//  Created by James Bush on 1/28/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

#import "InterfaceController.h"


@interface InterfaceController ()

@end


@implementation InterfaceController

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];

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

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *,id> *)message replyHandler:(void (^)(NSDictionary<NSString *,id> * _Nonnull))replyHandler
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *,id> *)message
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)sessionReachabilityDidChange:(WCSession *)session
{
    BOOL reachable = session.isReachable;
    [self.sessionWatchStateImageView setTintColor:(reachable) ? [UIColor grayColor] : [UIColor redColor]];
}

@end



