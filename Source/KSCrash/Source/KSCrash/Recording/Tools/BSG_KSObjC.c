//
//  BSG_KSObjC.c
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

#include "BSG_KSObjC.h"
#include "BSG_KSObjCApple.h"

#include "BSG_KSMach.h"
#include "BSG_KSString.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED > 70000
#include <objc/NSObjCRuntime.h>
#else
#if __LP64__ || (TARGET_OS_EMBEDDED && !TARGET_OS_IPHONE) ||                   \
    TARGET_OS_WIN32 || NS_BUILD_32_LIKE_64
typedef long NSInteger;
typedef unsigned long NSUInteger;
#else
typedef int NSInteger;
typedef unsigned int NSUInteger;
#endif
#endif

#include <CoreGraphics/CGBase.h>
#include <objc/runtime.h>

#define kMaxNameLength 128

//======================================================================
#pragma mark - Macros -
//======================================================================

// Compiler hints for "if" statements
#define likely_if(x) if (__builtin_expect(x, 1))
#define unlikely_if(x) if (__builtin_expect(x, 0))

//======================================================================
#pragma mark - Types -
//======================================================================

typedef struct {
    const char *name;
    BSG_KSObjCClassType type;
} ClassData;

//======================================================================
#pragma mark - Globals -
//======================================================================

static ClassData bsg_g_taggedClassData[] = {
    {"NSAtom", BSG_KSObjCClassTypeUnknown},
    {NULL, BSG_KSObjCClassTypeUnknown},
    {"NSString", BSG_KSObjCClassTypeString},
    {"NSNumber", BSG_KSObjCClassTypeUnknown},
    {"NSIndexPath", BSG_KSObjCClassTypeUnknown},
    {"NSManagedObjectID", BSG_KSObjCClassTypeUnknown},
    {"NSDate", BSG_KSObjCClassTypeUnknown},
    {NULL, BSG_KSObjCClassTypeUnknown},
};
static size_t bsg_g_taggedClassDataCount =
    sizeof(bsg_g_taggedClassData) / sizeof(*bsg_g_taggedClassData);

static const char *bsg_g_blockBaseClassName = "NSBlock";

//======================================================================
#pragma mark - Utility -
//======================================================================

#if SUPPORT_TAGGED_POINTERS
bool bsg_isTaggedPointer(const void *pointer) {
    return (((uintptr_t)pointer) & TAG_MASK) != 0;
}
uintptr_t bsg_getTaggedSlot(const void *pointer) {
    return (((uintptr_t)pointer) >> TAG_SLOT_SHIFT) & TAG_SLOT_MASK;
}
uintptr_t bsg_getTaggedPayload(const void *pointer) {
    return (((uintptr_t)pointer) << TAG_PAYLOAD_LSHIFT) >> TAG_PAYLOAD_RSHIFT;
}
#else
bool bsg_isTaggedPointer(__unused const void *pointer) { return false; }
uintptr_t bsg_getTaggedSlot(__unused const void *pointer) { return 0; }
uintptr_t bsg_getTaggedPayload(const void *pointer) {
    return (uintptr_t)pointer;
}
#endif

/** Get class data for a tagged pointer.
 *
 * @param object The tagged pointer.
 * @return The class data.
 */
static const ClassData *
getClassDataFromTaggedPointer(const void *const object) {
    uintptr_t slot = bsg_getTaggedSlot(object);
    return &bsg_g_taggedClassData[slot];
}

static bool isValidTaggedPointer(const void *object) {
    if (bsg_isTaggedPointer(object)) {
        if (bsg_getTaggedSlot(object) <= bsg_g_taggedClassDataCount) {
            const ClassData *classData = getClassDataFromTaggedPointer(object);
            return classData->type != BSG_KSObjCClassTypeUnknown;
        }
    }
    return false;
}

const void *bsg_decodeIsaPointer(const void *const isaPointer) {
#if ISA_TAG_MASK
    uintptr_t isa = (uintptr_t)isaPointer;
    if (isa & ISA_TAG_MASK) {
        return (const void *)(isa & ISA_MASK);
    }
#endif
    return isaPointer;
}

static inline bool isValidObject(const void *object) {
    if (bsg_isTaggedPointer(object)) {
        return isValidTaggedPointer(object);
    }

    struct class_t data;
    return bsg_ksmachcopyMem(object, &data, sizeof(data)) == KERN_SUCCESS;
}

