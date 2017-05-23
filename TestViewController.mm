//
//  TestViewController.m
//  TEST2
//
//  Created by RossSong on 2017. 5. 4..
//
//

#import "TestViewController.h"
#include "ofxFaceTracker.h"
#import <opencv2/opencv.hpp>
#import "opencv2/highgui/ios.h"
#import <GLKit/GLKit.h>
#include "ofxiOSExtras.h"
#include "Clone.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <Photos/Photos.h>
#import <QuartzCore/QuartzCore.h>
#include "AVAsset+VideoOrientation.h"
#import "EffectCollectionViewCell.h"

#define BACK_CAM   0
#define FRONT_CAM  1

#define FRAME_PER_SECOND_FOR_SAVE 20

using namespace cv;

@interface TestViewController () <GLKViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource>
{
    VideoCapture    cap;
    ofVideoGrabber  cam;
    ofVideoGrabber  cam2;
    ofxFaceTracker  cameraFaceTracker;
    ofxFaceTracker  maskFaceTracker;
    
    ofImage         maskImage;
    vector<ofVec2f> maskPoints;
    
    ofFbo           cameraFbo;
    ofFbo           maskFbo;
   
    Clone           clone;
    bool            cloneReady;
    
    ofImage         maskedImage;
    
    ofTrueTypeFont  font;
    ofMesh          originalTitleMesh, titleMesh, cameraMesh;
    ofxFaceTracker  titleFaceTracker;
    
    Mat             currentFrame;
}
@property (strong, nonatomic) NSTimer *animationTimer;
@property (retain, nonatomic) IBOutlet UIImageView *imageView;
@property (retain, nonatomic) IBOutlet GLKView *glkView;
@property (assign, nonatomic) BOOL usingLocalFile;
@property (assign, nonatomic) float framePerSecond;

@property (retain, nonatomic) IBOutlet UIButton *buttonVideoRecord;
@property (assign, nonatomic) int cameraId;
@property (strong, nonatomic) AVAsset *avasset;
@property (assign, nonatomic) int counter;
@property (assign, nonatomic) Float64 durationSeconds;
@property (assign, nonatomic) Float64 totalFrames;
@property (assign, nonatomic) Float64 timePerFrame;
@property (strong, nonatomic) AVAssetImageGenerator *imageGenerator;
@property (strong, nonatomic) IBOutlet UIView *viewContainerForViewSelection;
@property (retain, nonatomic) IBOutlet UIView *viewSelection;
@property (retain, nonatomic) IBOutlet UICollectionView *collectionView;
@property (strong, nonatomic) NSArray *arrayEffects;
@property (assign, nonatomic) BOOL isRecording;
@property (strong, nonatomic) AVAssetWriter *videoWriter;
@property (strong, nonatomic) AVAssetWriterInput* writerInput;
@property (strong, nonatomic) AVAssetWriterInputPixelBufferAdaptor *adaptor;
@property (assign, nonatomic) NSInteger frameIndex;
@property (strong, nonatomic) UIView *tooltipView;
@end

@implementation TestViewController

- (void)setupGLKView {
    self.glkView.delegate = self;
    self.glkView.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    [self.glkView setOpaque:NO];
    self.glkView.context = [EAGLContext currentContext];
}

- (void)setupCamera {
    self.cameraId = 1;
    cam.setDeviceID(1); // front camera - 1
    cam.setup(ofGetWidth(), ofGetHeight());
}

- (void)setupFaceTrackers {
    maskFaceTracker.setup();
    cameraFaceTracker.setup();
}

- (void)setupButtonVideoRecord {
    self.buttonVideoRecord.layer.cornerRadius = self.buttonVideoRecord.frame.size.width /2.0;
    self.buttonVideoRecord.clipsToBounds = YES;
    self.buttonVideoRecord.backgroundColor = [self colorWithRGBHex:0x3AA5DC];
}

- (void)setupCollectionView {
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;

    UINib* nib = [UINib nibWithNibName:@"EffectCollectionViewCell" bundle:nil];
    [self.collectionView registerNib:nib forCellWithReuseIdentifier:@"EffectCollectionViewCell"];
    
    [self.collectionView reloadData];
}

