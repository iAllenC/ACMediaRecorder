//
//  ACRecordButton.h
//  AC
//
//  Created by Allen on 2017/5/24.
//  Copyright © 2017年 Cpsdna. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ACRecordButton;

@protocol ACRecordButtonDelegate <NSObject>

- (void)recordButtonTapped:(ACRecordButton *)button;

- (void)recordButtonDidBeginLongpress:(ACRecordButton *)button;

- (void)recordButtonDidFinishLongpress:(ACRecordButton *)button;

@end

@interface ACRecordButton : UIView

@property (assign, nonatomic) NSTimeInterval duration;

@property (strong, nonatomic) UIColor                           *progressColor;

@property (assign, nonatomic, getter=isTapDisabled) BOOL        tapDisabled;

@property (assign, nonatomic, getter=isLongPressDisabled) BOOL  longPressDisabled;

@property (weak, nonatomic) id<ACRecordButtonDelegate>    delegate;

- (instancetype)initWithFrame:(CGRect)frame duration:(NSTimeInterval)duration;

- (void)restore;

@end