static inline bool hasValidISAPointer(const void *object) {
    // Note: Assuming that this isn't a tagged pointer!
    const struct class_t *ptr = object;
    const void *isaPtr = bsg_decodeIsaPointer(ptr->isa);
    struct class_t data;
    return bsg_ksmachcopyMem(isaPtr, &data, sizeof(data)) == KERN_SUCCESS;
}

const void *bsg_getIsaPointer(const void *const objectOrClassPtr) {
    const struct class_t *ptr = objectOrClassPtr;
    return bsg_decodeIsaPointer(ptr->isa);
}

static inline struct class_rw_t *getClassRW(const struct class_t *const class) {
    uintptr_t ptr = class->data_NEVER_USE & (~WORD_MASK);
    return (struct class_rw_t *)ptr;
}

static inline const struct class_ro_t *
getClassRO(const struct class_t *const class) {
    return getClassRW(class)->ro;
}

static inline bool isMetaClass(const void *const classPtr) {
    return (getClassRO(classPtr)->flags & RO_META) != 0;
}

static inline bool isRootClass(const void *const classPtr) {
    return (getClassRO(classPtr)->flags & RO_ROOT) != 0;
}

static inline const char *getClassName(const void *classPtr) {
    const struct class_ro_t *ro = getClassRO(classPtr);
    return ro->name;
}

//======================================================================
#pragma mark - Validation -
//======================================================================

// Lookup table for validating class/ivar names and objc @encode types.
// An ivar name must start with a letter, and can contain letters & numbers.
// An ivar type can in theory be any combination of numbers, letters, and
// symbols in the ASCII range (0x21-0x7e).
#define INV 0 // Invalid.
#define N_C                                                                    \
    5 // Name character: Valid for anything except the first letter of a name.
#define N_S 7 // Name start character: Valid for anything.
#define T_C 4 // Type character: Valid for types only.

static const unsigned int bsg_g_nameChars[] = {
    INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV,
    INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV,
    INV, INV, INV, T_C, T_C, T_C, T_C, T_C, T_C, T_C, T_C, T_C, T_C, T_C, T_C,
    T_C, T_C, T_C, N_C, N_C, N_C, N_C, N_C, N_C, N_C, N_C, N_C, N_C, T_C, T_C,
    T_C, T_C, T_C, T_C, T_C, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S,
    N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S,
    N_S, T_C, T_C, T_C, T_C, N_S, T_C, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S,
    N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S, N_S,
    N_S, N_S, N_S, T_C, T_C, T_C, T_C, INV, INV, INV, INV, INV, INV, INV, INV,
    INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV,
    INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV,
    INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV,
    INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV,
    INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV,
    INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV,
    INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV,
    INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV, INV,
    INV,
};

#define VALID_NAME_CHAR(A) ((bsg_g_nameChars[(uint8_t)(A)] & 1) != 0)
#define VALID_NAME_START_CHAR(A) ((bsg_g_nameChars[(uint8_t)(A)] & 2) != 0)
#define VALID_TYPE_CHAR(A) ((bsg_g_nameChars[(uint8_t)(A)] & 7) != 0)

static bool isValidName(const char *const name, const size_t maxLength) {
    if ((uintptr_t)name + maxLength < (uintptr_t)name) {
        // Wrapped around address space.
        return false;
    }

    char buffer[maxLength];
    size_t length = bsg_ksmachcopyMaxPossibleMem(name, buffer, maxLength);
    if (length == 0 || !VALID_NAME_START_CHAR(name[0])) {
        return false;
    }
    for (size_t i = 1; i < length; i++) {
        unlikely_if(!VALID_NAME_CHAR(name[i])) {
            if (name[i] == 0) {
                return true;
            }
            return false;
        }
    }
    return false;
}

static bool isValidIvarType(const char *const type) {
    char buffer[100];
    const size_t maxLength = sizeof(buffer);

    if ((uintptr_t)type + maxLength < (uintptr_t)type) {
        // Wrapped around address space.
        return false;
    }

    size_t length = bsg_ksmachcopyMaxPossibleMem(type, buffer, maxLength);
    if (length == 0 || !VALID_TYPE_CHAR(type[0])) {
        return false;
    }
    for (size_t i = 0; i < length; i++) {
        unlikely_if(!VALID_TYPE_CHAR(type[i])) {
            if (type[i] == 0) {
                return true;
            }
        }
    }
    return false;
}

static bool containsValidROData(const void *const classPtr) {
    struct class_t class;
    struct class_rw_t rw;
    struct class_ro_t ro;
    if (bsg_ksmachcopyMem(classPtr, &class, sizeof(class)) != KERN_SUCCESS) {
        return false;
    }
    if (bsg_ksmachcopyMem(getClassRW(&class), &rw, sizeof(rw)) !=
        KERN_SUCCESS) {
        return false;
    }
    if (bsg_ksmachcopyMem(rw.ro, &ro, sizeof(ro)) != KERN_SUCCESS) {
        return false;
    }
    return true;
}

