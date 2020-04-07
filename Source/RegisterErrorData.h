//
//  RegisterErrorData.h
//  Bugsnag
//
//  Created by Jamie Lynch on 07/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RegisterErrorData : NSObject
@property (nonatomic, strong) NSString *_Nullable errorClass;
@property (nonatomic, strong) NSString *_Nullable errorMessage;
+ (instancetype _Nonnull )errorDataFromThreads:(NSArray *_Nullable)threads;
- (instancetype _Nonnull )initWithClass:(NSString *_Nonnull)errorClass
                      message:(NSString *_Nonnull)errorMessage NS_DESIGNATED_INITIALIZER;
@end
