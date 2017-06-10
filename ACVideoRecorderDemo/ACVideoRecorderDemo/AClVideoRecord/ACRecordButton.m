//
//  ACRecordButton.m
//  AC
//
//  Created by Allen on 2017/5/24.
//  Copyright © 2017年 Cpsdna. All rights reserved.
//

#import "ACRecordButton.h"
#define OUT_INSET_ORIGIN 30
@interface ACRoundProgress : UIView

@property (assign, nonatomic) NSTimeInterval duration;

@property (assign, nonatomic) CGFloat progresss;

@property (strong, nonatomic) NSTimer *timer;

@property (strong, nonatomic) UIColor *strokColor;

- (void)startAnimation;

- (void)stopAnimation;

@end

@implementation ACRoundProgress

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    if (self.progresss == 0) return;
    CGFloat lineWidth = 5, radius = self.frame.size.width/2 - lineWidth/2;
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(self.frame.size.width/2, lineWidth/2)];
    CGFloat startAngle = - M_PI_2, endAngle = (M_PI * 2) * self.progresss + startAngle;
    [path addArcWithCenter:CGPointMake(self.frame.size.width/2, self.frame.size.width/2) radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
    [self.strokColor setStroke];
    path.lineWidth = lineWidth;
    [path stroke];
}

- (void)startAnimation {
    [self startTimer];
}

- (void)stopAnimation {
    [self stopTimer];
    self.progresss = 0;
}

- (void)startTimer {
    [self stopTimer];
    __weak typeof(self) weakSelf = self;
    NSTimeInterval interval = 0.05;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer * _Nonnull timer) {
        weakSelf.progresss += interval/weakSelf.duration;
        if (weakSelf.progresss >= 1.0) [weakSelf stopTimer];
    }];
}

- (void)stopTimer {
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)setProgresss:(CGFloat)progresss {
    _progresss = progresss;
    [self setNeedsDisplay];
}

@end


@interface ACRecordButton ()
@property (assign, nonatomic) CGFloat   outInset;
@property (strong, nonatomic) NSTimer   *expandTimer;
@property (strong, nonatomic) UIView    *centerCircle;
@property (strong, nonatomic) UIView    *outCircle;
@property (strong, nonatomic) ACRoundProgress *progress;
@property (strong, nonatomic) UITapGestureRecognizer    *tap;
@property (strong, nonatomic) UILongPressGestureRecognizer  *longPress;
@end

@implementation ACRecordButton

- (void)setTapDisabled:(BOOL)tapDisabled {
    _tapDisabled = tapDisabled;
    if (_tapDisabled && [self.gestureRecognizers containsObject:self.tap]) {
        [self removeGestureRecognizer:self.tap];
    } else if (!_tapDisabled && ![self.gestureRecognizers containsObject:self.tap]) {
        [self addGestureRecognizer:self.tap];
    }
}

- (void)setLongPressDisabled:(BOOL)longPressDisabled {
    _longPressDisabled = longPressDisabled;
    if (_longPressDisabled && [self.gestureRecognizers containsObject:self.longPress]) {
        [self removeGestureRecognizer:self.longPress];
    } else if (!_longPressDisabled && ![self.gestureRecognizers containsObject:self.longPress]){
        [self addGestureRecognizer:self.longPress];
    }
}

- (instancetype)initWithFrame:(CGRect)frame duration:(NSTimeInterval)duration {
    if (self = [super initWithFrame:frame]) {
        _duration = duration;
        [self setup];
    }
    return self;
}

