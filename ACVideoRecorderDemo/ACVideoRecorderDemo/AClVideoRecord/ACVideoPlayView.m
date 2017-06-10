//
//  ACVideoPlayView.m
//  AC
//
//  Created by Allen on 2017/5/23.
//  Copyright © 2017年 Cpsdna. All rights reserved.
//

#import "ACVideoPlayView.h"
#import <AVFoundation/AVFoundation.h>
@interface ACVideoPlayView ()

@end

@implementation ACVideoPlayView

+ (Class)layerClass {
    return [AVPlayerLayer class];
}

- (AVPlayerLayer *)playerLayer {
    return (AVPlayerLayer *)self.layer;
}

- (void)setPlayer:(AVPlayer *)player {
    if (_player == player) return;
    if (_player) {
        [_player pause];
//        [_player.currentItem removeObserver:self forKeyPath:@"status"];
        [_player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
    }
    _player = player;
    [[self playerLayer] setPlayer:player];
    if (!_player) return;
    if (self.isMute) _player.volume = 0;
    [_player play];
//    [_player.currentItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [_player.currentItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(moviePlayEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
}

- (void)play {
    [self.player play];
}

- (void)stop {
    [self.player pause];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context{
    AVPlayerItem * playItem = (AVPlayerItem*)object;
    if ([keyPath isEqualToString:@"status"]) {
        if (playItem.status == AVPlayerStatusReadyToPlay) {
            if (self.player) [self.player play];
        }
    } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        NSArray *array=playItem.loadedTimeRanges;
        CMTimeRange timeRange = [array.firstObject CMTimeRangeValue];//本次缓冲时间范围
        if (timeRange.duration.value > 0)  {
            if (self.player.rate == 0) [self.player play];
        }
    }
}

- (void)moviePlayEnd:(NSNotification *)notification {
    if (notification.object != self.player.currentItem) return;
    [self.player seekToTime:CMTimeMake(0, 1)];
    [self.player play];
}

- (void)dealloc {
    if (self.player) {
        [self.player pause];
//        [self.player.currentItem removeObserver:self forKeyPath:@"status"];
        [self.player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



@end
