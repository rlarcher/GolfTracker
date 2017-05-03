//
//  ViewController.m
//  CvVideoCamera_Example
//
//  Created by Simon Lucey on 10/1/16.
//  Copyright © 2016 CMU_16623. All rights reserved.
//

#import "CameraViewController.h"
#import <AVFoundation/AVCaptureOutput.h>
#import "GolfTrackerVideoDelegate.h"

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
    int64 curr_time;
    cv::Point curr_center;
    cv::Point next_center;
    UIButton *startButton;
    bool stopped;
    AVCaptureDevice *camera_device;
    AVCaptureDeviceInput *camera_device_input;
    AVCaptureSession *session;
    AVCaptureVideoDataOutput *output;
    CAShapeLayer *line_layer;
    IBOutlet UIImageView *imageView;
    CGFloat scaleFactorX;
    CGFloat scaleFactorY;
    UIBezierPath *path;
}

@end

@implementation CameraViewController

const cv::Scalar RED = cv::Scalar(255, 0, 0);
const float GOLF_BALL_MILLI_RADIUS = 21.3;

using namespace std;

- (void)viewDidLoad {
    [super viewDidLoad];
    num_points = 0;
    
    // set up calayer for drawing line
    self->line_layer = [CAShapeLayer layer];
    self->line_layer.lineWidth = 6.0f;
    [self->line_layer setFillColor:[[UIColor colorWithWhite:0 alpha:0] CGColor]];
    self->line_layer.lineCap = kCALineCapRound;
    self->line_layer.strokeColor = [[UIColor redColor] CGColor];
    self->line_layer.backgroundColor = [UIColor colorWithWhite:0.f alpha:0.3f].CGColor;
    [self.view.layer addSublayer:self->line_layer];
    path = [[UIBezierPath alloc] init];
    
    session = [[AVCaptureSession alloc] init];
    //[session setSessionPreset:AVCaptureSessionPresetHigh];
    
    self->startButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    CGSize size = self.view.frame.size;
    CGRect button_frame = CGRectMake(size.width / 2, size.height - 100, 50, 50);
    self->startButton.frame = button_frame;
    self->startButton.titleLabel.text = @"Start";
    [startButton addTarget:self action:@selector(start) forControlEvents:UIControlEventTouchUpInside];
    //[self.view addSubview:self->startButton];
    
    camera_device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    if (camera_device != NULL) {
        [self configureCameraForHighestFrameRate:camera_device];
        [self configureInput];
        [self configureOutput];
        [session commitConfiguration];
    }
    
    //[session startRunning];
    [self startCapturingWithSession:session];
}

- (void)startCapturingWithSession: (AVCaptureSession *) captureSession
{
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
    
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    self.previewLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:self.previewLayer];
    
    [captureSession startRunning];
}

- (void) configureOutput {
    // create camera output
    output = [AVCaptureVideoDataOutput new];
    
    output.videoSettings = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey: (id)kCVPixelBufferPixelFormatTypeKey];
    [output setAlwaysDiscardsLateVideoFrames:YES];
    // set output delegate to self
    dispatch_queue_t queue = dispatch_queue_create("output_queue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    [[output connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
    [session addOutput:output];
}

- (void) configureInput {
    NSError *error = NULL;
    camera_device_input = [AVCaptureDeviceInput deviceInputWithDevice: camera_device error: &error];
    [session addInput:camera_device_input];
}
- (IBAction)reset_path:(id)sender {
    num_points = 1;
    //[session stopRunning];
    //[[NSOperationQueue mainQueue] waitUntilAllOperationsAreFinished];
    //[self drawLines];
}

