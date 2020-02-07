//
//  InterfaceController.h
//  ToneBarrier3D WatchKit Extension
//
//  Created by James Bush on 1/28/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

#import <WatchKit/WatchKit.h>
#import <Foundation/Foundation.h>
#import <WatchConnectivity/WatchConnectivity.h>

@interface InterfaceController : WKInterfaceController <WCSessionDelegate>

@property (strong, nonatomic) WCSession *watchConnectivitySession;

@property (weak, nonatomic) IBOutlet WKInterfaceImage *watchConnectivitySessionImageView;
@property (weak, nonatomic) IBOutlet WKInterfaceImage *sessionWatchStateImageView;


@end
