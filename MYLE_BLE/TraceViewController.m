#import "TraceViewController.h"
#import "ParametersViewController.h"
#import "TapManager.h"


@implementation TraceViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"Trace";
    
    // Add "Connect" button to the NavigationBar
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Connect"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self action:@selector(onConnectButtonTap)];
    
    // Add "Parameters" button on the right corner of NavigationBar
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Parameters"
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self action:@selector(onParametersButtonTap)];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss.SSS"];
    
    [[TapManager shared] addTraceListener:^(NSString *message) {
        self.tvLog.text = [NSString stringWithFormat:@"%@: %@\r\n%@", [formatter stringFromDate:[NSDate date]], message, self.tvLog.text];
    }];
}


- (void) onParametersButtonTap {
    [self performSegueWithIdentifier:@"parameter_segue" sender:self];
}


- (void) onConnectButtonTap {
    [self performSegueWithIdentifier:@"scan_segue" sender:self];
}


// Solve topbar hide content
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if([self respondsToSelector:@selector(edgesForExtendedLayout)])
        [self setEdgesForExtendedLayout:UIRectEdgeBottom];
}


// disconnect when comeback to ScanViewController
-(void) viewWillDisappear:(BOOL)animated {
    if ([self.navigationController.viewControllers indexOfObject:self] == NSNotFound) {
        if (self.navigationController.viewControllers.count == 2) {
            [self.navigationController popToRootViewControllerAnimated:NO];
        }
    }
    
    [super viewWillDisappear:animated];
}


@end
