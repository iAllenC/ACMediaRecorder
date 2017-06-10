//
//  ViewController.m
//  ACVideoRecorderDemo
//
//  Created by Allen on 2017/6/10.
//  Copyright © 2017年 Allen. All rights reserved.
//

#import "ViewController.h"
#import "ACMediaRecordViewController.h"
#import "ACVideoPlayView.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()<ACMediaRecordViewControllerDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet ACVideoPlayView *videoView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.videoView.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.videoView.hidden =self.imageView.hidden = YES;
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    if (!self.videoView.hidden) [self.videoView play];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.videoView stop];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    ACMediaRecordViewController *mediaVC = (ACMediaRecordViewController *)segue.destinationViewController;
    mediaVC.delegate = self;
}

//拍照并完成后由此回调
- (void)recordViewController:(ACMediaRecordViewController *)viewController succeededTakeImage:(UIImage *)image {
    self.videoView.hidden = YES;
    self.imageView.hidden = NO;
    self.imageView.image = image;
}

//录制视频并完成后由此回调
- (void)recordViewController:(ACMediaRecordViewController *)viewController succeededRecordVideoToFileURL:(NSURL *)fileURL thumbImage:(UIImage *)thumbImage {
    self.imageView.hidden = YES;
    self.videoView.hidden = NO;
    self.videoView.player = [AVPlayer playerWithURL:fileURL];
}


@end
