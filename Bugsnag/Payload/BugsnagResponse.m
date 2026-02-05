//
//  BugsnagResponse.m
//  Bugsnag
//
//  Created by Daria Bialobrzeska on 27/01/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BugsnagInternals.h"
#import "BugsnagCollections.h"
#import "BSGHttpKeys.h"

@implementation BugsnagResponse

+ (instancetype)responseFromJson:(NSDictionary *)json {
    if (json == nil) {
        return nil;
    }
    NSDictionary *headers = BSGDeserializeDict(json[BSGHttpHeaders]);
    NSNumber *statusCode = BSGDeserializeNumber(json[BSGHttpStatusCode]);

    NSString *bodyStr = BSGDeserializeString(json[BSGHttpBody]);
    NSData *body = [bodyStr dataUsingEncoding:NSUTF8StringEncoding];
    BugsnagResponse *response = [BugsnagResponse new];
    response.body = body;
    response.headers = headers ?: @{};
    response.statusCode = statusCode ?: @(0);
    response.bodyLength = body != nil ? body.length : 0;

    return response;
}

@end
