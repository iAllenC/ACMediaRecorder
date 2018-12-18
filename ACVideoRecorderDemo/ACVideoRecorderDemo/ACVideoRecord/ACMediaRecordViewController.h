//
//  OFMediaRecordViewController.h
//  AC
//
//  Created by Allen on 2017/5/17.
//  Copyright © 2017年 Cpsdna. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ACMediaRecordViewController;

@protocol ACMediaRecordViewControllerDelegate <NSObject>

- (void)recordViewController:(ACMediaRecordViewController *)viewController succeededRecordVideoToFileURL:(NSURL *)fileURL thumbImage:(UIImage *)thumbImage;

- (void)recordViewController:(ACMediaRecordViewController *)viewController succeededTakeImage:(UIImage *)image;

@end

@interface ACMediaRecordViewController : UIViewController

@property (weak, nonatomic) id<ACMediaRecordViewControllerDelegate> delegate;

@property (assign, nonatomic, getter=isVideoRecordDisabled) BOOL videoRecordDisabled;

@end
