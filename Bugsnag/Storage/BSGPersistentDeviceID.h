//
//  BSGPersistentDeviceID.h
//  Bugsnag-iOS
//
//  Created by Karl Stenerud on 26.06.23.
//  Copyright © 2023 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BSGPersistentDeviceID : NSObject

+ (nonnull BSGPersistentDeviceID *)current;

@property(readonly,nonatomic) NSString *external;
@property(readonly,nonatomic) NSString *internal;

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)unitTest_deviceIDWithFilePath:(nonnull NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
