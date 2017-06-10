//
//  ACMediaRecorder.m
//  AC
//
//  Created by Allen on 2017/5/17.
//  Copyright © 2017年 Cpsdna. All rights reserved.
//

#import "ACMediaRecorder.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import "ACVideoWriter.h"

@interface ACMediaRecorder ()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate,ACViideoWriterDelegate>

@property (strong, nonatomic) AVCaptureSession                  *session;

@property (nonatomic) dispatch_queue_t                          sessionQueue;

@property (assign, nonatomic) AVCaptureDeviceInput              *videoDeviceInput;

@property (assign, nonatomic) AVCaptureDeviceInput              *audioDeviceInput;

@property (assign, nonatomic) AVCaptureStillImageOutput         *photoOutput;

@property (strong, nonatomic) AVCaptureVideoDataOutput          *videoDataOutput;

@property (strong, nonatomic) AVCaptureAudioDataOutput          *audioDataOutput;

@property (strong, nonatomic) AVCaptureDeviceDiscoverySession   *videoDeviceDiscoverySession;

@property (strong, nonatomic) ACVideoWriter               *videoWriter;

@property (strong, nonatomic) NSDictionary                      *videoCompressionSettings;

@property (strong, nonatomic) NSDictionary                      *audioCompressionSettings;

@property (strong, nonatomic) AVCaptureConnection               *audioConnection;

@property (strong, nonatomic) AVCaptureConnection               *videoConnection;

@property (nonatomic) CMFormatDescriptionRef                    outputVideoFormatDescription;

@property (nonatomic) CMFormatDescriptionRef                    outputAudioFormatDescription;

@property (assign, nonatomic) CGSize                            outputSize;

@property (strong, nonatomic) NSURL                             *tempURL;

@property (strong, nonatomic) NSDate                            *recordStartTime;

@end

@implementation ACMediaRecorder

+ (instancetype)sharedRecorder {
    static dispatch_once_t onceToken;
    static ACMediaRecorder *_sharedRecorder;
    dispatch_once(&onceToken, ^{
        _sharedRecorder = [[ACMediaRecorder alloc] init];
    });
    return _sharedRecorder;
}

#pragma mark - Setter && Getter

- (void)setPreviewView:(ACCamPreviewView *)previewView {
    _previewView = previewView;
    _previewView.videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [_previewView setSession:self.session];
}


- (BOOL)isRecordingVideo {
    return self.videoWriter.status == ACVideoWriterStatusWriting;
}

- (void)setOutputAudioFormatDescription:(CMFormatDescriptionRef)outputAudioFormatDescription {
    _outputAudioFormatDescription = outputAudioFormatDescription;
    [self checkIfVideoRecordReady];
}

- (void)setOutputVideoFormatDescription:(CMFormatDescriptionRef)outputVideoFormatDescription {
    _outputVideoFormatDescription = outputVideoFormatDescription;
    [self checkIfVideoRecordReady];
}

- (BOOL)isVideoRecordPrepared {
    return _outputAudioFormatDescription && _outputVideoFormatDescription;
}

- (void)checkIfVideoRecordReady {
    if (self.isVideoRecordPrepared && [self.delegate respondsToSelector:@selector(recorderDidPreparedToRecordVideo:)]) {
        [self.delegate recorderDidPreparedToRecordVideo:self];
    }

}

- (instancetype)init {
    if (self = [super init]) {
        _totalInterval = 10;
        _sessionQueue = dispatch_queue_create("com.cpsdna.social.media.record", DISPATCH_QUEUE_SERIAL);
        _session = [[AVCaptureSession alloc] init];
        _outputSize = CGSizeMake([UIScreen mainScreen].bounds.size.width + 1, [UIScreen mainScreen].bounds.size.height + 1);//+1解决绿边
        // Create a device discovery session.
        NSArray<AVCaptureDeviceType> *deviceTypes = @[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInDuoCamera];
        _videoDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];

    }
    return self;
}

- (void)configureSession
{
    if (self.status == ACMediaRecorderStatusStarted) return;
    NSError *error = nil;
    [self.session beginConfiguration];
    [self addVideoInputWithError:error];
    [self addAudioInputWithError:error];
    [self addPhotoOutput];
    [self addDataOutput];
    [self.session commitConfiguration];
    if (self.status == ACVideoWriterStatusIdle) self.status = ACMediaRecorderStatusReady;
    [self configCompressionSettings];
}

