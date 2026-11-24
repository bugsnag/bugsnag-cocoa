//
//  BSGFeatureFlagFileFormat.h
//  Bugsnag
//
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BSGDefines.h"

#import <stddef.h>
#import <stdint.h>

@class BugsnagFeatureFlag;

//
// The format of featureflag.bin, in which BSGPersistentFeatureFlagStore saves the feature flags.
//
// The flags are stored in a single binary file containing two slots, each of which can hold a
// log of changes to the flags:
//
//   [header][slot 0][slot 1]
//   log = record*
//   record = [name length][variant length][name][variant]
//
// Lengths are uint32 values in native byte order (little-endian on every supported platform),
// and records are packed with no alignment padding. The name and variant are UTF-8.
//
// The variant length is UINT32_MAX for a flag without a variant, and UINT32_MAX - 1 for a
// record that removes the flag (which has no variant bytes). Replaying the log in order gives
// the flags, in the same order as BSGMemoryFeatureFlagStore keeps them: a record for a flag that
// is already present replaces its variant and keeps its position, and a record for a flag that is
// not present (including one removed by an earlier record) adds it at the end.
//
// File format policy. Released versions of the SDK only read files whose version they know,
// so once a format version has been released it must never change:
//
// - A change that older versions can ignore uses the reserved header fields, which are written
//   as zero and ignored when read; a newer version must treat zero as "not set". They may only
//   hold values that are fixed when the file is created (a file is always created whole and
//   renamed into place), because an older version that appends to a newer version's file leaves
//   them unchanged. Anything that describes the log needs a new version.
// - Any other change (header layout, record layout, the meaning of a length or of the special
//   variant lengths) needs a new version number. A version that writes format N+1 must still
//   read every earlier version, so that flags survive an upgrade.
// - A file with a different magic number or an unknown version is discarded, never misread. So
//   when older and newer versions of the SDK replace each other (upgrade, downgrade, or two
//   versions in the same container), only the flags from the previous launch can be lost.
// - The JSON files written by SDK versions before this file existed (one file per flag) are
//   imported and deleted at launch. That import must be kept as long as an upgrade from such a
//   version is supported (see BSGLegacyFeatureFlags.h).
//

NS_ASSUME_NONNULL_BEGIN

__BEGIN_DECLS

static const uint32_t BSGFeatureFlagFileMagic = 0x46465342; // "BSFF"
static const uint32_t BSGFeatureFlagFileVersion = 1;
static const uint32_t BSGFeatureFlagNoVariant = UINT32_MAX;
static const uint32_t BSGFeatureFlagRemoved = UINT32_MAX - 1;
// The most flags that are persisted: flags whose records take up more than this (just under 2 MB) are
// kept in memory but not persisted.
#define BSG_FEATURE_FLAG_MAX_PERSISTED_LENGTH (2ULL * 1024 * 1024 - 16)
static const uint64_t BSGFeatureFlagMaxPersistedLength = BSG_FEATURE_FLAG_MAX_PERSISTED_LENGTH;
// The largest slot capacity that is written, which makes the largest file 8 MB. It is at least twice
// the most flags that are persisted, so that a log of flags at that limit can still double before it is
// rewritten; otherwise nearly every change to such flags would rewrite all of them. Files are not
// preallocated, so the disk space used is only that of the parts of the slots that have been written.
#define BSG_FEATURE_FLAG_MAX_SLOT_CAPACITY (4ULL * 1024 * 1024 - 16)
static const uint64_t BSGFeatureFlagMaxSlotCapacity = BSG_FEATURE_FLAG_MAX_SLOT_CAPACITY;
// The largest slot capacity that is read; anything larger in a header means the file is corrupt.
// It is larger than the capacity that is written so that a later version can raise that limit
// without its files being discarded by this one, and small enough that a corrupt header cannot
// make the store read or allocate much memory (only the active log is read).
#define BSG_FEATURE_FLAG_MAX_READABLE_SLOT_CAPACITY (16ULL * 1024 * 1024)
static const uint64_t BSGFeatureFlagMaxReadableSlotCapacity = BSG_FEATURE_FLAG_MAX_READABLE_SLOT_CAPACITY;

struct bsg_feature_flag_file_header {
    uint32_t magic;
    uint32_t version;
    uint32_t slotCapacity; // Size of each of the two slots that follow the header
    uint32_t reserved;
    // The length of the log (high bits) and the slot it is in (low bit).
    uint64_t active;
    uint64_t reserved2;
};

// The layout is part of the file format, so it must be the same on every architecture (e.g. arm64_32).
_Static_assert(sizeof(struct bsg_feature_flag_file_header) == 32, "Feature flag file header size");
_Static_assert(offsetof(struct bsg_feature_flag_file_header, active) == 16, "Feature flag file header layout");
// The macros are used because older compilers don't treat static const variables as constant
// expressions in C.
_Static_assert(BSG_FEATURE_FLAG_MAX_SLOT_CAPACITY <= BSG_FEATURE_FLAG_MAX_READABLE_SLOT_CAPACITY, "Files that are written must be readable");
_Static_assert(BSG_FEATURE_FLAG_MAX_READABLE_SLOT_CAPACITY <= UINT32_MAX, "Slot capacities must fit in the header");
_Static_assert(2 * BSG_FEATURE_FLAG_MAX_PERSISTED_LENGTH <= BSG_FEATURE_FLAG_MAX_SLOT_CAPACITY,
               "The largest slot must have room for a log of the most flags that are persisted to double");

static inline uint64_t BSGFeatureFlagFileActiveValue(uint64_t length, uint32_t slot) {
    return (length << 1) | slot;
}

// Calculated in 64 bits because it can overflow a 32-bit size_t (e.g. on arm64_32) for a corrupt header.
static inline uint64_t BSGFeatureFlagFileSize(uint64_t slotCapacity) {
    return sizeof(struct bsg_feature_flag_file_header) + 2 * slotCapacity;
}

static inline uint64_t BSGFeatureFlagSlotOffset(uint64_t slotCapacity, uint32_t slot) {
    return sizeof(struct bsg_feature_flag_file_header) + slot * slotCapacity;
}

/// Writes all of the bytes, returning NO (with errno set) on failure.
BOOL BSGFeatureFlagFileWrite(int fd, const void *bytes, uint64_t length, uint64_t offset);

/// Reads exactly length bytes, returning NO if they could not all be read.
BOOL BSGFeatureFlagFileRead(int fd, void *bytes, uint64_t length, uint64_t offset);

/// Returns the record for a flag, or nil if it cannot be encoded.
NSData * _Nullable BSGFeatureFlagEncode(NSString *name, NSString * _Nullable variant);

/// Returns the record that removes a flag whose record was returned by BSGFeatureFlagEncode.
NSData * _Nullable BSGFeatureFlagEncodeRemoval(NSString *name);

/// Calls the block with each record in a log: the flag it adds and its encoded record, or the name of
/// the flag it removes. Returns NO if the log is corrupt. Each record is a copy of its bytes in the log.
BOOL BSGFeatureFlagsDecode(NSData *log,
                           void (^ block)(NSString *name, NSString * _Nullable variant, BOOL removed, NSData *record));

/// Decodes a record returned by BSGFeatureFlagEncode.
BugsnagFeatureFlag * _Nullable BSGFeatureFlagDecodeRecord(NSData *record);

__END_DECLS

NS_ASSUME_NONNULL_END
