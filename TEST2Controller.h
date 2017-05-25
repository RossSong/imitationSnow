//
//  TEST2Controller.h
//  TEST2
//
//  Created by RossSong on 2017. 5. 23..
//
//

#include "ofxFaceTracker.h"
#import <opencv2/opencv.hpp>
#import "opencv2/highgui/ios.h"
#include "ofxiOSExtras.h"
#include "Clone.h"
#include "AVAsset+VideoOrientation.h"
#import "EffectCollectionViewCell.h"
#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <Photos/Photos.h>
#import <QuartzCore/QuartzCore.h>
#import <GLKit/GLKit.h>
#import "FaceTrackerWrapper.h"
#import "VideoGrabberWrapper.h"


#define BACK_CAM   0
#define FRONT_CAM  1

#define FRAME_PER_SECOND_FOR_SAVE 20

using namespace cv;

@protocol TargetViewControllerDelegate
- (void)backgroundColorChanged:(UIColor*)color;
- (void)setImageViewImage:(UIImage *)image;
- (void)hideGLKView;
- (void)showGLKView;
- (void)glkViewDisplay;
- (UIImage *)getImageViewImage;
@end

@interface TEST2Controller : NSObject

@property (strong, nonatomic) id<FaceTrackerProtocol> cameraFaceTracker;
@property (strong, nonatomic) id<FaceTrackerProtocol> maskFaceTracker;
@property (strong, nonatomic) id<VideoGrabberProtocol> cam;

@property (retain, nonatomic) id<TargetViewControllerDelegate> targetDelegate;
@property (strong, nonatomic) NSTimer *animationTimer;
@property (strong, nonatomic) NSArray *arrayEffects;
@property (assign, nonatomic) BOOL isRecording;
@property (strong, nonatomic) AVAssetWriter *videoWriter;
@property (strong, nonatomic) AVAssetWriterInput* writerInput;
@property (strong, nonatomic) AVAssetWriterInputPixelBufferAdaptor *adaptor;
@property (assign, nonatomic) NSInteger frameIndex;
@property (assign, nonatomic) int cameraId;
@property (strong, nonatomic) AVAsset *avasset;
@property (assign, nonatomic) int counter;
@property (assign, nonatomic) Float64 durationSeconds;
@property (assign, nonatomic) Float64 totalFrames;
@property (assign, nonatomic) Float64 timePerFrame;
@property (strong, nonatomic) AVAssetImageGenerator *imageGenerator;
@property (assign, nonatomic) BOOL usingLocalFile;
@property (assign, nonatomic) float framePerSecond;

- (void)setup;
- (void)setupArrayEffects;
- (void)readMP4IfUsingLocalFile;
- (void)setupMaskFraceTracker:(NSString *)stringFileName;
- (void)stopTimer;
- (void)switchCamera;
- (void)toggleButtonVideoRecord;
- (void)drawGLKView:(GLKView *)view drawInRect:(CGRect)rect;
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info;

@end