- (void)setup {
    self.backgroundColor = [UIColor clearColor];
    _outInset = OUT_INSET_ORIGIN;
    CGFloat centerWidth = self.frame.size.width - 60, outWidth = self.frame.size.width - _outInset;
    _outCircle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, outWidth, outWidth)];
    _outCircle.center = CGPointMake(self.frame.size.width/2, self.frame.size.width/2);
    _outCircle.backgroundColor = [UIColor lightGrayColor];
    _outCircle.alpha = 0.6;
    _outCircle.layer.cornerRadius = outWidth/2;
    [self addSubview:_outCircle];
    _centerCircle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, centerWidth, centerWidth)];
    _centerCircle.center = _outCircle.center;
    _centerCircle.backgroundColor = [UIColor whiteColor];
    _centerCircle.layer.cornerRadius = centerWidth/2;
    [self addSubview:_centerCircle];
    _progress = [[ACRoundProgress alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.width)];
    _progress.backgroundColor = [UIColor clearColor];
    _progress.duration = self.duration;
    [self addSubview:_progress];
    self.longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPress:)];
    self.longPress.minimumPressDuration = 0.25;
    [self addGestureRecognizer:self.longPress];
    self.tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    [self addGestureRecognizer:self.tap];

}

- (void)setProgressColor:(UIColor *)progressColor {
    _progressColor = progressColor;
    self.progress.strokColor = progressColor;
}

- (void)startExpandWithCompletion:(void(^)())completion {
    [self stopExpand];
    NSTimeInterval totalDuration = 0.1, repeatTimes = 30, interval = totalDuration/repeatTimes, step = self.outInset/repeatTimes;
    __weak typeof(self) weakSelf = self;
    self.expandTimer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer * _Nonnull timer) {
        weakSelf.outInset -= step;
        CGFloat targetWidth = weakSelf.frame.size.width - weakSelf.outInset;
        CGRect originFrame =weakSelf.outCircle.frame;
        weakSelf.outCircle.frame = CGRectMake(originFrame.origin.x, originFrame.origin.y, targetWidth, targetWidth);
        weakSelf.outCircle.center = self.centerCircle.center;
        weakSelf.outCircle.layer.cornerRadius = (weakSelf.frame.size.width - weakSelf.outInset)/2;
        if (weakSelf.outInset <= 0.5) {
            [weakSelf stopExpand];
            if (completion)completion();
        }
    }];
}

- (void)stopExpand {
    if (self.expandTimer) {
        [self.expandTimer invalidate];
        self.expandTimer = nil;
    }
}

- (void)shrink {
    self.outInset = OUT_INSET_ORIGIN;
    CGFloat outWidth = self.frame.size.width - self.outInset;
    CGFloat targetWidth = self.frame.size.width - self.outInset;
    CGRect originFrame = self.outCircle.frame;
    self.outCircle.frame = CGRectMake(originFrame.origin.x, originFrame.origin.y, targetWidth, targetWidth);
    self.outCircle.center = self.centerCircle.center;
    self.outCircle.layer.cornerRadius = outWidth/2;
}

- (void)onLongPress:(UILongPressGestureRecognizer *)longPress {
    if (longPress.state == UIGestureRecognizerStateBegan) {
        [self startExpandWithCompletion:^{
            if (longPress.state == UIGestureRecognizerStateBegan || longPress.state == UIGestureRecognizerStateChanged) {
                [self.progress startAnimation];
            } else {
                [self shrink];
            }
        }];
        if ([self.delegate respondsToSelector:@selector(recordButtonDidBeginLongpress:)]) {
            [self.delegate recordButtonDidBeginLongpress:self];
        }
    } else if (longPress.state == UIGestureRecognizerStateEnded) {
        [self.progress stopAnimation];
        [self shrink];
        if ([self.delegate respondsToSelector:@selector(recordButtonDidFinishLongpress:)]) {
            [self.delegate recordButtonDidFinishLongpress:self];
        }
    }
}

- (void)onTap:(UITapGestureRecognizer *)tap {
    if ([self.delegate respondsToSelector:@selector(recordButtonTapped:)]) {
        [self.delegate recordButtonTapped:self];
    }
}

#pragma mark - Public

-(void)restore {
    [self stopExpand];
    [self shrink];
    [self.progress stopAnimation];
}

@end
