//
//  BugsnagMetadata+Private.h
//  Bugsnag
//
//  Created by Nick Dowell on 04/12/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "BugsnagInternals.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^ BSGMetadataObserver)(BugsnagMetadata *);

@interface BugsnagMetadata () <NSCopying>

#pragma mark Properties

@property (nullable, nonatomic) BSGMetadataObserver observer;

@end

NS_ASSUME_NONNULL_END
