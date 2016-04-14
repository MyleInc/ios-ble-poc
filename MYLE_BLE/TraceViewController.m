#import "TraceViewController.h"
#import "TapParametersViewController.h"
#import "TapManager.h"

@import AVFoundation;


@implementation TraceViewController
{
    NSDateFormatter *_formatter;
    AVAudioPlayer *_audioPlayer;
}


- (void) log:(NSString*)message {
    self.tvLog.text = [NSString stringWithFormat:@"%@: %@\r\n%@", [_formatter stringFromDate:[NSDate date]], message, self.tvLog.text];
}


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
    
    _formatter = [[NSDateFormatter alloc] init];
    [_formatter setDateFormat:@"mm:ss.SSS"];
    
    [[TapManager shared] addTraceListener:^(NSString *message) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self log:message];
        });
    }];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [TapManager setup:[defaults valueForKey:SETTINGS_PERIPHERAL_UUID] pass:[defaults valueForKey:SETTINGS_PERIPHERAL_PASS]];
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


- (IBAction)share:(id)sender {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://dev.getmyle.com:5681"]];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[self.tvLog.text dataUsingEncoding:NSUTF8StringEncoding]];
    
    
    // Fetch the JSON response
    NSURLResponse *response;
    NSError *error;
    
    // Make synchronous request
    [NSURLConnection sendSynchronousRequest:request
                          returningResponse:&response
                                      error:&error];
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"mm:ss.SSS"];
    
    self.tvLog.text = [NSString stringWithFormat:@"%@: %@\r\n%@", [formatter stringFromDate:[NSDate date]], @"The trace log has been shared!", self.tvLog.text];
}


- (IBAction)play:(id)sender {
    NSError *error;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *path = [defaults valueForKey:@"LAST_RECEIVED_FILE_PATH"];
    if (!path) {
        [self log:@"No recent file found"];
        return;
    }

    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error: &error];
    if (error) {
        [self log:[NSString stringWithFormat:@"Error setting up audio session category: %@", error]];
        return;
    }
    
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (error) {
        [self log:[NSString stringWithFormat:@"Error making audio session active: %@", error]];
        return;
    }
    
    if (_audioPlayer) {
        _audioPlayer = nil;
    }
    
    _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error: &error];
    if (error) {
        [self log:[NSString stringWithFormat:@"Error crating audio player: %@", error]];
        return;
    }
    
    [_audioPlayer prepareToPlay];
    [_audioPlayer play];
}

@end
