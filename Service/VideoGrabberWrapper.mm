//
//  VideoGrabberWrapper.m
//  TEST2
//
//  Created by RossSong on 2017. 5. 25..
//
//

#import "VideoGrabberWrapper.h"

@interface VideoGrabberWrapper () {
    ofVideoGrabber  cam;
}
@end

@implementation VideoGrabberWrapper

- (void)setDeviceID:(int)deviceId {
    cam.setDeviceID(deviceId);
}

- (void)setupWidth:(int)width withHeight:(int)height {
    cam.setup(width, height);
}

- (void)update {
    cam.update();
}

- (cv::Mat)getFrame {
    return ofxCv::toCv(cam);
}

- (bool)isFrameNew {
    return cam.isFrameNew();
}

- (void)drawMirror {
    cam.draw(cam.getWidth(),0,-cam.getWidth(),cam.getHeight());
}

- (void)draw {
    cam.draw(0, 0);
}

- (int)getWidth {
    return cam.getWidth();
}

- (int)getHeight {
    return cam.getHeight();
}

@end
