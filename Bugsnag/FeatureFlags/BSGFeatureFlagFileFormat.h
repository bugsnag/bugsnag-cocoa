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
// Format of featureflag.bin, in which BSGPersistentFeatureFlagStore saves the feature flags: a header and two slots,
// each able to hold a log of changes to the flags.
//
//   [header][slot 0][slot 1]
//   log = record*
//   record = [name length][variant length][name][variant]
//
// Lengths are uint32 in native byte order (little-endian on every supported platform); records are packed with no
// padding; name and variant are UTF-8. Variant length UINT32_MAX means no variant; UINT32_MAX - 1 means the record
// removes the flag (no variant bytes). Replaying the log in order gives the flags in BSGMemoryFeatureFlagStore's
// order: a record for a present flag replaces its variant in place; one for an absent flag (including one removed
// earlier) adds it at the end.
//
// File format policy. Released SDK versions only read files whose version they know, so a released format version
// must never change:
// - Changes older versions can ignore use the reserved header fields: written as zero, ignored when read, zero means
//   "not set". They may only hold values fixed at creation (a file is always created whole and renamed into place),
//   because an older version appending to a newer file leaves them unchanged. Anything describing the log needs a new
//   version.
// - All integers are little-endian (checked at build time, below).
// - Any other change (header or record layout, the meaning of a length or of the special variant lengths) needs a new
//   version number. A version that writes format N+1 must still read every earlier version, so flags survive upgrades.
// - A file with another magic number or an unknown version is discarded, never misread, so when SDK versions replace
//   each other (upgrade, downgrade, or two versions in one container) at most the previous launch's flags are lost.
// - The one-file-per-flag JSON files of earlier SDK versions are imported and deleted at launch; keep that import as
//   long as upgrading from such a version is supported (see BSGLegacyFeatureFlags.h).
//

NS_ASSUME_NONNULL_BEGIN

__BEGIN_DECLS

static const uint32_t BSGFeatureFlagFileMagic = 0x46465342; // "BSFF"
static const uint32_t BSGFeatureFlagFileVersion = 1;
static const uint32_t BSGFeatureFlagNoVariant = UINT32_MAX;
static const uint32_t BSGFeatureFlagRemoved = UINT32_MAX - 1;
// Flags whose records exceed this (just under 2 MB) are kept in memory but not persisted.
#define BSG_FEATURE_FLAG_MAX_PERSISTED_LENGTH (2ULL * 1024 * 1024 - 16)
static const uint64_t BSGFeatureFlagMaxPersistedLength = BSG_FEATURE_FLAG_MAX_PERSISTED_LENGTH;
// The largest slot capacity written (an 8 MB file). At least twice the persisted limit, so a log at the limit can
// double before a rewrite rather than nearly every change rewriting it. Files are not preallocated, so only the
// written parts of the slots use disk space.
#define BSG_FEATURE_FLAG_MAX_SLOT_CAPACITY (4ULL * 1024 * 1024 - 16)
static const uint64_t BSGFeatureFlagMaxSlotCapacity = BSG_FEATURE_FLAG_MAX_SLOT_CAPACITY;
// The largest slot capacity read; a larger one means the header is corrupt. Above the written capacity so a later
// version can raise that without this one discarding its files; small enough that a corrupt header cannot make the
// store read or allocate much memory (only the active log is read).
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
// Integers use the host's byte order, which is little-endian on every supported platform. A big-endian build must
// convert them rather than write another byte order.
#ifndef __LITTLE_ENDIAN__
#error "The feature flag file format is little-endian: convert its integers before building for a big-endian target"
#endif
// Macros, because older compilers don't treat static const variables as constant expressions in C.
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
