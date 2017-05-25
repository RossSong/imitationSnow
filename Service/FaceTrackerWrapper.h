//
//  FaceTrackerWrapper.h
//  TEST2
//
//  Created by RossSong on 2017. 5. 25..
//
//

#import <Foundation/Foundation.h>
#import "FaceTrackerProtocol.h"

@interface FaceTrackerWrapper : NSObject <FaceTrackerProtocol>
- (void)setup;
- (void)update:(cv::Mat &)frame;
- (vector<ofVec2f>)getImagePoints;
- (bool)getFound;
- (ofMesh)getImageMesh;
@end
