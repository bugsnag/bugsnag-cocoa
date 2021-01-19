#import "OutOfMemoryController.h"

#import <os/proc.h>

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
    const int blocksize = 2 * 1024 * 1024;
    const int pagesize = (int)NSPageSize();
    const int npages = blocksize / pagesize;
    while (1) {
        volatile char *ptr = malloc(blocksize);
        for (int i = 0; i < npages; i++) {
            ptr[i * pagesize] = 42; // Dirty each page
        }
        if (@available(iOS 13.0, *)) {
            NSLog(@"    Available memory: %@", [NSByteCountFormatter
                                                stringFromByteCount:os_proc_available_memory()
                                                countStyle:NSByteCountFormatterCountStyleMemory]);
        }
    }
}

@end
