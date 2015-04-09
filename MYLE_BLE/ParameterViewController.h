//
//  ParameterViewController.h
//  Myle
//
//  Created by cxphong-macmini on 12/25/14.
//  Copyright (c) 2014 Mobiletuts. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ParameterViewController : UIViewController <UITextFieldDelegate>


@property (weak, nonatomic) IBOutlet UITextField *tfRECLN;

@property (weak, nonatomic) IBOutlet UITextField *tfPAUSE_LEVEL;

@property (weak, nonatomic) IBOutlet UITextField *tfPAUSE_LEN;

@property (weak, nonatomic) IBOutlet UITextField *tfACCELER_SENS;

@property (weak, nonatomic) IBOutlet UITextField *tfMIC;

@property (weak, nonatomic) IBOutlet UITextField *tfPASSWORD;

@property (weak, nonatomic) IBOutlet UITextField *tfBTLOC;

@property (weak, nonatomic) IBOutlet UITextView *tvUUID;

@property (weak, nonatomic) IBOutlet UITextField *tfVERSION;

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;

- (IBAction)writeAll:(id)sender;

- (IBAction)clickReset:(id)sender;

- (IBAction)back:(id)sender;


@end