- (void)setupArrayEffects {
    self.arrayEffects = @[@"moon.jpg", @"Ahn.jpg", @"DonaldTrump.jpeg", @"joker.jpg", @"Abe.jpeg", @"young_moon.jpeg", @"test.jpg", @"jung.png"];
}

- (void)setupTooltip {
    [self showToolTip:self.buttonVideoRecord];
}

- (void)setupDefaultMask {
    [self setupMaskFraceTracker:self.arrayEffects[7]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupFaceTrackers];
    [self setupCamera];
    [self setupGLKView];
    [self setupTimer];
    [self setupButtonVideoRecord];
    [self setupArrayEffects];
    [self setupCollectionView];
    [self setupTooltip];
    [self setupDefaultMask];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if(self.usingLocalFile) {
        [self readMP4];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

- (void)updateFace {
    ofImage img;
    //img.setFromPixels(cam.getPixels());
    ofxCv::toOf(currentFrame, img);
    [self maskTakenPhoto:img];
}

- (void)drawFace {
    if(maskImage.getWidth() > 0){
        maskFaceTracker.update(ofxCv::toCv(maskImage));
        maskPoints = maskFaceTracker.getImagePoints();
        if(!maskFaceTracker.getFound()){
            NSLog(@"please select good mask image.");
        }
        else {
            [self updateFace];
        }
    }
    else {
        //cameraFaceTracker.draw();
    }
}

- (void)setupMovieInfo {
    ////
    NSArray *movieTracks = [self.avasset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *movieTrack = [movieTracks objectAtIndex:0];
    
    //Make the image Generator
    self.imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:self.avasset];
    self.imageGenerator.appliesPreferredTrackTransform = YES;
    
    //Create a variables for the time estimation
    self.durationSeconds = CMTimeGetSeconds(self.avasset.duration);
    self.framePerSecond = movieTrack.nominalFrameRate;
    self.timePerFrame = 1.0 / (Float64)movieTrack.nominalFrameRate;
    self.totalFrames = self.durationSeconds * movieTrack.nominalFrameRate;
    self.counter = 0;
    [self stopTimer];
    [self setupTimer];
}

- (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

- (void) updateImageFromVideo{
    UIImage* uiImage = nil;
    CMTime actualTime;
    Float64 secondsIn = ((float)self.counter/self.totalFrames)*self.durationSeconds;
    CMTime imageTimeEstimate = CMTimeMakeWithSeconds(secondsIn, 600);
    NSError *error;
    CGImageRef image = [self.imageGenerator copyCGImageAtTime:imageTimeEstimate actualTime:&actualTime error:&error];
    uiImage = [UIImage imageWithCGImage:image];
    CGImageRelease(image);
    self.counter = self.counter + 1;
    
    currentFrame = [self cvMatFromUIImage:uiImage];
    self.imageView.image = uiImage;
}

- (void)updateCap {
    
    //Step through the frames
    if(self.counter < self.totalFrames) {
        [self updateImageFromVideo];
    }
    else {
        [self stopTimer];
        return;
    }
}

- (void)updateButtonVideoRecord {
    self.counter = self.counter + 1;
    if(self.counter % 5) {
        self.buttonVideoRecord.backgroundColor = [UIColor redColor];
    }
    else {
        self.buttonVideoRecord.backgroundColor = [self colorWithRGBHex:0xE9650A];
    }
}

- (void)updateCam {
    cam.update();
    Mat frame = ofxCv::toCv(cam);
    
    if(self.isRecording){
        [self updateButtonVideoRecord];
    }
    
    if(BACK_CAM == self.cameraId) {
        //mirror
        cv::flip(frame, frame, 1);
    }
    
    if(cam.isFrameNew()) {
        cameraFaceTracker.update(frame);
    }
}

- (void)draw {
    if(self.usingLocalFile) {
        [self updateCap];
    }
    else {
        [self updateCam];
    }
    
    [self.glkView display];
}

- (void)setupTimer {
    int animationFrameInterval = 1;
    float fps = 60.0;
    
    if(self.framePerSecond) {
        fps = self.framePerSecond;
    }
    
    self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)((1.0 / fps) * animationFrameInterval)
                                                           target:self
                                                         selector:@selector(draw)
                                                         userInfo:nil
                                                          repeats:TRUE];
}

- (void)stopTimer {
    [self.animationTimer invalidate];
    self.animationTimer = nil;
}

- (void)resetTimer {
    [self stopTimer];
    [self setupTimer];
}

- (void)drawCam {
    if(BACK_CAM == self.cameraId) {
        cam.draw(cam.getWidth(),0,-cam.getWidth(),cam.getHeight());
    }
    else {
        cam.draw(0, 0);
    }
}

- (void)drawFaceMesh {
    cameraMesh = cameraFaceTracker.getImageMesh();
    if(cameraMesh.getVertices().size() > 0) {
        cameraMesh.clearTexCoords();
        cameraMesh.addTexCoords(maskPoints);
        for(int i=0; i< cameraMesh.getTexCoords().size(); i++) {
            ofVec2f & texCoord = cameraMesh.getTexCoords()[i];
            texCoord.x /= ofNextPow2(maskImage.getWidth());
            texCoord.y /= ofNextPow2(maskImage.getHeight());
        }
        
        maskImage.bind();
        cameraMesh.draw();
    }
}

- (void)setupCoordinateSystem{
    ofTranslate(ofGetWidth(), 0);
    ofScale(-1, 1);
    
    float scaleW = ofGetWidth() / cam.getWidth();
    float scaleH = ofGetHeight() / cam.getHeight();
    ofScale(scaleW, scaleH);
}

- (float)getVideoWidthWithScale:(CGFloat)scale withDownSampling:(CGFloat)downsampling withIsWidth:(BOOL)isWidth {
    float size = ofGetHeight();
    if(isWidth) {
        size = ofGetWidth();
    }
    
    return scale * size / downsampling;
}

- (CGFloat)getDownSamplingWithScale:(CGFloat)scale {
    if(3.0 == scale) {
        return 1.15;
    }
    
    return 1;
}

- (UIImage *)getCapturedImageWithSize:(CGSize)imageSize {
    int bitsPerComponent = 8;
    int bitsPerPixel = 32;
    int bytesPerRow = 4 * imageSize.width;
    NSUInteger length = imageSize.width * imageSize.height * 4;
    
    GLubyte * buffer = (GLubyte *)malloc(length * sizeof(GLubyte));
    
    if(NULL == buffer) {
        return nil;
    }
    
    glReadPixels(0, 0, imageSize.width, imageSize.height, GL_RGBA, GL_UNSIGNED_BYTE, buffer);
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer, length, NULL);
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    CGImageRef imageRef = CGImageCreate(imageSize.width, imageSize.height, bitsPerComponent,
                                        bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo,
                                        provider, NULL, NO, renderingIntent);
    
    UIGraphicsBeginImageContext(imageSize);
    CGContextDrawImage(UIGraphicsGetCurrentContext(), CGRectMake(0.0, 0.0, imageSize.width, imageSize.height), imageRef);
    UIImage * image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CGImageRelease(imageRef);
    CGColorSpaceRelease(colorSpaceRef);
    CGDataProviderRelease(provider);
    
    free(buffer);
    
    //UIImageWriteToSavedPhotosAlbum(image, self, nil, nil); //for test
    
    return image;
}