- (void)addVideoInputWithError:(NSError *)error {
    // 添加视频输入(优先双摄,否则广角,最后前置)
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInDuoCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    if (! videoDevice) {
        videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
        if (! videoDevice) {
            videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
        }
    }
    AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if (!videoDeviceInput) {
        NSLog(@"Could not create video device input: %@", error);
        self.status = ACMediaRecorderStatusFailed;
        [self.session commitConfiguration];
        return;
    }
    if ([self.session canAddInput:videoDeviceInput]) {
        [self.session addInput:videoDeviceInput];
        self.videoDeviceInput = videoDeviceInput;
        dispatch_async(dispatch_get_main_queue(), ^{
            UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
            AVCaptureVideoOrientation initialVideoOrientation = AVCaptureVideoOrientationPortrait;
            if (statusBarOrientation != UIInterfaceOrientationUnknown) initialVideoOrientation = (AVCaptureVideoOrientation)statusBarOrientation;
            
            self.previewView.videoPreviewLayer.connection.videoOrientation = initialVideoOrientation;
        });
    } else {
        NSLog(@"Could not add video device input to the session");
        self.status = ACMediaRecorderStatusFailed;
        [self.session commitConfiguration];
        return;
    }
}

- (void)addAudioInputWithError:(NSError *)error {
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    if (!audioDeviceInput) NSLog(@"Could not create audio device input: %@", error);
    if ([self.session canAddInput:audioDeviceInput]) {
        [self.session addInput:audioDeviceInput];
        self.audioDeviceInput = audioDeviceInput;
    } else {
        NSLog(@"Could not add audio device input to the session");
    }
}

- (void)addPhotoOutput {
    AVCaptureStillImageOutput *photoOutput = [[AVCaptureStillImageOutput alloc] init];
    if ([self.session canAddOutput:photoOutput]) {
        [self.session addOutput:photoOutput];
        self.photoOutput = photoOutput;
        self.photoOutput.highResolutionStillImageOutputEnabled = YES;
    } else {
        [self.session commitConfiguration];
        self.status = ACMediaRecorderStatusFailed;
        NSLog(@"Could not add photo device input to the session");
    }
}

- (void)addDataOutput {
    AVCaptureVideoDataOutput * videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    videoOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
    videoOutput.alwaysDiscardsLateVideoFrames = NO;
    [videoOutput setSampleBufferDelegate:self queue:self.sessionQueue];
    if ([self.session canAddOutput:videoOutput]) {
        [self.session addOutput:videoOutput];
        self.videoDataOutput = videoOutput;
        self.videoConnection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    } else {
        NSLog(@"Could not add video output to the session");
        [self.session commitConfiguration];
        return;
    }
    AVCaptureAudioDataOutput * audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [audioOutput setSampleBufferDelegate:self queue:self.sessionQueue];
    if ([self.session canAddOutput:audioOutput]) {
        [self.session addOutput:audioOutput];
        self.audioDataOutput = audioOutput;
        self.audioConnection = [self.audioDataOutput connectionWithMediaType:AVMediaTypeAudio];
    } else {
        //即使不能添加音频也可以录制视频,所以不用commit
        NSLog(@"Could not add video output to the session");
    }

}

- (void)configCompressionSettings {
    NSInteger numPixels = self.outputSize.width * self.outputSize.height;
    //每像素比特
    CGFloat bitsPerPixel = 6.0;
    NSInteger bitsPerSecond = numPixels * bitsPerPixel;
    
    // 码率和帧率设置
    NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(bitsPerSecond),
                                             AVVideoExpectedSourceFrameRateKey : @(30),
                                             AVVideoMaxKeyFrameIntervalKey : @(30),
                                             AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel };
    
    self.videoCompressionSettings = [self.videoDataOutput recommendedVideoSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4];
    
    self.videoCompressionSettings = @{ AVVideoCodecKey : AVVideoCodecH264,
                                       AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                                       AVVideoWidthKey : @(self.outputSize.height),
                                       AVVideoHeightKey : @(self.outputSize.width),
                                       AVVideoCompressionPropertiesKey : compressionProperties };
    
    // 音频设置
    self.audioCompressionSettings = @{ AVEncoderBitRatePerChannelKey : @(28000),
                                       AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                       AVNumberOfChannelsKey : @(1),
                                       AVSampleRateKey : @(22050) };
}


