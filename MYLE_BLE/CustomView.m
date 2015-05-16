//
//  CustomView.m
//  Myle
//
//  Created by Mikalai on 1/2/15.
//  Copyright (c) 2015 Myle Electronics Corp. All rights reserved.
//

#import "CustomView.h"

@implementation CustomView


- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    // hide keyboard for any touch outside of first responder
    // particularly it helps us to hide keyboard for serach text field
    
    UIView *view = [super hitTest:point withEvent:event];
    
    // do not hide keyboard when UITextField clear button is tapped
    if (![view isMemberOfClass:[UIButton class]] && ![view.superview isMemberOfClass:[UITextField class]])
    {
        [self endEditing:YES];
    }
    
    return view;
}

@end