- (CMTime)getPresentTime {
    self.frameIndex = self.frameIndex + 1;
    CMTime frameTime = CMTimeMake(0, FRAME_PER_SECOND_FOR_SAVE);
    CMTime lastTime = CMTimeMake(self.frameIndex, FRAME_PER_SECOND_FOR_SAVE);
    CMTime presentTime= CMTimeAdd(lastTime, frameTime);
    
    return presentTime;
}

- (void)captureScreen {
    if(NO == self.isRecording){
        return;
    }
    
    UIImage *image = nil;
    
    if(self.usingLocalFile) {
        image = self.imageView.image;
    }
    else {
        float imageWidth = [self getVideoImageWidth];
        float imageHeight =  [self getVideoImageHeight];
        CGSize imageSize = CGSizeMake(imageWidth, imageHeight);
        image = [self getCapturedImageWithSize:imageSize];
    }
    
    CMTime presentTime= [self getPresentTime];
    CVPixelBufferRef sampleBuffer = [self pixelBufferFromCGImage:image.CGImage];
    [self.adaptor appendPixelBuffer:sampleBuffer withPresentationTime:presentTime];
    CVPixelBufferRelease(sampleBuffer);
}

- (CVPixelBufferRef)getPixelBufferRefWithSize:(CGSize)imageSize {
    CVPixelBufferRef pxbuffer = NULL;
    NSDictionary *options = @{(id)kCVPixelBufferCGImageCompatibilityKey: @YES,
                              (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES};
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          imageSize.width, imageSize.height,
                                          kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    return pxbuffer;
}

- (CGContextRef)getCGContextRefWithPixelBuffer:(CVPixelBufferRef)pxbuffer
                             withColorSapceRef:(CGColorSpaceRef)rgbColorSpace
                                 withImageSize:(CGSize)imageSize{
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    size_t bytePerRow = CVPixelBufferGetBytesPerRow(pxbuffer);
    CGContextRef context = CGBitmapContextCreate(pxdata,
                                                 imageSize.width, imageSize.height,
                                                 8, bytePerRow, rgbColorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    return context;
}

- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image {
    
    CGSize imageSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
    CVPixelBufferRef pxbuffer = [self getPixelBufferRefWithSize:imageSize];
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = [self getCGContextRefWithPixelBuffer:pxbuffer withColorSapceRef:rgbColorSpace withImageSize:imageSize];
    
    CGContextDrawImage(context, CGRectMake(0, 0, imageSize.width, imageSize.height), image);
    
    CGContextRelease(context);
    CGColorSpaceRelease(rgbColorSpace);
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

- (void)drawCamAndFaceMesh {
    [self setupCoordinateSystem];
    [self drawCam];
    [self drawFaceMesh];
    [self captureScreen];
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    if(self.usingLocalFile) {
        self.glkView.hidden = YES;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self drawFace];
            [self captureScreen];
        });
    }
    else {
        [self drawCamAndFaceMesh];
    }
}

