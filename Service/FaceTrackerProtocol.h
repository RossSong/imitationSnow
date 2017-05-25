//
//  FaceTrackerProtocol.h
//  TEST2
//
//  Created by RossSong on 2017. 5. 25..
//
//

#ifndef FaceTrackerProtocol_h
#define FaceTrackerProtocol_h

#import <vector>
#import <opencv2/opencv.hpp>
#include "ofxFaceTracker.h"

@protocol FaceTrackerProtocol <NSObject>
- (void)setup;
- (void)update:(cv::Mat &)frame;
- (vector<ofVec2f>)getImagePoints;
- (bool)getFound;
- (ofMesh)getImageMesh;
@end

#endif /* FaceTrackerProtocol_h */
