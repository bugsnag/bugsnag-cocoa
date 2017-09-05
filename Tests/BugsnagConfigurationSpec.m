//
//  BugsnagConfigurationSpec.m
//  Bugsnag
//
//  Created by Delisa Mason on 11/30/16.
//  Copyright 2016 Bugsnag. All rights reserved.
//

#import "BugsnagConfiguration.h"
#import "Bugsnag.h"

@interface SomeDelegate : NSObject<NSURLSessionTaskDelegate>
@property (nonatomic) BOOL didInvoke;
@end

@implementation SomeDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(nonnull NSURLAuthenticationChallenge *)challenge completionHandler:(nonnull void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    self.didInvoke = YES;
    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
}

@end