- (void)dealloc {
    //주의: OpenFramework 의 Proeject Generator 로 프로젝트를 자동으로 생성하면 ARC 를 사용하지 않도록 설정되어 있어서
    //dealloc 처리를 따로 해줘야 함. (ARC를 쓰지 않음.)
    [self stopTimer];
    
    [_imageView release];
    [_glkView release];
    [_buttonVideoRecord release];
    [_viewContainerForViewSelection release];
    [_viewSelection release];
    [_collectionView release];
    [super dealloc];
}

- (void)clearAndReload:(NSString *)stringFileName {
    if(maskImage.isAllocated()) {
        maskImage.clear();
    }
    
    if(maskPoints.size() > 0) {
        maskPoints.clear();
    }
    
    maskImage.load([stringFileName UTF8String]);
}

- (void)updateMaskTakenPhoto {
    if(NO == maskFaceTracker.getFound()) {
        return;
    }
    
    if(NO == cap.isOpened()) {
        return;
    }
    
    ofImage img;
    ofxCv::toOf(currentFrame, img);
    [self maskTakenPhoto:img];
}

- (void)setupMaskFraceTracker:(NSString *)stringFileName {
    // setup maskFaceTracker
    [self clearAndReload:stringFileName];
    
    if(maskImage.getWidth() > 0){
        int count = 0;
        do {
            maskFaceTracker.update(ofxCv::toCv(maskImage));
            maskPoints = maskFaceTracker.getImagePoints();
            count++;
        } while (!maskFaceTracker.getFound() && count < 3);
        
        [self updateMaskTakenPhoto];
    }
}

-(void)setupImageType:(ofImage &)image {
    // change image type. OF_IMAGE_COLOR_ALPHA => OF_IMAGE_COLOR
    if(image.getImageType() == OF_IMAGE_COLOR_ALPHA){
        image.setImageType(OF_IMAGE_COLOR);
    }
}

- (void)resizeImage:(ofImage &)image {
    // resize input image.
    if(image.getWidth() > image.getHeight()){
        image.resize(ofGetWidth(), image.getHeight()*ofGetWidth() /image.getWidth());
    }
    else{
        image.resize(image.getWidth()*ofGetHeight()/image.getHeight(), ofGetHeight());
    }
}

- (void)setupMaskFBOWithImage:(ofImage)image {
    ofFbo::Settings settings;
    settings.width = image.getWidth();
    settings.height= image.getHeight();
    maskFbo.allocate(settings);
    cameraFbo.allocate(settings);
}

