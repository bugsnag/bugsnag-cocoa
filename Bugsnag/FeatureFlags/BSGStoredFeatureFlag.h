//
//  BSGStoredFeatureFlag.h
//  Bugsnag
//
//  Created by Robert B on 25/11/2024.
//  Copyright © 2024 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BSGDefines.h"

NS_ASSUME_NONNULL_BEGIN

BSG_OBJC_DIRECT_MEMBERS
@interface BSGStoredFeatureFlag: NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, nullable, strong) NSString *variant;
@property (nonatomic) uint64_t index;

+ (instancetype)fromJSON:(NSDictionary *)json;
- (instancetype)initWithName:(NSString *)name variant:(nullable NSString *)variant index:(uint64_t)index;
- (NSDictionary *)toJson;

@end

NS_ASSUME_NONNULL_END
