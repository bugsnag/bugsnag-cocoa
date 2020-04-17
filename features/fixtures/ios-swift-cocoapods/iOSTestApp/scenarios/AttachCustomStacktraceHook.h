//
//  AttachCustomStacktraceHook.h
//  iOSTestApp
//
//  Created by Jamie Lynch on 17/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Bugsnag/Bugsnag.h>

@interface BugsnagEvent ()
- (void)attachCustomStacktrace:(NSArray *)frames withType:(NSString *)type;
@end
