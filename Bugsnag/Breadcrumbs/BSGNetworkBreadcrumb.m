//
//  BSGNetworkBreadcrumb.m
//  Bugsnag
//
//  Created by Nick Dowell on 24/08/2022.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#import "BSGNetworkBreadcrumb.h"

NSString * BSGNetworkBreadcrumbMessageForResponse(NSHTTPURLResponse *response) {
    if (response) {
        if (100 <= response.statusCode && response.statusCode < 400) {
            return @"NSURLSession request succeeded";
        }
        if (400 <= response.statusCode && response.statusCode < 500) {
            return @"NSURLSession request failed";
        }
    }
    return @"NSURLSession request error";
}

BugsnagBreadcrumb * BSGNetworkBreadcrumbWithTaskMetrics(NSURLSessionTask *task, NSURLSessionTaskMetrics *metrics) {
    NSURLRequest *request = task.originalRequest ? task.originalRequest : task.currentRequest;
    if (!request) {
        return nil;
    }

    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    metadata[@"duration"] = @((unsigned)(metrics.taskInterval.duration * 1000));
    metadata[@"method"] = request.HTTPMethod;

    NSURL *url = request.URL;
    if (url) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
        metadata[@"url"] = BSGURLStringForComponents(components);
        metadata[@"urlParams"] = BSGURLParamsForQueryItems(components.queryItems);
    }

    if (task.countOfBytesSent) {
        metadata[@"requestContentLength"] = @(task.countOfBytesSent);
    } else if (request.HTTPBody) {
        // Fall back because task.countOfBytesSent is 0 when a custom NSURLProtocol is used
        metadata[@"requestContentLength"] = @(request.HTTPBody.length);
    }

    // Note: Cannot use metrics transaction response because it will be nil if a custom NSURLProtocol is present.
    // Note: If there was an error, task.response will be nil, and the following values will be set accordingly.
    NSHTTPURLResponse *response = [task.response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)task.response : nil;
    if (response) {
        metadata[@"responseContentLength"] = @(task.countOfBytesReceived);
        metadata[@"status"] = @(response.statusCode);
    }

    BugsnagBreadcrumb *breadcrumb = [BugsnagBreadcrumb new];
    breadcrumb.message = BSGNetworkBreadcrumbMessageForResponse(response);
    breadcrumb.metadata = metadata;
    breadcrumb.type = BSGBreadcrumbTypeRequest;
    return breadcrumb;
}

NSDictionary<NSString *, id> * BSGURLParamsForQueryItems(NSArray<NSURLQueryItem *> *queryItems) {
    if (!queryItems) {
        return nil;
    }
    NSMutableDictionary *result = [NSMutableDictionary new];
    for (NSURLQueryItem *item in queryItems) {
        // - note: If a NSURLQueryItem name-value pair is empty (i.e. the query string starts with '&', ends
        // with '&', or has "&&" within it), you get a NSURLQueryItem with a zero-length name and a nil value.
        // If a NSURLQueryItem name-value pair has nothing before the equals sign, you get a zero-length name.
        // If a NSURLQueryItem name-value pair has nothing after the equals sign, you get a zero-length value.
        // If a NSURLQueryItem name-value pair has no equals sign, the NSURLQueryItem name-value pair string
        // is the name and you get a nil value.
        id value = item.value ?: [NSNull null];
        
        id existingValue = result[item.name]; 
        if ([existingValue isKindOfClass:[NSMutableArray class]]) {
            [existingValue addObject:value];
        } else if (existingValue) {
            result[item.name] = [NSMutableArray arrayWithObjects:existingValue, value, nil];
        } else {
            result[item.name] = value;
        }
    }
    return result;
}

NSString * BSGURLStringForComponents(NSURLComponents *components) {
    if (components.rangeOfQuery.location == NSNotFound) {
        return components.string;
    }
    NSRange rangeOfQuery = components.rangeOfQuery;
    NSString *string = [components.string stringByReplacingCharactersInRange:rangeOfQuery withString:@""];
    // rangeOfQuery does not include the '?' character, so that must be removed separately
    if ([string characterAtIndex:rangeOfQuery.location - 1] == '?') {
        string = [string stringByReplacingCharactersInRange:NSMakeRange(rangeOfQuery.location - 1, 1) withString:@""];
    }
    return string;
}
