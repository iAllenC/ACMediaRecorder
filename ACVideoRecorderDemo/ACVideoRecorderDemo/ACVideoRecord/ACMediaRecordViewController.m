//
//  OFMediarecordBtnController.m
//  AC
//
//  Created by Allen on 2017/5/17.
//  Copyright © 2017年 Cpsdna. All rights reserved.
//

#import "ACMediaRecordViewController.h"
#import "ACCamPreviewView.h"
#import "ACMediaRecorder.h"
#import "ACVideoPlayView.h"
#import "ACRecordButton.h"
#import <AVFoundation/AVFoundation.h>
@interface ACMediaRecordViewController ()<ACMediaRecordDelegate, ACRecordButtonDelegate>

@property (strong, nonatomic) ACCamPreviewView          *mediaView;

@property (strong, nonatomic) UIButton                  *closeBtn;

@property (strong, nonatomic) UIView                    *controlPad;

@property (strong, nonatomic) ACRecordButton            *recordBtn;

@property (strong, nonatomic) UILabel                   *tipLabel;

@property (strong, nonatomic) UIButton                  *flashBtn;

@property (strong, nonatomic) UIButton                  *cameraTransferBtn;

@property (strong, nonatomic) UIButton                  *deleteBtn;

@property (strong, nonatomic) UIButton                  *completeBtn;

@property (strong, nonatomic) ACVideoPlayView           *videoPreviewView;

@property (strong, nonatomic) UIImageView               *imagePreviewView;

//获取的视频路径
@property (strong, nonatomic) NSURL                     *resultFileURL;

//获取的视频缩略图
@property (strong, nonatomic) UIImage                   *resultVideoThumbImage;

//获取的图片
@property (strong, nonatomic) UIImage                   *resultImage;

@end

@implementation ACMediaRecordViewController{
    CGFloat margin , closeWidth , smallWidth , mediumWidth , largeWidth , tipMargin ;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)tryStartMediaRecorder {
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
        case AVAuthorizationStatusNotDetermined: {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (granted) {
                    [[ACMediaRecorder sharedRecorder] setPreviewView:self.mediaView];
                    [[ACMediaRecorder sharedRecorder] openCamera];
                }
            }];
        }
            break;
        case AVAuthorizationStatusAuthorized:
            [[ACMediaRecorder sharedRecorder] setPreviewView:self.mediaView];
            [[ACMediaRecorder sharedRecorder] openCamera];
            break;
        case AVAuthorizationStatusRestricted:
        case AVAuthorizationStatusDenied:
            [self guideToAuthorizeCamera];
            break;
        default:
            break;
    }
}

