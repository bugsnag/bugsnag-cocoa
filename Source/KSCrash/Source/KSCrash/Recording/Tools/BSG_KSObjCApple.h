//
//  BSG_KSObjCApple.h
//
//  Created by Karl Stenerud on 2012-08-30.
//
// Copyright (c) 2011 Apple Inc. All rights reserved.
//
// This file contains Original Code and/or Modifications of Original Code
// as defined in and that are subject to the Apple Public Source License
// Version 2.0 (the 'License'). You may not use this file except in
// compliance with the License. Please obtain a copy of the License at
// http://www.opensource.apple.com/apsl/ and read it before using this
// file.
//

// This file contains structures and constants copied from Apple header
// files, arranged for use in BSG_KSObjC.

#ifndef HDR_BSG_KSObjCApple_h
#define HDR_BSG_KSObjCApple_h

#ifdef __cplusplus
extern "C" {
#endif

#include <objc/objc.h>

#define MAKE_LIST_T(TYPE)                                                      \
    typedef struct TYPE##_list_t {                                             \
        uint32_t entsizeAndFlags;                                              \
        uint32_t count;                                                        \
        TYPE##_t first;                                                        \
    } TYPE##_list_t;                                                           \
    typedef TYPE##_list_t TYPE##_array_t

#define OBJC_OBJECT(NAME)                                                      \
    NAME {                                                                     \
        Class isa OBJC_ISA_AVAILABILITY;

// ======================================================================
#pragma mark - objc4-680/runtime/objc-msg-x86_64.s -
// and objc4-680/runtime/objc-msg-arm64.s
// ======================================================================

#if __x86_64__
#define ISA_TAG_MASK 1UL
#define ISA_MASK 0x00007ffffffffff8UL
#elif defined(__arm64__)
#define ISA_TAG_MASK 1UL
#define ISA_MASK 0x00000001fffffff8UL
#else
#define ISA_TAG_MASK 0UL
#define ISA_MASK ~1UL
#endif

// ======================================================================
#pragma mark - objc4-680/runtime/objc-config.h -
// ======================================================================

// Define SUPPORT_TAGGED_POINTERS=1 to enable tagged pointer objects
// Be sure to edit tagged pointer SPI in objc-internal.h as well.
#if !(__LP64__)
#define SUPPORT_TAGGED_POINTERS 0
#else
#define SUPPORT_TAGGED_POINTERS 1
#endif

// Define SUPPORT_MSB_TAGGED_POINTERS to use the MSB
// as the tagged pointer marker instead of the LSB.
// Be sure to edit tagged pointer SPI in objc-internal.h as well.
#if !SUPPORT_TAGGED_POINTERS || !TARGET_OS_IPHONE
#define SUPPORT_MSB_TAGGED_POINTERS 0
#else
#define SUPPORT_MSB_TAGGED_POINTERS 1
#endif

// ======================================================================
#pragma mark - objc4-680/runtime/objc-object.h -
// ======================================================================

#if SUPPORT_TAGGED_POINTERS

// KS: The original values wouldn't have worked. The slot shift and mask
// were incorrect.
#define TAG_COUNT 8
//#define TAG_SLOT_MASK 0xf
#define TAG_SLOT_MASK 0x07

#if SUPPORT_MSB_TAGGED_POINTERS
#define TAG_MASK (1ULL << 63)
#define TAG_SLOT_SHIFT 60
#define TAG_PAYLOAD_LSHIFT 4
#define TAG_PAYLOAD_RSHIFT 4
#else
#define TAG_MASK 1
//#   define TAG_SLOT_SHIFT 0
#define TAG_SLOT_SHIFT 1
#define TAG_PAYLOAD_LSHIFT 0
#define TAG_PAYLOAD_RSHIFT 4
#endif

#endif

// ======================================================================
#pragma mark - objc4-680/runtime/objc-internal.h -
// ======================================================================

enum {
    OBJC_TAG_NSAtom = 0,
    OBJC_TAG_1 = 1,
    OBJC_TAG_NSString = 2,
    OBJC_TAG_NSNumber = 3,
    OBJC_TAG_NSIndexPath = 4,
    OBJC_TAG_NSManagedObjectID = 5,
    OBJC_TAG_NSDate = 6,
    OBJC_TAG_7 = 7
};

// ======================================================================
#pragma mark - objc4-680/runtime/objc-os.h -
// ======================================================================

#ifdef __LP64__
#define WORD_SHIFT 3UL
#define WORD_MASK 7UL
#define WORD_BITS 64
#else
#define WORD_SHIFT 2UL
#define WORD_MASK 3UL
#define WORD_BITS 32
#endif

// ======================================================================
#pragma mark - objc4-680/runtime/runtime.h -
// ======================================================================

typedef struct objc_cache *Cache;

// ======================================================================
#pragma mark - objc4-680/runtime/objc-runtime-new.h -
// ======================================================================

typedef struct method_t {
    SEL name;
    const char *types;
    IMP imp;
} method_t;

MAKE_LIST_T(method);

typedef struct ivar_t {
#if __x86_64__
// *offset was originally 64-bit on some x86_64 platforms.
// We read and write only 32 bits of it.
// Some metadata provides all 64 bits. This is harmless for unsigned
// little-endian values.
// Some code uses all 64 bits. class_addIvar() over-allocates the
// offset for their benefit.
#endif
    int32_t *offset;
    const char *name;
    const char *type;
    // alignment is sometimes -1; use alignment() instead
    uint32_t alignment_raw;
    uint32_t size;
} ivar_t;

MAKE_LIST_T(ivar);

typedef struct property_t {
    const char *name;
    const char *attributes;
} property_t;

MAKE_LIST_T(property);

typedef struct OBJC_OBJECT(protocol_t) const char *mangledName;
struct protocol_list_t *protocols;
method_list_t *instanceMethods;
method_list_t *classMethods;
method_list_t *optionalInstanceMethods;
method_list_t *optionalClassMethods;
property_list_t *instanceProperties;
uint32_t size; // sizeof(protocol_t)
uint32_t flags;
// Fields below this point are not always present on disk.
const char **extendedMethodTypes;
const char *_demangledName;
}
protocol_t;

