//
//  ACMediaRecorder.h
//  AC
//
//  Created by Allen on 2017/5/17.
//  Copyright © 2017年 Cpsdna. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ACCamPreviewView.h"

typedef NS_ENUM(NSUInteger, ACMediaRecorderMode) {
    ACMediaRecorderModePhoto = 0,
    ACMediaRecorderModeVideo
};

typedef NS_ENUM(NSUInteger, ACMediaRecorderStatus) {
    ACMediaRecorderStatusIdle = 0,
    ACMediaRecorderStatusReady,
    ACMediaRecorderStatusStarted,
    ACMediaRecorderStatusRecording,
    ACMediaRecorderStatusFailed
};

@class ACMediaRecorder;

@protocol ACMediaRecordDelegate <NSObject>


/**
 在此回调调用过之后方可调用视频录制(不影响拍照)
 */
- (void)recorderDidPreparedToRecordVideo:(ACMediaRecorder *)recorder;

- (void)recorderDidStartRecordVideo:(ACMediaRecorder *)recorder;

- (void)recorderDidStopRecordVideo:(ACMediaRecorder *)recorder;

- (void)recorder:(ACMediaRecorder *)recorder succeededRecordVideoToFileURL:(NSURL *)fileURL thumbImage:(UIImage *)thumbImage;

- (void)recorder:(ACMediaRecorder *)recorder failedRecordVideoWithError:(NSError *)error;

- (void)recorder:(ACMediaRecorder *)recorder succeededTakeImage:(UIImage *)image;

@end

@interface ACMediaRecorder : NSObject

@property (assign, nonatomic) ACMediaRecorderStatus           status;

@property (strong, nonatomic) ACCamPreviewView                *previewView;

@property (assign, nonatomic) NSTimeInterval                        totalInterval;

@property (weak, nonatomic)   id<ACMediaRecordDelegate>       delegate;

@property (assign, nonatomic, getter=isVideoRecordPrepared) BOOL    videoRecordPrepared;

@property (assign, nonatomic, getter=isRecordingVideo) BOOL         recordingVideo;

/**
 录制低于一秒时,是否拍照,YES-删除录制的视频并拍照,NO-仍然录制视频并回调给代理,默认NO
 */
@property (assign, nonatomic) BOOL                              takeImageOnShortRecord;

+ (instancetype)sharedRecorder;


/**
 打开摄像头
 */
- (void)openCamera;


/**
 关闭摄像头
 */
- (void)closeCamera;


/**
 开启/关闭闪光灯
 */
- (void)switchFlash;

/**
 切换前后摄像头
 */
- (void)changeCamera;


/**
 聚焦

 @param point 聚焦点
 */
- (void)setFocusPoint:(CGPoint)point;

/**
 开始录制

 @param mode 照片/视频
 */
- (void)startRecordWithMode:(ACMediaRecorderMode)mode;


/**
 结束录制视频
 */
- (void)stopRecord;


/**
 删除上一次拍摄的照片或视频
 */
- (void)removeLastResult;

@end
