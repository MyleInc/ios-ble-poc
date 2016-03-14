//
//  ParameterViewController.h
//  Myle
//
//  Created by cxphong-macmini on 12/25/14.
//  Copyright (c) 2014 MYLE. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TapParametersViewController : UIViewController <UITextFieldDelegate>


@property (weak, nonatomic) IBOutlet UITextField *tfRECLN;

@property (weak, nonatomic) IBOutlet UITextField *tfMIC;

@property (weak, nonatomic) IBOutlet UITextField *tfPAUSE_LEVEL;

@property (weak, nonatomic) IBOutlet UITextField *tfPAUSE_LEN;

@property (weak, nonatomic) IBOutlet UITextField *tfACCELER_SENS;

@property (weak, nonatomic) IBOutlet UITextField *tfPASSWORD;

@property (weak, nonatomic) IBOutlet UITextField *tfBATTERY_LEVEL;

@property (weak, nonatomic) IBOutlet UITextView *tvUUID;

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;

- (IBAction)readAll:(id)sender;

- (IBAction)writeAll:(id)sender;

- (IBAction)clickReset:(id)sender;

- (IBAction)clickDisconnect:(id)sender;

- (IBAction)clickLocate:(id)sender;
@property (weak, nonatomic) IBOutlet UITextField *fwVersion;
@property (weak, nonatomic) IBOutlet UITextField *hwVersion;

@end
