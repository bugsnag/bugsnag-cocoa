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

// "bit[0] of lr is set to the current value of the Thumb bit in the CPSR.
// The means that the return instruction can automatically return to the correct processor state."
// http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.dui0203h/Cacbacic.html
//
#define ARMV7_IS_THUMB_MASK (0x00000001)
#define ARMV7_ADDRESS_MASK (~ARMV7_IS_THUMB_MASK)
#define ARMV7_THUMB_INSTRUCTION_SIZE 2
#define ARMV7_FULL_INSTRUCTION_SIZE 4

@interface BugsnagEvent ()
@property (atomic, strong) NSMutableDictionary *dictionary;

- (void) addExceptionWithClass:(NSString*) errorClass andMessage:(NSString*) message andStacktrace:(NSArray*) stacktrace;
@end

@implementation BugsnagEvent

- (id) initWithConfiguration:(BugsnagConfiguration *)configuration andMetaData:(NSDictionary*)metaData {
    if (self = [super init]) {
        self.dictionary = [[NSMutableDictionary alloc] init];
        
        if (configuration.userId != nil) self.userId = configuration.userId;
        if (configuration.appVersion != nil) self.appVersion = configuration.appVersion;
        if (configuration.osVersion != nil) self.osVersion = configuration.osVersion;
        if (configuration.context != nil) self.context = configuration.context;
        if (configuration.releaseStage != nil) self.releaseStage = configuration.releaseStage;
        
        if (configuration.metaData != nil) {
            self.metaData = [configuration.metaData mutableCopy];
        } else {
            self.metaData = [[BugsnagMetaData alloc] init];
        }
        
        if (metaData != nil) [self.metaData mergeWith:metaData];
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
        uint32_t frameAddress;

        // The pointer returned by backtrace() is the address of the instruction immediately after a function call.
        // We actually want to know the address of the function call instruction itself, so we subtract one instruction.
        // To confuse things further armv7 has two instruction modes "thumb" and "full". Thumb instructions are either
        // 2 or 4 bytes long, and full instructions are always 4 bytes. Because pointers to instructions in either architecture
        // will always be even, by convention pointers to thumb instructions have the least significant bit set so that the
        // same instructions can be used for jumping to and returning from code in either instruction set.

        // In the case of "thumb" instructions, we always subtract 2 (even though some instructions are 4 bytes long) this
        // is because DWARF gives us the same result whn we look up a pointer half way through an instruction. Apple take
        // a different approach in their crash logs, and always subtract 4. This is unlikely to give any meaningful difference.
        if ((uint32_t)frames[i] & ARMV7_IS_THUMB_MASK) {
            frameAddress = ((uint32_t)frames[i] & ARMV7_ADDRESS_MASK) - ARMV7_THUMB_INSTRUCTION_SIZE;
        } else {
            frameAddress = ((uint32_t)frames[i] & ARMV7_ADDRESS_MASK) - ARMV7_FULL_INSTRUCTION_SIZE;
        }

        int status = dladdr((void *)frameAddress, &info);
        if (status != 0) {
            NSString *fileName = [NSString stringWithCString:info.dli_fname encoding:NSUTF8StringEncoding];
            NSString *binaryName = [NSString stringWithCString:rindex(info.dli_fname, '/') + sizeof(char) encoding:NSUTF8StringEncoding];
            NSDictionary *image = [loadedImages objectForKey:fileName];
            NSMutableDictionary *frame = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                          [image objectForKey:@"machoUUID"], @"machoUUID",
                                          binaryName, @"machoFile",
                                          nil];
            
            if ([binaryName isEqualToString:[[NSProcessInfo processInfo] processName]]) [frame setObject:[NSNumber numberWithBool:YES] forKey:@"inProject"];

            uint32_t machoLoadAddress = [[image objectForKey:@"machoLoadAddress"] unsignedIntValue];
            uint32_t machoVMAddress = [[image objectForKey:@"machoVMAddress"] unsignedIntValue];

            uint32_t symbolAddress;

            // The frameAddress we have is relative to process memory. This changes every time the process is run
            // due to address space layout randomization, so we actually want to report the address relative to the
            // start of the __TEXT section of the object file instead.
            frameAddress = (frameAddress - machoLoadAddress) + machoVMAddress;
            [frame setObject:[NSNumber numberWithUnsignedInt: frameAddress] forKey:@"frameAddress"];
            
            if (info.dli_saddr) {
                symbolAddress = (((uint32_t)info.dli_saddr & ARMV7_ADDRESS_MASK) - machoLoadAddress) + machoVMAddress;
                [frame setObject:[NSNumber numberWithUnsignedInt: symbolAddress] forKey:@"symbolAddress"];
            }

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
        [self.dictionary setObject:[self.metaData toDictionary] forKey:@"metaData"];
        return [NSDictionary dictionaryWithDictionary:self.dictionary];
    }
}

- (void) setUserAttribute:(NSString*)attributeName withValue:(id)value {
    [self addAttribute:attributeName withValue:value toTabWithName:USER_TAB_NAME];
}

- (void) clearUser {
    [self.metaData clearTab:USER_TAB_NAME];
}

- (void) addAttribute:(NSString*)attributeName withValue:(id)value toTabWithName:(NSString*)tabName {
    [self.metaData addAttribute:attributeName withValue:value toTabWithName:tabName];
}

- (void) clearTabWithName:(NSString*)tabName {
    [self.metaData clearTab:tabName];
}

- (NSString*) appVersion {
    @synchronized(self) {
        return [self.dictionary objectForKey:@"appVersion"];
    }
}

- (void) setAppVersion:(NSString *)appVersion {
    @synchronized(self) {
        [self.dictionary setObject:appVersion forKey:@"appVersion"];
    }
}

- (NSString*) osVersion {
    @synchronized(self) {
        return [self.dictionary objectForKey:@"osVersion"];
    }
}

- (void) setOsVersion:(NSString *)osVersion {
    @synchronized(self) {
        [self.dictionary setObject:osVersion forKey:@"osVersion"];
    }
}

- (NSString*) context {
    @synchronized(self) {
        return [self.dictionary objectForKey:@"context"];
    }
}

- (void) setContext:(NSString *)context {
    @synchronized(self) {
        [self.dictionary setObject:context forKey:@"context"];
    }
}

- (NSString*) releaseStage {
    @synchronized(self) {
        return [self.dictionary objectForKey:@"releaseStage"];
    }
}

- (void) setReleaseStage:(NSString *)releaseStage {
    @synchronized(self) {
        [self.dictionary setObject:releaseStage forKey:@"releaseStage"];
    }
}

- (NSString*) userId {
    @synchronized(self) {
        return [self.dictionary objectForKey:@"userId"];
    }
}

- (void) setUserId:(NSString *)userId {
    @synchronized(self) {
        [self.dictionary setObject:userId forKey:@"userId"];
    }
}
@end
