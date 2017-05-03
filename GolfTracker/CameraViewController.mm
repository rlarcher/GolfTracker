//
//  ViewController.m
//  CvVideoCamera_Example
//
//  Created by Simon Lucey on 10/1/16.
//  Copyright © 2016 CMU_16623. All rights reserved.
//

#import "CameraViewController.h"

#ifdef __cplusplus
#include <opencv2/opencv.hpp> // Includes the opencv library
#include "opencv2/features2d/features2d.hpp"
#include "opencv2/nonfree/features2d.hpp"
#include <stdlib.h> // Include the standard library
#include <iostream>
#endif

@interface CameraViewController(){
    UIImageView *imageView_; // Setup the image view
    cv::vector<cv::Vec3f> golf_balls_; // vector of golf balls being detected
    cv::Point points[10000];
    size_t num_points;
    UITextView *fpsView_; // Display the current FPS
    int64 curr_time_; // Store the current time
    cv::Point curr_center;
    cv::Point next_center;
    UIButton *startButton;
    bool stopped;
}

@end

@implementation CameraViewController

const cv::Scalar RED = cv::Scalar(255, 0, 0);
const float GOLF_BALL_MILLI_RADIUS = 21.3;

using namespace std;

@synthesize videoCamera;
- (IBAction)reset_path:(id)sender {
    num_points = 1;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    num_points = 1;
    float cam_width = 720; float cam_height = 1280;
    
    int view_width = self.view.frame.size.width;
    int view_height = (int)(cam_height*self.view.frame.size.width/cam_width);
    int offset = (self.view.frame.size.height - view_height)/2;
    
    imageView_ = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, offset, view_width, view_height-50)];
    
    //[imageView_ setContentMode:UIViewContentModeScaleAspectFill]; (does not work)
    [self.view addSubview:imageView_]; // Add the view
    
    // Initialize the video camera
    self.videoCamera = [[CvVideoCamera alloc] initWithParentView:imageView_];
    self.videoCamera.delegate = self;
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.videoCamera.defaultFPS = 240; // Set the frame rate
    self.videoCamera.grayscaleMode = YES; // Get hsvscale
    self.videoCamera.rotateVideo = YES; // Rotate video so everything looks correct
    
    // Choose these depending on the camera input chosen
    //self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset352x288;
    //self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset640x480;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset1280x720;
    
    // Finally add the FPS text to the view
    fpsView_ = [[UITextView alloc] initWithFrame:CGRectMake(0,15,view_width,std::max(offset,35))];
    [fpsView_ setOpaque:false]; // Set to be Opaque
    [fpsView_ setBackgroundColor:[UIColor clearColor]]; // Set background color to be clear
    [fpsView_ setTextColor:[UIColor redColor]]; // Set text to be RED
    [fpsView_ setFont:[UIFont systemFontOfSize:18]]; // Set the Font size
    [self.view addSubview:fpsView_];

    [videoCamera start];
    self->startButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    CGSize size = self.view.frame.size;
    CGRect frame = CGRectMake(size.width / 2, size.height - 100, 50, 50);
    self->startButton.frame = frame;
    self->startButton.titleLabel.text = @"Start";
    [startButton addTarget:self action:@selector(start) forControlEvents:UIControlEventTouchUpInside];
    //[self.view addSubview:self->startButton];
    //[self.videoCamera start];
}

- (void)start:(id)sender
{
    //[self.videoCamera start];
    [self->startButton removeFromSuperview];
    UIButton *stopButton = [[UIButton alloc] init];
    CGSize size = self.view.frame.size;
    CGRect frame = CGRectMake(size.width / 2, size.height - 40, 50, 50);
    stopButton.frame = frame;
    stopButton.titleLabel.text = @"Stop";
    [stopButton addTarget:self action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:stopButton];
}

- (void)stop:(id)sender {
    self->stopped = true;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

double CircularityStandard(double area,double perimeter)
{
    if( (area<=0) || (perimeter<=0)) return 0;
    return (4 * CV_PI*area) / (perimeter*perimeter);
}

float euclideanDist(float x1, float x2, float y1, float y2) {
    float diffx = x1 - x2;
    float diffy = y1 - y2;
    return cv::sqrt(diffx*diffx + diffy*diffy);
}

// Function to run apply image on
- (void) processImage:(cv:: Mat &)image
{
    // Now apply Brisk features on the live camera
    using namespace cv;
    
    // Convert image to hsvscale....
    //std::cout << image.channels() << std::endl;
    
    Mat hsv;
    if(image.channels() == 4)
        cvtColor(image, hsv, CV_RGB2HSV); // Convert to hsvscale
    else hsv = image;
    
    GaussianBlur(hsv, hsv, cv::Size(9, 9), 2, 2 );

    curr_center = next_center;

    using namespace cv;
    
    Mat threshold_output;
    vector<vector<cv::Point> > contours;
    vector<Vec4i> hierarchy;
    //threshold( hsv, threshold_output, 127, 255, THRESH_BINARY );
    
    inRange(hsv, cv::Scalar(0, 0, 200, 0), cv::Scalar(180, 255, 255, 0), threshold_output);
    
    findContours( threshold_output, contours, hierarchy, RETR_TREE, CHAIN_APPROX_SIMPLE, cv::Point(0, 0) );
    vector<vector<cv::Point> > contours_poly( contours.size() );
    vector<cv::Rect> boundRect( contours.size() );
    vector<Point2f>center( contours.size() );
    vector<float>radius( contours.size() );
    
    for( size_t i = 1; i < contours.size(); i++ )
    {
        double area = cv::contourArea(contours[i]);
        cv::Rect rect = cv::boundingRect(contours[i]);
        int r = rect.width / 2;
        //std::cout << std::abs(1 - ((double)rect.width / rect.height)) << " " <<
        //std::abs(1 - (area / (CV_PI * (radius * radius)))) << "\n";
        if (std::abs(1 - ((double)rect.width / rect.height)) <= 0.2
            && std::abs(1 - (area / (CV_PI * (r * r)))) <= 0.2){
            //std::cout << "adding" << "\n";
            cv::minEnclosingCircle(contours[i], center[i], radius[i]);
            double dist = euclideanDist(points[num_points-1].x, center[i].x,
                                        points[num_points-1].y, center[i].y);
            cout << dist << "\n";
            if(dist < 45 || num_points < 5) {
                points[num_points] = center[i];
                curr_center = center[i];
                num_points++;
            }
        }
    }
    for(size_t i = 1; i < num_points -1; i++) {
        cv::Point start = points[i];
        cv::Point end = points[i+1];
        cv::line(image, start, end, Scalar(0,0,255), 2);
    }
    
    // Finally estimate the frames per second (FPS)
    int64 next_time = getTickCount(); // Get the next time stamp
    float fps = (float)getTickFrequency()/(next_time - curr_time_); // Estimate the fps
    curr_time_ = next_time; // Update the time
    NSString *fps_NSStr = [NSString stringWithFormat:@"FPS = %2.2f",fps];
    
    // Have to do this so as to communicate with the main thread
    // to update the text display
    dispatch_sync(dispatch_get_main_queue(), ^{
        fpsView_.text = fps_NSStr;
    });
}


@end
