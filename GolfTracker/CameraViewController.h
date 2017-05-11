//
//  ViewController.h
//  CvVideoCamera_Example
//
//  Created by Simon Lucey on 10/1/16.
//  Copyright © 2016 CMU_16623. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <opencv2/highgui/ios.h>
#import "Helper.h"
#import "GolfTrackerVideoDelegate.h"

@interface CameraViewController : UIViewController<AVCaptureVideoDataOutputSampleBufferDelegate>
@property bool finding_speed;
@property AVCaptureVideoPreviewLayer *previewLayer;
@end
