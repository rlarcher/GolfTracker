//
//  ViewController.m
//  CvVideoCamera_Example
//
//  Created by Simon Lucey on 10/1/16.
//  Copyright © 2016 CMU_16623. All rights reserved.
//

#import "ViewController.h"

#ifdef __cplusplus
#include <opencv2/opencv.hpp> // Includes the opencv library
#include "opencv2/features2d/features2d.hpp"
#include "opencv2/nonfree/features2d.hpp"
#include <stdlib.h> // Include the standard library
#include <iostream>
#endif

@interface ViewController(){
    UIImageView *imageView_; // Setup the image view
    cv::vector<cv::Vec3f> golf_balls_; // vector of golf balls being detected
    cv::Point points[10000];
    size_t num_points;
}

@end

@implementation ViewController

const cv::Scalar RED = cv::Scalar(255, 0, 0);

// Important as when you when you override a property of a superclass, you must explicitly synthesize it
@synthesize videoCamera;

- (void)viewDidLoad {
    [super viewDidLoad];
    num_points = 1;
    float cam_width = 288; float cam_height = 352;
    
    int view_width = self.view.frame.size.width;
    int view_height = (int)(cam_height*self.view.frame.size.width/cam_width);
    int offset = (self.view.frame.size.height - view_height)/2;
    
    imageView_ = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, offset, view_width, view_height)];
    
    //[imageView_ setContentMode:UIViewContentModeScaleAspectFill]; (does not work)
    [self.view addSubview:imageView_]; // Add the view
    
    // Initialize the video camera
    self.videoCamera = [[CvVideoCamera alloc] initWithParentView:imageView_];
    self.videoCamera.delegate = self;
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.videoCamera.defaultFPS = 30; // Set the frame rate
    self.videoCamera.grayscaleMode = YES; // Get grayscale
    self.videoCamera.rotateVideo = YES; // Rotate video so everything looks correct
    
    // Choose these depending on the camera input chosen
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset352x288;
    //self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset640x480;
    //self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset1280x720;

    [videoCamera start];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

// Function to run apply image on
- (void) processImage:(cv:: Mat &)image
{
    // Now apply Brisk features on the live camera
    using namespace cv;
    
    // Convert image to grayscale....
    //std::cout << image.channels() << std::endl;
    
    Mat gray;
    if(image.channels() == 4)
        cvtColor(image, gray, CV_RGBA2GRAY); // Convert to grayscale
    else gray = image;
    
    GaussianBlur(gray, gray, cv::Size(9, 9), 2, 2 );
    
    vector<Vec3f> circles;
    
    HoughCircles(gray, circles, CV_HOUGH_GRADIENT, 1, gray.rows/8, 200, 100, 0, 0 );
    for(size_t i = 0; i < circles.size(); i++) {
        std::cout << "Detected circle";
        cv::Point center(cvRound(circles[i][0]), cvRound(circles[i][1]));
        //int radius = cvRound(circles[i][2]);
        // circle center
        //circle( image, center, 3, Scalar(0,255,0), -1, 8, 0 );
        // circle outline
        //circle( image, center, radius, Scalar(0,0,255), 3, 8, 0 );
        points[num_points] = center;
        num_points++;
    }
    for(size_t i = 1; i < num_points -1; i++) {
        cv::Point start = points[i];
        cv::Point end = points[i+1];
        cv::line(image, start, end, Scalar(0,0,255), 2);
    }

}


@end
