//
//  ConcurrentCrashesScenario.mm
//  iOSTestApp
//
//  Created by Nick Dowell on 19/01/2022.
//  Copyright © 2022 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

#import <pthread.h>
#import <stdexcept>

@interface ConcurrentCrashesScenario : Scenario

@end

@implementation ConcurrentCrashesScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = NO;
}

static volatile bool ready;

static void * ConcurrentCrashesThread(void *ptr) {
    NSException *nsexception;
    @try {
        [(id)[NSNull null] objectForKey:@""];
    } @catch (NSException *exception) {
        nsexception = exception;
    }
    
    while (!ready);
    
    switch (rand() % 4) {
        case 0: // Signal
            abort();
            break;
            
        case 1: // Mach exception
            __builtin_trap();
            break;
            
        case 2: // C++ exception
            throw std::runtime_error("Something went wrong");
            break;
            
        case 3: // NSException
            @throw nsexception;
            break;
    }
    return NULL;
}

- (void)run {
    srand((unsigned int)time(NULL));
    for (int i = 0; i < 4; i++) {
        pthread_t thread;
        pthread_create(&thread, NULL, ConcurrentCrashesThread, NULL);
    }
    sleep(1);
    ready = true;
}

@end
