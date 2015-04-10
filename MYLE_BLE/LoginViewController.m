//
//  LauncherViewController.m
//  CBTutorial
//
//  Created by cxphong-macmini on 12/20/14.
//  Copyright (c) 2014 MYLE. All rights reserved.
//

#import "LoginViewController.h" 
#import "TraceViewController.h"
#import "TapManager.h"
#import "Globals.h"


@interface LoginViewController ()

@end


@implementation LoginViewController {
    NSString *initialPassword;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"Login";
    
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
}


- (IBAction)start:(id)sender {

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *uuid = [defaults valueForKey:SETTINGS_PERIPHERAL_UUID];
    
    TapManager *tap = [TapManager shared];
    [tap connect:[tap getPeripheralByUUID:uuid] pass:self.tfPassword.text];
    
    [self.navigationController popViewControllerAnimated:YES];
}


@end
