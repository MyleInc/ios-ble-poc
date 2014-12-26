//
//  ParameterViewController.m
//  MYLE_BLE
//
//  Created by cxphong-macmini on 12/25/14.
//  Copyright (c) 2014 Mobiletuts. All rights reserved.
//

#import "ParameterViewController.h"

@interface ParameterViewController ()
    - (NSData *)makeUpdateRECLN:(NSString *)value;
    - (NSData *)makeUpdatePAUSELEVEL:(NSString *)value;
    - (NSData *)makeUpdatePAUSELEN:(NSString *)value;
    - (NSData *)makeUpdateACCELERSENS:(NSString *)value;
    - (NSData *)makeUpdateMIC:(NSString *)value;
    - (NSData *)makeUpdatePASSWORD:(NSString *)value;

    - (NSData *)makeReadRECLN;
    - (NSData *)makeReadBTLOC;
    - (NSData *)makeReadPAUSELEVEL;
    - (NSData *)makeReadPAUSELEN;
    - (NSData *)makeReadACCELERSENS;
    - (NSData *)makeReadMIC;
@end

@implementation ParameterViewController {
    CBPeripheral *peripheral;
    CBCentralManagerViewController *centralViewController;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // Set title Navigation ControlBar
    UINavigationController *navCon  = (UINavigationController*) [self.navigationController.viewControllers objectAtIndex:2];
    navCon.navigationItem.title = @"Parameter";
    
    //Set delegate
    centralViewController.delegate = self;
}

// Solve topbar hide content
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if([self respondsToSelector:@selector(edgesForExtendedLayout)])
        [self setEdgesForExtendedLayout:UIRectEdgeBottom];
    
    self.scrollView.contentOffset = CGPointMake(0, 64);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) setPeripheral: (CBCentralManagerViewController *)viewcontroller peripheral: (CBPeripheral *)_peripheral{
    self->centralViewController = viewcontroller;
    self->peripheral = _peripheral;
}

- (IBAction)tfExit:(id)sender {
}

- (IBAction)readRECLN:(id)sender {
    NSData *data = [self makeReadRECLN];
    [self send:data];
}

- (IBAction)writeRECLN:(id)sender {
    NSData *data = [self makeUpdateRECLN:[self formatString:[self.tfRECLN text] numberDigit:2]];
    
    [self send:data];
}
- (IBAction)readPAUSE_LEVEL:(id)sender {
    NSData *data = [self makeReadPAUSELEVEL];
    
    [self send:data];
}

- (IBAction)writePAUSE_LEVEL:(id)sender {
    NSData *data = [self makeUpdatePAUSELEVEL:[self formatString:[self.tfPAUSE_LEVEL text] numberDigit:3]];
    
    [self send:data];
}
- (IBAction)readPAUSE_LEN:(id)sender {
    NSData *data = [self makeReadPAUSELEN];
    
   [self send:data];
}

- (IBAction)writePAUSE_LEN:(id)sender {
    NSData *data = [self makeUpdatePAUSELEN:[self formatString:[self.tfPAUSE_LEN text] numberDigit:2]];
    
    [self send:data];
}
- (IBAction)readACCELER_SENS:(id)sender {
    NSData *data = [self makeReadACCELERSENS];
    
    [self send:data];
}

- (IBAction)writeACCELER_SENS:(id)sender {
    NSData *data = [self makeUpdateACCELERSENS:[self formatString:[self.tfACCELER_SENS text] numberDigit:3]];

    [self send:data];
}
- (IBAction)readMIC:(id)sender {
    NSData *data = [self makeReadMIC];
    
   [self send:data];
}

- (IBAction)writeMIC:(id)sender {
    NSData *data = [self makeUpdateMIC:[self formatString:[self.tfMIC text] numberDigit:3]];
    
   [self send:data];
}
- (IBAction)readPASSWORD:(id)sender {
    /** Load old password */
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *pass = [defaults valueForKey:@"PASSWORD"];
    if (pass == nil) pass = @"1234abcd";
    self.tfPASSWORD.text = pass;
}

- (IBAction)writePASSWORD:(id)sender {
    NSData *data = [self makeUpdatePASSWORD:self.tfPASSWORD.text];
    // Save pass
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:self.tfPASSWORD.text forKey:@"PASSWORD"];
    [defaults synchronize];
    
    [self send:data];
}

