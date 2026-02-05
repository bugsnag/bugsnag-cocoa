//
//  BugsnagResponse.h
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
@interface BugsnagResponse : NSObject

@property (copy, nullable, nonatomic) NSData *body;
@property (copy, nullable, nonatomic) NSDictionary<NSString *, NSString *> *headers;
@property (strong, nonnull, nonatomic) NSNumber *statusCode;
@property (nonatomic) NSUInteger bodyLength;

@end
