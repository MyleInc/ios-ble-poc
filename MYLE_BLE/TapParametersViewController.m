//
//  ParameterViewController.m
//  Myle
//
//  Created by cxphong-macmini on 12/25/14.
//  Copyright (c) 2014 MYLE. All rights reserved.
//

#import "TapParametersViewController.h"
#import "TapManager.h"
#import "Globals.h"


@implementation TapParametersViewController {
    TapManager *_tap;
    ReadParameterListener _listenerFn;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"Parameters";
    
    _tap = [TapManager shared];
    
    // subscribe to tap parameter read notifications
    TapParametersViewController *this = self;
    _listenerFn = ^(NSString *par, NSUInteger intValue, NSString *strValue){
        [this onParameterRead:par intValue:intValue strValue:strValue];
    };
    [_tap addParameterReadListener:_listenerFn];
    
    self.scrollView.contentSize = CGSizeMake(self.scrollView.superview.frame.size.width, 600);
    
    self.tfBATTERY_LEVEL.text = batteryValueStr;
    
    [self readAll];
}


- (void)readAll {
    if (![_tap isConnected]) {
        NSLog(@"Tap not connected");
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Tap connection"
                                                        message:@"Tap is not found"
                                                       delegate:nil
                                              cancelButtonTitle:@"Close"
                                              otherButtonTitles:nil];
        return [alert show];
    }
    
    self.tvUUID.text = [_tap getCurrentTapUUID];
    
    [_tap sendReadRECLN];
    [_tap sendReadPAUSELEVEL];
    [_tap sendReadPAUSELEN];
    [_tap sendReadACCELERSENS];
    [_tap sendReadMIC];
    [_tap sendReadBTLOC];
    [_tap sendReadUUID];
    [_tap sendReadVERSION];
    [_tap sendReadBATTERY_LEVEL];
    
    // get current password
 //   self.tfPASSWORD.text = [_tap getCurrentTapPassword];
}


- (void)onParameterRead:(NSString*)par intValue:(NSUInteger)intValue strValue:(NSString*)strValue {
    if ([par isEqual: @"RECLN"]) {
        self.tfRECLN.text = [NSString stringWithFormat:@"%lu", (unsigned long)intValue];
    } else if ([par isEqual: @"PAUSELEVEL"]) {
        self.tfPAUSE_LEVEL.text = [NSString stringWithFormat:@"%lu", (unsigned long)intValue];
    } else if ([par isEqual: @"PAUSELEN"]) {
        self.tfPAUSE_LEN.text = [NSString stringWithFormat:@"%lu", (unsigned long)intValue];
    } else if ([par isEqual: @"ACCELERSENS"]) {
        self.tfACCELER_SENS.text = [NSString stringWithFormat:@"%lu", (unsigned long)intValue];
    } else if ([par isEqual: @"MIC"]) {
        self.tfMIC.text = [NSString stringWithFormat:@"%lu", (unsigned long)intValue];
    } else if ([par isEqual: @"BTLOC"]) {
        self.tfBTLOC.text = [NSString stringWithFormat:@"%lu", (unsigned long)intValue];
    } else if ([par isEqual: @"VERSION"]) {
        NSLog(@"OK = \"%@\"", strValue);
        self.tfVERSION.text = strValue;
    } else if ([par isEqual: @"UUID"]) {
        NSLog(@"UUID = \"%@\"", strValue);
        self.tvUUID.text = strValue;
    }

    self.tfBATTERY_LEVEL.text = batteryValueStr;
}


- (IBAction)writeAll:(id)sender {
    [_tap sendWriteRECLN:[self formatString:[self.tfRECLN text] numberDigit:2]];
    [_tap sendWritePAUSELEVEL:[self formatString:[self.tfPAUSE_LEVEL text] numberDigit:3]];
    [_tap sendWritePAUSELEN:[self formatString:[self.tfPAUSE_LEN text] numberDigit:2]];
    [_tap sendWriteACCELERSENS:[self formatString:[self.tfACCELER_SENS text] numberDigit:3]];
    [_tap sendWriteMIC:[self formatString:[self.tfMIC text] numberDigit:3]];
    [_tap sendWriteBTLOC:[self formatString:[self.tfBTLOC text] numberDigit:1]];
    [_tap sendWritePASSWORD:self.tfPASSWORD.text];
    
    // save password in user defaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:self.tfPASSWORD.text forKey:SETTINGS_PERIPHERAL_PASS];
    [defaults synchronize];
}


// Format String to match specified number of characters
- (NSString *)formatString:(NSString *)data numberDigit: (NSUInteger)num {
    if (data.length == num) { return data; }
    
    NSMutableString *ms = [data mutableCopy];
    for (int i = 0; i < num - data.length; i++) {
        [ms insertString:@"0" atIndex:0];
    }
    
    return ms;
}


- (IBAction)clickReset:(id)sender {
    // Forget this device
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:nil forKey:SETTINGS_PERIPHERAL_UUID];
    [defaults setValue:nil forKey:SETTINGS_PERIPHERAL_PASS];
    [defaults synchronize];
    
    [_tap forgetCurrent];
    
    // Show notification
    UIAlertView *alert =[[UIAlertView alloc] initWithTitle: @"Reset complete"
                                                   message: @"" delegate: nil
                                         cancelButtonTitle: @"OK" otherButtonTitles:nil];
    [alert show];
}


- (IBAction)back:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    if (![[self.navigationController viewControllers] containsObject: self]) {      
        [_tap removeParameterReadListener:_listenerFn];
    }
}

@end