- (void)checkReadyToMorphWithImage:(ofImage)image {
    if(0 == image.getWidth() || 0 == image.getHeight()) {
        return;
    }
    
    //Clone library is responsbile for merging the Mask with the Input
    clone.setup(image.getWidth(), image.getHeight());
    cameraFaceTracker.update(ofxCv::toCv(image));
    cloneReady = cameraFaceTracker.getFound(); //yes if FaceTracker could identify a face from our input
}

-(void)maskTakenPhoto:(ofImage &)image {
    //Input variable refers to our "just taken photo, your face, from the camera"
    [self setupImageType:image];
    [self resizeImage:image];
    [self setupMaskFBOWithImage:image];
    [self checkReadyToMorphWithImage:image];
    [self drawMaskOnInput:image];
}

- (void)updateCameraMeshAndTexture {
    cameraMesh = cameraFaceTracker.getImageMesh();
    cameraMesh.clearTexCoords();
    cameraMesh.addTexCoords(maskPoints);
    for(int i=0; i< cameraMesh.getTexCoords().size(); i++) {
        ofVec2f & texCoord = cameraMesh.getTexCoords()[i];
        texCoord.x /= ofNextPow2(maskImage.getWidth());
        texCoord.y /= ofNextPow2(maskImage.getHeight());
    }
}

- (void)drawCameraMeshWithMaskFBO {
    maskFbo.begin();
    ofClear(0, 255);
    cameraMesh.draw();
    maskFbo.end();
}

- (void) drawCeamraMeshWithMaskTexture:(ofImage &)input{
    cameraFbo.begin();
    ofClear(0, 255);
    input.getTexture().bind();
    maskImage.bind();
    cameraMesh.draw();
    maskImage.unbind();
    cameraFbo.end();
}

- (void)updateMaskedImage:(ofImage &)input withPixels:(ofPixels &)pixels {
    clone.setStrength(25);
    //original setting was 12 but raising it to 30 really exaggerates the clone, dramatic.
    clone.update(cameraFbo.getTexture(), input.getTexture(), maskFbo.getTexture());
    clone.buffer.readToPixels(pixels);
    //at this point, we are done with the merging, and the merged image is now in pixels form.
    //We set it to our ofImage maskedImage property.
    maskedImage.setFromPixels(pixels);
    maskedImage.update();
}

- (void)drawImageOnImageView:(ofPixels)pixels {
    Mat frame = ofxCv::toCv(pixels);
    UIImage *image = MatToUIImage(frame);
    self.imageView.image = image;
}

-(void) drawMaskOnInput:(ofImage &)image{
    if(cloneReady){
        //this is the actual MERGING of the images.
        ofPixels pixels;
        [self updateCameraMeshAndTexture];
        [self drawCameraMeshWithMaskFBO];
        [self drawCeamraMeshWithMaskTexture:image];
        [self updateMaskedImage:image withPixels:pixels];
        [self drawImageOnImageView:pixels];
    }
    else{
        if(image.getHeight() > 0 && image.getWidth() > 0) {
            maskedImage = image;
        }
    }
}

- (void)readMP4 {
    NSArray *docPaths            = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
    NSString *documentsDirectory = [docPaths objectAtIndex:0];
    NSString  *imagePath         = [documentsDirectory stringByAppendingPathComponent:@"/vid1.mp4"];

    cap.open([imagePath UTF8String]);
    [self setupTimer];
}

- (IBAction)buttonVideoTapped:(id)sender {
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeMovie,      nil];
    imagePicker.videoQuality = UIImagePickerControllerQualityTypeHigh;
    [self presentViewController:imagePicker animated:YES completion:nil];
}

