//
//  BSGMetricKitStacktraceConverter.m
//  BugsnagMetricKitPlugin
//
//  Created by Robert Bartoszewski on 09/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BSGMetricKitStacktraceConverter.h"

#if __has_include(<MetricKit/MetricKit.h>)

#import "BugsnagFromBugsnagMetricKitPlugin.h"
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
    
    // Dynamically load BugsnagStackframe class at runtime
    Class BugsnagStackframeClass = NSClassFromString(@"BugsnagStackframe");
    if (!BugsnagStackframeClass) {
        return nil;
    }
    
    id frame = [[BugsnagStackframeClass alloc] init];
    
    // Extract address
    NSNumber *address = frameDict[@"address"];
    if ([address isKindOfClass:[NSNumber class]]) {
        [frame setValue:address forKey:@"frameAddress"];
    }
    
    // Extract binary name
    NSString *binaryName = frameDict[@"binaryName"];
    if ([binaryName isKindOfClass:[NSString class]]) {
        [frame setValue:binaryName forKey:@"machoFile"];
    }
    
    // Extract binary UUID
    NSString *binaryUUID = frameDict[@"binaryUUID"];
    if ([binaryUUID isKindOfClass:[NSString class]]) {
        [frame setValue:binaryUUID forKey:@"machoUuid"];
    }
    
    // Extract offset into binary text segment
    NSNumber *offsetIntoBinaryTextSegment = frameDict[@"offsetIntoBinaryTextSegment"];
    if ([offsetIntoBinaryTextSegment isKindOfClass:[NSNumber class]] && address) {
        NSNumber *symbolAddress = @([address unsignedLongLongValue] - [offsetIntoBinaryTextSegment unsignedLongLongValue]);
        [frame setValue:symbolAddress forKey:@"symbolAddress"];
    }
    
    if ([binaryName isKindOfClass:[NSString class]] && [offsetIntoBinaryTextSegment isKindOfClass:[NSNumber class]]) {
        NSString *method = [NSString stringWithFormat:@"%@ + %llu", binaryName, [offsetIntoBinaryTextSegment unsignedLongLongValue]];
        [frame setValue:method forKey:@"method"];
    }
    
    // Mark MetricKit frames as cocoa type
    [frame setValue:@"cocoa" forKey:@"type"];
    
    return frame;
}

@end

#endif