- (void)configureCameraForHighestFrameRate:(AVCaptureDevice *)device
{
    AVCaptureDeviceFormat *bestFormat = nil;
    AVFrameRateRange *bestFrameRateRange = nil;
    for (AVCaptureDeviceFormat *format in [device formats] ) {
        for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges ) {
            if (range.maxFrameRate < bestFrameRateRange.maxFrameRate ) {
                bestFormat = format;
                bestFrameRateRange = range;
                cout << "Got best format " << range.maxFrameRate << "\n";
            }
        }
    }
    if (bestFormat) {
        if ([device lockForConfiguration:NULL] == YES) {
            // lock config
            device.activeFormat = bestFormat;
            device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
            device.activeVideoMinFrameDuration = bestFrameRateRange.minFrameDuration;
            device.activeVideoMaxFrameDuration = bestFrameRateRange.minFrameDuration;
            [device unlockForConfiguration];
        }
    }
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
    scaleFactorX = image.rows / self->imageView.frame.size.width;
    scaleFactorY = image.cols / self->imageView.frame.size.height;
    // Now apply Brisk features on the live camera
    using namespace cv;
    
    cout << "Processing image\n";
    
    // Convert image to hsvscale....
    //std::cout << image.channels() << std::endl;
    
    Mat hsv;
    if(image.channels() == 4)
        cvtColor(image, hsv, CV_RGB2HSV); // Convert to hsvscale
    else hsv = image;
    
    GaussianBlur(hsv, hsv, cv::Size(3, 3), 2, 2 );
    int64 next_time = getTickCount();
    
    curr_time = next_time;
    
    
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
            std::cout << "adding" << "\n";
            cv::minEnclosingCircle(contours[i], center[i], radius[i]);
            double dist = euclideanDist(points[num_points-1].x, center[i].x,
                                        points[num_points-1].y, center[i].y);
            cout << dist << "\n";
            //if(dist < 45 || num_points < 5) {
                points[num_points] = center[i];
                curr_center = center[i];
                num_points++;
            //}
        }
    }/*
    for(size_t i = 1; i < num_points -1; i++) {
        cout << "drawing line\n";
        cv::Point start = points[i];
        cv::Point end = points[i+1];
        cv::line(image, start, end, Scalar(0,0,255), 2);
    }*/
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self drawLines];
    }];
}

- (void) drawLines {
    if (num_points > 1) {
    /*[self->line_layer removeFromSuperlayer];
    UIBezierPath *path=[UIBezierPath bezierPath];
    CGPoint start = CGPointMake(points[1].x/scaleFactorX, points[1].y/scaleFactorY);
    [path moveToPoint:start];
    cout << "first point is " << start.x << " " << start.y << "\n";
    for (size_t i = 1; i < num_points; i++) {
        CGFloat x = points[i].x / scaleFactorX;
        CGFloat y = points[i].y / scaleFactorY;
        [path addLineToPoint:CGPointMake(y, x)];
        cout << "moving to " << x << " and " << y << "\n";
    }
    self->line_layer.path = path.CGPath;
    [self.view.layer addSublayer:self->line_layer];
     */
        CGFloat x = points[num_points-1].x / scaleFactorX;
        CGFloat y = points[num_points-1].y / scaleFactorY;
        [path addLineToPoint:CGPointMake(x,y)];
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    (void)captureOutput;
    (void)connection;
    using namespace std;
        // convert from Core Media to Core Video
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        
        void* bufferAddress;
        size_t width;
        size_t height;
        size_t bytesPerRow;
        
        int format_opencv;
        
        OSType format = CVPixelBufferGetPixelFormatType(imageBuffer);
        if (format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            
            format_opencv = CV_8UC1;
            
            bufferAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
            width = CVPixelBufferGetWidthOfPlane(imageBuffer, 0);
            height = CVPixelBufferGetHeightOfPlane(imageBuffer, 0);
            bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
            
        } else { // expect kCVPixelFormatType_32BGRA
            
            format_opencv = CV_8UC4;
            
            bufferAddress = CVPixelBufferGetBaseAddress(imageBuffer);
            width = CVPixelBufferGetWidth(imageBuffer);
            height = CVPixelBufferGetHeight(imageBuffer);
            bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
            
        }
        
        // delegate image processing to the delegate
        cv::Mat image((int)height, (int)width, format_opencv, bufferAddress, bytesPerRow);
    
        [self processImage:image];
    
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);

}

@end