MAKE_LIST_T(protocol);

// Values for class_ro_t->flags
// These are emitted by the compiler and are part of the ABI.
// class is a metaclass
#define RO_META (1 << 0)
// class is a root class
#define RO_ROOT (1 << 1)

typedef struct class_ro_t {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;
#ifdef __LP64__
    uint32_t reserved;
#endif

    const uint8_t *ivarLayout;

    const char *name;
    method_list_t *baseMethodList;
    protocol_list_t *baseProtocols;
    const ivar_list_t *ivars;

    const uint8_t *weakIvarLayout;
    property_list_t *baseProperties;
} class_ro_t;

typedef struct class_rw_t {
    uint32_t flags;
    uint32_t version;

    const class_ro_t *ro;

    method_array_t methods;
    property_array_t properties;
    protocol_array_t protocols;

    Class firstSubclass;
    Class nextSiblingClass;

    char *demangledName;
} class_rw_t;

typedef struct class_t {
    struct class_t *isa;
    struct class_t *superclass;
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    Cache cache;
#pragma clang diagnostic pop
    IMP *vtable;
    uintptr_t data_NEVER_USE; // class_rw_t * plus custom rr/alloc flags
} class_t;

// ======================================================================
#pragma mark - CF-1153.18/CFRuntime.h -
// ======================================================================

typedef struct __CFRuntimeBase {
    uintptr_t _cfisa;
    uint8_t _cfinfo[4];
#if __LP64__
    uint32_t _rc;
#endif
} CFRuntimeBase;

// ======================================================================
#pragma mark - CF-1153.18/CFInternal.h -
// ======================================================================

#if defined(__BIG_ENDIAN__)
#define __CF_BIG_ENDIAN__ 1
#define __CF_LITTLE_ENDIAN__ 0
#endif

#if defined(__LITTLE_ENDIAN__)
#define __CF_LITTLE_ENDIAN__ 1
#define __CF_BIG_ENDIAN__ 0
#endif

