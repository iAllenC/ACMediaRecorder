//
//  ACVideoPlayView.h
//  AC
//
//  Created by Allen on 2017/5/23.
//  Copyright © 2017年 Cpsdna. All rights reserved.
//

#import <UIKit/UIKit.h>
@class AVPlayerLayer;
@class AVPlayer;
@interface ACVideoPlayView : UIView

@property (strong, nonatomic) AVPlayerLayer             *playerLayer;

@property (nonatomic, strong) AVPlayer                  *player;

@property (nonatomic, assign, getter=isMute) BOOL mute;

@property (nonatomic,getter=isPlaying)BOOL playing;

- (void)play;

- (void)stop;

@end
