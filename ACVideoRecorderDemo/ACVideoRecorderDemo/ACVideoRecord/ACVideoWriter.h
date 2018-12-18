//
//  ACVideoWriter.h
//  AC
//
//  Created by Allen on 2017/5/19.
//  Copyright © 2017年 Cpsdna. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>

typedef NS_ENUM(NSUInteger, ACVideoWriterStatus) {
    ACVideoWriterStatusIdle,//初始状态
    ACVideoWriterStatusStarted,//已启动
    ACVideoWriterStatusWriting,//正在写入
    ACVideoWriterStatusStopped,//已停止
    ACVideoWriterStatusCanceled,//已取消
    ACVideoWriterStatusSucceeded,//成功
    ACVideoWriterStatusFailed//失败
};

@class ACVideoWriter;

@protocol ACViideoWriterDelegate <NSObject>

- (void)writer:(ACVideoWriter *)writer succeededWriteTo:(NSURL *)fileURL firstFrame:(UIImage *)image;

- (void)writer:(ACVideoWriter *)writer failedWriteWithError:(NSError *)error;

@end

@interface ACVideoWriter : NSObject

@property (assign, nonatomic) ACVideoWriterStatus status;

@property (weak, nonatomic)   id<ACViideoWriterDelegate> delegate;

- (instancetype)initWithTempFilePath:(NSString *)tempFilePath;


/**
 开始写入视频数据

 @return 是否成功
 */
- (BOOL)startWriting;


/**
 结束写入视频数据并生成视频文件,视频文件将在- (void)writer:(ACVideoWriter *)writer succeededWriteTo:(NSURL *)fileURL firstFrame:(UIImage *)image;回调
 */
- (void)stopWriting;


/**
 取消写入数据并删除已写入的文件
 */
- (void)cancelWriting;

- (void)addVideoTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription settings:(NSDictionary *)videoSettings;

- (void)addAudioTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription settings:(NSDictionary *)audioSettings;


- (void)appendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)appendAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end
