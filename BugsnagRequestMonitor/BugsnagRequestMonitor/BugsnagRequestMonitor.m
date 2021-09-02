//
//  BugsnagRequestMonitor.m
//  BugsnagRequestMonitor
//
//  Created by Karl Stenerud on 26.08.21.
//

#import "BugsnagRequestMonitor.h"

#import "BSFPRNSURLSessionInstrument.h"


@interface BugsnagRequestMonitor: NSObject
@end

@implementation BugsnagRequestMonitor

+ (void)load {
    static BSFPRNSURLSessionInstrument *instrument;
    instrument = [[BSFPRNSURLSessionInstrument alloc]
                    initWithTraceCallback:^(BSFPRNetworkTrace * _Nonnull trace) {
        NSLog(@"### REQUEST: %@", trace);
        // TODO: Leave breadcrumb
    }];
    [instrument registerInstrumentors];
}

@end
