//
//  ViewController.h
//  LSTFL_Gather
//
//  Created by Jeremy Feldman on 15/2/19.
//  Copyright © 2019 Jeremy Feldman. All rights reserved.
//

#import <opencv2/videoio/cap_ios.h>
#import <UIKit/UIKit.h>

NSTimer *TimeOfActiveUser;

@interface ViewController : UIViewController<CvVideoCameraDelegate>
//@property (weak, nonatomic) IBOutlet UIImageView *imageViewInstance0;


@end

