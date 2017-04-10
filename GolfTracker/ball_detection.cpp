//
//  ball_detection.cpp
//  GolfTracker
//
//  Created by Ryan Archer on 4/8/17.
//  Copyright © 2017 CMU_16623. All rights reserved.
//

#include "ball_detection.hpp"
#include <opencv2/opencv.hpp> // Includes the opencv library
#include "opencv2/features2d/features2d.hpp"
#include "opencv2/nonfree/features2d.hpp"

using namespace cv;

void detect_golf_ball(Mat &image, vector<Vec3f> &circleVector, int currentSize) {
    // take in the image from the camera
    Mat gray;
    cvtColor(image, gray, CV_RGB2BGR);
    GaussianBlur(gray, gray, Size(9,9), 3.0);
    vector<Vec3f> circles;
    // give a large value for min dist since we only detect one circle
    HoughCircles(gray, circles, CV_HOUGH_GRADIENT, 1, 100);
    // add the circle to the vector
    if (circles.size() > 0) {
        circleVector[currentSize] = circles[0];
    }
}