static bool containsValidIvarData(const void *const classPtr) {
    const struct class_ro_t *ro = getClassRO(classPtr);
    const struct ivar_list_t *ivars = ro->ivars;
    if (ivars == NULL) {
        return true;
    }

    struct ivar_list_t ivarsBuffer;
    if (bsg_ksmachcopyMem(ivars, &ivarsBuffer, sizeof(ivarsBuffer)) !=
        KERN_SUCCESS) {
        return false;
    }

    if (ivars->count > 0) {
        struct ivar_t ivar;
        uint8_t *ivarPtr = (uint8_t *)(&ivars->first) + ivars->entsizeAndFlags;
        for (uint32_t i = 1; i < ivarsBuffer.count; i++) {
            if (bsg_ksmachcopyMem(ivarPtr, &ivar, sizeof(ivar)) !=
                KERN_SUCCESS) {
                return false;
            }
            uintptr_t offset;
            if (bsg_ksmachcopyMem(ivar.offset, &offset, sizeof(offset)) !=
                KERN_SUCCESS) {
                return false;
            }
            if (!isValidName(ivar.name, kMaxNameLength)) {
                return false;
            }
            if (!isValidIvarType(ivar.type)) {
                return false;
            }
            ivarPtr += ivars->entsizeAndFlags;
        }
    }
    return true;
}

static bool containsValidClassName(const void *const classPtr) {
    const struct class_ro_t *ro = getClassRO(classPtr);
    return isValidName(ro->name, kMaxNameLength);
}

//======================================================================
#pragma mark - Basic Objective-C Queries -
//======================================================================

const void *bsg_ksobjc_isaPointer(const void *const objectOrClassPtr) {
    return bsg_getIsaPointer(objectOrClassPtr);
}
const void *bsg_ksobjc_baseClass(const void *const classPtr) {
    const struct class_t *superClass = classPtr;
    const struct class_t *subClass = classPtr;

    for (int i = 0; i < 20; i++) {
        if (isRootClass(superClass)) {
            return subClass;
        }
        subClass = superClass;
        superClass = superClass->superclass;
        if (!containsValidROData(superClass)) {
            return NULL;
        }
    }
    return NULL;
}

static inline bool isBlockClass(const void *class) {
    const void *baseClass = bsg_ksobjc_baseClass(class);
    if (baseClass == NULL) {
        return false;
    }
    const char *name = getClassName(baseClass);
    if (name == NULL) {
        return false;
    }
    return strcmp(name, bsg_g_blockBaseClassName) == 0;
}

BSG_KSObjCType bsg_ksobjc_objectType(const void *objectOrClassPtr) {
    if (objectOrClassPtr == NULL) {
        return BSG_KSObjCTypeUnknown;
    }

    if (bsg_isTaggedPointer(objectOrClassPtr)) {
        return BSG_KSObjCTypeObject;
    }

    if (!isValidObject(objectOrClassPtr)) {
        return BSG_KSObjCTypeUnknown;
    }

    if (!hasValidISAPointer(objectOrClassPtr)) {
        return BSG_KSObjCTypeUnknown;
    }

    const struct class_t *isa = bsg_getIsaPointer(objectOrClassPtr);

    if (!containsValidROData(isa)) {
        return BSG_KSObjCTypeUnknown;
    }
    if (!containsValidClassName(isa)) {
        return BSG_KSObjCTypeUnknown;
    }

    if (isBlockClass(isa)) {
        return BSG_KSObjCTypeBlock;
    }
    if (!isMetaClass(isa)) {
        return BSG_KSObjCTypeObject;
    }

    if (!containsValidIvarData(isa)) {
        return BSG_KSObjCTypeUnknown;
    }
    if (!containsValidClassName(isa)) {
        return BSG_KSObjCTypeUnknown;
    }

    return BSG_KSObjCTypeClass;
}

//======================================================================
#pragma mark - General Queries -
//======================================================================

bool bsg_ksobjc_bsg_isTaggedPointer(const void *const pointer) {
    return bsg_isTaggedPointer(pointer);
}

bool bsg_ksobjc_isValidTaggedPointer(const void *const pointer) {
    return isValidTaggedPointer(pointer);
}

void bsg_ksobjc_init(void) {
#if SUPPORT_TAGGED_POINTERS

#endif
}
