//
//  ViewController.h
//  ToneBarrier3D
//
//  Created by James Bush on 1/28/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WatchConnectivity/WatchConnectivity.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController : UIViewController <WCSessionDelegate>

@property (strong, nonatomic) WCSession *watchConnectivitySession;

@property (weak, nonatomic) IBOutlet UIImageView *watchConnectivitySessionImageView;
@property (weak, nonatomic) IBOutlet UIImageView *sessionWatchStateImageView;  
@property (weak, nonatomic) IBOutlet UIImageView *headphonesImageView;
@property (weak, nonatomic) IBOutlet UIImageView *thermalStateImageView;
@property (weak, nonatomic) IBOutlet UIImageView *batteryStateImageView;
@property (weak, nonatomic) IBOutlet UIImageView *batteryLevelImageView;
@property (weak, nonatomic) IBOutlet UIImageView *proximityMonitorImageView;
@property (weak, nonatomic) IBOutlet UIButton *playButton;


@end

