//
//  BSGFeatureFlagFileFormat.m
//  Bugsnag
//
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BSGFeatureFlagFileFormat.h"

#import "BugsnagFeatureFlag.h"

#import <errno.h>
#import <string.h>
#import <unistd.h>

/// Writes all of the bytes, returning NO (with errno set) on failure.
BOOL BSGFeatureFlagFileWrite(int fd, const void *bytes, uint64_t length, uint64_t offset) {
    while (length > 0) {
        const ssize_t written = pwrite(fd, bytes, (size_t)length, (off_t)offset);
        if (written < 0) {
            if (errno == EINTR) {
                continue;
            }
            return NO;
        }
        if (written == 0) {
            errno = EIO;
            return NO;
        }
        bytes = (const uint8_t *)bytes + written;
        length -= (uint64_t)written;
        offset += (uint64_t)written;
    }
    return YES;
}

/// Reads exactly length bytes, returning NO if they could not all be read.
BOOL BSGFeatureFlagFileRead(int fd, void *bytes, uint64_t length, uint64_t offset) {
    while (length > 0) {
        const ssize_t count = pread(fd, bytes, (size_t)length, (off_t)offset);
        if (count < 0) {
            if (errno == EINTR) {
                continue;
            }
            return NO;
        }
        if (count == 0) {
            return NO;
        }
        bytes = (uint8_t *)bytes + count;
        length -= (uint64_t)count;
        offset += (uint64_t)count;
    }
    return YES;
}

static NSData * BSGFeatureFlagRecord(NSData *nameData, uint32_t variantLength, NSData *variantData) {
    const uint32_t lengths[2] = {(uint32_t)nameData.length, variantLength};
    NSMutableData *record = [NSMutableData dataWithCapacity:sizeof(lengths) + nameData.length + variantData.length];
    [record appendBytes:lengths length:sizeof(lengths)];
    [record appendData:nameData];
    if (variantData) {
        [record appendData:variantData];
    }
    return record;
}

/// Returns the record for a flag, or nil if it cannot be encoded.
NSData * BSGFeatureFlagEncode(NSString *name, NSString *variant) {
    NSData *nameData = [name dataUsingEncoding:NSUTF8StringEncoding];
    NSData *variantData = [variant dataUsingEncoding:NSUTF8StringEncoding];
    if (!nameData || (variant && !variantData) ||
        nameData.length >= BSGFeatureFlagRemoved || variantData.length >= BSGFeatureFlagRemoved) {
        return nil;
    }
    return BSGFeatureFlagRecord(nameData, variantData ? (uint32_t)variantData.length : BSGFeatureFlagNoVariant, variantData);
}

/// Returns the record that removes a flag whose record was returned by BSGFeatureFlagEncode.
NSData * BSGFeatureFlagEncodeRemoval(NSString *name) {
    NSData *nameData = [name dataUsingEncoding:NSUTF8StringEncoding];
    return nameData ? BSGFeatureFlagRecord(nameData, BSGFeatureFlagRemoved, nil) : nil;
}

/// Decodes UTF-8 bytes, keeping a leading byte order mark, which Foundation would remove.
static NSString * BSGFeatureFlagDecodeString(const uint8_t *bytes, uint32_t length) {
    static const uint8_t byteOrderMark[] = {0xEF, 0xBB, 0xBF};
    NSString *string = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
    if (string && length >= sizeof(byteOrderMark) && memcmp(bytes, byteOrderMark, sizeof(byteOrderMark)) == 0 &&
        [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding] == length - sizeof(byteOrderMark)) {
        string = [@"\uFEFF" stringByAppendingString:string];
    }
    return string;
}

/// Calls the block with each record in the bytes of a log, giving the range of the record. Returns NO if the log is
/// corrupt.
static BOOL BSGFeatureFlagsDecodeBytes(const uint8_t *bytes, uint64_t length,
                                       void (^ block)(NSString *name, NSString *variant, BOOL removed, NSRange range)) {
    uint64_t offset = 0;
    while (offset < length) {
        const uint64_t start = offset;
        uint32_t lengths[2];
        if (length - offset < sizeof(lengths)) {
            return NO;
        }
        memcpy(lengths, bytes + offset, sizeof(lengths));
        offset += sizeof(lengths);
        const uint32_t nameLength = lengths[0];
        const BOOL hasVariant = lengths[1] != BSGFeatureFlagNoVariant && lengths[1] != BSGFeatureFlagRemoved;
        const uint32_t variantLength = hasVariant ? lengths[1] : 0;
        if (nameLength > length - offset || variantLength > length - offset - nameLength) {
            return NO;
        }
        NSString *name = BSGFeatureFlagDecodeString(bytes + offset, nameLength);
        offset += nameLength;
        NSString *variant = nil;
        if (hasVariant) {
            variant = BSGFeatureFlagDecodeString(bytes + offset, variantLength);
            offset += variantLength;
            if (!variant) {
                return NO;
            }
        }
        if (!name) {
            return NO;
        }
        block(name, variant, lengths[1] == BSGFeatureFlagRemoved, NSMakeRange((NSUInteger)start, (NSUInteger)(offset - start)));
    }
    return YES;
}

/// Calls the block with each record in a log: the flag it adds and its encoded record, or the name of
/// the flag it removes. Returns NO if the log is corrupt.
BOOL BSGFeatureFlagsDecode(NSData *log,
                           void (^ block)(NSString *name, NSString *variant, BOOL removed, NSData *record)) {
    const uint8_t *bytes = log.bytes;
    return BSGFeatureFlagsDecodeBytes(bytes, log.length, ^(NSString *name, NSString *variant, BOOL removed, NSRange range) {
        // The record refers to the log's bytes rather than copying them; the log stays allocated for as long as
        // any record does.
        NSData *record = [[NSData alloc] initWithBytesNoCopy:(void *)(uintptr_t)(bytes + range.location) length:range.length
                                                 deallocator:^(__unused void *recordBytes, __unused NSUInteger recordLength) {
            (void)log;
        }];
        block(name, variant, removed, record);
    });
}

/// Decodes a record returned by BSGFeatureFlagEncode.
BugsnagFeatureFlag * BSGFeatureFlagDecodeRecord(NSData *record) {
    __block BugsnagFeatureFlag *flag = nil;
    BSGFeatureFlagsDecodeBytes(record.bytes, record.length, ^(NSString *name, NSString *variant, BOOL removed, __unused NSRange range) {
        if (!removed) {
            flag = [BugsnagFeatureFlag flagWithName:name variant:variant];
        }
    });
    return flag;
}
