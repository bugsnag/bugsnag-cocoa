//
//  KSCrashReport.h
//  Bugsnag
//
//  Created by Simon Maynard on 11/26/14.
//
//

#import <Foundation/Foundation.h>

@interface BugsnagCrashReport : NSObject

- (id)initWithKSReport:(NSDictionary*)report;

@property NSDictionary *ksReport;

@property (readonly) NSString *releaseStage;
@property (readonly) NSArray *notifyReleaseStages;
@property (readonly) NSString *context;
@property (readonly) NSString *appVersion;

@property (readonly) NSArray *binaryImages;
@property (readonly) NSArray *threads;
@property (readonly) NSDictionary *error;
@property (readonly) NSString *errorType;
@property (readonly) NSString *errorClass;
@property (readonly) NSString *errorMessage;
@property (readonly) NSString *severity;
@property (readonly) NSString *dsymUUID;
@property (readonly) NSString *deviceAppHash;
@property (readonly) NSUInteger depth;

@property (readonly) NSDictionary *metaData;
@property (readonly) NSDictionary *appStats;

// These shouldnt be exposed
@property (readonly) NSDictionary *system;
@property (readonly) NSDictionary *state;

@end
