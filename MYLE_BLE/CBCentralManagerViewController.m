#import "CBCentralManagerViewController.h"
#import "ParameterViewController.h"
#import "LauncherViewController.h"
#import "TapManager.h"


@implementation CBCentralManagerViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
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
