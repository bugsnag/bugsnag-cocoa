//
//  BugsnagHttpResponse.m
//  Bugsnag
//
//  Created by Daria Bialobrzeska on 27/01/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BugsnagInternals.h"
#import "BugsnagCollections.h"
#import "BSGHttpKeys.h"

@implementation BugsnagHttpResponse

+ (instancetype _Nonnull)initWithHttpResponse:(NSHTTPURLResponse * _Nullable)httpResponse {
    BugsnagHttpResponse *response = [BugsnagHttpResponse new];
    response.headers = httpResponse.allHeaderFields;
    response.statusCode = httpResponse.statusCode;
    // BODY UNAVAILABLE
    response.body = nil;
    response.bodyLength = 0;

    return response;
}


+ (instancetype)responseFromJson:(NSDictionary *)json {
    if (json == nil) {
        return nil;
    }
    NSDictionary *headers = BSGDeserializeDict(json[BSGHttpHeaders]);
    NSNumber *statusCode = BSGDeserializeNumber(json[BSGHttpStatusCode]);

    NSString *body = BSGDeserializeString(json[BSGHttpBody]);
    BugsnagHttpResponse *response = [BugsnagHttpResponse new];
    response.body = body;
    response.headers = headers ?: @{};
    response.statusCode = statusCode != nil ? [statusCode integerValue] : 0;
    response.bodyLength = body != nil ? body.length : 0;

    return response;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[BSGHttpBody] = self.body;
    if (self.bodyLength != 0) {
        dict[BSGHttpBodyLength] = @(self.bodyLength);
    }
    dict[BSGHttpHeaders] = self.headers;
    dict[BSGHttpStatusCode] = @(self.statusCode);
    return dict;
}

@end
