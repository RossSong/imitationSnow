//
//  TestViewController.m
//  TEST2
//
//  Created by RossSong on 2017. 5. 4..
//
//

#import "TestViewController.h"
#import "TEST2Controller.h"
#import "Util.h"

@interface TestViewController () <GLKViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, TargetViewControllerDelegate>

@property (retain, nonatomic) IBOutlet UIImageView *imageView;
@property (retain, nonatomic) IBOutlet GLKView *glkView;

@property (retain, nonatomic) IBOutlet UIButton *buttonVideoRecord;
@property (strong, nonatomic) IBOutlet UIView *viewContainerForViewSelection;
@property (retain, nonatomic) IBOutlet UIView *viewSelection;
@property (retain, nonatomic) IBOutlet UICollectionView *collectionView;
@property (strong, nonatomic) UIView *tooltipView;
@property (strong, nonatomic) TEST2Controller *controller;
@end

@implementation TestViewController

- (void)setupGLKView {
    self.glkView.delegate = self;
    self.glkView.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    [self.glkView setOpaque:NO];
    self.glkView.context = [EAGLContext currentContext];
}

- (void)setupButtonVideoRecord {
    self.buttonVideoRecord.layer.cornerRadius = self.buttonVideoRecord.frame.size.width /2.0;
    self.buttonVideoRecord.clipsToBounds = YES;
    self.buttonVideoRecord.backgroundColor = [Util colorWithRGBHex:0x3AA5DC];
}

- (void)setupCollectionView {
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;

    UINib* nib = [UINib nibWithNibName:@"EffectCollectionViewCell" bundle:nil];
    [self.collectionView registerNib:nib forCellWithReuseIdentifier:@"EffectCollectionViewCell"];
    [self.collectionView reloadData];
}

- (void)setupTooltip {
    [self showToolTip:self.buttonVideoRecord];
}

- (void)setupController {
    self.controller = [[TEST2Controller alloc] init];
    id<VideoGrabberProtocol> camera = [[VideoGrabberWrapper alloc] init];
    id<FaceTrackerProtocol> maskTracker = [[FaceTrackerWrapper alloc] init];
    id<FaceTrackerProtocol> cameraTracker = [[FaceTrackerWrapper alloc] init];
    
    [self.controller setupCamera:camera];
    [self.controller setFaceTrackersWithMaskFaceTracker:maskTracker
                                  withCameraFaceTracker:cameraTracker];

    self.controller.targetDelegate = self;
    [self.controller setup];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupGLKView];
    [self setupButtonVideoRecord];
    [self setupCollectionView];
    [self setupTooltip];
    [self setupController];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.controller readMP4IfUsingLocalFile];
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


- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [self.controller drawGLKView:view drawInRect:rect];
}

- (void)dealloc {
    //주의: OpenFramework 의 Proeject Generator 로 프로젝트를 자동으로 생성하면 ARC 를 사용하지 않도록 설정되어 있어서
    //dealloc 처리를 따로 해줘야 함. (ARC를 쓰지 않음.)
    [_controller stopTimer];
    
    [_imageView release];
    [_glkView release];
    [_buttonVideoRecord release];
    [_viewContainerForViewSelection release];
    [_viewSelection release];
    [_collectionView release];
    [_controller release];
    [super dealloc];
}

- (IBAction)buttonVideoTapped:(id)sender {
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeMovie,      nil];
    imagePicker.videoQuality = UIImagePickerControllerQualityTypeHigh;
    [self presentViewController:imagePicker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [self.controller imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info];
}

- (IBAction)buttonSwitchCamera:(id)sender {
    [self.controller switchCamera];
}

- (IBAction)buttonToggleViewSelect:(id)sender {
    [self.view addSubview:self.viewContainerForViewSelection];
    [self.view bringSubviewToFront:self.viewContainerForViewSelection];
}

- (IBAction)buttonFoldViewSelectionTapped:(id)sender {
    [self.viewContainerForViewSelection removeFromSuperview];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSLog(@"%lu", (unsigned long)self.controller.arrayEffects.count);
    return self.controller.arrayEffects.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    EffectCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"EffectCollectionViewCell" forIndexPath:indexPath];
    [cell setupImage:self.controller.arrayEffects[indexPath.row]];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *stringImageName = self.controller.arrayEffects[indexPath.row];
    [self.controller setupMaskFraceTracker:stringImageName];
    [self.viewContainerForViewSelection removeFromSuperview];
}

- (void)backgroundColorChanged:(UIColor *)color {
    [self.buttonVideoRecord setBackgroundColor:color];
}

- (IBAction)buttonVideoRecordTapped:(id)sender {
    [self.tooltipView removeFromSuperview];
    [self.controller toggleButtonVideoRecord];
}

- (void)showToolTip:(UIButton *)sender
{
    int posX = sender.frame.origin.x + 10;
    int posY = sender.frame.origin.y - 40;
    self.tooltipView = [[UIView alloc] init];
    int width = 150;
    self.tooltipView.frame = CGRectMake(posX, posY, width, 30.0f);
    self.tooltipView.backgroundColor = [Util colorWithRGBHex:0x12A9DE];
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

- (void)setImageViewImage:(UIImage *)image {
    self.imageView.image = image;
}

- (void)hideGLKView {
    self.glkView.hidden = YES;
}

- (void)showGLKView {
    self.glkView.hidden = NO;
}

- (void)glkViewDisplay {
    [self.glkView display];
}

- (UIImage *)getImageViewImage {
    return self.imageView.image;
}

@end
