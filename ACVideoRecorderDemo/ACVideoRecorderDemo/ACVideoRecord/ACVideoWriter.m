//
//  ACVideoWriter.m
//  AC
//
//  Created by Allen on 2017/5/19.
//  Copyright © 2017年 Cpsdna. All rights reserved.
//

#import "ACVideoWriter.h"
#import <AVFoundation/AVFoundation.h>

@interface ACVideoWriter ()

@property (nonatomic) dispatch_queue_t writingQueue;

@property (nonatomic) dispatch_queue_t delegateCallbackQueue;

@property (strong, nonatomic) NSString *tempFilePath;

@property (strong, nonatomic) AVAssetWriter *assetWriter;

@property (assign, nonatomic,getter=isSessionStarted) BOOL sessionStarted;

@property (nonatomic) CMFormatDescriptionRef audioTrackSourceFormatDescription;

@property (nonatomic) CMFormatDescriptionRef videoTrackSourceFormatDescription;

@property (strong, nonatomic) NSDictionary *audioTrackSettings;

@property (strong, nonatomic) NSDictionary *videoTrackSettings;

@property (strong, nonatomic) AVAssetWriterInput *audioInput;

@property (strong, nonatomic) AVAssetWriterInput *videoInput;

@property (assign, nonatomic) CGAffineTransform videoTrackTransform;

@property (strong, nonatomic) UIImage *firstFrame;


@end

@implementation ACVideoWriter

- (instancetype)initWithTempFilePath:(NSString *)tempFilePath {
    if (!tempFilePath) return nil;
    self = [super init];
    if (self) {
        _delegateCallbackQueue = dispatch_queue_create("serial_queue_callback", DISPATCH_QUEUE_SERIAL );
        _writingQueue = dispatch_queue_create("serial_queue_write", DISPATCH_QUEUE_SERIAL );
        _videoTrackTransform = CGAffineTransformMakeRotation(M_PI_2);//人像方向
        _tempFilePath = tempFilePath;
    }
    return self;
}

- (void)addVideoTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription settings:(NSDictionary *)videoSettings {
    @synchronized(self) {
        self.videoTrackSourceFormatDescription = (CMFormatDescriptionRef)CFRetain(formatDescription);
        self.videoTrackSettings = [videoSettings copy];
    }
}

- (void)addAudioTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription settings:(NSDictionary *)audioSettings {
    @synchronized(self) {
        self.audioTrackSourceFormatDescription = (CMFormatDescriptionRef)CFRetain(formatDescription);
        self.audioTrackSettings = [audioSettings copy];
    }
}

- (BOOL)startWriting {
    @synchronized(self) {
        if (self.status != ACVideoWriterStatusIdle) return NO;
    }
    NSError *error = nil;
    //确保当前url文件不存在
    [[NSFileManager defaultManager] removeItemAtPath:self.tempFilePath error:&error];
    self.assetWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:self.tempFilePath] fileType:AVFileTypeMPEG4 error:&error];
    //创建添加输入
    if (!error && self.videoTrackSourceFormatDescription) {
        [self setupAssetWriterVideoInputWithSourceFormatDescription:self.videoTrackSourceFormatDescription transform:self.videoTrackTransform settings:self.videoTrackSettings error:&error];
    }
    if (!error && self.audioTrackSourceFormatDescription) {
        [self setupAssetWriterAudioInputWithSourceFormatDescription:self.audioTrackSourceFormatDescription settings:self.audioTrackSettings error:&error];
    }
    //开始
    BOOL success = NO;
    if (!error) {
        success = [self.assetWriter startWriting];
        if (!success) error = self.assetWriter.error;
    }
    @synchronized(self) {
        if (error) {
            self.status = ACVideoWriterStatusFailed;
        } else {
            self.status = ACVideoWriterStatusWriting;
        }
    }
    return success;
}

- (void)stopWriting {
    @synchronized (self) {
        if (self.status != ACVideoWriterStatusWriting) return;
        self.status = ACVideoWriterStatusStopped;
    }
    dispatch_async(self.writingQueue, ^{
        [self.assetWriter finishWritingWithCompletionHandler:^{
            if (self.assetWriter.status == AVAssetWriterStatusCompleted && [self.delegate respondsToSelector:@selector(writer:succeededWriteTo:firstFrame:)]) {
                @synchronized (self) {
                    self.status = ACVideoWriterStatusSucceeded;
                }
                dispatch_async(self.delegateCallbackQueue, ^{
                    [self.delegate writer:self succeededWriteTo:[NSURL fileURLWithPath:self.tempFilePath] firstFrame:self.firstFrame];
                });
            } else if (self.assetWriter.status == AVAssetWriterStatusFailed && [self.delegate respondsToSelector:@selector(writer:failedWriteWithError:)]) {
                @synchronized (self) {
                    self.status = ACVideoWriterStatusFailed;
                }
                dispatch_async(self.delegateCallbackQueue, ^{
                    [self.delegate writer:self failedWriteWithError:self.assetWriter.error];
                });
            }
        }];
    });
}

