//
//  LauncherViewController.m
//  CBTutorial
//
//  Created by cxphong-macmini on 12/20/14.
//  Copyright (c) 2014 Mobiletuts. All rights reserved.
//

#import "LauncherViewController.h" 
#import "CBCentralManagerViewController.h"
#import "TapManager.h"
#import "Globals.h"


@interface LauncherViewController ()

@end


@implementation LauncherViewController {
    NSString *initialPassword;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tfPassword.text = DEFAULT_TAP_PASSWORD;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


// Solve topbar hide content
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if([self respondsToSelector:@selector(edgesForExtendedLayout)])
        [self setEdgesForExtendedLayout:UIRectEdgeBottom];
    
    /** Set title Navigation ControlBar*/
    UINavigationController *navCon  = (UINavigationController*) [self.navigationController.viewControllers objectAtIndex:0];
    navCon.navigationItem.title = @"Login to Tap";
}


- (IBAction)start:(id)sender {

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *uuid = [defaults valueForKey:SETTINGS_PERIPHERAL_UUID];
    
    TapManager *tap = [TapManager shared];
    [tap connect:[tap getPeripheralByUUID:uuid] pass:self.tfPassword.text];
    
    [self.navigationController popViewControllerAnimated:YES];
}


@end
