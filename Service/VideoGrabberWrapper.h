//
//  VideoGrabberWrapper.h
//  TEST2
//
//  Created by RossSong on 2017. 5. 25..
//
//

#import <Foundation/Foundation.h>
#import "VideoGrabberProtocol.h"

@interface VideoGrabberWrapper : NSObject <VideoGrabberProtocol>
- (void)setDeviceID:(int)deviceId;
- (void)setupWidth:(int)width withHeight:(int)height;
- (void)update;
- (cv::Mat)getFrame;
- (bool)isFrameNew;
- (void)drawMirror;
- (void)draw;
- (float)getWidth;
- (float)getHeight;
@end
