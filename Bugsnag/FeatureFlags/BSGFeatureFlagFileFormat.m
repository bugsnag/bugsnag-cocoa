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

NSData * BSGFeatureFlagEncode(NSString *name, NSString *variant) {
    NSData *nameData = [name dataUsingEncoding:NSUTF8StringEncoding];
    NSData *variantData = [variant dataUsingEncoding:NSUTF8StringEncoding];
    if (!nameData || (variant && !variantData) ||
        nameData.length >= BSGFeatureFlagRemoved || variantData.length >= BSGFeatureFlagRemoved) {
        return nil;
    }
    return BSGFeatureFlagRecord(nameData, variantData ? (uint32_t)variantData.length : BSGFeatureFlagNoVariant, variantData);
}

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

/// As BSGFeatureFlagsDecode, but on raw bytes, giving each record's range.
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

BOOL BSGFeatureFlagsDecode(NSData *log,
                           void (^ block)(NSString *name, NSString *variant, BOOL removed, NSData *record)) {
    return BSGFeatureFlagsDecodeBytes(log.bytes, log.length, ^(NSString *name, NSString *variant, BOOL removed, NSRange range) {
        block(name, variant, removed, [log subdataWithRange:range]);
    });
}

BugsnagFeatureFlag * BSGFeatureFlagDecodeRecord(NSData *record) {
    __block BugsnagFeatureFlag *flag = nil;
    BSGFeatureFlagsDecodeBytes(record.bytes, record.length, ^(NSString *name, NSString *variant, BOOL removed, __unused NSRange range) {
        if (!removed) {
            flag = [BugsnagFeatureFlag flagWithName:name variant:variant];
        }
    });
    return flag;
}
