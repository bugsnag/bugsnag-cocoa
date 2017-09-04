//
//  BSGConnectivity.m
//
//  Created by Jamie Lynch on 2017-09-04.
//
//  Copyright (c) 2017 Bugsnag, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "BSGConnectivity.h"

#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>

@interface BSGConnectivity ()

@property (nonatomic, assign) SCNetworkReachabilityRef reachabilityRef;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) id reachability;

- (void)connectivityChanged:(SCNetworkReachabilityFlags)flags;

@end

static void BSGConnectivityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info) {
    
    BSGConnectivity *connectivity = ((__bridge BSGConnectivity *) info);
    @autoreleasepool {
        [connectivity connectivityChanged:flags];
    }
}

@implementation BSGConnectivity

- (instancetype)initWithURL:(NSURL *)url {
    NSString *hostName = [url absoluteString];
    SCNetworkReachabilityRef ref = SCNetworkReachabilityCreateWithName(NULL, [hostName UTF8String]);
    
    if (self = [super init]) {
        self.reachabilityRef = ref;
        self.serialQueue = dispatch_queue_create("com.bugsnag.cocoa", NULL);
    }
    return self;    
}

- (void)dealloc {
    [self stopWatchingConnectivity];

    if (self.reachabilityRef) {
        CFRelease(self.reachabilityRef);
        self.reachabilityRef = nil;
    }

    self.connectivityChangeBlock = nil;
    self.serialQueue = nil;
}

/**
 * Sets a callback with SCNetworkReachability
 */
- (void)startWatchingConnectivity {
    SCNetworkReachabilityContext context = { 0, NULL, NULL, NULL, NULL };
    context.info = (__bridge void *) self;

    if (SCNetworkReachabilitySetCallback(self.reachabilityRef, BSGConnectivityCallback, &context)) {
        if (SCNetworkReachabilitySetDispatchQueue(self.reachabilityRef, self.serialQueue)) {
            self.reachability = self;
        } else {
            SCNetworkReachabilitySetCallback(self.reachabilityRef, NULL, NULL);
        }
    }
}

/**
 * Stops the callback with SCNetworkReachability
 */
-(void)stopWatchingConnectivity {
    SCNetworkReachabilitySetCallback(self.reachabilityRef, NULL, NULL);
    SCNetworkReachabilitySetDispatchQueue(self.reachabilityRef, NULL);
    self.reachability = nil;
}

- (void)connectivityChanged:(SCNetworkReachabilityFlags)flags {
    BOOL connected = YES;
    
    if (!(flags & kSCNetworkReachabilityFlagsReachable)) {
        connected = NO;
    }
    if (connected) { // notify via block
        self.connectivityChangeBlock(self);
    }
}

@end
