//
//  VideoGrabberProtocol.h
//  TEST2
//
//  Created by RossSong on 2017. 5. 25..
//
//

#ifndef VideoGrabberProtocol_h
#define VideoGrabberProtocol_h

#import <opencv2/opencv.hpp>
#import "opencv2/highgui/ios.h"
#include "ofxFaceTracker.h"

@protocol VideoGrabberProtocol <NSObject>
- (void)setDeviceID:(int)deviceId;
- (void)setupWidth:(int)width withHeight:(int)height;
- (void)update;
- (cv::Mat)getFrame;
- (bool)isFrameNew;
- (void)drawMirror;
- (void)draw;
- (int)getWidth;
- (int)getHeight;
@end

#endif /* VideoGrabberProtocol_h */
