//
//  BugsnagHttpResponse.h
//  Bugsnag
//
//  Created by Daria Bialobrzeska on 27/01/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Bugsnag/BugsnagDefines.h>

/**
 * Represents a network response received by the application.
 */
BUGSNAG_EXTERN
@interface BugsnagHttpResponse : NSObject

+ (instancetype _Nonnull)initWithHttpResponse:(NSHTTPURLResponse * _Nullable)httpResponse;

@property (copy, nullable, nonatomic) NSString *body;

@property (copy, nullable, nonatomic) NSDictionary<NSString *, NSString *> *headers;

@property (nonatomic) NSInteger statusCode;

@property (nonatomic) NSUInteger bodyLength;

@end
