#import "CBCentralManagerViewController.h"
#import "ParameterViewController.h"
#import "LauncherViewController.h"

@interface  CBCentralManagerViewController ()

@end

@implementation CBCentralManagerViewController
{
    unsigned int time;
    Boolean isVerified;
    Boolean isDropListSetVisible;
    Boolean isDropListReadVisible;
    Boolean isReceivingAudioFile;
    NSString *initialPassword;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Hide keyboard when user touch outside textfield
    UITapGestureRecognizer *tap =[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(dismissKeyboard)];
    [self.view addGestureRecognizer:tap];
    
    // Add "Write/Read Parameters" button on the right corner of NavigationBar
    UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:@"Parameters"
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self action:@selector(btDevicePress)];
    self.navigationItem.rightBarButtonItem = anotherButton;
}

- (void) btDevicePress {
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

//// Display log to screen function
- (void)log: (NSString*)message {
    NSLog(@"message = %@", message);
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss.SSS"];
    
    self.tvLog.text = [NSString stringWithFormat:@"%@\r\n%@: %@", self.tvLog.text, [formatter stringFromDate:[NSDate date]], message];
    
    [self.tvLog scrollRangeToVisible:NSMakeRange([self.tvLog.text length], 0)];
    [self.tvLog setScrollEnabled:YES];
}

// Disable rotate screen
- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

@end
