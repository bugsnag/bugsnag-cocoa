//
//  BSGMetricKitStacktraceConverter.m
//  BugsnagMetricKitPlugin
//
//  Created by Robert Bartoszewski on 09/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BSGMetricKitStacktraceConverter.h"

#if __has_include(<MetricKit/MetricKit.h>)

#import <Bugsnag/Bugsnag.h>
#import <Bugsnag/BugsnagStackframe.h>
#import <Bugsnag/BugsnagSymbolicator.h>
#import <MetricKit/MetricKit.h>

@implementation BSGMetricKitStacktraceConverter

+ (NSArray<BugsnagStackframe *> *)stackframesFromCallStackTree:(MXCallStackTree *)callStackTree API_AVAILABLE(ios(14.0), macosx(12.0)) {
    if (!callStackTree) {
        return @[];
    }
    
    NSMutableArray<BugsnagStackframe *> *frames = [NSMutableArray array];
    
    if (@available(iOS 14.0, macOS 12.0, *)) {
        // Parse the JSON representation to extract frame information
        NSData *jsonData = callStackTree.JSONRepresentation;
        if (jsonData) {
            NSError *error = nil;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
            if (json && !error) {
                [self extractFramesFromJSON:json intoArray:frames];
                
                // Symbolicate the frames to add method names and other details
                [BugsnagSymbolicator symbolicateStackframes:frames];
            }
        }
    }
    
    return [frames copy];
}

+ (void)extractFramesFromJSON:(NSDictionary *)json intoArray:(NSMutableArray<BugsnagStackframe *> *)frames {
    // MetricKit JSON structure has call stacks with frames
    // Example structure: { "callStacks": [{ "threadAttributed": true, "callStackRootFrames": [...] }] }
    
    NSArray *callStacks = json[@"callStacks"];
    if ([callStacks isKindOfClass:[NSArray class]]) {
        for (NSDictionary *callStack in callStacks) {
            if ([callStack isKindOfClass:[NSDictionary class]]) {
                NSArray *rootFrames = callStack[@"callStackRootFrames"];
                if ([rootFrames isKindOfClass:[NSArray class]]) {
                    [self extractFramesFromRootFrames:rootFrames intoArray:frames];
                }
            }
        }
    }
}

+ (void)extractFramesFromRootFrames:(NSArray *)rootFrames intoArray:(NSMutableArray<BugsnagStackframe *> *)frames {
    for (NSDictionary *frameDict in rootFrames) {
        if (![frameDict isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        
        BugsnagStackframe *frame = [self stackframeFromDictionary:frameDict];
        if (frame) {
            [frames addObject:frame];
        }
        
        // Recursively process sub-frames
        NSArray *subFrames = frameDict[@"subFrames"];
        if ([subFrames isKindOfClass:[NSArray class]]) {
            [self extractFramesFromRootFrames:subFrames intoArray:frames];
        }
    }
}

+ (BugsnagStackframe *)stackframeFromDictionary:(NSDictionary *)frameDict {
    if (!frameDict || ![frameDict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    BugsnagStackframe *frame = [[BugsnagStackframe alloc] init];
    
    // Extract address
    NSNumber *address = frameDict[@"address"];
    if ([address isKindOfClass:[NSNumber class]]) {
        frame.frameAddress = address;
    }
    
    // Extract binary name
    NSString *binaryName = frameDict[@"binaryName"];
    if ([binaryName isKindOfClass:[NSString class]]) {
        frame.machoFile = binaryName;
    }
    
    // Extract binary UUID
    NSString *binaryUUID = frameDict[@"binaryUUID"];
    if ([binaryUUID isKindOfClass:[NSString class]]) {
        frame.machoUuid = binaryUUID;
    }
    
    // Extract offset into binary text segment
    NSNumber *offsetIntoBinaryTextSegment = frameDict[@"offsetIntoBinaryTextSegment"];
    if ([offsetIntoBinaryTextSegment isKindOfClass:[NSNumber class]] && address) {
        frame.symbolAddress = @([address unsignedLongLongValue] - [offsetIntoBinaryTextSegment unsignedLongLongValue]);
    }
    
    // For MetricKit frames, we mark them as cocoa type
    frame.type = BugsnagStackframeTypeCocoa;
    
    return frame;
}

@end

#endif
