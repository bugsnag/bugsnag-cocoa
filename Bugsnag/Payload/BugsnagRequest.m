//
//  BugsnagRequest.m
//  Bugsnag
//
//  Created by Daria Bialobrzeska on 27/01/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BugsnagInternals.h"
#import "BugsnagCollections.h"
#import "BSGHttpKeys.h"

@implementation BugsnagRequest

+ (instancetype)requestFromJson:(NSDictionary *)json {
    if (json == nil) {
        return nil;
    }
    NSDictionary *headers = BSGDeserializeDict(json[BSGHttpHeaders]);
    NSDictionary *params = BSGDeserializeDict(json[BSGHttpParams]);
    NSString *httpMethod = BSGDeserializeString(json[BSGHttpMethod]);
    NSString *httpVersion = BSGDeserializeString(json[BSGHttpVersion]);

    NSString *bodyStr = BSGDeserializeString(json[BSGHttpBody]);
    NSData *body = [bodyStr dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:BSGDeserializeString(json[BSGHttpURL]) ?: @""];

    BugsnagRequest *request = [BugsnagRequest new];
    request.body = body;
    request.headers = headers ?: @{};
    request.params = params ?: @{};
    request.httpMethod = httpMethod;
    request.httpVersion = httpVersion;
    request.url = url;
    request.bodyLength = body != nil ? body.length : 0;

    return request;
}

@end
