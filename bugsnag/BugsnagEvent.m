//
//  BugsnagEvent.m
//  bugsnag
//
//  Created by Simon Maynard on 8/28/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#include <dlfcn.h>
#import <execinfo.h>
#import <mach-o/dyld.h>
#import <mach-o/arch.h>

#import "BugsnagEvent.h"

@interface BugsnagEvent ()
@property (atomic, strong) NSMutableDictionary *dictionary;

- (void) addExceptionWithClass:(NSString*) errorClass andMessage:(NSString*) message andStacktrace:(NSArray*) stacktrace;
@end

@implementation BugsnagEvent

- (id) initWithConfiguration:(BugsnagConfiguration *)configuration andMetaData:(BugsnagMetaData*)metaData {
    if (self = [super init]) {
        self.dictionary = [[NSMutableDictionary alloc] init];
        
        if (configuration.userId != nil) [self.dictionary setObject:configuration.userId forKey:@"userId"];
        if (configuration.appVersion != nil) [self.dictionary setObject:configuration.appVersion forKey:@"appVersion"];
        if (configuration.osVersion != nil) [self.dictionary setObject:configuration.osVersion forKey:@"osVersion"];
        if (configuration.context != nil) [self.dictionary setObject:configuration.context forKey:@"context"];
        if (configuration.releaseStage != nil) [self.dictionary setObject:configuration.releaseStage forKey:@"releaseStage"];
        if (metaData != nil) [self.dictionary setObject:[metaData toDictionary] forKey:@"metaData"];
    }
    return self;
}

- (void) addSignal:(int) signal {
    NSString *errorClass = [NSString stringWithCString:strsignal(signal) encoding:NSUTF8StringEncoding];
    NSString *message = @"";
    NSArray *stacktrace = [BugsnagEvent getStackTraceWithException:nil];
    
    [self addExceptionWithClass:errorClass andMessage:message andStacktrace:stacktrace];
}

- (void) addException:(NSException*)exception {
    NSArray *stacktrace = [BugsnagEvent getStackTraceWithException:nil];
    //TODO:SM can we use userdata on the exception as metadata?
    
    [self addExceptionWithClass:exception.name andMessage:exception.reason andStacktrace:stacktrace];
}

- (void) addExceptionWithClass:(NSString*) errorClass andMessage:(NSString*) message andStacktrace:(NSArray*) stacktrace {
    NSMutableArray *exceptions = [self.dictionary objectForKey:@"exceptions"];
    if (exceptions == nil) {
        exceptions = [NSMutableArray array];
        [self.dictionary setObject:exceptions forKey:@"exceptions"];
    }
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys: errorClass, @"errorClass",
                                                                           message, @"message",
                                                                           stacktrace, @"stacktrace", nil];
    [exceptions addObject:dictionary];
}

+ (NSArray *) getStackTraceWithException:(NSException*) exception {
    // TODO:SM Make this work with non stripped code
    int count = 256;
    void *frames[count];
    
    // Try to grab the addresses from the exception, if not just grab what we have now
    if (exception != nil && [[exception callStackReturnAddresses] count] != 0 ) {
        NSArray *stackFrames = [exception callStackReturnAddresses];
        count = stackFrames.count;
        for (int i = 0; i < count; ++i) {
            frames[i] = (void *)[[stackFrames objectAtIndex:i] intValue];
        }
    } else {
        //TODO:SM When we have this settled we should think about stripping our own code from these frames
        count = backtrace(frames, count);
    }
    Dl_info info;
    
    NSMutableArray *stackTrace = [NSMutableArray array];
    NSDictionary *loadedImages = [self loadedImages];
    
    for(uint32_t i = 0; i < count; i++) {
        int status = dladdr(frames[i], &info);
        if (status != 0) {
            NSString *fileName = info.dli_fname ? [NSString stringWithCString:info.dli_fname encoding:NSStringEncodingConversionAllowLossy] : @"";
//            NSString *sname = info.dli_sname ? [NSString stringWithCString:info.dli_sname encoding:NSStringEncodingConversionAllowLossy] : @"";
//            
//            NSLog(@"dli_fname: %@, dli_sname: %@, dli_fbase: 0x%08x, dli_saddr: 0x%08x", fileName, sname, (uint32_t)info.dli_fbase, (uint32_t)info.dli_saddr);
//            
            NSMutableDictionary *frame = [NSMutableDictionary dictionaryWithDictionary:[loadedImages objectForKey:fileName]];
            [frame setObject:[NSString stringWithFormat:@"0x%08x", (uint32_t)info.dli_saddr] forKey:@"objectAddress"];
            //TODO:SM Set the mainObject field appropriately
            
            [stackTrace addObject:[NSDictionary dictionaryWithDictionary:frame]];
        }
    }
    
//    NSLog(@"That was the dladdr now for symbols");
//    char **strs = backtrace_symbols(frames, count);
//    for(uint32_t i = 0; i < count; i++) {
//        NSLog(@"%@\n", [NSString stringWithCString:strs[i] encoding:NSStringEncodingConversionAllowLossy]);
//    }
    
//    NSLog(@"Now to log the loaded images");
//    NSLog(@"%@", loadedImages);
    
    return [NSArray arrayWithArray:stackTrace];
}