- (void)clearSession {
    [self.session beginConfiguration];
    if (self.videoDeviceInput && [self.session.inputs containsObject:self.videoDeviceInput]) {
        [self.session removeInput:self.videoDeviceInput];
    }
    if (self.audioDeviceInput && [self.session.inputs containsObject:self.audioDeviceInput]) {
        [self.session removeInput:self.audioDeviceInput];
    }
    if (self.photoOutput && [self.session.outputs containsObject:self.photoOutput]) {
        [self.session removeOutput:self.photoOutput];
    }
    if (self.videoDataOutput && [self.session.outputs containsObject:self.videoDataOutput]) {
        [self.session removeOutput:self.videoDataOutput];
    }
    if (self.audioDataOutput && [self.session.outputs containsObject:self.audioDataOutput]) {
        [self.session removeOutput:self.audioDataOutput];
    }
    [self.session commitConfiguration];
    self.status = ACMediaRecorderStatusIdle;
}

- (void)openCamera {
    if (self.status == ACMediaRecorderStatusStarted) return;
    dispatch_async(self.sessionQueue, ^{
        [self configureSession];
        if (self.status == ACMediaRecorderStatusReady) self.status = ACMediaRecorderStatusStarted;
        [self.session startRunning];
    });
}

- (void)closeCamera {
    dispatch_async(self.sessionQueue, ^{
        if (self.session.isRunning) [self.session stopRunning];
        [self clearSession];
    });
}

- (void)switchFlash {
    dispatch_async(self.sessionQueue, ^{
        AVCaptureDevice *currentDevice = self.videoDeviceInput.device;
        switch (currentDevice.torchMode) {
            case AVCaptureTorchModeOn:
                if ([currentDevice isTorchModeSupported:AVCaptureTorchModeOff]) {
                    [currentDevice lockForConfiguration:nil];
                    [currentDevice setTorchMode:AVCaptureTorchModeOff];
                    [currentDevice unlockForConfiguration];
                }
                break;
            case AVCaptureTorchModeOff:
            case AVCaptureTorchModeAuto:
                if ([currentDevice isTorchModeSupported:AVCaptureTorchModeOn]) {
                    [currentDevice lockForConfiguration:nil];
                    [currentDevice setTorchMode:AVCaptureTorchModeOn];
                    [currentDevice unlockForConfiguration];
                }
                break;
            default:
                break;
        } 
    });
}

- (void)changeCamera {
    dispatch_async(self.sessionQueue, ^{
        AVCaptureDevice *currentVideoDevice = self.videoDeviceInput.device;
        AVCaptureDevicePosition currentPosition = currentVideoDevice.position;
        
        AVCaptureDevicePosition preferredPosition;
        AVCaptureDeviceType preferredDeviceType;
        
        switch ( currentPosition )
        {
            case AVCaptureDevicePositionUnspecified:
            case AVCaptureDevicePositionFront:
                preferredPosition = AVCaptureDevicePositionBack;
                preferredDeviceType = AVCaptureDeviceTypeBuiltInDuoCamera;
                break;
            case AVCaptureDevicePositionBack:
                preferredPosition = AVCaptureDevicePositionFront;
                preferredDeviceType = AVCaptureDeviceTypeBuiltInWideAngleCamera;
                break;
        }
        NSArray<AVCaptureDevice *> *devices = self.videoDeviceDiscoverySession.devices;
        AVCaptureDevice *newVideoDevice = nil;
        // First, look for a device with both the preferred position and device type.
        for ( AVCaptureDevice *device in devices ) {
            if ( device.position == preferredPosition && [device.deviceType isEqualToString:preferredDeviceType] ) {
                newVideoDevice = device;
                break;
            }
        }
        // Otherwise, look for a device with only the preferred position.
        if ( ! newVideoDevice ) {
            for ( AVCaptureDevice *device in devices ) {
                if ( device.position == preferredPosition ) {
                    newVideoDevice = device;
                    break;
                }
            }
        }
        if ( newVideoDevice ) {
            AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:newVideoDevice error:NULL];
            
            [self.session beginConfiguration];
            
            // Remove the existing device input first, since using the front and back camera simultaneously is not supported.
            [self.session removeInput:self.videoDeviceInput];
            
            if ( [self.session canAddInput:videoDeviceInput] ) {
                [self.session addInput:videoDeviceInput];
                self.videoDeviceInput = videoDeviceInput;
            } else {
                [self.session addInput:self.videoDeviceInput];
            }
            
            if (self.videoConnection.isVideoStabilizationSupported) {
                self.videoConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
            }
            //不重新添加videoDataOutput的话切换摄像头之后就拿不到流了
            if (self.videoDataOutput && [self.session.outputs containsObject:self.videoDataOutput]) {
                [self.session removeOutput:self.videoDataOutput];
            }
            if (self.audioDataOutput && [self.session.outputs containsObject:self.audioDataOutput]) {
                [self.session removeOutput:self.audioDataOutput];
            }
            [self addDataOutput];
            [self.session commitConfiguration];
        }
        
    });

}

