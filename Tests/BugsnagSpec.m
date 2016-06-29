//
//  BugsnagSpec.m
//  Bugsnag
//
//  Created by Delisa Mason on 6/29/16.
//  Copyright 2016 Bugsnag. All rights reserved.
//

#import <Kiwi/Kiwi.h>
#import "Bugsnag.h"

#define shouldSoon shouldEventuallyBeforeTimingOutAfter(0.1)

SPEC_BEGIN(BugsnagSpec)

beforeAll(^{
    [Bugsnag startBugsnagWithApiKey:@"123"];
});

describe(@"Bugsnag", ^{

    __block NSURLRequest *request;

    id(^requestEventKeyPath)(NSString *) = ^id(NSString *keyPath) {
        NSDictionary *body = [NSJSONSerialization JSONObjectWithData:[request HTTPBody] options:0 error:nil];
        NSDictionary *event = [body valueForKeyPath:@"events.@firstObject"];
        return [event valueForKeyPath:keyPath];
    };

    id(^requestExceptionValue)(NSString *) = ^id(NSString *keyPath) {
        NSDictionary *exception = requestEventKeyPath(@"exceptions.@firstObject");
        return [exception valueForKeyPath:keyPath];
    };

    beforeEach(^{
        [NSURLConnection stub:@selector(sendAsynchronousRequest:queue:completionHandler:) withBlock:^id(NSArray *params) {
            request = [params firstObject];
            void (^block)(NSURLResponse *, NSData *, NSError *) = [params lastObject];
            block(nil, nil, nil);
            return nil;
        }];
    });

    afterEach(^{
        request = nil;
    });

    describe(@"notify:", ^{

        beforeEach(^{
            NSException *exception = [NSException exceptionWithName:@"failure to launch"
                                                             reason:@"no pilot" userInfo:nil];
            [Bugsnag notify:exception];
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
});

SPEC_END