#define CF_INFO_BITS (!!(__CF_BIG_ENDIAN__)*3)
#define CF_RC_BITS (!!(__CF_LITTLE_ENDIAN__)*3)

/* Bit manipulation macros */
/* Bits are numbered from 31 on left to 0 on right */
/* May or may not work if you use them on bitfields in types other than UInt32,
 * bitfields the full width of a UInt32, or anything else for which they were
 * not designed. */
/* In the following, N1 and N2 specify an inclusive range N2..N1 with N1 >= N2
 */
#define __CFBitfieldMask(N1, N2)                                               \
    ((((UInt32)~0UL) << (31UL - (N1) + (N2))) >> (31UL - N1))
#define __CFBitfieldGetValue(V, N1, N2) (((V)&__CFBitfieldMask(N1, N2)) >> (N2))

// ======================================================================
#pragma mark - CF-1153.18/CFString.c -
// ======================================================================

// This is separate for C++
struct __notInlineMutable {
    void *buffer;
    CFIndex length;
    CFIndex capacity;        // Capacity in bytes
    unsigned int hasGap : 1; // Currently unused
    unsigned int isFixedCapacity : 1;
    unsigned int isExternalMutable : 1;
    unsigned int capacityProvidedExternally : 1;
#if __LP64__
    unsigned long desiredCapacity : 60;
#else
    unsigned long desiredCapacity : 28;
#endif
    CFAllocatorRef contentsAllocator; // Optional
};                                    // The only mutable variant for CFString

/* !!! Never do sizeof(CFString); the union is here just to make it easier to
 * access some fields.
 */
struct __CFString {
    CFRuntimeBase base;
    union { // In many cases the allocated structs are smaller than these
        struct __inline1 {
            CFIndex length;
        } inline1; // Bytes follow the length
        struct __notInlineImmutable1 {
            void *buffer; // Note that the buffer is in the same place for all
                          // non-inline variants of CFString
            CFIndex length;
            CFAllocatorRef
                contentsDeallocator; // Optional; just the dealloc func is used
        } notInlineImmutable1;       // This is the usual not-inline immutable
                                     // CFString
        struct __notInlineImmutable2 {
            void *buffer;
            CFAllocatorRef
                contentsDeallocator; // Optional; just the dealloc func is used
        } notInlineImmutable2; // This is the not-inline immutable CFString when
                               // length is stored with the contents (first
                               // byte)
        struct __notInlineMutable notInlineMutable;
    } variants;
};

/*
 I = is immutable
 E = not inline contents
 U = is Unicode
 N = has NULL byte
 L = has length byte
 D = explicit deallocator for contents (for mutable objects, allocator)
 C = length field is CFIndex (rather than UInt32); only meaningful for 64-bit,
 really if needed this bit (valuable real-estate) can be given up for another
 bit elsewhere, since this info is needed just for 64-bit

 Also need (only for mutable)
 F = is fixed
 G = has gap
 Cap, DesCap = capacity

 B7 B6 B5 B4 B3 B2 B1 B0
 U  N  L  C  I

 B6 B5
 0  0   inline contents
 0  1   E (freed with default allocator)
 1  0   E (not freed)
 1  1   E D

 !!! Note: Constant CFStrings use the bit patterns:
 C8 (11001000 = default allocator, not inline, not freed contents; 8-bit; has
 NULL byte; doesn't have length; is immutable) D0 (11010000 = default allocator,
 not inline, not freed contents; Unicode; is immutable) The bit usages should
 not be modified in a way that would effect these bit patterns.
 */

