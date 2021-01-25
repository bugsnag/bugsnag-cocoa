#import "OutOfMemoryController.h"

#define PRINT_STATS 0

#if PRINT_STATS
#import <mach/mach_init.h>
#import <mach/task_info.h>
#import <mach/task.h>
#endif

#define MEGABYTE 0x100000

@implementation OutOfMemoryController {
    NSUInteger _blockSize;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.groupTableViewBackgroundColor;
}

- (void)didReceiveMemoryWarning {
    NSLog(@"--> Received a low memory warning");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    NSUInteger physicalMemory = (NSUInteger)NSProcessInfo.processInfo.physicalMemory;
    NSUInteger megabytes = physicalMemory / MEGABYTE;
    NSLog(@"*** Physical memory = %lu MB", (unsigned long)megabytes);
    
    // The ActiveHard limit varies between devices
    //
    // Device       iOS     Total   Limit
    // ========================================
    // iPad3,19      9       987     700  (70%)
    // iPhone12,1   14      3859    2098  (54%)
    // iPhone12,8   14      2965    2095  (70%)
    // iPhone13,1   14      3718    2098  (57%)
    //
    NSUInteger limit = MIN(2098, megabytes * 70 / 100);
    
    NSUInteger initial = limit * 95 / 100;
    NSLog(@"*** Dirtying an initial block of %lu MB", (unsigned long)initial);
    [self consumeMegabytes:initial];
    
    _blockSize = limit <= 1024 ? 1 : 2;
    NSLog(@"*** Dirtying remaining memory in %lu MB blocks", (unsigned long)_blockSize);
    // This should take around 2 seconds to trigger an OOM kill
    [NSTimer scheduledTimerWithTimeInterval:0.03 target:self selector:@selector(timerFired) userInfo:nil repeats:YES];
}

- (void)timerFired {
    [self consumeMegabytes:_blockSize];
}

- (void)consumeMegabytes:(NSUInteger)megabytes {
    for (NSUInteger i = 0; i < megabytes; i++) {
        const NSUInteger pagesize = NSPageSize();
        const NSUInteger npages = MEGABYTE / pagesize;
        volatile char *ptr = malloc(MEGABYTE);
        for (NSUInteger page = 0; page < npages; page++) {
            ptr[page * pagesize] = 42; // Dirty each page
        }
    }
#if PRINT_STATS
    task_vm_info_data_t info;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t result = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t) &info, &count);
    assert(result == KERN_SUCCESS);
    unsigned long long physicalMemory = NSProcessInfo.processInfo.physicalMemory;
    NSLog(@"%4llu / %4llu MB (%llu%%)", info.phys_footprint / MEGABYTE, physicalMemory / MEGABYTE, info.phys_footprint * 100 / physicalMemory);
#endif
}

@end