- (void)readVideoData:(AVAsset *)asset {
    if ([asset isKindOfClass:[AVURLAsset class]]) {
        NSLog(@"orientation %d", asset.videoOrientation);
        NSURL *originURL = [(AVURLAsset *)asset URL];
        NSData *videoData = [NSData dataWithContentsOfURL:originURL];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *tempPath = [documentsDirectory stringByAppendingFormat:@"/vid1.mp4"];
        NSLog(@"%@", tempPath);
        
        BOOL success = [videoData writeToFile:tempPath atomically:NO];
        if(NO == success) {
            NSLog(@"failed!!");
            return;
        }
        
        self.avasset = asset;
        [self setupMovieInfo];
        self.usingLocalFile = YES;
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSString *mediaType = info[UIImagePickerControllerMediaType];
    NSString *videoString = (NSString *)kUTTypeVideo;
    NSString *movieString = (NSString *)kUTTypeMovie;
    
    if ([mediaType isEqualToString:videoString] || [mediaType isEqualToString:movieString]) {
        NSURL *videoRef = info[UIImagePickerControllerReferenceURL];
        PHFetchResult *refResult = [PHAsset fetchAssetsWithALAssetURLs:@[videoRef] options:nil];
        PHVideoRequestOptions *videoRequestOptions = [[PHVideoRequestOptions alloc] init];
        videoRequestOptions.version = PHVideoRequestOptionsVersionOriginal;
        [[PHImageManager defaultManager] requestAVAssetForVideo:[refResult firstObject] options:videoRequestOptions resultHandler:^(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info) {
            [self readVideoData:asset];
            [picker dismissViewControllerAnimated:YES completion:nil];
        }];
    }
}

- (IBAction)buttonSwitchCamera:(id)sender {
    ofVideoGrabber grabber;
    
    if(BACK_CAM == self.cameraId) {
        self.cameraId = FRONT_CAM;
        
    } else {
        self.cameraId = BACK_CAM;
    }
    
    grabber.setDeviceID(self.cameraId);
    grabber.setup(ofGetWidth(), ofGetHeight());
    cam = grabber;
    
    self.usingLocalFile = NO;
    self.glkView.hidden = NO;
    [self resetTimer];
}

- (IBAction)buttonToggleViewSelect:(id)sender {
    [self.view addSubview:self.viewContainerForViewSelection];
    [self.view bringSubviewToFront:self.viewContainerForViewSelection];
}

- (IBAction)buttonFoldViewSelectionTapped:(id)sender {
    [self.viewContainerForViewSelection removeFromSuperview];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSLog(@"%lu", (unsigned long)self.arrayEffects.count);
    return self.arrayEffects.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    EffectCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"EffectCollectionViewCell" forIndexPath:indexPath];
    [cell setupImage:self.arrayEffects[indexPath.row]];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *stringImageName = self.arrayEffects[indexPath.row];
    [self setupMaskFraceTracker:stringImageName];
    [self.viewContainerForViewSelection removeFromSuperview];
}

- (NSString *)getStringPath {
    NSString *filename = @"temp.mp4";
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *path = [[paths objectAtIndex:0] stringByAppendingPathComponent:filename];
    
    return path;
}

- (float)getSizeWithIsWidth:(BOOL)isWidth {
    CGFloat scale = [[UIScreen mainScreen] scale];
    CGFloat downsampling = [self getDownSamplingWithScale:scale];
    
    return [self getVideoWidthWithScale:scale withDownSampling:downsampling withIsWidth:isWidth];
}

- (float)getVideoImageWidth {
    return [self getSizeWithIsWidth:YES];
}

- (float)getVideoImageHeight {
    return [self getSizeWithIsWidth:NO];
}

- (void)setupVideoWriter {
    NSError *error = nil;
    NSString *stringPath = [self getStringPath];
    [[NSFileManager defaultManager] removeItemAtPath:stringPath error: &error];
    self.videoWriter = [[AVAssetWriter alloc] initWithURL:
                        [NSURL fileURLWithPath:stringPath] fileType:AVFileTypeQuickTimeMovie
                                                    error:&error];
    NSParameterAssert(self.videoWriter);
}

- (void)setupWriteInput {
    float videoWidth = [self getVideoImageWidth];
    float videoHeight = [self getVideoImageHeight];
    
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:videoWidth], AVVideoWidthKey,
                                   [NSNumber numberWithInt:videoHeight], AVVideoHeightKey,
                                   nil];
    self.writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                          outputSettings:videoSettings];
    
    NSParameterAssert(self.writerInput);
    NSParameterAssert([self.videoWriter canAddInput:self.writerInput]);
    [self.videoWriter addInput:self.writerInput];
}

- (void)setupAdaptor {
    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    
    self.adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.writerInput
                                                                                    sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
}

- (void)setupAVAssetWriter {
    [self setupVideoWriter];
    [self setupWriteInput];
    [self setupAdaptor];
}

- (void)releaseAVAssetWriter {
    self.adaptor = nil;
    self.writerInput = nil;
    self.videoWriter = nil;
}

