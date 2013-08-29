//
//  BugsnagEvent.m
//  bugsnag
//
//  Created by Simon Maynard on 8/28/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import <execinfo.h>
#include <string.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>
#import <mach-o/arch.h>

#import "BugsnagEvent.h"

@interface BugsnagEvent ()
@property (atomic, strong) NSMutableDictionary *dictionary;
@end

@implementation BugsnagEvent

- (id) initWithConfiguration:(BugsnagConfiguration *)configuration andMetaData:(BugsnagMetaData*)metaData {
    if (self = [super init]) {
        self.dictionary = [[NSMutableDictionary alloc] init];
        
        [self.dictionary setObject:configuration.userId forKey:@"userId"];
        [self.dictionary setObject:configuration.appVersion forKey:@"appVersion"];
        [self.dictionary setObject:configuration.osVersion forKey:@"osVersion"];
        [self.dictionary setObject:configuration.context forKey:@"context"];
        [self.dictionary setObject:configuration.releaseStage forKey:@"releaseStage"];
        [self.dictionary setObject:[metaData toDictionary] forKey:@"metaData"];
    }
    return self;
}

- (void) addSignal:(int) signal {
    int count = 256;
    void *frames[count];
    count = backtrace(frames, count);
}

- (void) addException:(NSException*)exception {
    if([[exception callStackReturnAddresses] count] == 0) {
        @try {
            @throw exception;
        }
        @catch (NSException *exception) {}
    }
}

- (NSDictionary *) getStackTraceWithException:(NSException*) exception {
    
}

+ (NSDictionary *) loadedImages {
    //Get count of all currently loaded images
    uint32_t count = _dyld_image_count();
    NSMutableDictionary *returnValue = [NSMutableDictionary dictionary];
    
    for(uint32_t i = 0; i < count; i++) {
        const char *dyld = _dyld_get_image_name(i);
        const struct mach_header *header = _dyld_get_image_header(i);
        const NXArchInfo *info = NXGetArchInfoFromCpuType(header->cputype, header->cpusubtype);
        
        NSString *objectFile = [NSString stringWithCString:dyld encoding:NSStringEncodingConversionAllowLossy];
        NSString *objectName = [NSString stringWithCString:(rindex(dyld, '/') + sizeof(char)) encoding:NSStringEncodingConversionAllowLossy];
        NSNumber *objectAddress = [NSNumber numberWithUnsignedInt:(uint32_t)header];
        NSString *objectArchitecture = [NSString stringWithCString:info->name encoding:NSStringEncodingConversionAllowLossy];
        NSString *objectUUID = nil;
        
        // Now lets look at the load_commands
        uint8_t *header_ptr = (uint8_t*)header;
        header_ptr += sizeof(struct mach_header);
        struct load_command *command = (struct load_command*)header_ptr;
        
        for(int i = 0; i < header->ncmds > 0; ++i) {
            // We are only interested in the UUID command
            if(command->cmd == LC_UUID) {
                struct uuid_command ucmd = *(struct uuid_command*)header_ptr;
                
                CFUUIDRef cuuid = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, *((CFUUIDBytes*)ucmd.uuid));
                CFStringRef suuid = CFUUIDCreateString(kCFAllocatorDefault, cuuid);
                CFStringEncoding encoding = CFStringGetFastestEncoding(suuid);
                
                objectUUID = [NSString stringWithCString:CFStringGetCStringPtr(suuid, encoding) encoding:NSStringEncodingConversionAllowLossy];
                
                CFRelease(cuuid);
                CFRelease(suuid);
                
                break;
            }
            
            header_ptr += command->cmdsize;
            command = (struct load_command*)header_ptr;
        }
        
        NSDictionary *objectValues = [NSDictionary dictionaryWithObjectsAndKeys:objectFile, @"objectFile",
                                                                                objectAddress, @"objectAddress",
                                                                                objectUUID, @"objectUUID",
                                                                                objectArchitecture, @"objectArchitecture", nil];
        [returnValue setObject:objectValues forKey:objectName];
    }
    return returnValue;
}

- (NSDictionary *) toDictionary {
    return [NSDictionary dictionaryWithDictionary:self.dictionary];
}
@end
