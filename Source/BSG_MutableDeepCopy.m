//
//  BSG_MutableDeepCopy.m
//  Bugsnag
//
//  Created by Robin Macharg on 31/03/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//
// https://gist.github.com/yfujiki/1664847#gistcomment-1681340

#import "BSG_MutableDeepCopy.h"

@implementation NSDictionary (MutableDeepCopy)
- (NSMutableDictionary *) mutableDeepCopy {
  NSMutableDictionary * returnDict = [[NSMutableDictionary alloc] initWithCapacity:self.count];
  NSArray * keys = [self allKeys];
  for(id key in keys) {
    id aValue = [self objectForKey:key];
    id theCopy = nil;
    if([aValue conformsToProtocol:@protocol(MutableDeepCopying)]) {
      theCopy = [aValue mutableDeepCopy];
    } else if([aValue conformsToProtocol:@protocol(NSMutableCopying)]) {
      theCopy = [aValue mutableCopy];
    } else if([aValue conformsToProtocol:@protocol(NSCopying)]){
      theCopy = [aValue copy];
    } else {
      theCopy = aValue;
    }
    [returnDict setValue:theCopy forKey:key];
  }
  return returnDict;
}
@end

@implementation NSArray (MutableDeepCopy)
-(NSMutableArray *)mutableDeepCopy {
  NSMutableArray *returnArray = [[NSMutableArray alloc] initWithCapacity:self.count];
  for(id aValue in self) {
    id theCopy = nil;
    if([aValue conformsToProtocol:@protocol(MutableDeepCopying)]) {
      theCopy = [aValue mutableDeepCopy];
    } else if([aValue conformsToProtocol:@protocol(NSMutableCopying)]) {
      theCopy = [aValue mutableCopy];
    } else if([aValue conformsToProtocol:@protocol(NSCopying)]){
      theCopy = [aValue copy];
    } else {
      theCopy = aValue;
    }
    [returnArray addObject:theCopy];
  }
  return returnArray;
}
@end
