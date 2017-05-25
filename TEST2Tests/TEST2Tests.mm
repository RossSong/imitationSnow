//
//  TEST2Tests.m
//  TEST2Tests
//
//  Created by RossSong on 2017. 5. 23..
//
//

#import <XCTest/XCTest.h>
#import "TEST2Controller.h"

@interface MockVideoGrabberWrapper : NSObject <VideoGrabberProtocol>
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

@implementation MockVideoGrabberWrapper

- (void)setDeviceID:(int)deviceId {
    
}

- (void)setupWidth:(int)width withHeight:(int)height {
    
}

- (void)update {
    
}

- (cv::Mat)getFrame {
    Mat frame;
    return frame;
}

- (bool)isFrameNew {
    return NO;
}

- (void)drawMirror {
    
}

- (void)draw {
    
}

- (float)getWidth {
    return 0.0;
}

- (float)getHeight {
    return 0.0;
}

@end

@interface MockFaceTrackerWrapper : NSObject <FaceTrackerProtocol>

@property (assign, nonatomic) bool isSetupCalled;

- (void)setup;
- (void)update:(cv::Mat &)frame;
- (vector<ofVec2f>)getImagePoints;
- (bool)getFound;
- (ofMesh)getImageMesh;
@end

@implementation MockFaceTrackerWrapper
- (void)setup {
    self.isSetupCalled = YES;
}

- (void)update:(cv::Mat &)frame {
    
}

- (vector<ofVec2f>)getImagePoints {
    vector<ofVec2f> points;
    return points;
}

- (bool)getFound {
    return NO;
}

- (ofMesh)getImageMesh {
    ofMesh mesh;
    return mesh;
}

@end

@interface TEST2Tests : XCTestCase

@property (strong, nonatomic) TEST2Controller *controller;
@property (strong, nonatomic) MockFaceTrackerWrapper *maskTracker;
@property (strong, nonatomic) MockFaceTrackerWrapper *cameraTracker;

@end

@implementation TEST2Tests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.controller = [[TEST2Controller alloc] init];
    id<VideoGrabberProtocol> camera = [[MockVideoGrabberWrapper alloc] init];
    id<FaceTrackerProtocol> maskTracker = [[MockFaceTrackerWrapper alloc] init];
    id<FaceTrackerProtocol> cameraTracker = [[MockFaceTrackerWrapper alloc] init];
    
    self.maskTracker = (MockFaceTrackerWrapper*)maskTracker;
    self.cameraTracker = (MockFaceTrackerWrapper*)cameraTracker;
    
    [self.controller setupCamera:camera];
    [self.controller setFaceTrackersWithMaskFaceTracker:maskTracker
                                  withCameraFaceTracker:cameraTracker];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    self.controller = nil;
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

- (void)testSetup {
    [self.controller setup];
    XCTAssert(self.maskTracker.isSetupCalled);
    XCTAssert(self.cameraTracker.isSetupCalled);
    XCTAssert(FRONT_CAM == self.controller.cameraId);
}

- (void)testSetupArrayEffects {
    [self.controller setupArrayEffects];
    XCTAssert(8 == self.controller.arrayEffects.count);
    
    NSString *string = self.controller.arrayEffects[0];
    XCTAssert([string isEqualToString:@"moon.jpg"]);
    
    string = self.controller.arrayEffects[1];
    XCTAssert([string isEqualToString:@"Ahn.jpg"]);
    
    string = self.controller.arrayEffects[2];
    XCTAssert([string isEqualToString:@"DonaldTrump.jpeg"]);
    
    string = self.controller.arrayEffects[3];
    XCTAssert([string isEqualToString:@"joker.jpg"]);
    
    string = self.controller.arrayEffects[4];
    XCTAssert([string isEqualToString:@"Abe.jpeg"]);
    
    string = self.controller.arrayEffects[5];
    XCTAssert([string isEqualToString:@"young_moon.jpeg"]);
    
    string = self.controller.arrayEffects[6];
    XCTAssert([string isEqualToString:@"test.jpg"]);
    
    string = self.controller.arrayEffects[7];
    XCTAssert([string isEqualToString:@"jung.png"]);
}

@end