- (void)setFocusPoint:(CGPoint)point {
    AVCaptureDevice *captureDevice = self.videoDeviceInput.device;
    point = [self.previewView.videoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [captureDevice lockForConfiguration:nil];
    if ([captureDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        [captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
    }
    if ([captureDevice isFocusPointOfInterestSupported]) {
        [captureDevice setFocusPointOfInterest:point];
    }
//    if ([captureDevice isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
//        [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
//    }
//    if ([captureDevice isExposurePointOfInterestSupported]) {
//        [captureDevice setExposurePointOfInterest:point];
//    }
    [captureDevice unlockForConfiguration];
}

- (void)startRecordWithMode:(ACMediaRecorderMode)mode {
    switch (mode) {
        case ACMediaRecorderModePhoto: {
            [self startPhototOutputRecord];
        }
            break;
        case ACMediaRecorderModeVideo: {
            [self startVideoRecord];
        }
            break;
        default:
            break;
    }
}

- (void)stopRecord {
    if (!self.isRecordingVideo) return;
    dispatch_async(self.sessionQueue, ^{
        if (self.takeImageOnShortRecord && [[NSDate date] timeIntervalSinceDate:self.recordStartTime] <= 1) {
            [self.videoWriter cancelWriting];
            [self removeLastResult];
            self.status = ACMediaRecorderStatusStarted;//回到已启动状态
            [self startRecordWithMode:ACMediaRecorderModePhoto];
        } else {
            [self.videoWriter stopWriting];
        }
        if ([self.delegate respondsToSelector:@selector(recorderDidStopRecordVideo:)]) {
            [self.delegate recorderDidStopRecordVideo:self];
        }
    });
}

- (void)startPhototOutputRecord {
    dispatch_async(self.sessionQueue, ^{
        [self.photoOutput captureStillImageAsynchronouslyFromConnection:[self.photoOutput connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *image = [UIImage imageWithData:imageData];
            if (self.videoDeviceInput.device.position == AVCaptureDevicePositionFront) {//前置摄像头做镜像操作
                image = [UIImage imageWithCGImage:image.CGImage scale:1 orientation:UIImageOrientationLeftMirrored];
            }
            if ([self.delegate respondsToSelector:@selector(recorder:succeededTakeImage:)]) {
                [self.delegate recorder:self succeededTakeImage:image];
            }
        }];
    });
}

- (void)startVideoRecord {
    if (!self.isVideoRecordPrepared) {
        NSDictionary *errorDict = @{ NSLocalizedDescriptionKey : @"视频录制配置尚未完成,请稍后重试",
                                     NSLocalizedFailureReasonErrorKey : @"视频录制配置尚未完成,请稍后重试" };
        NSError *error = [NSError errorWithDomain:@"com.cpsdna.socal.media.writer.initialFailed" code:0 userInfo:errorDict];
        if ([self.delegate respondsToSelector:@selector(recorder:failedRecordVideoWithError:)]) {
            [self.delegate recorder:self failedRecordVideoWithError:error];
        }
        return;
    }
    NSString *uuidStr = [NSUUID UUID].UUIDString;
    NSURL *targetURL = [NSURL fileURLWithPath:[[[self mediaCacheDir] stringByAppendingPathComponent:uuidStr] stringByAppendingPathExtension:@"mp4"]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:targetURL.path]) {
        [[NSFileManager defaultManager] removeItemAtURL:targetURL error:nil];
    }
    self.videoWriter = [[ACVideoWriter alloc] initWithTempFilePath:targetURL.path];
    self.videoWriter.delegate = self;
    [self.videoWriter addVideoTrackWithSourceFormatDescription:self.outputVideoFormatDescription settings:self.videoCompressionSettings];
    [self.videoWriter addAudioTrackWithSourceFormatDescription:self.outputAudioFormatDescription settings:self.audioCompressionSettings];
    if ([self.videoWriter startWriting]) {
        self.status = ACMediaRecorderStatusRecording;
        self.recordStartTime = [NSDate date];
        if ([self.delegate respondsToSelector:@selector(recorderDidStartRecordVideo:)]) {
            [self.delegate recorderDidStartRecordVideo:self];
        }
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopRecord) object:nil];
        [self performSelector:@selector(stopRecord) withObject:nil afterDelay:self.totalInterval];
    }
}

