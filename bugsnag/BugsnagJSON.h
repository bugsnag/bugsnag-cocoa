//
//  BugsnagJSON.h
//  Bugsnag
//
//  Created by Simon Maynard on 8/28/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BugsnagJSON : NSObject
+ (NSString*) encodeDictionary:(NSDictionary*)dictionary;
@end
