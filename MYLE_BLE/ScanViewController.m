//
//  ScanViewController.m
//  MYLE_BLE
//
//  Created by cxphong-macmini on 3/27/15.
//  Copyright (c) 2015 Mobiletuts. All rights reserved.
//

#import "ScanViewController.h"
#import "BluetoothManager.h"
#import "ScanDeviceInfo.h"
#import "Cell_Session.h"

@interface ScanViewController ()
@end

@implementation ScanViewController {
    BluetoothManager *bluetoothManager;
    NSMutableArray *listDeviceScan;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    listDeviceScan = [[NSMutableArray alloc] initWithCapacity:100];
    bluetoothManager = [BluetoothManager createInstance];
    bluetoothManager.ScanDelegate = self;
}

// disconnect when comeback to ScanViewController
-(void) viewWillDisappear:(BOOL)animated {
    if ([self.navigationController.viewControllers indexOfObject:self] == NSNotFound) {
        NSLog(@"OK");
        [BluetoothManager destroyInstance];
    }
    [super viewWillDisappear:animated];
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
    
    cell.lbName.text = [[listDeviceScan objectAtIndex:indexPath.section] getPeripheral].name;
    cell.lbUUID.text = [[[listDeviceScan objectAtIndex:indexPath.section] getPeripheral].identifier UUIDString];
    
    return cell;
}

// Row is selected
- (void)        tableView:(UITableView *)tableView
  didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [bluetoothManager connect:[[listDeviceScan objectAtIndex:indexPath.section] getPeripheral]];
    
    // Save chose device
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:[[[listDeviceScan objectAtIndex:indexPath.section]
                         getPeripheral].identifier UUIDString]
                forKey:@"PERIPHERAL_UUID"];
    [defaults synchronize];
    
    [self performSegueWithIdentifier:@"connect_segue" sender:self];
}

///////////// Add space between cells ////////////////////////////
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [listDeviceScan count];
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

- (void)didScanNewDevice: (ScanDeviceInfo*)device {
    NSLog(@"didScanNewDevice");
    NSLog(@"%@", [[device getPeripheral].identifier UUIDString]);
    [listDeviceScan addObject:device];
    [self.tableView reloadData];
}

@end
