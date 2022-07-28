#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Removes any values which would be rejected by NSJSONSerialization for
 documented reasons

 @param input an array
 @return a new array
 */
NSArray * BSGSanitizeArray(NSArray *input);

/**
 Removes any values which would be rejected by NSJSONSerialization for
 documented reasons

 @param input a dictionary
 @return a new dictionary
 */
NSDictionary * BSGSanitizeDict(NSDictionary *input);

/**
 Checks whether the base type would be accepted by the serialization process

 @param obj any object or nil
 @return YES if the object is an Array, Dictionary, String, Number, or NSNull
 */
BOOL BSGIsSanitizedType(id _Nullable obj);

/**
 Cleans the object, including nested dictionary and array values

 @param obj any object or nil
 @return a new object for serialization or nil if the obj was incompatible
 */
id _Nullable BSGSanitizeObject(id _Nullable obj);

typedef struct _BSGTruncateContext {
    NSUInteger maxLength;
    NSUInteger strings;
    NSUInteger length;
} BSGTruncateContext;

NSString * BSGTruncateString(BSGTruncateContext *context, NSString *string);

id BSGTruncateStrings(BSGTruncateContext *context, id object);

NS_ASSUME_NONNULL_END
