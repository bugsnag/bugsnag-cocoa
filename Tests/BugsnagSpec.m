//
//  BugsnagSpec.m
//  Bugsnag
//
//  Created by Delisa Mason on 6/29/16.
//  Copyright 2016 Bugsnag. All rights reserved.
//

#import <Kiwi/Kiwi.h>
#import <KSCrash/KSCrash.h>
#import "Bugsnag.h"
#import "BugsnagSink.h"

#define shouldSoon shouldEventuallyBeforeTimingOutAfter(3)

@interface BugsnagTestError : NSError
@end

@implementation BugsnagTestError
@end

SPEC_BEGIN(BugsnagSpec)

beforeAll(^{
    [Bugsnag startBugsnagWithApiKey:@"123"];
});

describe(@"Bugsnag", ^{

    __block NSURLRequest *request;
    __block NSData *httpBody;

    id(^requestEventKeyPath)(NSString *) = ^id(NSString *keyPath) {
        NSDictionary *body = [NSJSONSerialization JSONObjectWithData:httpBody options:0 error:nil];
        NSDictionary *event = [body valueForKeyPath:@"events.@firstObject"];
        return [event valueForKeyPath:keyPath];
    };

    id(^requestExceptionValue)(NSString *) = ^id(NSString *keyPath) {
        NSDictionary *exception = requestEventKeyPath(@"exceptions.@firstObject");
        return [exception valueForKeyPath:keyPath];
    };

    beforeEach(^{
        BugsnagSink *sink = [[KSCrash sharedInstance] valueForKeyPath:@"sink"];
        NSURLSession *session = [sink valueForKeyPath:@"session"];
        [session stub:@selector(uploadTaskWithRequest:fromData:completionHandler:) withBlock:^id(NSArray *params) {
            request = [params firstObject];
            httpBody = params[1];
            void (^handler)(NSData *, NSURLResponse *, NSError *) = [params lastObject];
            handler(nil, nil, nil);
            return nil;
        }];
    });

    afterEach(^{
        request = nil;
        httpBody = nil;
    });

    describe(@"notify:", ^{

        beforeEach(^{
            NSException *exception = [NSException exceptionWithName:@"failure to launch"
                                                             reason:@"no pilot" userInfo:nil];
            [Bugsnag notify:exception];
            [NSThread sleepForTimeInterval:2];
        });

        it(@"sends to the default endpoint", ^{
            [[expectFutureValue([[request URL] absoluteString]) shouldSoon] equal:@"https://notify.bugsnag.com/"];
        });

        it(@"sends via POST method", ^{
            [[expectFutureValue([request HTTPMethod]) shouldSoon] equal:@"POST"];
        });

        it(@"sends the exception name", ^{
            [[expectFutureValue(requestExceptionValue(@"errorClass")) shouldSoon] equal:@"failure to launch"];
        });

        it(@"sends the exception reason", ^{
            [[expectFutureValue(requestExceptionValue(@"message")) shouldSoon] equal:@"no pilot"];
        });
    });

    describe(@"notify:block:", ^{

        __block NSException *exception;
        NSArray *breadcrumbs = @[@[[[Bugsnag payloadDateFormatter] stringFromDate:[NSDate date]], @"[kitchen] ate beans"]];

        beforeEach(^{
            exception = [NSException exceptionWithName:@"failure to launch"
                                                reason:@"no fuel" userInfo:nil];
            [Bugsnag notify:exception block:^(BugsnagCrashReport * _Nonnull report) {
                report.context = @"walking to the falafel shop";
                report.groupingHash = @"HUNGRY";
                report.severity = BSGSeverityInfo;
                report.errorClass = @"High Class";
                report.errorMessage = @"I forgot to pick up groceries";
                report.metaData = @{ @"labels": @{ @"enabled": @"false" }};
                report.breadcrumbs = breadcrumbs;
            }];
            [NSThread sleepForTimeInterval:2];
        });

        it(@"sends the context", ^{
            [[expectFutureValue(requestEventKeyPath(@"context")) shouldSoon] equal:@"walking to the falafel shop"];
        });

        it(@"sends the grouping hash", ^{
            [[expectFutureValue(requestEventKeyPath(@"groupingHash")) shouldSoon] equal:@"HUNGRY"];
        });

        it(@"sends the severity", ^{
            [[expectFutureValue(requestEventKeyPath(@"severity")) shouldSoon] equal:@"info"];
        });

        it(@"sends the error class", ^{
            [[expectFutureValue(requestExceptionValue(@"errorClass")) shouldSoon] equal:@"High Class"];
        });

        it(@"sends the error message", ^{
            [[expectFutureValue(requestExceptionValue(@"message")) shouldSoon] equal:@"I forgot to pick up groceries"];
        });

        it(@"sends the metadata", ^{
            [[expectFutureValue(requestEventKeyPath(@"metaData.labels")) shouldSoon] equal: @{ @"enabled": @"false" }];
        });
        
        it(@"sends the breadcrumbs", ^{
            [[expectFutureValue(requestEventKeyPath(@"breadcrumbs")) shouldSoon] equal:breadcrumbs];
        });
    });

    describe(@"notifyError:", ^{

        beforeEach(^{
            NSError *error = [BugsnagTestError errorWithDomain:@"com.bugsnag.ios-error"
                                                          code:420
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Stuff is broken",
                                                                 NSLocalizedFailureReasonErrorKey: @"The rent is too high"}];
            [Bugsnag notifyError:error];
            [NSThread sleepForTimeInterval:2];
        });

        it(@"sends the error class", ^{
            [[expectFutureValue(requestExceptionValue(@"errorClass")) shouldSoon] equal:@"BugsnagTestError"];
        });

        it(@"sends the error message", ^{
            [[expectFutureValue(requestExceptionValue(@"message")) shouldSoon] equal:@"Stuff is broken"];
        });

        it(@"sends the domain", ^{
            [[expectFutureValue(requestEventKeyPath(@"metaData.nserror.domain")) shouldSoon] equal: @"com.bugsnag.ios-error"];
        });

        it(@"sends the code", ^{
            [[expectFutureValue(requestEventKeyPath(@"metaData.nserror.code")) shouldSoon] equal: @420];
        });

        it(@"sends the failure reason", ^{
            [[expectFutureValue(requestEventKeyPath(@"metaData.nserror.reason")) shouldSoon] equal: @"The rent is too high"];
        });
    });

    describe(@"notifyError:", ^{
        beforeEach(^{
            NSError *error = [BugsnagTestError errorWithDomain:@"com.bugsnag.ios-error"
                                                          code:420
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Stuff is broken",
                                                                 NSLocalizedFailureReasonErrorKey: @"The rent is too high"}];
            [Bugsnag notifyError:error block:^(BugsnagCrashReport * _Nonnull report) {
                NSMutableDictionary *metadata = [report.metaData mutableCopy];
                metadata[@"nserror"] = @{ @"code": @504, @"domain": @"com.example.borg", @"reason": @"None" };
                report.metaData = metadata;
                report.errorClass = @"Doughnut";
                report.errorMessage = @"None";
            }];
            [NSThread sleepForTimeInterval:2];
        });

        it(@"updates the error class", ^{
            [[expectFutureValue(requestExceptionValue(@"errorClass")) shouldSoon] equal:@"Doughnut"];
        });

        it(@"updates the error message", ^{
            [[expectFutureValue(requestExceptionValue(@"message")) shouldSoon] equal:@"None"];
        });

        it(@"updates the code", ^{
            [[expectFutureValue(requestEventKeyPath(@"metaData.nserror.code")) shouldSoon] equal: @504];
        });

        it(@"updates the domain", ^{
            [[expectFutureValue(requestEventKeyPath(@"metaData.nserror.domain")) shouldSoon] equal: @"com.example.borg"];
        });

        it(@"update the failure reason", ^{
            [[expectFutureValue(requestEventKeyPath(@"metaData.nserror.reason")) shouldSoon] equal: @"None"];
        });
    });
});

SPEC_END