- (void)guideToAuthorizeCamera {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:@"请在iPhone的\"设置-隐私\"选项中,允许路骂宝访问你的摄像头和麦克风" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self popOrDismissWithCompletion:nil];
    }];
    [alert addAction:action];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)popOrDismissWithCompletion:(void(^)())completion {
    if ([ACMediaRecorder sharedRecorder].isRecordingVideo) return;
    if (self.navigationController) {
        if (self.navigationController.viewControllers.count > 1) {
            [self.navigationController popViewControllerAnimated:YES];
            if (completion) completion();
        } else {
            [self.navigationController dismissViewControllerAnimated:YES completion:completion];
        }
    } else {
        [self dismissViewControllerAnimated:YES completion:completion];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self configSubviews];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    [ACMediaRecorder sharedRecorder].delegate = self;
    [ACMediaRecorder sharedRecorder].takeImageOnShortRecord = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

- (void)configSubviews {
    margin = 10, closeWidth = 44, smallWidth = 56, mediumWidth = 72, largeWidth = 96, tipMargin = 20;
    self.mediaView = [[ACCamPreviewView alloc] initWithFrame:self.view.bounds];
    UITapGestureRecognizer *focusTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onFocusTap:)];
    [self.mediaView addGestureRecognizer:focusTap];
    self.mediaView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.mediaView];
    self.videoPreviewView = [[ACVideoPlayView alloc] initWithFrame:self.view.bounds];
    self.videoPreviewView.backgroundColor = [UIColor clearColor];
    self.videoPreviewView.hidden = YES;
    self.videoPreviewView.mute = NO;
    self.videoPreviewView.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view addSubview:self.videoPreviewView];
    self.imagePreviewView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.imagePreviewView];
    self.closeBtn = [[UIButton alloc] initWithFrame:CGRectMake(margin, margin, closeWidth, closeWidth)];
    [self.closeBtn setImage:[UIImage imageNamed:@"return"] forState:UIControlStateNormal];
    [self.closeBtn addTarget:self action:@selector(onCloseBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.closeBtn];
    self.controlPad = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height * 2.0/3, self.view.frame.size.width, self.view.frame.size.height * 1.0/3)];
    CGFloat controlTop = self.controlPad.frame.origin.y;
    self.controlPad.userInteractionEnabled = NO;
    [self.view addSubview:self.controlPad];
    self.tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, controlTop + tipMargin, self.view.frame.size.width, 20)];
    self.tipLabel.hidden = YES;
    self.tipLabel.textAlignment = NSTextAlignmentCenter;
    self.tipLabel.text = self.isVideoRecordDisabled ? @"轻触拍照" : @"轻触拍摄,长按录像";
    self.tipLabel.textColor = [UIColor whiteColor];
    self.tipLabel.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:self.tipLabel];
    self.flashBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, smallWidth, smallWidth)];
    self.flashBtn.center = CGPointMake((self.view.frame.size.width - largeWidth)/2/2, controlTop + self.controlPad.frame.size.height/2);
    [self.flashBtn addTarget:self action:@selector(onFlashBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    self.flashBtn.backgroundColor = [UIColor whiteColor];
    [self.flashBtn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    [self.flashBtn setTitle:@"闪光灯" forState:UIControlStateNormal];
    self.flashBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    self.flashBtn.layer.cornerRadius = smallWidth/2;
    [self.view addSubview:self.flashBtn];
    self.recordBtn = [[ACRecordButton alloc] initWithFrame:CGRectMake(0, 0, largeWidth, largeWidth) duration:10];
    self.recordBtn.center = self.controlPad.center;
    if (![ACMediaRecorder sharedRecorder].isVideoRecordPrepared || self.isVideoRecordDisabled) {
        self.recordBtn.longPressDisabled = YES;
    }
    self.recordBtn.progressColor = [UIColor greenColor];
    self.recordBtn.delegate = self;
    [self.view addSubview:self.recordBtn];
    self.cameraTransferBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, smallWidth, smallWidth)];
    self.cameraTransferBtn.center = CGPointMake(self.view.frame.size.width - self.flashBtn.center.x, self.flashBtn.center.y);
    [self.cameraTransferBtn addTarget:self action:@selector(onCameraTransferBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.cameraTransferBtn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    self.cameraTransferBtn.backgroundColor = [UIColor whiteColor];
    self.cameraTransferBtn.layer.cornerRadius = smallWidth/2;
    [self.cameraTransferBtn setTitle:@"翻转" forState:UIControlStateNormal];
    self.cameraTransferBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:self.cameraTransferBtn];
    self.deleteBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, mediumWidth, mediumWidth)];
    self.deleteBtn.center = self.controlPad.center;
    [self.deleteBtn addTarget:self action:@selector(onDeleteBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    self.deleteBtn.hidden = YES;
    self.deleteBtn.backgroundColor = [UIColor whiteColor];
    self.deleteBtn.layer.cornerRadius = mediumWidth/2;
    [self.deleteBtn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    [self.deleteBtn setTitle:@"删除" forState:UIControlStateNormal];
    self.deleteBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:self.deleteBtn];
    self.completeBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, mediumWidth, mediumWidth)];
    self.completeBtn.center = self.controlPad.center;
    [self.completeBtn addTarget:self action:@selector(onCompleteBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    self.completeBtn.hidden = YES;
    self.completeBtn.backgroundColor = [UIColor whiteColor];
    self.completeBtn.layer.cornerRadius = mediumWidth/2;
    [self.completeBtn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    [self.completeBtn setTitle:@"完成" forState:UIControlStateNormal];
    self.completeBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:self.completeBtn];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self tryStartMediaRecorder];
    if (self.videoPreviewView.hidden) [self showTip];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[ACMediaRecorder sharedRecorder] closeCamera];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)showTip {
    self.tipLabel.hidden = NO;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTip) object:nil];
    [self performSelector:@selector(hideTip) withObject:nil afterDelay:3];
}

- (void)hideTip {
    self.tipLabel.hidden = YES;
}

#pragma mark - UIControl

- (void)openPreview {
    void(^showPreview)(BOOL isVideo, NSURL *URL, UIImage *image) = ^(BOOL isVideo, NSURL *URL, UIImage *image) {
        self.recordBtn.hidden = YES;
        self.videoPreviewView.hidden = !isVideo;
        self.imagePreviewView.hidden = isVideo;
        if (isVideo && URL) [self.videoPreviewView setPlayer:[AVPlayer playerWithURL:URL]];
        if (!isVideo && image) self.imagePreviewView.image = image;
    };
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.resultFileURL) {
            showPreview(YES, self.resultFileURL, nil);
        } else if (self.resultImage) {
            showPreview(NO, nil, self.resultImage);
        } else {
            return;
        }
        [UIView animateWithDuration:0.25 animations:^{
            self.flashBtn.center = self.controlPad.center;
            self.cameraTransferBtn.center = self.controlPad.center;
        } completion:^(BOOL finished) {
            self.flashBtn.hidden = YES;
            self.cameraTransferBtn.hidden = YES;
            self.deleteBtn.hidden = NO;
            self.completeBtn.hidden = NO;
            [self hideTip];
            [UIView animateWithDuration:0.25 animations:^{
                self.deleteBtn.center = CGPointMake(self.controlPad.frame.size.width*1.0/3, self.deleteBtn.center.y);
                self.completeBtn.center = CGPointMake(self.controlPad.frame.size.width*2.0/3, self.completeBtn.center.y);
            } completion:^(BOOL finished) {
            }];
        }];
    });
}

