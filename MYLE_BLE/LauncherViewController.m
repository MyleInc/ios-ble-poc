//
//  LauncherViewController.m
//  CBTutorial
//
//  Created by cxphong-macmini on 12/20/14.
//  Copyright (c) 2014 Mobiletuts. All rights reserved.
//

#import "LauncherViewController.h" 
#import "CBCentralManagerViewController.h"

@interface LauncherViewController ()

@end

@implementation LauncherViewController {
    NSString *initialPassword;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Hide keyboard when user touch outside textfield
    UITapGestureRecognizer *tap =[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(dismissKeyboard)];
    [self.view addGestureRecognizer:tap];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

// Solve topbar hide content
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if([self respondsToSelector:@selector(edgesForExtendedLayout)])
        [self setEdgesForExtendedLayout:UIRectEdgeBottom];
    
    /** Set title Navigation ControlBar*/
    UINavigationController *navCon  = (UINavigationController*) [self.navigationController.viewControllers objectAtIndex:0];
    navCon.navigationItem.title = @"Launcher";
    
    /** Load old password */
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    initialPassword = [defaults valueForKey:@"PASSWORD"];
    if (initialPassword == nil) initialPassword = @"1234abcd";
    self.tfPassword.text = initialPassword;
}

// Hide keyboard when tocuch outside
- (void)dismissKeyboard {
    [self.tfPassword resignFirstResponder];
}

- (IBAction)tfExit:(id)sender {
    [sender resignFirstResponder];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Make sure your segue name in storyboard is the same as this line
    if ([[segue identifier] isEqualToString:@"BLE"])
    {
        // Get reference to the destination view controller
       CBCentralManagerViewController *vc = [segue destinationViewController];
        
        // Pass any objects to the view controller here, like...
        [vc setInitialPassword:self.tfPassword.text];
    }
}

@end
