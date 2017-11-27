//
//  JsonSerializable.h
//  Bugsnag
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol JsonSerializable <NSObject>

/**
 * Serializes an object as a JSON payload
 *
 *  @return the object's JSON representation
 */
- (NSDictionary *_Nonnull)toJson;

@end
