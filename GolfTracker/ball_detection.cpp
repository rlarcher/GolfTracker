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

const float GOLF_BALL_MILLI_RADIUS = 21.3;

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

float get_speed(float delta_mm, float elapsed_time) {
    // return the speed in mm / s
    return delta_mm / elapsed_time;
}

float cv_points_to_mm(float delta_points, float cv_radius) {
    // proportion between radius in mm and cv points
    float scale = cv_radius / GOLF_BALL_MILLI_RADIUS;
    return delta_points * scale;
}
