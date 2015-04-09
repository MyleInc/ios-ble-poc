//
//  ScanViewController.m
//  MYLE_BLE
//
//  Created by cxphong-macmini on 3/27/15.
//  Copyright (c) 2015 Mobiletuts. All rights reserved.
//

#import "ScanViewController.h"
#import "Cell_Session.h"
#import "TapManager.h"


@interface ScanViewController ()
@end


@implementation ScanViewController {
    TapManager *_tap;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tap = [TapManager shared];
    
    // subscribe to new peripheral notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onScanPeripheral:)
                                                 name:kScanNotification
                                               object:nil];
    
    [self.tableView reloadData];
}


// disconnect when comeback to ScanViewController
-(void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // unsubscribe from new peripheral notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kScanNotification
                                                  object:nil];
}


- (void)onScanPeripheral:(NSNotification *)notification
{
    [self.tableView reloadData];
}


#pragma mark - Table view data source
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Custom cell
    static NSString *simpleTableIdentifier = @"Cell";
    
    Cell_Session *cell = (Cell_Session *)[tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    if (cell == nil)
    {
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"Cell_Session" owner:self options:nil];
        cell = [nib objectAtIndex:0];
    }
    
    CBPeripheral *peripheral = [[_tap getAvailableTaps] objectAtIndex:indexPath.section];
    cell.lbName.text = peripheral.name;
    cell.lbUUID.text = [peripheral.identifier UUIDString];
    
    return cell;
}


// Row is selected
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CBPeripheral *peripheral = [[_tap getAvailableTaps] objectAtIndex:indexPath.section];
    
    [_tap connect:peripheral];
    
    // Save chose device
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:[peripheral.identifier UUIDString] forKey:@"PERIPHERAL_UUID"];
    [defaults synchronize];
    
    [self performSegueWithIdentifier:@"connect_segue" sender:self];
}


///////////// Add space between cells ////////////////////////////
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[_tap getAvailableTaps] count];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 10.0f; // you can have your own choice, of course
}


- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *headerView = [[UIView alloc] init];
    headerView.backgroundColor = [UIColor clearColor];
    return headerView;
}


@end
