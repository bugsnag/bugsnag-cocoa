//
//  BugsnagJSON.m
//  Bugsnag
//
//  Created by Simon Maynard on 8/28/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import "BugsnagJSON.h"

@implementation BugsnagJSON
+ (NSString*) encodeDictionary:(NSDictionary*)dictionary {
    CFTypeRef result;
    NSString *returnValue = nil;
    
    id NSJSONClass = NSClassFromString(@"NSJSONSerialization");
    SEL NSJSONSel = NSSelectorFromString(@"dataWithJSONObject:options:error:");
    
    SEL SBJsonSel = NSSelectorFromString(@"JSONRepresentation");
    
    SEL JSONKitSel = NSSelectorFromString(@"JSONString");
    
    SEL YAJLSel = NSSelectorFromString(@"yajl_JSONString");
    
    id NXJsonClass = NSClassFromString(@"NXJsonSerializer");
    SEL NXJsonSel = NSSelectorFromString(@"serialize:");
    
    if(NSJSONClass && [NSJSONClass respondsToSelector:NSJSONSel]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[NSJSONClass methodSignatureForSelector:NSJSONSel]];
        invocation.target = NSJSONClass;
        invocation.selector = NSJSONSel;
        
        __unsafe_unretained NSDictionary *tempDictionary = dictionary;
        [invocation setArgument:&tempDictionary atIndex:2];
        NSUInteger writeOptions = 0;
        [invocation setArgument:&writeOptions atIndex:3];
        
        [invocation invoke];
        
        NSData *data = nil;
        [invocation getReturnValue:&result];
        if (result) {
            CFRetain(result);
        }
        data = (__bridge_transfer NSData *)result;
        
        returnValue = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    } else if (SBJsonSel && [dictionary respondsToSelector:SBJsonSel]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[dictionary methodSignatureForSelector:SBJsonSel]];
        invocation.target = dictionary;
        invocation.selector = SBJsonSel;
        
        [invocation invoke];
        [invocation getReturnValue:&result];
        if (result) {
            CFRetain(result);
        }
        returnValue = (__bridge_transfer NSString *)result;
    } else if (JSONKitSel && [dictionary respondsToSelector:JSONKitSel]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[dictionary methodSignatureForSelector:JSONKitSel]];
        invocation.target = dictionary;
        invocation.selector = JSONKitSel;
        
        [invocation invoke];
        [invocation getReturnValue:&result];
        if (result) {
            CFRetain(result);
        }
        returnValue = (__bridge_transfer NSString *)result;
    } else if (YAJLSel && [dictionary respondsToSelector:YAJLSel]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[dictionary methodSignatureForSelector:YAJLSel]];
        invocation.target = dictionary;
        invocation.selector = YAJLSel;
        
        [invocation invoke];
        [invocation getReturnValue:&result];
        if (result) {
            CFRetain(result);
        }
        returnValue = (__bridge_transfer NSString *)result;
    } else if (NXJsonClass && [NXJsonClass respondsToSelector:NXJsonSel]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[NXJsonClass methodSignatureForSelector:NXJsonSel]];
        invocation.target = NXJsonClass;
        invocation.selector = NXJsonSel;
        
        __unsafe_unretained NSDictionary *tempDictionary = dictionary;
        [invocation setArgument:&tempDictionary atIndex:2];
        
        [invocation invoke];
        [invocation getReturnValue:&result];
        if (result) {
            CFRetain(result);
        }
        returnValue = (__bridge_transfer NSString *)result;
    }
    return returnValue;
}
@end
