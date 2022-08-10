//
//  BugsnagUser+Private.h
//  Bugsnag
//
//  Created by Nick Dowell on 04/12/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <Bugsnag/BugsnagUser.h>

NS_ASSUME_NONNULL_BEGIN

@interface BugsnagUser ()

- (instancetype)initWithDictionary:(nullable NSDictionary *)dict;

- (instancetype)initWithId:(nullable NSString *)id name:(nullable NSString *)name emailAddress:(nullable NSString *)emailAddress;

- (NSDictionary *)toJson;

/// Returns the receiver if it has a non-nil `id`, or a copy of the receiver with a `id` set to `[BSG_KSSystemInfo deviceAndAppHash]`. 
- (BugsnagUser *)withId;

@end

NS_ASSUME_NONNULL_END
