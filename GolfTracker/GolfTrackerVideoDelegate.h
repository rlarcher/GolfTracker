//
//  GolfTrackerVideoDelegate.h
//  GolfTracker
//
//  Created by Ryan Archer on 5/2/17.
//  Copyright © 2017 CMU_16623. All rights reserved.
//

#import <opencv2/highgui/cap_ios.h>
#import <opencv2/highgui/ios.h>

#define DEGREES_RADIANS(angle) ((angle) / 180.0 * M_PI)

@class GolfTrackerVideoDelegate;

@protocol GolfTrackerVideoDel <CvPhotoCameraDelegate>
#ifdef __cplusplus
- (void)processImage:(cv::Mat&)image;
#endif
@end

@interface GolfTrackerVideoDelegate : CvPhotoCamera <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, retain) CALayer *customPreviewLayer;
@property (nonatomic, retain) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, weak) id <GolfTrackerVideoDel> delegate;

- (void)createCustomVideoPreview;

@end

