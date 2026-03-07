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

+ (instancetype _Nonnull)initFromHttpResponse:(NSURLResponse * _Nullable)httpResponse maxBodyCapture:(NSUInteger)maxBodyCapture {
    BugsnagResponse *response = [BugsnagResponse new];

    if ([httpResponse isKindOfClass:[NSHTTPURLResponse class]] != YES) {
        return response;
    }

    NSHTTPURLResponse *castedResponse = (NSHTTPURLResponse *)httpResponse;
    response.headers = castedResponse.allHeaderFields;
    response.statusCode = castedResponse.statusCode;
    response.body = nil;
    response.bodyLength = 0;

    // TODO BODY UNAVAILABLE

    return response;
}


+ (instancetype)responseFromJson:(NSDictionary *)json {
    if (json == nil) {
        return nil;
    }
    NSDictionary *headers = BSGDeserializeDict(json[BSGHttpHeaders]);
    NSNumber *statusCode = BSGDeserializeNumber(json[BSGHttpStatusCode]);

    NSString *body = BSGDeserializeString(json[BSGHttpBody]);
    BugsnagResponse *response = [BugsnagResponse new];
    response.body = body;
    response.headers = headers ?: @{};
    response.statusCode = statusCode != nil ? [statusCode integerValue] : 0;
    response.bodyLength = body != nil ? body.length : 0;

    return response;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[BSGHttpBody] = self.body;
    dict[BSGHttpBodyLength] = [NSString stringWithFormat:@"%tu", self.bodyLength];
    dict[BSGHttpHeaders] = self.headers;
    dict[BSGHttpStatusCode] = [NSString stringWithFormat:@"%ld", self.statusCode];
    return dict;
}

@end
