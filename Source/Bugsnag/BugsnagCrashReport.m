//
//  KSCrashReport.m
//  Bugsnag
//
//  Created by Simon Maynard on 11/26/14.
//
//

#import "BugsnagCrashReport.h"

@implementation BugsnagCrashReport
-(id)initWithKSReport:(NSDictionary *)report {
    if((self = [super init])) {
        self.ksReport = report;
    }
    return self;
}

-(NSString*) releaseStage {
    return [self.config objectForKey:@"releaseStage"];
}

-(NSArray*) notifyReleaseStages {
    return [self.config objectForKey:@"notifyReleaseStages"];
}

-(NSString*) context {
    if ([[self.config objectForKey:@"context"] isKindOfClass:[NSString class]]) {
        return [self.config objectForKey:@"context"];
    }
    //TODO:SM Get other contexts if possible
    return nil;
}

-(NSString*) appVersion {
    if ([[self.config objectForKey:@"appVersion"] isKindOfClass:[NSString class]]) {
        return [self.config objectForKey:@"appVersion"];
    }
    return nil;
}

-(NSArray*) binaryImages {
    return [self.ksReport objectForKey:@"binary_images"];
}

-(NSArray*) threads {
    return [self.crash objectForKey:@"threads"];
}

-(NSDictionary*) error {
    return [self.crash objectForKey:@"error"];
}

-(NSString*) errorType {
    return [self.error objectForKey:@"type"];
}

- (NSString*) errorClass {
    if ([self.errorType isEqualToString: @"cpp_exception"]) {
        return [(NSDictionary*)[self.error objectForKey:@"cpp_exception"] objectForKey:@"name"];
    } else if ([self.errorType isEqualToString:@"mach"]) {
        return [(NSDictionary*)[self.error objectForKey:@"mach"] objectForKey:@"exception_name"];
    } else if ([self.errorType isEqualToString:@"signal"]) {
        return [(NSDictionary*)[self.error objectForKey:@"signal"] objectForKey:@"name"];
    } else if ([self.errorType isEqualToString:@"nsexception"]) {
        return [(NSDictionary*)[self.error objectForKey:@"nsexception"] objectForKey:@"name"];
    } else if ([self.errorType isEqualToString:@"user"]) {
        return [(NSDictionary*)[self.error objectForKey:@"user_reported"] objectForKey:@"name"];
    }
    return @"Exception";
}

- (NSString*) errorMessage {
    if ([self.errorType isEqualToString:@"mach"]) {
        NSString* diagnosis = [self.crash objectForKey:@"diagnosis"];
        if (diagnosis && ![diagnosis hasPrefix:@"No diagnosis"]) {
            return [[diagnosis componentsSeparatedByString:@"\n"] firstObject];
        }
    }
    return [self.error objectForKey:@"reason"];
}

- (NSArray*) breadcrumbs {
    return [[self.state objectForKey:@"crash"] objectForKey:@"breadcrumbs"];
}

-(NSString*) severity {
    return [[self.state objectForKey:@"crash"] objectForKey:@"severity"];
}

-(NSString*) dsymUUID {
    return [self.system objectForKey:@"app_uuid"];
}

-(NSString*) deviceAppHash {
    return [self.system objectForKey:@"device_app_hash"];
}

- (NSUInteger) depth {
    return [[[self.state objectForKey:@"crash"] objectForKey:@"depth"] unsignedIntegerValue];
}

-(NSDictionary*) metaData {
    return [[self.ksReport objectForKey:@"user"] objectForKey:@"metaData"];
}

-(NSDictionary*) appStats {
    return [self.system objectForKey:@"application_stats"];
}

// PRIVATE
-(NSDictionary*) system {
    return [self.ksReport objectForKey:@"system"];
}

-(NSDictionary*) state {
    return [[self.ksReport objectForKey:@"user"] objectForKey:@"state"];
}

-(NSDictionary*) config {
    return [[self.ksReport objectForKey:@"user"] objectForKey:@"config"];
}

-(NSDictionary*) crash {
    return [self.ksReport objectForKey:@"crash"];
}

@end
