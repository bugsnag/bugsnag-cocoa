//
//  BugsnagHttpRequest.m
//  Bugsnag
//
//  Created by Daria Bialobrzeska on 27/01/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BugsnagInternals.h"
#import "BugsnagCollections.h"
#import "BSGHttpKeys.h"

@implementation BugsnagHttpRequest

+ (instancetype _Nonnull)initWithHttpRequest:(NSURLRequest * _Nullable)httpRequest httpVersion:(NSString * _Nullable)httpVersion maxBodyCapture:(NSUInteger)maxBodyCapture {
    BugsnagHttpRequest *request = [BugsnagHttpRequest new];
    request.headers = httpRequest.allHTTPHeaderFields;
    request.httpMethod = httpRequest.HTTPMethod ?: @"";
    request.httpVersion = httpVersion ?: @"";
    [request setNewUrl:httpRequest.URL.absoluteString];

    if (maxBodyCapture != 0) {
        if (httpRequest.HTTPBody != nil) {
            NSUInteger lengthToCopy = MIN(httpRequest.HTTPBody.length, maxBodyCapture);
            NSRange range = NSMakeRange(0, lengthToCopy);
            NSData *truncatedData = [httpRequest.HTTPBody subdataWithRange:range];
            NSString *bodyStr;
            [NSString stringEncodingForData:truncatedData encodingOptions:nil convertedString:&bodyStr usedLossyConversion:nil];
            request.body = bodyStr;
            if (bodyStr != nil) {
                request.bodyLength = bodyStr.length;
            }
        }
    } else {
        request.body = nil;
        request.bodyLength = 0;
    }

    return request;
}

+ (instancetype)requestFromJson:(NSDictionary *)json {
    if (json == nil) {
        return nil;
    }
    NSDictionary *headers = BSGDeserializeDict(json[BSGHttpHeaders]);
    NSDictionary *params = BSGDeserializeDict(json[BSGHttpParams]);
    NSString *httpMethod = BSGDeserializeString(json[BSGHttpMethod]);
    NSString *httpVersion = BSGDeserializeString(json[BSGHttpVersion]);

    NSString *body = BSGDeserializeString(json[BSGHttpBody]);
    NSString *url = BSGDeserializeString(json[BSGHttpURL]);

    BugsnagHttpRequest *request = [BugsnagHttpRequest new];
    request.body = body;
    request.headers = headers ?: @{};
    request.params = params ?: @{};
    request.httpMethod = httpMethod;
    request.httpVersion = httpVersion;
    request.url = url;
    request.bodyLength = body != nil ? body.length : 0;

    return request;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[BSGHttpBody] = self.body;
    dict[BSGHttpBodyLength] = [NSString stringWithFormat:@"%tu", self.bodyLength];
    dict[BSGHttpHeaders] = self.headers;
    dict[BSGHttpParams] = self.params;
    dict[BSGHttpMethod] = self.httpMethod;
    dict[BSGHttpVersion] = self.httpVersion;
    dict[BSGHttpURL] = self.url;
    return dict;
}

- (void)setNewUrl:(NSString * _Nullable)url {
    if (url == nil) {
        self.url = @"";
        self.params = @{};
    } else {
        NSRange queryRange = [url rangeOfString: @"?"];
        if (queryRange.location != NSNotFound) {
            self.url = [url substringToIndex:queryRange.location];
            NSURLComponents *components = [NSURLComponents componentsWithString:url ?: @""];
            NSMutableDictionary *params = [NSMutableDictionary new];
            for (NSURLQueryItem *item in components.queryItems) {
                params[item.name] = item.value;
            }
            self.params = params;

        } else {
            self.url = url;
        }
    }
}

@end
