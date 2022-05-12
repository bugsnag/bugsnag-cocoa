//
//  BSGJSONSerialization.m
//  Bugsnag
//
//  Created by Karl Stenerud on 03.09.20.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "BSGJSONSerialization.h"

static NSError* wrapException(NSException* exception) {
    return [NSError errorWithDomain:@"BSGJSONSerializationErrorDomain" code:1 userInfo:@{
        NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]
    }];
}

BOOL BSGJSONDictionaryIsValid(NSDictionary *_Nullable obj) {
    @try {
        return [obj isKindOfClass:[NSDictionary class]] && [NSJSONSerialization isValidJSONObject:(id _Nonnull)obj];
    } @catch (NSException *exception) {
        return NO;
    }
}

NSData *_Nullable BSGJSONDataFromDictionary(NSDictionary *_Nullable obj, NSError **error) {
    if (!obj) {
        return nil;
    }
    @try {
        if (![NSJSONSerialization isValidJSONObject:(id _Nonnull)obj]) {
            if (error) {
                *error = [NSError errorWithDomain:@"BSGJSONSerializationErrorDomain" code:0 userInfo:@{
                    NSLocalizedDescriptionKey: @"Not a valid JSON object"}];
            }
            return nil;
        }
        return [NSJSONSerialization dataWithJSONObject:(id _Nonnull)obj options:0 error:error];
    } @catch (NSException *exception) {
        if (error) {
            *error = wrapException(exception);
        }
        return nil;
    }
    return nil;
}

NSDictionary *_Nullable BSGJSONDictionaryFromData(NSData *data, NSJSONReadingOptions opt, NSError **error) {
    @try {
        id obj = [NSJSONSerialization JSONObjectWithData:data options:opt error:error];
        return [obj isKindOfClass:[NSDictionary class]] ? obj : nil;
    } @catch (NSException *exception) {
        if (error) {
            *error = wrapException(exception);
        }
        return nil;
    }
    return nil;
}

BOOL BSGJSONWriteDictionaryToFile(NSDictionary *_Nullable JSONObject, NSString *file, NSError **errorPtr) {
    if (!BSGJSONDictionaryIsValid(JSONObject)) {
        if (errorPtr) {
            *errorPtr = [NSError errorWithDomain:@"BSGJSONSerializationErrorDomain" code:0 userInfo:@{
                NSLocalizedDescriptionKey: @"Not a valid JSON object"}];
        }
        return NO;
    }
    NSData *data = BSGJSONDataFromDictionary(JSONObject, errorPtr);
    return [data writeToFile:file options:NSDataWritingAtomic error:errorPtr];
}

NSDictionary *_Nullable BSGJSONDictionaryFromFile(NSString *file, NSJSONReadingOptions options, NSError **errorPtr) {
    NSData *data = [NSData dataWithContentsOfFile:file options:0 error:errorPtr];
    if (!data) {
        return nil;
    }
    return BSGJSONDictionaryFromData(data, options, errorPtr);
}
