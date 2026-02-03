//
//  BSGRelativeAddressExtractor.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 20/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGRelativeAddressExtractor.h"

static NSString * const JsonKeyFrameAddress = @"frameAddress";
static NSString * const JsonKeyLoadAddress = @"loadAddress";
static NSString * const JsonKeyMachoLoadAddress = @"machoLoadAddress";

@implementation BSGRelativeAddressExtractor

- (void)extractFromJSON:(NSDictionary<NSString *,id> *)json onElementExtracted:(void (^)(NSString *))onElementExtracted {
    for (id element in [self.path extractFromJSON:json]) {
        if (![element isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *elementJson = element;
        id frameAddressValue = elementJson[JsonKeyFrameAddress];
        id loadAddressValue = elementJson[JsonKeyLoadAddress];
        if (![loadAddressValue isKindOfClass:[NSString class]]) {
            loadAddressValue = elementJson[JsonKeyMachoLoadAddress];
        }
        
        // Convert to unsigned long long for address arithmetic
        unsigned long long frameAddress = [self parseAddress:frameAddressValue];
        unsigned long long loadAddress = [self parseAddress:loadAddressValue];
        
        if (frameAddress != 0 && loadAddress != 0) {
            unsigned long long relativeAddress = frameAddress - loadAddress;
            
            // Format as hex string with 0x prefix
            NSString *relativeAddressString = [NSString stringWithFormat:@"0x%llx", relativeAddress];
            onElementExtracted(relativeAddressString);
        }
    }
}

- (unsigned long long)parseAddress:(id)value {
    if ([value isKindOfClass:[NSString class]]) {
        NSString *stringValue = (NSString *)value;
        // Remove 0x prefix if present
        if ([stringValue hasPrefix:@"0x"]) {
            stringValue = [stringValue substringFromIndex:2];
        }
        // Parse hex string
        unsigned long long address = 0;
        NSScanner *scanner = [NSScanner scannerWithString:stringValue];
        [scanner scanHexLongLong:&address];
        return address;
    } else if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value unsignedLongLongValue];
    }
    return 0;
}

@end
