//
//  KSCrashReport.h
//  Bugsnag
//
//  Created by Simon Maynard on 11/26/14.
//
//

#import <Foundation/Foundation.h>

@interface BugsnagCrashReport : NSObject

@property(readonly) NSDictionary *ksReport;

- (id)initWithKSReport:(NSDictionary *)report;
- (NSDictionary *)serializableValueWithTopLevelData:(NSMutableDictionary *)data;

- (NSString *)releaseStage;
- (NSArray *)notifyReleaseStages;

@end
