#import "OutOfMemoryController.h"

@implementation OutOfMemoryController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.groupTableViewBackgroundColor;
}

- (void)didReceiveMemoryWarning {
    NSLog(@"--> Received a low memory warning");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [NSThread detachNewThreadSelector:@selector(consumeMemory) toTarget:self withObject:nil];
}

- (void)consumeMemory {
    NSLog(@"*** Consuming all available memory...");
    __block BOOL pause = NO;
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil
                                                     queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        pause = YES;
    }];
    const int blocksize = 1024 * 1024;
    const int pagesize = (int)NSPageSize();
    const int npages = blocksize / pagesize;
    while (1) {
        volatile char *ptr = malloc(blocksize);
        for (int i = 0; i < npages; i++) {
            ptr[i * pagesize] = 42; // Dirty each page
            
            if (pause) {
                pause = NO;
                NSLog(@"*** Pausing memory consumption to allow Bugsnag to write breadcrumbs and metadata");
                [NSThread sleepForTimeInterval:0.5];
                NSLog(@"*** Resuming memory consumption...");
            }
        }
    }
}

@end
