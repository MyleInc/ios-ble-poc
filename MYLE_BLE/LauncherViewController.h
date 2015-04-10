//
//  LauncherViewController.h
//  CBTutorial
//
//  Created by cxphong-macmini on 12/20/14.
//  Copyright (c) 2014 Mobiletuts. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LauncherViewController : UIViewController
@property (weak, nonatomic) IBOutlet UITextField *tfPassword;
- (IBAction)tfExit:(id)sender;
- (IBAction)start:(id)sender;
@property (weak, nonatomic) IBOutlet UIButton *btStart;


@end