- (CGFloat)getfileSize:(NSString *)path
{
    NSDictionary *outputFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    return (CGFloat)[outputFileAttributes fileSize]/1024.00 /1024.00;
}

- (void)saveResultToSystemAlbumFrom:(NSURL *)outputFileURL {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status ) {
        if ( status == PHAuthorizationStatusAuthorized ) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                PHAssetCreationRequest *creationRequest = [PHAssetCreationRequest creationRequestForAsset];
                [creationRequest addResourceWithType:PHAssetResourceTypeVideo fileURL:outputFileURL options:options];
            } completionHandler:^( BOOL success, NSError *error ) {
                if (!success) NSLog( @"Could not save movie to photo library: %@", error );
            }];
        }
    }];
}

- (void)removeLastResult {
    if (self.tempURL && [[NSFileManager defaultManager] fileExistsAtPath:self.tempURL.path]) {
        [[NSFileManager defaultManager] removeItemAtPath:self.tempURL.path error:nil];
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate AVCaptureAudioDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (connection == self.videoConnection){
        if (!self.outputVideoFormatDescription) {
            @synchronized(self) {
                CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
                self.outputVideoFormatDescription = CFRetain(formatDescription);
            }
        } else {
            @synchronized(self) {
                if (self.status == ACMediaRecorderStatusRecording){
                    [self.videoWriter appendVideoSampleBuffer:sampleBuffer];
                }
            }
        }
    } else if (connection == self.audioConnection ){
        if (!self.outputAudioFormatDescription) {
            @synchronized(self) {
                CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
                self.outputAudioFormatDescription = CFRetain(formatDescription);
            }
        } else {
            @synchronized(self) {
                if (self.status == ACMediaRecorderStatusRecording){
                    [self.videoWriter appendAudioSampleBuffer:sampleBuffer];
                }
            }
        }
    }
}


#pragma mark - ACViideoWriterDelegate

- (void)writer:(ACVideoWriter *)writer succeededWriteTo:(NSURL *)fileURL firstFrame:(UIImage *)image {
    self.status = ACMediaRecorderStatusStarted;//回到已启动状态
    self.videoWriter = nil;
    NSLog(@"FileSize:%f",[self getfileSize:fileURL.path]);
    if ([self.delegate respondsToSelector:@selector(recorder:succeededRecordVideoToFileURL:thumbImage:)]) {
        [self.delegate recorder:self succeededRecordVideoToFileURL:fileURL thumbImage:image];
    }
}

- (void)writer:(ACVideoWriter *)writer failedWriteWithError:(NSError *)error {
    NSLog(@"写入视频失败:%@",error);
}

- (void)dealloc {
    CFRelease(self.outputAudioFormatDescription);
    CFRelease(self.outputVideoFormatDescription);
}

- (NSString *)mediaCacheDir {
    NSString *documentDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *cacheDir = [documentDir stringByAppendingPathComponent:@"OFSocialMomentMedia"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:cacheDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:cacheDir withIntermediateDirectories:NO attributes:nil error:nil];
    }
    return cacheDir;
}


@end
