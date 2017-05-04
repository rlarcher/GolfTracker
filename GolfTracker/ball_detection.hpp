//
//  ball_detection.hpp
//  GolfTracker
//
//  Created by Ryan Archer on 4/8/17.
//  Copyright © 2017 CMU_16623. All rights reserved.
//

#ifndef ball_detection_hpp
#define ball_detection_hpp

#include <stdio.h>

float cv_points_to_mm(float delta_points, float cv_radius);
float get_speed(float delta_mm, float elapsed_time);


#endif /* ball_detection_hpp */
