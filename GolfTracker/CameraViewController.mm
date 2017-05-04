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
#include "ball_detection.hpp"
#include <stdlib.h> // Include the standard library
#include <iostream>
#endif


@interface CameraViewController(){
    cv::vector<cv::Vec3f> golf_balls_; // vector of golf balls being detected
    cv::Point points[10000];
    size_t num_points;
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
    UITextView *fpsView_;
    UITextView *mpsView_;
    int64 curr_time_; // Store the current time
    int speed_count;
}

@end

@implementation CameraViewController

using namespace std;

- (void)viewDidLoad {
    [super viewDidLoad];
    num_points = 0;
    speed_count = 0;
    
    fpsView_ = [[UITextView alloc] initWithFrame:CGRectMake(0,15,150,50)];
    [fpsView_ setOpaque:false]; // Set to be Opaque
    [fpsView_ setBackgroundColor:[UIColor clearColor]]; // Set background color to be clear
    [fpsView_ setTextColor:[UIColor redColor]]; // Set text to be RED
    [fpsView_ setFont:[UIFont systemFontOfSize:18]]; // Set the Font size
    [self.view addSubview:fpsView_];
    
    mpsView_ = [[UITextView alloc] initWithFrame:CGRectMake(300, 15, 150, 50)];
    [mpsView_ setOpaque:false];
    [mpsView_ setBackgroundColor:[UIColor clearColor]];
    [mpsView_ setTextColor:[UIColor redColor]];
    [mpsView_ setFont:[UIFont systemFontOfSize:18]];
    [self.view addSubview:mpsView_];
    
    // set up calayer for drawing line
    self->line_layer = [CAShapeLayer layer];
    self->line_layer.opaque = YES;
    self->line_layer.lineWidth = 6.0f;
    [self->line_layer setFillColor:[[UIColor colorWithWhite:0 alpha:0] CGColor]];
    self->line_layer.lineCap = kCALineCapRound;
    self->line_layer.strokeColor = [[UIColor redColor] CGColor];
    self->line_layer.backgroundColor = [UIColor colorWithWhite:0.f alpha:0.3f].CGColor;
    [self.view.layer addSublayer:self->line_layer];
    path = [UIBezierPath bezierPath];
    
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
    //[self.view.layer addSublayer:self.previewLayer];
    
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
    [[output connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[self videoOrientationFromDeviceOrientation]];
    [session addOutput:output];
}

-(AVCaptureVideoOrientation)videoOrientationFromDeviceOrientation {
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    AVCaptureVideoOrientation result;
    if ( orientation == UIDeviceOrientationLandscapeLeft )
        result = AVCaptureVideoOrientationLandscapeRight;
    else result = AVCaptureVideoOrientationLandscapeLeft;
    return result;
}

- (void) configureInput {
    NSError *error = NULL;
    camera_device_input = [AVCaptureDeviceInput deviceInputWithDevice: camera_device error: &error];
    [session addInput:camera_device_input];
}
- (IBAction)reset_path:(id)sender {
    num_points = 0;
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
            if (range.maxFrameRate > bestFrameRateRange.maxFrameRate ) {
                bestFormat = format;
                bestFrameRateRange = range;
                cout << "Got best format " << range.maxFrameRate << "\n";
            }
        }
    }
    if (bestFormat) {
        if ([device lockForConfiguration:NULL] == YES) {
            // lock config
            cout << "using best format " << bestFrameRateRange.maxFrameRate << "\n";
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
    using namespace cv;

    Mat canny_output;
    vector<vector<cv::Point> > contours;
    vector<Vec4i> hierarchy;
    int thresh = 100;
    Mat thresholdMat;
    threshold( image, thresholdMat, thresh, 255, THRESH_BINARY );
    /// Find contours
    findContours( thresholdMat, contours, hierarchy, CV_RETR_TREE, CV_CHAIN_APPROX_SIMPLE, cv::Point(0, 0) );
    
    int max_radius = 0; int max_radius_index = 0;
    vector<vector<cv::Point> > contours_poly( contours.size() );
    vector<cv::Rect> boundRect( contours.size() );
    vector<Point2f>center( contours.size() );
    vector<float>radius( contours.size() );
    for( int i = 0; i< contours.size(); i++ ) // iterate through each contour.
    {
        approxPolyDP( Mat(contours[i]), contours_poly[i], 3, true );
        minEnclosingCircle( (Mat)contours_poly[i], center[i], radius[i] );
        if( radius[i] > max_radius )
        {
            max_radius = radius[i];
            max_radius_index = i;               //Store the index of largest contour
        }
    }
    
    if (contours.size() > 0) {
        double perimeter = cv::arcLength(contours[max_radius_index], true);
        double area = contourArea(contours[max_radius_index]);
        double roundness = CircularityStandard(area, perimeter);
        cout << roundness << "round\n";
        if (roundness < 2.0 && roundness > 0.4) {
            // good enough approx of a circle
            circle( image, center[max_radius_index], (int)radius[max_radius_index], Scalar(255,0,0), 2, 8, 0 );
            //cout << "Max radius is " << max_radius << "\n";
            if (max_radius < 400) {
                points[num_points] = center[max_radius_index];
                speed_count++;
                num_points++;
            } else {
                speed_count = 0;
            }
        }
    }
    // Finally estimate the frames per second (FPS)
    int64 next_time = getTickCount(); // Get the next time stamp
    int64 time_diff = next_time - curr_time_;
    float fps = (float)getTickFrequency()/(time_diff); // Estimate the fps
    if(speed_count > 0 && num_points > 2) {
        Point2f center1 = center[num_points-2];
        Point2f center2 = center[num_points-1];
        int distance = euclideanDist(center1.x, center2.x, center1.y, center2.y);
        cout << distance << "\n";
        float dist_mm = cv_points_to_mm(distance, radius[num_points-1]);
        cout << dist_mm << "\n";
        float speed = get_speed(dist_mm*1000, time_diff);
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSString *mps_NSStr = [NSString stringWithFormat:@"MPS = %2.2f", speed];
            mpsView_.text = mps_NSStr;
            NSLog(@"%@", mps_NSStr);
        });
    }
    curr_time_ = next_time; // Update the time
    NSString *fps_NSStr = [NSString stringWithFormat:@"FPS = %2.2f",fps];
    //NSLog(@"%@\n", fps_NSStr);
    // Have to do this so as to communicate with the main thread
    // to update the text display
    cv::Mat color;
    [self drawLines:image];
    cvtColor(image, color, CV_GRAY2RGB);
    UIImage *uiImage = [Helper UIImageFromCVMat:color];
    UIImage *finalImage = [[UIImage alloc] initWithCGImage: uiImage.CGImage
                                                     scale: 1.0
                                               orientation: UIImageOrientationRight];
    dispatch_sync(dispatch_get_main_queue(), ^{
        fpsView_.text = fps_NSStr;
        self->imageView.image = finalImage;
    });
}



- (void) drawLines:(cv::Mat &)image {
    if (num_points > 1) {
        for(size_t i = 1; i < num_points; i++) {
            cv::line(image, points[i-1], points[i], cvScalar(255,0,0), 3);
        }
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
