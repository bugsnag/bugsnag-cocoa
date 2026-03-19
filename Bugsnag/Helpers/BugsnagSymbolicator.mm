//
//  BugsnagSymbolicator.mm
//  Bugsnag
//
//  Created by Robert Bartoszewski on 19/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <Bugsnag/BugsnagSymbolicator.h>
#import <Bugsnag/BugsnagStackframe.h>

#include "BSG_Symbolicate.h"
#include "BSG_KSMachHeaders.h"

@implementation BugsnagSymbolicator

+ (void)symbolicateStackframes:(NSArray<BugsnagStackframe *> *)stackframes {
    if (!stackframes.count) {
        return;
    }
    
    for (BugsnagStackframe *frame in stackframes) {
        // Only symbolicate if we have a frame address but missing method name
        if (frame.frameAddress == nil || frame.method != nil) {
            continue;
        }
        
        uintptr_t address = [frame.frameAddress unsignedLongValue];
        struct bsg_symbolicate_result result;
        bsg_symbolicate(address, &result);
        
        if (result.image) {
            // Set the method/symbol name
            if (result.function_name) {
                frame.method = @(result.function_name);
            }
            
            // Set the binary image information
            if (result.image->name) {
                frame.machoFile = @(result.image->name);
            }
            
            if (result.image->uuid) {
                // Convert UUID bytes to string
                const uint8_t *uuid = result.image->uuid;
                frame.machoUuid = [NSString stringWithFormat:
                    @"%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
                    uuid[0], uuid[1], uuid[2], uuid[3],
                    uuid[4], uuid[5], uuid[6], uuid[7],
                    uuid[8], uuid[9], uuid[10], uuid[11],
                    uuid[12], uuid[13], uuid[14], uuid[15]];
            }
            
            frame.machoLoadAddress = @((uintptr_t)result.image->header);
            
            if (result.image->imageVmAddr) {
                frame.machoVmAddress = @(result.image->imageVmAddr);
            }
            
            // Set symbol address if available
            if (result.function_address) {
                frame.symbolAddress = @(result.function_address);
            }
        }
    }
}

@end