- (void)closePreview {
    self.videoPreviewView.hidden = YES;
    self.imagePreviewView.hidden = YES;
    [self.videoPreviewView stop];
    [self.videoPreviewView setPlayer:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.25 animations:^{
            self.deleteBtn.center = self.completeBtn.center = self.controlPad.center;
        } completion:^(BOOL finished) {
            self.flashBtn.hidden = NO;
            self.cameraTransferBtn.hidden = NO;
            self.deleteBtn.hidden = YES;
            self.completeBtn.hidden = YES;
            [self showTip];
            [UIView animateWithDuration:0.25 animations:^{
                self.flashBtn.center = CGPointMake((self.view.frame.size.width - largeWidth)/2/2, self.controlPad.frame.origin.y + self.controlPad.frame.size.height/2);
                self.cameraTransferBtn.center = CGPointMake(self.view.frame.size.width - self.flashBtn.center.x, self.flashBtn.center.y);
            } completion:^(BOOL finished) {
                self.recordBtn.hidden = NO;
            }];
        }];
    });
}

#pragma mark - BtnAction

- (void)onFlashBtnClick:(UIButton *)sender {
    [[ACMediaRecorder sharedRecorder] switchFlash];
}

- (void)onCameraTransferBtnClick:(UIButton *)sender {
    [[ACMediaRecorder sharedRecorder] changeCamera];
}

- (void)onDeleteBtnClick:(UIButton *)sender {
    if (self.resultFileURL && [[NSFileManager defaultManager] fileExistsAtPath:self.resultFileURL.path]) {
        [[NSFileManager defaultManager] removeItemAtPath:self.resultFileURL.path error:nil];
        self.resultFileURL = nil;
    } else if (self.resultImage) {
        self.resultImage = nil;
    }
    [self closePreview];
}

- (void)onCompleteBtnClick:(UIButton *)sender {
    [self popOrDismissWithCompletion:^{
        if (self.resultFileURL && [self.delegate respondsToSelector:@selector(recordViewController:succeededRecordVideoToFileURL:thumbImage:)]) {
            [self.delegate recordViewController:self succeededRecordVideoToFileURL:self.resultFileURL thumbImage:self.resultVideoThumbImage];
        } else if (self.resultImage && [self.delegate respondsToSelector:@selector(recordViewController:succeededTakeImage:)]) {
            [self.delegate recordViewController:self succeededTakeImage:self.resultImage];
        }
    }];
}

- (void)onCloseBtnClick:(UIButton *)sender {
    [self popOrDismissWithCompletion:nil];
}
#pragma mark - UIGestureRecognizer

- (void)onFocusTap:(UITapGestureRecognizer *)tap {
    CGPoint point = [tap locationInView:tap.view];
    [[ACMediaRecorder sharedRecorder] setFocusPoint:point];
}

#pragma mark - ACRecordButtonDelegate

- (void)recordButtonTapped:(ACRecordButton *)button {
    [[ACMediaRecorder sharedRecorder] startRecordWithMode:ACMediaRecorderModePhoto];
}

- (void)recordButtonDidBeginLongpress:(ACRecordButton *)button {
    [[ACMediaRecorder sharedRecorder] startRecordWithMode:ACMediaRecorderModeVideo];
    [self hideTip];
}

- (void)recordButtonDidFinishLongpress:(ACRecordButton *)button {
    [[ACMediaRecorder sharedRecorder] stopRecord];
}

#pragma mark - ACMediaRecordDelegate

- (void)recorderDidPreparedToRecordVideo:(ACMediaRecorder *)recorder {
    if (!self.isVideoRecordDisabled) {
        self.recordBtn.longPressDisabled = NO;
    }
}

- (void)recorderDidStartRecordVideo:(ACMediaRecorder *)recorder {
}

- (void)recorderDidStopRecordVideo:(ACMediaRecorder *)recorder {
}

- (void)recorder:(ACMediaRecorder *)recorder succeededRecordVideoToFileURL:(NSURL *)fileURL thumbImage:(UIImage *)thumbImage {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.resultFileURL = fileURL;
        self.resultVideoThumbImage = thumbImage;
        self.resultImage = nil;
        [self openPreview];
    });
}

- (void)recorder:(ACMediaRecorder *)recorder failedRecordVideoWithError:(NSError *)error {
    [self.recordBtn restore];
}

- (void)recorder:(ACMediaRecorder *)recorder succeededTakeImage:(UIImage *)image {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.resultFileURL = nil;
        self.resultVideoThumbImage = nil;
        self.resultImage = image;
        [self openPreview];
    });
}

@end
