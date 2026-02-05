//
//  BugsnagRequest.h
//  Bugsnag
//
//  Created by Daria Bialobrzeska on 27/01/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Bugsnag/BugsnagDefines.h>

/**
 * Represents a network request made by the application.
 */
BUGSNAG_EXTERN
@interface BugsnagRequest : NSObject

@property (copy, nullable, nonatomic) NSData *body;

@property (copy, nullable, nonatomic) NSDictionary<NSString *, NSString *> *headers;

@property (copy, nullable, nonatomic) NSDictionary<NSString *, NSString *> *params;

@property (copy, nonnull, nonatomic) NSString *httpMethod;

@property (copy, nullable, nonatomic) NSString *httpVersion;

@property (copy, nullable, nonatomic) NSURL *url;

@property (nonatomic) NSUInteger bodyLength;

@end
