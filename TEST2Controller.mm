//
//  TEST2Controller.m
//  TEST2
//
//  Created by RossSong on 2017. 5. 23..
//
//

#import "TEST2Controller.h"
#import "Util.h"

@interface TEST2Controller ()
{
    VideoCapture    cap;
    
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
@end

@implementation TEST2Controller

- (void)dealloc {
    //OpenFramework 설정으로 인해 ARC를 사용하지 않음.
    self.targetDelegate = nil;
    [self.maskFaceTracker release];
    [self.cameraFaceTracker release];
    [self.cam release];
    [super dealloc];
}

- (void)setupArrayEffects {
    self.arrayEffects = @[@"moon.jpg", @"Ahn.jpg", @"DonaldTrump.jpeg", @"joker.jpg", @"Abe.jpeg", @"young_moon.jpeg", @"test.jpg", @"jung.png"];
}

- (void)setupDefaultMask {
    [self setupMaskFraceTracker:self.arrayEffects[7]];
}

- (void)setupCamera {
    self.cameraId = 1;
    self.cam = [[VideoGrabberWrapper alloc] init];
    [self.cam setDeviceID:1]; // front camera - 1
    [self.cam setupWidth:ofGetWidth() withHeight:ofGetHeight()];
}

- (void)setupFaceTrackers {
    self.maskFaceTracker = [[FaceTrackerWrapper alloc] init];
    self.cameraFaceTracker = [[FaceTrackerWrapper alloc] init];
    [self.maskFaceTracker setup];
    [self.cameraFaceTracker setup];
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

- (void)setup {
    [self setupFaceTrackers];
    [self setupCamera];
    [self setupTimer];
    [self setupArrayEffects];
    [self setupDefaultMask];
}

- (void)readMP4IfUsingLocalFile {
    if(self.usingLocalFile) {
        [self readMP4];
    }
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
    //self.imageView.image = uiImage;
    [self.targetDelegate setImageViewImage:uiImage];
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
        [self.targetDelegate backgroundColorChanged:[UIColor redColor]];
    }
    else {
        [self.targetDelegate backgroundColorChanged:[Util colorWithRGBHex:0xE9650A]];
    }
}

- (void)updateCam {
    [self.cam update];
    Mat frame = [self.cam getFrame];
    
    if(self.isRecording){
        [self updateButtonVideoRecord];
    }
    
    if(BACK_CAM == self.cameraId) {
        //mirror
        cv::flip(frame, frame, 1);
    }
    
    if([self.cam isFrameNew]) {
        [self.cameraFaceTracker update:frame];
    }
}

- (void)draw {
    if(self.usingLocalFile) {
        [self updateCap];
    }
    else {
        [self updateCam];
    }
    
    //[self.glkView display];
    [self.targetDelegate glkViewDisplay];
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

- (void)updateFace {
    ofImage img;
    //img.setFromPixels(cam.getPixels());
    ofxCv::toOf(currentFrame, img);
    [self maskTakenPhoto:img];
}

- (void)drawFace {
    if(maskImage.getWidth() > 0){
        Mat frame = ofxCv::toCv(maskImage);
        [self.maskFaceTracker update:frame];
        if(![self.maskFaceTracker getFound]){
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

- (void)drawCam {
    if(BACK_CAM == self.cameraId) {
        [self.cam drawMirror];
    }
    else {
        [self.cam draw];
    }
}

- (void)drawFaceMesh {
    cameraMesh = [self.cameraFaceTracker getImageMesh];
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
    
    float scaleW = ofGetWidth() / [self.cam getWidth];
    float scaleH = ofGetHeight() / [self.cam getHeight];
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
        //image = self.imageView.image;
        image = [self.targetDelegate getImageViewImage];
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
    if(NO == [self.maskFaceTracker getFound]) {
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
            Mat frame = ofxCv::toCv(maskImage);
            [self.maskFaceTracker update:frame];
            maskPoints = [self.maskFaceTracker getImagePoints];
            count++;
        } while (![self.maskFaceTracker getFound] && count < 3);
        
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
    Mat frame = ofxCv::toCv(image);
    [self.cameraFaceTracker update:frame];
    cloneReady = [self.cameraFaceTracker getFound]; //yes if FaceTracker could identify a face from our input
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
    cameraMesh = [self.cameraFaceTracker getImageMesh];
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
    //self.imageView.image = image;
    [self.targetDelegate setImageViewImage:image];
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

- (void)switchCamera {
    //ofVideoGrabber grabber;
    id<VideoGrabberProtocol> grabber = [[VideoGrabberWrapper alloc] init];
    
    if(BACK_CAM == self.cameraId) {
        self.cameraId = FRONT_CAM;
        
    } else {
        self.cameraId = BACK_CAM;
    }
    
    [grabber setDeviceID:self.cameraId];
    [grabber setupWidth:ofGetWidth() withHeight:ofGetHeight()];
    [self.cam release];
    self.cam = grabber;
    
    self.usingLocalFile = NO;
    //self.glkView.hidden = NO;
    [self.targetDelegate showGLKView];
    [self resetTimer];
}

- (float)getSizeWithIsWidth:(BOOL)isWidth {
    CGFloat scale = [[UIScreen mainScreen] scale];
    CGFloat downsampling = [self getDownSamplingWithScale:scale];
    
    return [self getVideoWidthWithScale:scale withDownSampling:downsampling withIsWidth:isWidth];
}

- (NSString *)getStringPath {
    NSString *filename = @"temp.mp4";
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *path = [[paths objectAtIndex:0] stringByAppendingPathComponent:filename];
    
    return path;
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
    [self.targetDelegate backgroundColorChanged:[Util colorWithRGBHex:0x3AA5DC]];
    
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
    //[self.buttonVideoRecord setBackgroundColor:[UIColor redColor]];
    [self.targetDelegate backgroundColorChanged:[UIColor redColor]];
    self.frameIndex = 0;
    self.framePerSecond = 60;
    
    ///
    [self setupAVAssetWriter];
    [self.videoWriter startWriting];
    [self.videoWriter startSessionAtSourceTime:kCMTimeZero]; //use kCMTimeZero if unsure
}

- (void)toggleButtonVideoRecord {
    if(self.isRecording) {
        [self stopRecording];
    }
    else {
        [self startRecording];
    }
}

- (void)drawGLKView:(GLKView *)view drawInRect:(CGRect)rect {
    if(self.usingLocalFile) {
        //self.glkView.hidden = YES;
        [self.targetDelegate hideGLKView];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self drawFace];
            [self captureScreen];
        });
    }
    else {
        [self drawCamAndFaceMesh];
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

@end
