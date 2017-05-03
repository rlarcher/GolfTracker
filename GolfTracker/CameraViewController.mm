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
}

@end

@implementation CameraViewController

const cv::Scalar RED = cv::Scalar(255, 0, 0);
const float GOLF_BALL_MILLI_RADIUS = 21.3;

using namespace std;

- (void)viewDidLoad {
    [super viewDidLoad];
    num_points = 1;
    
    
    session = [[AVCaptureSession alloc] init];
    [session setSessionPreset:AVCaptureSessionPresetHigh];
    
    imageView_ = [[UIImageView alloc] init];
    CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - 100);
    imageView_.frame = frame;
    [self.view addSubview:imageView_];
    
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
    }
    
    
    
    //[session startRunning];
    [self startCapturingWithSession:session];
}

- (void)startCapturingWithSession: (AVCaptureSession *) captureSession
{
    NSLog(@"Adding video preview layer");
    [self setPreviewLayer:[[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession]];
    
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    
    //----- DISPLAY THE PREVIEW LAYER -----
    //Display it full screen under out view controller existing controls
    NSLog(@"Display the preview layer");
    CGRect layerRect = [[[self view] layer] bounds];
    [self.previewLayer setBounds:layerRect];
    [self.previewLayer setPosition:CGPointMake(CGRectGetMidX(layerRect),
                                               CGRectGetMidY(layerRect))];
    
    //[self.view.layer addSublayer:self.previewLayer];
    
    
    //----- START THE CAPTURE SESSION RUNNING -----
    [captureSession startRunning];
}

- (void) configureOutput {
    // create camera output
    output = [[AVCaptureVideoDataOutput alloc] init];
    
    output.videoSettings = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey: (id)kCVPixelBufferPixelFormatTypeKey];
    
    // set output delegate to self
    dispatch_queue_t queue = dispatch_queue_create("output_queue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    [session addOutput:output];
}

- (void) configureInput {
    NSError *error = NULL;
    camera_device_input = [AVCaptureDeviceInput deviceInputWithDevice: camera_device error: &error];
    [session addInput:camera_device_input];
}
- (IBAction)reset_path:(id)sender {
    num_points = 1;
    [session stopRunning];
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
            }
        }
    }
    if (bestFormat) {
        if ([device lockForConfiguration:NULL] == YES) {
            // lock config
            device.activeFormat = bestFormat;
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
- (cv::Mat&) processImage:(cv:: Mat &)image
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
        cout << "drawing line\n";
        cv::Point start = points[i];
        cv::Point end = points[i+1];
        cv::line(image, start, end, Scalar(0,0,255), 2);
    }
    return image;
}


- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
    (void)captureOutput;
    (void)connection;
    using namespace std;
    cout << "capturing output\n";
        cout << "processing image\n";
        // convert from Core Media to Core Video
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        
        void* bufferAddress;
        size_t width;
        size_t height;
        size_t bytesPerRow;
        
        CGColorSpaceRef colorSpace;
        CGContextRef context;
        
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
        
        CGImage* dstImage;
        
        image = [self processImage:image];
        
        // check if matrix data pointer or dimensions were changed by the delegate
        bool iOSimage = false;
        if (height == (size_t)image.rows && width == (size_t)image.cols && format_opencv == image.type() && bufferAddress == image.data && bytesPerRow == image.step) {
            iOSimage = true;
        }
        
        
        // (create color space, create graphics context, render buffer)
        CGBitmapInfo bitmapInfo;
        
        // basically we decide if it's a grayscale, rgb or rgba image
        if (image.channels() == 1) {
            colorSpace = CGColorSpaceCreateDeviceGray();
            bitmapInfo = kCGImageAlphaNone;
        } else if (image.channels() == 3) {
            colorSpace = CGColorSpaceCreateDeviceRGB();
            bitmapInfo = kCGImageAlphaNone;
            if (iOSimage) {
                bitmapInfo |= kCGBitmapByteOrder32Little;
            } else {
                bitmapInfo |= kCGBitmapByteOrder32Big;
            }
        } else {
            colorSpace = CGColorSpaceCreateDeviceRGB();
            bitmapInfo = kCGImageAlphaPremultipliedFirst;
            if (iOSimage) {
                bitmapInfo |= kCGBitmapByteOrder32Little;
            } else {
                bitmapInfo |= kCGBitmapByteOrder32Big;
            }
        }
        
        if (iOSimage) {
            context = CGBitmapContextCreate(bufferAddress, width, height, 8, bytesPerRow, colorSpace, bitmapInfo);
            dstImage = CGBitmapContextCreateImage(context);
            CGContextRelease(context);
        } else {
            
            NSData *data = [NSData dataWithBytes:image.data length:image.elemSize()*image.total()];
            CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
            
            // Creating CGImage from cv::Mat
            dstImage = CGImageCreate(image.cols,                                 // width
                                     image.rows,                                 // height
                                     8,                                          // bits per component
                                     8 * image.elemSize(),                       // bits per pixel
                                     image.step,                                 // bytesPerRow
                                     colorSpace,                                 // colorspace
                                     bitmapInfo,                                 // bitmap info
                                     provider,                                   // CGDataProviderRef
                                     NULL,                                       // decode
                                     false,                                      // should interpolate
                                     kCGRenderingIntentDefault                   // intent
                                     );
            
            CGDataProviderRelease(provider);
        }
        
        
        // render buffer
        dispatch_sync(dispatch_get_main_queue(), ^{
            cout << "Setting image to modified mat\n";
            UIImage *newImage = [UIImage imageWithCGImage:dstImage];
            imageView_.image = newImage;
        });
        
        
        // cleanup
        CGImageRelease(dstImage);
        
        CGColorSpaceRelease(colorSpace);
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);

}

@end
