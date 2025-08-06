//
//  BSG_KSCrashDoctor.h
//  BSG_KSCrash
//
//  Created by Karl Stenerud on 2012-11-10.
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BSGDefines.h"


@interface BSG_KSCrashDoctor : NSObject

- (NSString *)diagnoseCrash:(NSDictionary *)crashReport;

@end