+ (NSDictionary *) loadedImages {
    //Get count of all currently loaded images
    uint32_t count = _dyld_image_count();
    NSMutableDictionary *returnValue = [NSMutableDictionary dictionary];
    
    for (uint32_t i = 0; i < count; i++) {
        const char *dyld = _dyld_get_image_name(i);
        const struct mach_header *header = _dyld_get_image_header(i);
        const NXArchInfo *info = NXGetArchInfoFromCpuType(header->cputype, header->cpusubtype);
        
        NSString *objectFile = [NSString stringWithCString:dyld encoding:NSStringEncodingConversionAllowLossy];
        //NSString *objectName = [NSString stringWithCString:(rindex(dyld, '/') + sizeof(char)) encoding:NSStringEncodingConversionAllowLossy];
        NSString *objectAddress = [NSString stringWithFormat:@"0x%08x", (uint32_t)header];
        NSString *objectArchitecture = [NSString stringWithCString:info->name encoding:NSStringEncodingConversionAllowLossy];
        NSString *objectUUID = nil;
        
        // Now lets look at the load_commands
        uint8_t *header_ptr = (uint8_t*)header;
        header_ptr += sizeof(struct mach_header);
        struct load_command *command = (struct load_command*)header_ptr;
        
        for (int i = 0; i < header->ncmds > 0; ++i) {
            if (command->cmd == LC_UUID) {
                struct uuid_command ucmd = *(struct uuid_command*)header_ptr;
                
                CFUUIDRef cuuid = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, *((CFUUIDBytes*)ucmd.uuid));
                CFStringRef suuid = CFUUIDCreateString(kCFAllocatorDefault, cuuid);
                CFStringEncoding encoding = CFStringGetFastestEncoding(suuid);
                
                objectUUID = [NSString stringWithCString:CFStringGetCStringPtr(suuid, encoding) encoding:NSStringEncodingConversionAllowLossy];
                
                CFRelease(cuuid);
                CFRelease(suuid);
            } else if (command->cmd == LC_SEGMENT) {
                struct segment_command ucmd = *(struct segment_command*)header_ptr;
                if (strcmp("__TEXT", ucmd.segname) == 0) {
                    objectAddress = [NSString stringWithFormat:@"0x%08x", (uint32_t)header - (uint32_t)ucmd.vmaddr];
                }
            }
            
            header_ptr += command->cmdsize;
            command = (struct load_command*)header_ptr;
        }
        
        NSDictionary *objectValues = [NSDictionary dictionaryWithObjectsAndKeys:objectFile, @"objectFile",
                                                                                objectAddress, @"objectAddress",
                                                                                objectUUID, @"objectUUID",
                                                                                objectArchitecture, @"objectArchitecture", nil];
        [returnValue setObject:objectValues forKey:objectFile];
    }
    return returnValue;
}

- (NSDictionary *) toDictionary {
    return [NSDictionary dictionaryWithDictionary:self.dictionary];
}
@end
