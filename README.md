Ryan Archer 16-423 Final Project 

Title: Mobile Golf Tracker

Team Members: Ryan Archer

REPO UPDATED 5/11/2017, see below for changes since checkpoint
UPDATED YOUTUBE LINK AS OF 5/10/2017: https://www.youtube.com/watch?v=RQlZfZvCeOA

Summary: This project seeks to produce a mobile version of the Golf Pro Tracker often seen on television broadcasts of PGA tournaments, while adding other forms of analysis into the golf swing. The application’s main feature will be to draw a line representing the trajectory of the golf ball after impact. Other features may include analyzing launch angle, swing speed, or ball speed after impact. For an example of what the Pro Tracker looks like, refer to the following link: https://www.youtube.com/watch?v=X9epYdKPJUk. 

Background: 
The Challenge: One of the challenges here is the high speed involved with ball flight. The app will need to take advantage of the iOS high speed camera to follow the flight of the ball and the swinging of the club. There are also some computer vision techniques that are not unique to mobile phones, such as OpenCV feature detection, which I will use to detect the golf ball. 

Goals and Deliverables: The piece of the application that can detect ball flight and draw the trajectory of the ball is essential for the project to be a success. The other pieces, such as displaying launch angles or ball speed will only be accomplished if I am ahead of schedule. To validate a successful product, I will need to provide a video where one can clearly see the line being drawn over the flight of the ball. For things like swing speed, results from a traditional radar gun (not on a mobile phone) could be compared to what my app produces. Producing the minimum requirements for a successful project should be feasible, as it really just involves being able to detect the ball and access the high speed camera. The more complicated parts could be the physics of determining speed of the club and ball. 

The Challenge: The real product here is bringing something that exists for professionals to the mobile phone. I have seen some similar apps that measure baseball swing statistics, but there are not as many apps to analyze the golf swing. I am hoping to learn about the high speed camera that is available on our iOS devices and how they can be used for computer vision. I have made mobile apps in the past, but never specifically for computer vision, so I am also hoping to discover what extra challenges in computer vision are added by the limitations of a mobile device. In addition to the challenges of the camera, there is also an aspect of image recognition because the ball and golf club must be identified in order to perform the computations. While detecting the ball could be done using some existing OpenCV functions, combining these detections from numerous frames to find trajectory could pose a challenge. My limited physics knowledge will also be tested when I implement the statistics involving speed and launch angles. 

Updated Schedule
April 12: Finish ball path accumulation
April 16: Finish and test line drawing on replayed golf shot video
Apirl 21: Research physics involved with ball speed detection
April 25: Finish work on detecting ball speed
Apirl 30: Test speed analytics and touch up any remaining problems
May 4: Youtube clip showcasing ball tracing and ball speed detection

Since Checkpoint
Created another UIImageView, so that the user can see the real image and the threshold image.
Speed Detection.
Switched to AVCaptureSession instead of CVVideoCamera for better performance. 
Switched to findContours for better detection.
Updated Youtube video after presentation.
Added image into repo called app.png that shows the app in progress. 