- (IBAction)readBTLOC:(id)sender {
    NSData *data = [self makeReadBTLOC];
    
    [self send:data];
}


- (void) send: (NSData *) data {
    [self->peripheral writeValue:data forCharacteristic:[[[self->peripheral.services objectAtIndex:0] characteristics] objectAtIndex:1] type:CBCharacteristicWriteWithoutResponse];
}

/************ UPDATE PARAMETER ****************/

// Update Parameter RECLN
- (NSData *)makeUpdateRECLN: (NSString *)value {
    NSData *data;
    
    Byte *byteData = (Byte*)malloc(11);
    byteData[0] = [@"5" characterAtIndex:0];
    byteData[1] = [@"5" characterAtIndex:0];
    byteData[2] = [@"0" characterAtIndex:0];
    byteData[3] = [@"2" characterAtIndex:0];
    byteData[4] = [@"R" characterAtIndex:0];
    byteData[5] = [@"E" characterAtIndex:0];
    byteData[6] = [@"C" characterAtIndex:0];
    byteData[7] = [@"L" characterAtIndex:0];
    byteData[8] = [@"N" characterAtIndex:0];
    byteData[9] = [value characterAtIndex:0];
    byteData[10] = [value characterAtIndex:1];
    
    data = [NSData dataWithBytes:byteData length:11];
    
    return data;
}

// Update Parameter PAUSE_LEVEL
- (NSData *)makeUpdatePAUSELEVEL: (NSString *)value {
    NSData *data;
    
    Byte *byteData = (Byte*)malloc(17);
    byteData[0] = [@"5" characterAtIndex:0];
    byteData[1] = [@"5" characterAtIndex:0];
    byteData[2] = [@"0" characterAtIndex:0];
    byteData[3] = [@"2" characterAtIndex:0];
    byteData[4] = [@"P" characterAtIndex:0];
    byteData[5] = [@"A" characterAtIndex:0];
    byteData[6] = [@"U" characterAtIndex:0];
    byteData[7] = [@"S" characterAtIndex:0];
    byteData[8] = [@"E" characterAtIndex:0];
    byteData[9] = [@"L" characterAtIndex:0];
    byteData[10] = [@"E" characterAtIndex:0];
    byteData[11] = [@"V" characterAtIndex:0];
    byteData[12] = [@"E" characterAtIndex:0];
    byteData[13] = [@"L" characterAtIndex:0];
    byteData[14] = [value characterAtIndex:0];
    byteData[15] = [value characterAtIndex:1];
    byteData[16] = [value characterAtIndex:2];
    
    data = [NSData dataWithBytes:byteData length:17];
    
    return data;
}

// Update Parameter PAUSE_LEN
- (NSData *)makeUpdatePAUSELEN: (NSString *)value{
    NSData *data;
    
    Byte *byteData = (Byte*)malloc(14);
    byteData[0] = [@"5" characterAtIndex:0];
    byteData[1] = [@"5" characterAtIndex:0];
    byteData[2] = [@"0" characterAtIndex:0];
    byteData[3] = [@"2" characterAtIndex:0];
    byteData[4] = [@"P" characterAtIndex:0];
    byteData[5] = [@"A" characterAtIndex:0];
    byteData[6] = [@"U" characterAtIndex:0];
    byteData[7] = [@"S" characterAtIndex:0];
    byteData[8] = [@"E" characterAtIndex:0];
    byteData[9] = [@"L" characterAtIndex:0];
    byteData[10] = [@"E" characterAtIndex:0];
    byteData[11] = [@"N" characterAtIndex:0];
    byteData[12] = [value characterAtIndex:0];
    byteData[13] = [value characterAtIndex:1];
    
    data = [NSData dataWithBytes:byteData length:14];
    
    return data;
}

