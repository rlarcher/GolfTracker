//
//  GolfTrackerVideoDelegate.m
//  GolfTracker
//
//  Created by Ryan Archer on 5/2/17.
//  Copyright © 2017 CMU_16623. All rights reserved.
//

#import "GolfTrackerVideoDelegate.h"
#ifdef __cplusplus
#include <opencv2/opencv.hpp> // Includes the opencv library
#include "opencv2/features2d/features2d.hpp"
#include "opencv2/nonfree/features2d.hpp"
#include <stdlib.h> // Include the standard library
#include <iostream>
#endif

@implementation GolfTrackerVideoDelegate

-(void)createCaptureOutput;
{
    [super createCaptureOutput];
    [self createVideoDataOutput];
}
- (void)createCustomVideoPreview;
{
    [self.parentView.layer addSublayer:self.customPreviewLayer];
}


//Method mostly taken from this source: https://github.com/Itseez/opencv/blob/b46719b0931b256ab68d5f833b8fadd83737ddd1/modules/videoio/src/cap_ios_video_camera.mm

-(void)createVideoDataOutput{
    // Make a video data output
    self.videoDataOutput = [AVCaptureVideoDataOutput new];
    
    //Drop grayscale support here
    self.videoDataOutput.videoSettings  = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    
    // discard if the data output queue is blocked (as we process the still image)
    [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    if ( [self.captureSession canAddOutput:self.videoDataOutput] ) {
        [self.captureSession addOutput:self.videoDataOutput];
    }
    [[self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
    
    // set video mirroring for front camera (more intuitive)
    if ([self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo].supportsVideoMirroring) {
        if (self.defaultAVCaptureDevicePosition == AVCaptureDevicePositionFront) {
            [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo].videoMirrored = YES;
        } else {
            [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo].videoMirrored = NO;
        }
    }
    
    // set default video orientation
    if ([self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo].supportsVideoOrientation) {
        [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo].videoOrientation = self.defaultAVCaptureVideoOrientation;
    }
    
    // create a custom preview layer
    self.customPreviewLayer = [CALayer layer];
    
    self.customPreviewLayer.bounds = CGRectMake(0, 0, self.parentView.frame.size.width, self.parentView.frame.size.height);
    
    self.customPreviewLayer.position = CGPointMake(self.parentView.frame.size.width/2., self.parentView.frame.size.height/2.);
    
    // create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured
    // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
    // see the header doc for setSampleBufferDelegate:queue: for more information
    dispatch_queue_t videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [self.videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
}


@end

