//
//  BSG_KSObjC.h
//
//  Created by Karl Stenerud on 2012-08-30.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#ifndef HDR_BSG_KSObjC_h
#define HDR_BSG_KSObjC_h

#ifdef __cplusplus
extern "C" {
#endif

#include <CoreFoundation/CoreFoundation.h>
#include <mach/kern_return.h>

typedef enum {
    BSG_KSObjCTypeUnknown = 0,
    BSG_KSObjCTypeClass,
    BSG_KSObjCTypeObject,
    BSG_KSObjCTypeBlock,
} BSG_KSObjCType;

typedef enum {
    BSG_KSObjCClassTypeUnknown = 0,
    BSG_KSObjCClassTypeString,
    BSG_KSObjCClassTypeDate,
    BSG_KSObjCClassTypeURL,
    BSG_KSObjCClassTypeArray,
    BSG_KSObjCClassTypeDictionary,
    BSG_KSObjCClassTypeNumber,
    BSG_KSObjCClassTypeException,
} BSG_KSObjCClassType;

typedef struct {
    const char *name;
    const char *type;
    size_t index;
} BSG_KSObjCIvar;

//======================================================================
#pragma mark - Initialization -
//======================================================================

/** Initialize BSG_KSObjC.
 */
void bsg_ksobjc_init(void);

//======================================================================
#pragma mark - Basic Objective-C Queries -
//======================================================================

/** Check if a pointer is a tagged pointer or not.
 *
 * @param pointer The pointer to check.
 * @return true if it's a tagged pointer.
 */
bool bsg_ksobjc_isTaggedPointer(const void *const pointer);

/** Check if a pointer is a valid tagged pointer.
 *
 * @param pointer The pointer to check.
 * @return true if it's a valid tagged pointer.
 */
bool bsg_ksobjc_isValidTaggedPointer(const void *const pointer);

/** Query a pointer to see what kind of object it points to.
 * If the pointer points to a class, this method will verify that its basic
 * class data and ivars are valid,
 * If the pointer points to an object, it will verify the object data (if
 * recognized as a common class), and the isa's basic class info (everything
 * except ivars).
 *
 * Warning: In order to ensure that an object is both valid and accessible,
 *          always call this method on an object or class pointer (including
 *          those returned by bsg_ksobjc_isaPointer() and
 * bsg_ksobjc_superclass()) BEFORE calling any other function in this module.
 *
 * @param objectOrClassPtr Pointer to something that may be an object or class.
 *
 * @return The type of object, or BSG_KSObjCTypeNone if it was not an object or
 *         was inaccessible.
 */
BSG_KSObjCType bsg_ksobjc_objectType(const void *objectOrClassPtr);

/** Check that an object contains valid data.
 * If the object is of a recognized type (string, date, array, etc),
 * this function will verify that its internal data is intact.
 *
 * Call this function before calling any object-specific functions.
 *
 * @param object The object to verify.
 *
 * @return true if the object is valid.
 */
bool bsg_ksobjc_isValidObject(const void *object);

/** Fetch the isa pointer from an object or class.
 *
 * @param objectOrClassPtr Pointer to a valid object or class.
 *
 * @return The isa pointer.
 */
const void *bsg_ksobjc_isaPointer(const void *objectOrClassPtr);

/** Fetch the super class pointer from a class.
 *
 * @param classPtr Pointer to a valid class.
 *
 * @param the super class.
 */
const void *bsg_ksobjc_superClass(const void *classPtr);

/** Get the base class this class is derived from.
 * It will always return the highest level non-root class in the hierarchy
 * (one below NSObject or NSProxy), unless the passed in object or class
 * actually is a root class.
 *
 * @param classPtr Pointer to a valid class.
 *
 * @return The base class.
 */
const void *bsg_ksobjc_baseClass(const void *const classPtr);

/** Check if a class is a meta class.
 *
 * @param classPtr Pointer to a valid class.
 *
 * @return true if the class is a meta class.
 */
bool bsg_ksobjc_isMetaClass(const void *classPtr);

/** Check if a class is a root class.
 *
 * @param classPtr Pointer to a valid class.
 *
 * @return true if the class is a root class.
 */
bool bsg_ksobjc_isRootClass(const void *classPtr);

/** Get the name of a class.
 *
 * @param classPtr Pointer to a valid class.
 *
 * @return the name, or NULL if the name inaccessible.
 */
const char *bsg_ksobjc_className(const void *classPtr);

/** Get the name of an object's class.
 * This also handles tagged pointers.
 *
 * @param objectPointer Pointer to a valid object.
 *
 * @return the name, or NULL if the name is inaccessible.
 */
const char *bsg_ksobjc_objectClassName(const void *objectPtr);

/** Check if a class has a specific name.
 *
 * @param classPtr Pointer to a valid class.
 *
 * @param className The class name to compare against.
 *
 * @param true if the class has the specified name.
 */
bool bsg_ksobjc_isClassNamed(const void *const classPtr,
                             const char *const className);

/** Check if a class is of the specified type or a subclass thereof.
 * Note: This function is considerably slower than bsg_ksobjc_baseClassName().
 *
 * @param classPtr Pointer to a valid class.
 *
 * @param className The class name to compare against.
 *
 * @param true if the class is of the specified type or a subclass of that type.
 */
bool bsg_ksobjc_isKindOfClass(const void *classPtr, const char *className);

/** Get the number of ivars registered with a class.
 *
 * @param classPtr Pointer to a valid class.
 *
 * @return The number of ivars.
 */
size_t bsg_ksobjc_ivarCount(const void *classPtr);

/** Get information about ivars in a class.
 *
 * @param classPtr Pointer to a valid class.
 *
 * @param dstIvars Buffer to hold ivar data.
 *
 * @param ivarsCount The number of ivars the buffer can hold.
 *
 * @return The number of ivars copied.
 */
size_t bsg_ksobjc_ivarList(const void *classPtr, BSG_KSObjCIvar *dstIvars,
                           size_t ivarsCount);

/** Get ivar information by name/
 *
 * @param classPtr Pointer to a valid class.
 *
 * @param name The name of the ivar to get information about.
 *
 * @param dst Buffer to hold the result.
 *
 * @return true if the operation was successful.
 */
bool bsg_ksobjc_ivarNamed(const void *const classPtr, const char *name,
                          BSG_KSObjCIvar *dst);

/** Get the value of an ivar in an object.
 *
 * @param objectPtr Pointer to a valid object.
 *
 * @param ivarIndex The index of the ivar to fetch.
 *
 * @param dst Pointer to buffer big enough to contain the data.
 *
 * @return true if the operation was successful.
 */
bool bsg_ksobjc_ivarValue(const void *objectPtr, size_t ivarIndex, void *dst);

/* Get the payload from a tagged pointer.
 *
 * @param objectPtr Pointer to a valid object.
 *
 * @return the payload value.
 */
uintptr_t bsg_ksobjc_taggedPointerPayload(const void *taggedObjectPtr);

/** Generate a description of an object.
 *
 * For known common object classes it will print extra information.
 * For all other objects, it will print a standard <SomeClass: 0x12345678>
 *
 * For containers, it will only print the first object in the container.
 *
 * buffer will be null terminated unless bufferLength is 0.
 * If the string doesn't fit, it will be truncated.
 *
 * @param object the object to generate a description for.
 *
 * @param string The string to copy data from.
 *
 * @param buffer The buffer to copy into.
 *
 * @param bufferLength The length of the buffer.
 *
 * @return the number of bytes copied (not including null terminator).
 */
size_t bsg_ksobjc_getDescription(void *object, char *buffer,
                                 size_t bufferLength);

/** Get the class type of an object.
 * There are a number of common class types that BSG_KSObjC understamds,
 * listed in BSG_KSObjCClassType.
 *
 * @param object The object to query.
 *
 * @return The class type, or BSG_KSObjCClassTypeUnknown if it couldn't be
 * determined.
 */
BSG_KSObjCClassType bsg_ksobjc_objectClassType(const void *object);

//======================================================================
#pragma mark - Object-Specific Queries -
//======================================================================

/** Check if a number was stored as floating point.
 *
 * @param object The number to query.
 * @return true if the number is floating point.
 */
bool bsg_ksobjc_numberIsFloat(const void *object);

/** Get the contents of a number as a floating point value.
 *
 * @param object The number.
 * @return The value.
 */
Float64 bsg_ksobjc_numberAsFloat(const void *object);

/** Get the contents of a number as an integer value.
 * If the number was stored as floating point, it will be
 * truncated as per C's conversion rules.
 *
 * @param object The number.
 * @return The value.
 */
int64_t bsg_ksobjc_numberAsInteger(const void *object);

/** Copy the contents of a date object.
 *
 * @param date The date to copy data from.
 *
 * @return Time interval since Jan 1 2001 00:00:00 GMT.
 */
CFAbsoluteTime bsg_ksobjc_dateContents(const void *datePtr);

/** Copy the contents of a URL object.
 *
 * dst will be null terminated unless maxLength is 0.
 * If the string doesn't fit, it will be truncated.
 *
 * @param url The URL to copy data from.
 *
 * @param dst The destination to copy into.
 *
 * @param maxLength The size of the buffer.
 *
 * @return the number of bytes copied (not including null terminator).
 */
size_t bsg_ksobjc_copyURLContents(const void *nsurl, char *dst,
                                  size_t maxLength);

/** Get the length of a string in characters.
 *
 * @param stringPtr Pointer to a string.
 *
 * @return The length of the string.
 */
size_t bsg_ksobjc_stringLength(const void *const stringPtr);

/** Copy the contents of a string object.
 *
 * dst will be null terminated unless maxLength is 0.
 * If the string doesn't fit, it will be truncated.
 *
 * @param string The string to copy data from.
 *
 * @param dst The destination to copy into.
 *
 * @param maxLength The size of the buffer.
 *
 * @return the number of bytes copied (not including null terminator).
 */
size_t bsg_ksobjc_copyStringContents(const void *string, char *dst,
                                     size_t maxLength);

/** Get an NSArray's count.
 *
 * @param arrayPtr The array to get the count from.
 *
 * @return The array's count.
 */
size_t bsg_ksobjc_arrayCount(const void *arrayPtr);

/** Get an NSArray's contents.
 *
 * @param arrayPtr The array to get the contents of.
 *
 * @param contents Location to copy the array's contents into.
 *
 * @param count The number of objects to copy.
 *
 * @return The number of items copied.
 */
size_t bsg_ksobjc_arrayContents(const void *arrayPtr, uintptr_t *contents,
                                size_t count);

//======================================================================
#pragma mark - Broken/Unimplemented Stuff -
//======================================================================

/** Get the first entry from an NSDictionary.
 *
 * WARNING: This function is broken!
 *
 * @param dict The dictionary to copy from.
 *
 * @param key Location to copy the first key into.
 *
 * @param value Location to copy the first value into.
 *
 * @return true if the operation was successful.
 */
bool bsg_ksobjc_dictionaryFirstEntry(const void *dict, uintptr_t *key,
                                     uintptr_t *value);

/** UNIMPLEMENTED
 */
size_t bsg_ksobjc_dictionaryCount(const void *dict);

#ifdef __cplusplus
}
#endif

#endif // HDR_BSG_KSObjC_h