// Update Parameter ACCELER_SENS
- (NSData *)makeUpdateACCELERSENS:(NSString *)value {
    NSData *data;
    
    Byte *byteData = (Byte*)malloc(18);
    byteData[0] = [@"5" characterAtIndex:0];
    byteData[1] = [@"5" characterAtIndex:0];
    byteData[2] = [@"0" characterAtIndex:0];
    byteData[3] = [@"2" characterAtIndex:0];
    byteData[4] = [@"A" characterAtIndex:0];
    byteData[5] = [@"C" characterAtIndex:0];
    byteData[6] = [@"C" characterAtIndex:0];
    byteData[7] = [@"E" characterAtIndex:0];
    byteData[8] = [@"L" characterAtIndex:0];
    byteData[9] = [@"E" characterAtIndex:0];
    byteData[10] = [@"R" characterAtIndex:0];
    byteData[11] = [@"S" characterAtIndex:0];
    byteData[12] = [@"E" characterAtIndex:0];
    byteData[13] = [@"N" characterAtIndex:0];
    byteData[14] = [@"S" characterAtIndex:0];
    byteData[15] = [value characterAtIndex:0];
    byteData[16] = [value characterAtIndex:1];
    byteData[17] = [value characterAtIndex:2];
    
    data = [NSData dataWithBytes:byteData length:18];
    
    return data;
}

// Update parameter MIC
- (NSData *)makeUpdateMIC:(NSString *)value {
    NSData *data;
    
    Byte *byteData = (Byte*)malloc(10);
    byteData[0] = [@"5" characterAtIndex:0];
    byteData[1] = [@"5" characterAtIndex:0];
    byteData[2] = [@"0" characterAtIndex:0];
    byteData[3] = [@"2" characterAtIndex:0];
    byteData[4] = [@"M" characterAtIndex:0];
    byteData[5] = [@"I" characterAtIndex:0];
    byteData[6] = [@"C" characterAtIndex:0];
    byteData[7] = [value characterAtIndex:0];
    byteData[8] = [value characterAtIndex:1];
    byteData[9] = [value characterAtIndex:2];
    
    data = [NSData dataWithBytes:byteData length:10];
    
    return data;
}

- (NSData *)makeUpdatePASSWORD:(NSString *)value {
    NSData *data;
    NSData *passData = [value dataUsingEncoding:NSUTF8StringEncoding];
    
    Byte *byteData = (Byte*)malloc(9);
    byteData[0] = [@"5" characterAtIndex:0];
    byteData[1] = [@"5" characterAtIndex:0];
    byteData[2] = [@"0" characterAtIndex:0];
    byteData[3] = [@"2" characterAtIndex:0];
    byteData[4] = [@"P" characterAtIndex:0];
    byteData[5] = [@"A" characterAtIndex:0];
    byteData[6] = [@"S" characterAtIndex:0];
    byteData[7] = [@"S" characterAtIndex:0];
    byteData[8] = value.length & 0xff;
    
    data = [NSData dataWithBytes:byteData length:9];
    NSMutableData *concatenatedData = [[NSMutableData alloc] init];
    [concatenatedData appendData:data];
    [concatenatedData appendData:passData];
    
    return concatenatedData;
}
/************ END UPDATE PARAMETER ****************/

/************ READ PARAMETER ****************/

- (NSData *)makeReadRECLN {
    NSData *data;
    
    Byte *byteData = (Byte*)malloc(9);
    byteData[0] = [@"5" characterAtIndex:0];
    byteData[1] = [@"5" characterAtIndex:0];
    byteData[2] = [@"0" characterAtIndex:0];
    byteData[3] = [@"3" characterAtIndex:0];
    byteData[4] = [@"R" characterAtIndex:0];
    byteData[5] = [@"E" characterAtIndex:0];
    byteData[6] = [@"C" characterAtIndex:0];
    byteData[7] = [@"L" characterAtIndex:0];
    byteData[8] = [@"N" characterAtIndex:0];
    
    data = [NSData dataWithBytes:byteData length:9];
    
    return data;
}

- (NSData *)makeReadBTLOC {
    NSData *data;
    
    Byte *byteData = (Byte*)malloc(9);
    byteData[0] = [@"5" characterAtIndex:0];
    byteData[1] = [@"5" characterAtIndex:0];
    byteData[2] = [@"0" characterAtIndex:0];
    byteData[3] = [@"3" characterAtIndex:0];
    byteData[4] = [@"B" characterAtIndex:0];
    byteData[5] = [@"T" characterAtIndex:0];
    byteData[6] = [@"L" characterAtIndex:0];
    byteData[7] = [@"O" characterAtIndex:0];
    byteData[8] = [@"C" characterAtIndex:0];
    
    data = [NSData dataWithBytes:byteData length:9];
    
    return data;
}