enum {
    __kCFFreeContentsWhenDoneMask = 0x020,
    __kCFFreeContentsWhenDone = 0x020,
    __kCFContentsMask = 0x060,
    __kCFHasInlineContents = 0x000,
    __kCFNotInlineContentsNoFree = 0x040,      // Don't free
    __kCFNotInlineContentsDefaultFree = 0x020, // Use allocator's free function
    __kCFNotInlineContentsCustomFree =
        0x060, // Use a specially provided free function
    __kCFHasContentsAllocatorMask = 0x060,
    __kCFHasContentsAllocator =
        0x060, // (For mutable strings) use a specially provided allocator
    __kCFHasContentsDeallocatorMask = 0x060,
    __kCFHasContentsDeallocator = 0x060,
    __kCFIsMutableMask = 0x01,
    __kCFIsMutable = 0x01,
    __kCFIsUnicodeMask = 0x10,
    __kCFIsUnicode = 0x10,
    __kCFHasNullByteMask = 0x08,
    __kCFHasNullByte = 0x08,
    __kCFHasLengthByteMask = 0x04,
    __kCFHasLengthByte = 0x04,
    // !!! Bit 0x02 has been freed up
};

// !!! Assumptions:
// Mutable strings are not inline
// Compile-time constant strings are not inline
// Mutable strings always have explicit length (but they might also have length
// byte and null byte) If there is an explicit length, always use that instead
// of the length byte (length byte is useful for quickly returning pascal
// strings) Never look at the length byte for the length; use __CFStrLength or
// __CFStrLength2

/* The following set of functions and macros need to be updated on change to the
 * bit configuration
 */
CF_INLINE Boolean __CFStrIsMutable(CFStringRef str) {
    return (str->base._cfinfo[CF_INFO_BITS] & __kCFIsMutableMask) ==
           __kCFIsMutable;
}
CF_INLINE Boolean __CFStrIsInline(CFStringRef str) {
    return (str->base._cfinfo[CF_INFO_BITS] & __kCFContentsMask) ==
           __kCFHasInlineContents;
}
CF_INLINE Boolean __CFStrFreeContentsWhenDone(CFStringRef str) {
    return (str->base._cfinfo[CF_INFO_BITS] & __kCFFreeContentsWhenDoneMask) ==
           __kCFFreeContentsWhenDone;
}
CF_INLINE Boolean __CFStrHasContentsDeallocator(CFStringRef str) {
    return (str->base._cfinfo[CF_INFO_BITS] &
            __kCFHasContentsDeallocatorMask) == __kCFHasContentsDeallocator;
}
CF_INLINE Boolean __CFStrIsUnicode(CFStringRef str) {
    return (str->base._cfinfo[CF_INFO_BITS] & __kCFIsUnicodeMask) ==
           __kCFIsUnicode;
}
CF_INLINE Boolean __CFStrIsEightBit(CFStringRef str) {
    return (str->base._cfinfo[CF_INFO_BITS] & __kCFIsUnicodeMask) !=
           __kCFIsUnicode;
}
CF_INLINE Boolean __CFStrHasNullByte(CFStringRef str) {
    return (str->base._cfinfo[CF_INFO_BITS] & __kCFHasNullByteMask) ==
           __kCFHasNullByte;
}
CF_INLINE Boolean __CFStrHasLengthByte(CFStringRef str) {
    return (str->base._cfinfo[CF_INFO_BITS] & __kCFHasLengthByteMask) ==
           __kCFHasLengthByte;
}
CF_INLINE Boolean __CFStrHasExplicitLength(CFStringRef str) {
    return (str->base._cfinfo[CF_INFO_BITS] &
            (__kCFIsMutableMask | __kCFHasLengthByteMask)) !=
           __kCFHasLengthByte;
} // Has explicit length if (1) mutable or (2) not mutable and no length byte
CF_INLINE Boolean __CFStrIsConstant(CFStringRef str) {
#if __LP64__
    return str->base._rc == 0;
#else
    return (str->base._cfinfo[CF_RC_BITS]) == 0;
#endif
}

/* Returns ptr to the buffer (which might include the length byte).
 */
CF_INLINE const void *__CFStrContents(CFStringRef str) {
    if (__CFStrIsInline(str)) {
        return (const void *)(((uintptr_t) & (str->variants)) +
                              (__CFStrHasExplicitLength(str) ? sizeof(CFIndex)
                                                             : 0));
    } else { // Not inline; pointer is always word 2
        return str->variants.notInlineImmutable1.buffer;
    }
}

#ifdef __cplusplus
}
#endif

#endif // HDR_BSG_KSObjCApple_h
