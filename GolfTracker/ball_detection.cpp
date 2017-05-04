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

float get_speed(float delta_mm, float elapsed_time) {
    // return the speed in mm / s
    return delta_mm / elapsed_time;
}

float cv_points_to_mm(float delta_points, float cv_radius) {
    // proportion between radius in mm and cv points
    float scale = cv_radius / GOLF_BALL_MILLI_RADIUS;
    return delta_points / scale;
}