- (NSData *)makeReadPAUSELEVEL {
    NSData *data;
    
    Byte *byteData = (Byte*)malloc(14);
    byteData[0] = [@"5" characterAtIndex:0];
    byteData[1] = [@"5" characterAtIndex:0];
    byteData[2] = [@"0" characterAtIndex:0];
    byteData[3] = [@"3" characterAtIndex:0];
    byteData[4] = [@"P" characterAtIndex:0];
    byteData[5] = [@"A" characterAtIndex:0];
    byteData[6] = [@"U" characterAtIndex:0];
    byteData[7] = [@"S" characterAtIndex:0];
    byteData[8] = [@"E" characterAtIndex:0];
    byteData[9] = [@"L" characterAtIndex:0];
    byteData[10] = [@"E" characterAtIndex:0];
    byteData[11] = [@"V" characterAtIndex:0];
    byteData[12] = [@"E" characterAtIndex:0];
    byteData[13] = [@"L" characterAtIndex:0];
    
    data = [NSData dataWithBytes:byteData length:14];
    
    return data;
}

- (NSData *)makeReadPAUSELEN {
    NSData *data;
    
    Byte *byteData = (Byte*)malloc(12);
    byteData[0] = [@"5" characterAtIndex:0];
    byteData[1] = [@"5" characterAtIndex:0];
    byteData[2] = [@"0" characterAtIndex:0];
    byteData[3] = [@"3" characterAtIndex:0];
    byteData[4] = [@"P" characterAtIndex:0];
    byteData[5] = [@"A" characterAtIndex:0];
    byteData[6] = [@"U" characterAtIndex:0];
    byteData[7] = [@"S" characterAtIndex:0];
    byteData[8] = [@"E" characterAtIndex:0];
    byteData[9] = [@"L" characterAtIndex:0];
    byteData[10] = [@"E" characterAtIndex:0];
    byteData[11] = [@"N" characterAtIndex:0];
    
    data = [NSData dataWithBytes:byteData length:12];
    
    return data;
}

- (NSData *)makeReadACCELERSENS {
    NSData *data;
    
    Byte *byteData = (Byte*)malloc(15);
    byteData[0] = [@"5" characterAtIndex:0];
    byteData[1] = [@"5" characterAtIndex:0];
    byteData[2] = [@"0" characterAtIndex:0];
    byteData[3] = [@"3" characterAtIndex:0];
    byteData[4] = [@"A" characterAtIndex:0];
    byteData[5] = [@"C" characterAtIndex:0];
    byteData[6] = [@"C" characterAtIndex:0];
    byteData[7] = [@"E" characterAtIndex:0];
    byteData[8] = [@"L" characterAtIndex:0];
    byteData[9] = [@"E" characterAtIndex:0];
    byteData[10] = [@"R" characterAtIndex:0];
    byteData[11] = [@"S" characterAtIndex:0];
    byteData[12] = [@"E" characterAtIndex:0];
    byteData[13] = [@"N" characterAtIndex:0];
    byteData[14] = [@"S" characterAtIndex:0];
    
    data = [NSData dataWithBytes:byteData length:15];
    
    return data;
}

- (NSData *)makeReadMIC {
    NSData *data;
    
    Byte *byteData = (Byte*)malloc(7);
    byteData[0] = [@"5" characterAtIndex:0];
    byteData[1] = [@"5" characterAtIndex:0];
    byteData[2] = [@"0" characterAtIndex:0];
    byteData[3] = [@"3" characterAtIndex:0];
    byteData[4] = [@"M" characterAtIndex:0];
    byteData[5] = [@"I" characterAtIndex:0];
    byteData[6] = [@"C" characterAtIndex:0];
    
    data = [NSData dataWithBytes:byteData length:7];
    
    return data;
}

