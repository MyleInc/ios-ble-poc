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
    _listenerFn = ^(NSString *par, NSUInteger intValue, NSString *strValue) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [this onParameterRead:par intValue:intValue strValue:strValue];
        });
    };
    [_tap addParameterReadListener:_listenerFn];
    
    self.scrollView.contentSize = CGSizeMake(self.scrollView.superview.frame.size.width, 600);
    
    self.tfBATTERY_LEVEL.enabled = NO;
    self.tfVERSION.enabled = NO;
    
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
    [_tap sendReadMIC];
    [_tap sendReadPAUSELEVEL];
    [_tap sendReadPAUSELEN];
    [_tap sendReadACCELERSENS];
    [_tap sendReadPASSWORD];
    [_tap sendReadVERSION];
    [_tap sendReadBATTERY_LEVEL];
    
    // get current password
    //self.tfPASSWORD.text = [_tap getCurrentTapPassword];
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
    } else if ([par isEqual: @"PASSWORD"]) {
        self.tfPASSWORD.text = strValue;
    } else if ([par isEqual: @"VERSION"]) {
        self.tfVERSION.text = strValue;
    } else if ([par isEqual: @"BATTERY_LEVEL"]) {
        self.tfBATTERY_LEVEL.text = [NSString stringWithFormat:@"%lu", (unsigned long)intValue];
    }
}


- (IBAction)writeAll:(id)sender {
    [_tap sendWriteRECLN:[self byteFromString:[self.tfRECLN text]]];
    [_tap sendWriteMIC:[self byteFromString:[self.tfMIC text]]];
    [_tap sendWritePAUSELEVEL:[self byteFromString:[self.tfPAUSE_LEVEL text]]];
    [_tap sendWritePAUSELEN:[self byteFromString:[self.tfPAUSE_LEN text]]];
    [_tap sendWriteACCELERSENS:[self byteFromString:[self.tfACCELER_SENS text]]];
    [_tap sendWritePASSWORD:self.tfPASSWORD.text];
    
    // save password in user defaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:self.tfPASSWORD.text forKey:SETTINGS_PERIPHERAL_PASS];
    [defaults synchronize];
}


- (Byte)byteFromString:(NSString*)str {
    return str.intValue % 256;
}


- (IBAction)clickDisconnect:(id)sender {
    // Forget this device
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:nil forKey:SETTINGS_PERIPHERAL_UUID];
    [defaults setValue:nil forKey:SETTINGS_PERIPHERAL_PASS];
    [defaults synchronize];
    
    [_tap disconnect];
    
    [self.navigationController popViewControllerAnimated:YES];
}


- (IBAction)clickLocate:(id)sender {
    [_tap locate];
}


- (IBAction)clickReset:(id)sender {
    [_tap resetToFactoryDefaults];
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
