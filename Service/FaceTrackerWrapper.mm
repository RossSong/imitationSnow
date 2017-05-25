//
//  FaceTrackerWrapper.m
//  TEST2
//
//  Created by RossSong on 2017. 5. 25..
//
//

#import "FaceTrackerWrapper.h"

@interface FaceTrackerWrapper () {
    ofxFaceTracker faceTracker;
}
@end

@implementation FaceTrackerWrapper

- (void)setup {
    faceTracker.setup();
}

- (void)update:(cv::Mat &)frame {
    faceTracker.update(frame);
}

- (vector<ofVec2f>)getImagePoints {
    return faceTracker.getImagePoints();
}

- (bool)getFound {
    return faceTracker.getFound();
}

- (ofMesh)getImageMesh {
    return faceTracker.getImageMesh();
}

@end