- (void)cancelWriting {
    @synchronized (self) {
        if (self.status != ACVideoWriterStatusWriting) return;
        self.status = ACVideoWriterStatusCanceled;
    }
    dispatch_async(self.writingQueue, ^{
        [self.assetWriter cancelWriting];
    });

}

- (void)appendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    [self appendSampleBuffer:sampleBuffer ofMediaType:AVMediaTypeVideo];
}

- (void)appendAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    [self appendSampleBuffer:sampleBuffer ofMediaType:AVMediaTypeAudio];
}


#pragma mark - Private methods

- (BOOL)setupAssetWriterAudioInputWithSourceFormatDescription:(CMFormatDescriptionRef)audioFormatDescription settings:(NSDictionary *)audioSettings error:(NSError **)errorOut {
    if ([self.assetWriter canApplyOutputSettings:audioSettings forMediaType:AVMediaTypeAudio]){
        self.audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioSettings sourceFormatHint:audioFormatDescription];
        self.audioInput.expectsMediaDataInRealTime = YES;
        
        if ([self.assetWriter canAddInput:self.audioInput]){
            [self.assetWriter addInput:self.audioInput];
        } else {
            if (errorOut) *errorOut = [self cannotSetupInputError];
            return NO;
        }
    } else {
        if (errorOut) *errorOut = [self cannotSetupInputError];
        return NO;
    }
    
    return YES;
}

- (BOOL)setupAssetWriterVideoInputWithSourceFormatDescription:(CMFormatDescriptionRef)videoFormatDescription transform:(CGAffineTransform)transform settings:(NSDictionary *)videoSettings error:(NSError **)errorOut {
    if ([self.assetWriter canApplyOutputSettings:videoSettings forMediaType:AVMediaTypeVideo]){
        self.videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings sourceFormatHint:videoFormatDescription];
        self.videoInput.expectsMediaDataInRealTime = YES;
        self.videoInput.transform = transform;
        if ([self.assetWriter canAddInput:self.videoInput]){
            [self.assetWriter addInput:self.videoInput];
        } else {
            if (errorOut) *errorOut = [self cannotSetupInputError];
            return NO;
        }
    } else {
        if (errorOut) *errorOut = [self cannotSetupInputError];
        return NO;
    }
    return YES;
}

- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer ofMediaType:(NSString *)mediaType {
    if (sampleBuffer == NULL){
        NSLog(@"你一定传了一个假的sampleBuffer");
        return;
    }
    @synchronized(self){
        if (self.status < ACVideoWriterStatusStarted){
            NSLog(@"还没准备好记录");
            return;
        }
    }
    CFRetain(sampleBuffer);
    dispatch_async(self.writingQueue, ^{
        @autoreleasepool {
            @synchronized(self) {
                if (self.status > ACVideoWriterStatusWriting) {
                    CFRelease(sampleBuffer);
                    return;
                }
            }
            if (!self.isSessionStarted && mediaType == AVMediaTypeVideo) {//只有当获取第一帧视频帧之后才开启,否则直接忽略
                [self.assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
                self.sessionStarted = YES;
                self.firstFrame = [self imageFromSampleBuffer:sampleBuffer];
            }
            if (!self.isSessionStarted) {
                CFRelease(sampleBuffer);
                return;
            }
            AVAssetWriterInput *input = (mediaType == AVMediaTypeVideo) ? self.videoInput : self.audioInput;
            if (input.readyForMoreMediaData){
                [input appendSampleBuffer:sampleBuffer];
            } else {
                NSLog( @"%@ 输入不能添加更多数据了，抛弃 buffer", mediaType );
            }
            CFRelease(sampleBuffer);
        }
    } );
}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    
    // Get the number of bytes per row for the pixel buffer
    u_int8_t *baseAddress = (u_int8_t *)malloc(bytesPerRow*height);
    memcpy( baseAddress, CVPixelBufferGetBaseAddress(imageBuffer), bytesPerRow * height     );
    
    // size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    
    //The context draws into a bitmap which is `width'
    //  pixels wide and `height' pixels high. The number of components for each
    //      pixel is specified by `space'
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst);
    
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    //CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage scale:1.0 orientation:UIImageOrientationRight];
    free(baseAddress);
    // Release the Quartz image
    CGImageRelease(quartzImage);
    return image;
}


- (NSError *)cannotSetupInputError {
    NSDictionary *errorDict = @{ NSLocalizedDescriptionKey : @"记录不能开始",
                                 NSLocalizedFailureReasonErrorKey : @"不能初始化writer" };
    return [NSError errorWithDomain:@"com.cpsdna.socal.media.writer.initialFailed" code:0 userInfo:errorDict];
}


- (void)dealloc {
    [self.assetWriter cancelWriting];
    CFRelease(self.audioTrackSourceFormatDescription);
    CFRelease(self.videoTrackSourceFormatDescription);
}


@end
