//
//  BugsnagConfigurationSpec.m
//  Bugsnag
//
//  Created by Delisa Mason on 11/30/16.
//  Copyright 2016 Bugsnag. All rights reserved.
//

#import <Kiwi/Kiwi.h>
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


SPEC_BEGIN(BugsnagConfigurationSpec)

describe(@"BugsnagConfiguration", ^{

    it(@"sets the request session", ^{
        SomeDelegate *delegate = [SomeDelegate new];
        BugsnagConfiguration *config = [BugsnagConfiguration new];
        config.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                       delegate:delegate
                                                  delegateQueue:[NSOperationQueue mainQueue]];
        [Bugsnag startBugsnagWithConfiguration:config];
        [Bugsnag notify:[NSException exceptionWithName:@"oh no" reason:nil userInfo:nil]];
        [[expectFutureValue(@(delegate.didInvoke)) shouldEventually] beYes];
    });
});

SPEC_END
