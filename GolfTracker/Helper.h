//
//  Helper.h
//  GolfTracker
//
//  Created by Ryan Archer on 5/2/17.
//  Copyright © 2017 CMU_16623. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <opencv2/highgui/ios.h>

@interface Helper : NSObject

// this is necessary to convert to opencv format
// method used from https://mkonrad.net/2014/06/24/cvvideocamera-vs-native-ios-camera-apis.html
+ (void)convertYUVSampleBuffer:(CMSampleBufferRef)buf toGrayscaleMat:(cv::Mat &)mat;

@end