- (NSData *)makeReadVERSION {
    NSData *data;
    
    Byte *byteData = (Byte*)malloc(11);
    byteData[0] = [@"5" characterAtIndex:0];
    byteData[1] = [@"5" characterAtIndex:0];
    byteData[2] = [@"0" characterAtIndex:0];
    byteData[3] = [@"3" characterAtIndex:0];
    byteData[4] = [@"V" characterAtIndex:0];
    byteData[5] = [@"E" characterAtIndex:0];
    byteData[6] = [@"R" characterAtIndex:0];
    byteData[7] = [@"S" characterAtIndex:0];
    byteData[8] = [@"I" characterAtIndex:0];
    byteData[9] = [@"O" characterAtIndex:0];
    byteData[10] = [@"N" characterAtIndex:0];
    
    data = [NSData dataWithBytes:byteData length:11];
    
    return data;
}

// Format String to match number of bytes
- (NSString *) formatString:(NSString *)data numberDigit: (NSUInteger)num {
    if (data.length == num) return data;
    
    int digitNum = data.length;
    int digitInsert = num - digitNum;
    NSMutableString *mu;
    mu = [[NSMutableString alloc] init];
    
    
    for (int i = 0; i < digitInsert; i++) {
        [mu appendString:@"0"];
    }
    
    NSMutableString *mu1;
    mu1 = [[NSMutableString alloc] init];
    [mu1 appendString:mu];
    [mu1 appendString:data];
    
    return mu1;
}


// DELEGATE
- (void) didReceiveRECLN: (NSUInteger) value {
    self.tfRECLN.text = [NSString stringWithFormat:@"%d", value];
}

- (void) didReceivePAUSE_LEVEL: (NSUInteger) value {
      self.tfPAUSE_LEVEL.text = [NSString stringWithFormat:@"%d", value];
}
- (void) didReceivePAUSE_LEN: (NSUInteger) value {
      self.tfPAUSE_LEN.text = [NSString stringWithFormat:@"%d", value];
}
- (void) didReceiveACCELER_SENS: (NSUInteger) value {
     self.tfACCELER_SENS.text = [NSString stringWithFormat:@"%d", value];
}
- (void) didReceiveMIC: (NSUInteger) value {
      self.tfMIC.text = [NSString stringWithFormat:@"%d", value];
}
- (void) didReceiveBTLOC: (NSUInteger) value {
     self.tfBTLOC.text = [NSString stringWithFormat:@"%d", value];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.scrollView.contentOffset = CGPointMake(0, textField.frame.origin.y - 20);
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.scrollView.contentOffset = CGPointMake(0, 64);
}

- (void) didReceiveVERSION: (NSString *) value {
    NSLog(@"OK = \"%@\"", value);
    self.tfVERSION.text = value;
}

- (IBAction)readAll:(id)sender {
    NSData *data;

    data = [self makeReadRECLN];
    [self send:data];
    
    data = [self makeReadPAUSELEVEL];
    [self send:data];
    
    data = [self makeReadPAUSELEN];
    [self send:data];

    data = [self makeReadACCELERSENS];
    [self send:data];

    data = [self makeReadMIC];
    [self send:data];
    
    data = [self makeReadBTLOC];
    [self send:data];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *pass = [defaults valueForKey:@"PASSWORD"];
    if (pass == nil) pass = @"1234abcd";
    self.tfPASSWORD.text = pass;
    
    self.tvUUID.text = [NSString stringWithFormat:@"%@", [[[self->peripheral services] objectAtIndex:0] UUID]];
    
    data = [self makeReadVERSION];
    [self send:data];
}

- (IBAction)writeAll:(id)sender {
    NSData *data;
    
    data = [self makeUpdateRECLN:[self formatString:[self.tfRECLN text] numberDigit:2]];
    [self send:data];
    
    data = [self makeUpdatePAUSELEVEL:[self formatString:[self.tfPAUSE_LEVEL text] numberDigit:3]];
    [self send:data];
    
    data = [self makeUpdatePAUSELEN:[self formatString:[self.tfPAUSE_LEN text] numberDigit:2]];
    [self send:data];
    
    data = [self makeUpdateACCELERSENS:[self formatString:[self.tfACCELER_SENS text] numberDigit:3]];
    [self send:data];
    
    data = [self makeUpdateMIC:[self formatString:[self.tfMIC text] numberDigit:3]];
    [self send:data];
}
@end