- (void)saveVideoWithColleciton:(PHAssetCollection *)album {
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        ///
        // Request creating an asset from the image.
        //
        NSString *stringPath = [self getStringPath];
        NSURL *videoFileURL = [NSURL fileURLWithPath:stringPath];
        PHAssetChangeRequest *createAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:videoFileURL];
        PHObjectPlaceholder *placeholder = [createAssetRequest placeholderForCreatedAsset];
        PHFetchResult *assetsInAlbum = [PHAsset fetchAssetsInAssetCollection:album options:nil];
        PHAssetCollectionChangeRequest *albumChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:album assets:assetsInAlbum];
        [albumChangeRequest addAssets:@[placeholder]];
    } completionHandler:^(BOOL success, NSError *error) {
        NSLog(@"Finished adding asset. %@", (success ? @"Success" : error));
    }];
}

- (void)createAlbumAndSaveVideoWithAppName:(NSString*)appName {
    __block PHAssetCollection *collection = nil;
    __block PHObjectPlaceholder *placeholder = nil;
    
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetCollectionChangeRequest *createAlbum = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:appName];
        placeholder = [createAlbum placeholderForCreatedAssetCollection];
    } completionHandler:^(BOOL success, NSError *error) {
        if (success && placeholder && placeholder.localIdentifier)
        {
            PHFetchResult *collectionFetchResult = [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[placeholder.localIdentifier]
                                                                                                        options:nil];
            collection = collectionFetchResult.firstObject;
            [self saveVideoWithColleciton:collection];
        }
    }];
}

- (PHAssetCollection *)getCollectionForSaveWithAppName:(NSString *)appName {
    PHFetchResult<PHAssetCollection *> *collectionResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    for (PHAssetCollection *coll in collectionResult) {
        if ([coll.localizedTitle isEqualToString:appName]) {
            return coll;
        }
    }
    
    return nil;
}

- (void)stopRecording {
    self.isRecording = NO;
    [self.buttonVideoRecord setBackgroundColor:[self colorWithRGBHex:0x3AA5DC]];
    
    [self.writerInput markAsFinished];
    [self.videoWriter finishWritingWithCompletionHandler:^{
        __block PHAssetCollection *collection = nil;
        NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        collection = [self getCollectionForSaveWithAppName:appName];
        
        if(collection) {
            [self saveVideoWithColleciton:collection];
        }
        else {
            [self createAlbumAndSaveVideoWithAppName:appName];
        }
    }];
    
    [self releaseAVAssetWriter];
}

- (void)startRecording {
    self.isRecording = YES;
    [self.buttonVideoRecord setBackgroundColor:[UIColor redColor]];
    self.frameIndex = 0;
    self.framePerSecond = 60;
    
    ///
    [self setupAVAssetWriter];
    [self.videoWriter startWriting];
    [self.videoWriter startSessionAtSourceTime:kCMTimeZero]; //use kCMTimeZero if unsure
}

- (IBAction)buttonVideoRecordTapped:(id)sender {
    [self.tooltipView removeFromSuperview];
    
    if(self.isRecording) {
        [self stopRecording];
    }
    else {
        [self startRecording];
    }
}

- (UIColor *)colorWithRGBHex:(NSUInteger)RGBHex {
        CGFloat red = ((CGFloat)((RGBHex & 0xFF0000) >> 16)) / 255.0f;
        CGFloat green = ((CGFloat)((RGBHex & 0xFF00) >> 8)) / 255.0f;
        CGFloat blue = ((CGFloat)((RGBHex & 0xFF))) / 255.0f;
        
        return [UIColor colorWithRed:red green:green blue:blue alpha:1.0f];
        
}

- (void)showToolTip:(UIButton *)sender
{
    int posX = sender.frame.origin.x + 10;
    int posY = sender.frame.origin.y - 40;
    self.tooltipView = [[UIView alloc] init];
    int width = 150;
    self.tooltipView.frame = CGRectMake(posX, posY, width, 30.0f);
    self.tooltipView.backgroundColor = [self colorWithRGBHex:0x12A9DE];
    self.tooltipView.layer.cornerRadius = 5.0f;
    [self.tooltipView clipsToBounds];
    self.tooltipView.hidden = NO;
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(5, 5, width - 10, 25)];
    label.text = @"누르면 동영상으로 저장됩니다!";
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:11];
    [self.tooltipView addSubview:label];
    [self.view addSubview:self.tooltipView];
}


@end
