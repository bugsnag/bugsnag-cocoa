//
//  BugsnagEndpointConfiguration.h
//  Bugsnag
//
//  Created by Jamie Lynch on 15/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Bugsnag/BugsnagDefines.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Set the endpoints to send data to. By default we'll send error reports to
 * https://notify.bugsnag.com, and sessions to https://sessions.bugsnag.com, but you can
 * override this if you are using Bugsnag Enterprise to point to your own Bugsnag endpoints.
 */
BUGSNAG_EXTERN
@interface BugsnagEndpointConfiguration : NSObject

/**
 * Configures the endpoint to which events should be sent
 */
@property (copy, nonatomic) NSString *notify;

/**
 * Configures the endpoint to which sessions should be sent
 */
@property (copy, nonatomic) NSString *sessions;

/**
 * Returns YES if the endpoints have been customized, i.e., they are not the default Bugsnag or Secondary URL endpoints.
 */
@property (nonatomic, readonly) BOOL isCustom;

+ (instancetype)defaultForApiKey:(NSString *)apiKey; 

- (instancetype)initWithNotify:(NSString *)notify
                      sessions:(NSString *)sessions;

@end

NS_ASSUME_NONNULL_END
