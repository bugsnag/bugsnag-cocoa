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
bool bsg_ksobjc_bsg_isTaggedPointer(const void *const pointer);

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

/** Fetch the isa pointer from an object or class.
 *
 * @param objectOrClassPtr Pointer to a valid object or class.
 *
 * @return The isa pointer.
 */
const void *bsg_ksobjc_isaPointer(const void *objectOrClassPtr);

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


#ifdef __cplusplus
}
#endif

#endif // HDR_BSG_KSObjC_h
