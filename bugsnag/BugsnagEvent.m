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
    NSArray *stacktrace = [self getStackTraceWithException:nil];
    
    [self addExceptionWithClass:errorClass andMessage:message andStacktrace:stacktrace];
}

- (void) addException:(NSException*)exception {
    NSArray *stacktrace = [self getStackTraceWithException:exception];
    //TODO:SM can we use userdata on the exception as metadata?
    
    [self addExceptionWithClass:exception.name andMessage:exception.reason andStacktrace:stacktrace];
}

- (void) addExceptionWithClass:(NSString*) errorClass andMessage:(NSString*) message andStacktrace:(NSArray*) stacktrace {
    @synchronized(self) {
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
}

- (NSArray *) getStackTraceWithException:(NSException*) exception {
    // TODO:SM Make this work with non stripped code
    int count = 256;
    void *frames[count];
    int offset = 0;
    
    // Try to grab the addresses from the exception, if not just grab what we have now
    if (exception != nil && [[exception callStackReturnAddresses] count] != 0 ) {
        NSArray *stackFrames = [exception callStackReturnAddresses];
        count = stackFrames.count;
        for (int i = 0; i < count; ++i) {
            frames[i] = (void *)[[stackFrames objectAtIndex:i] intValue];
        }
    } else {
        count = backtrace(frames, count);
        
        // This offset is a hack to remove our own frames for creating the stacktrace in the event
        // that we have either been passed a signal or an exception without a stack. We could pass
        // this in from up top if we want to, but thats almost as hacky as this.
        offset = 4;
    }
    Dl_info info;
    
    NSMutableArray *stackTrace = [NSMutableArray array];
    NSDictionary *loadedImages = [self loadedImages];
    
    for(uint32_t i = offset; i < count; i++) {
        int status = dladdr(frames[i], &info);
        if (status != 0) {
            NSString *fileName = [NSString stringWithCString:info.dli_fname encoding:NSUTF8StringEncoding];
            NSMutableDictionary *frame = [NSMutableDictionary dictionaryWithDictionary:[loadedImages objectForKey:fileName]];
            [frame setObject:[NSNumber numberWithUnsignedInt:(uint32_t)frames[i]] forKey:@"frameAddress"];
            
            if (info.dli_sname != NULL && strcmp(info.dli_sname, "<redacted>") != 0) {
                NSString *method = [NSString stringWithCString:info.dli_sname encoding:NSUTF8StringEncoding];
                [frame setObject:method forKey:@"method"];
            }
            
            [stackTrace addObject:[NSDictionary dictionaryWithDictionary:frame]];
        }
    }
    
    return [NSArray arrayWithArray:stackTrace];
}

- (NSDictionary *) loadedImages {
    //Get count of all currently loaded images
    uint32_t count = _dyld_image_count();
    NSMutableDictionary *returnValue = [NSMutableDictionary dictionary];
    
    for (uint32_t i = 0; i < count; i++) {
        const char *dyld = _dyld_get_image_name(i);
        const struct mach_header *header = _dyld_get_image_header(i);
        
        NSString *machoFile = [NSString stringWithCString:dyld encoding:NSUTF8StringEncoding];
        NSNumber *machoLoadAddress = [NSNumber numberWithUnsignedInt:(uint32_t)header];
        NSString *machoUUID = nil;
        NSNumber *machoVMAddress = nil;
        
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
                
                machoUUID = [NSString stringWithCString:CFStringGetCStringPtr(suuid, encoding) encoding:NSUTF8StringEncoding];
                
                CFRelease(cuuid);
                CFRelease(suuid);
            } else if (command->cmd == LC_SEGMENT) {
                struct segment_command ucmd = *(struct segment_command*)header_ptr;
                if (strcmp("__TEXT", ucmd.segname) == 0) {
                    machoVMAddress = [NSNumber numberWithUnsignedInt:(uint32_t)ucmd.vmaddr];
                }
            }
            
            header_ptr += command->cmdsize;
            command = (struct load_command*)header_ptr;
        }
        
        NSDictionary *objectValues = [NSDictionary dictionaryWithObjectsAndKeys:machoFile, @"machoFile",
                                                                                machoLoadAddress, @"machoLoadAddress",
                                                                                machoUUID, @"machoUUID",
                                                                                machoVMAddress, @"machoVMAddress", nil];
        [returnValue setObject:objectValues forKey:machoFile];
    }
    return returnValue;
}

- (NSDictionary *) toDictionary {
    @synchronized(self) {
        return [NSDictionary dictionaryWithDictionary:self.dictionary];
    }
}
@end
