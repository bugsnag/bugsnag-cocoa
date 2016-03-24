//
//  KSCrashReport.h
//  Bugsnag
//
//  Created by Simon Maynard on 11/26/14.
//
//

#import <Foundation/Foundation.h>

@interface BugsnagCrashReport : NSObject

@property(readonly, nonnull) NSDictionary *ksReport;

- (instancetype _Nonnull)initWithKSReport:(NSDictionary *_Nonnull)report;
- (NSDictionary *_Nonnull)serializableValueWithTopLevelData:
    (NSMutableDictionary *_Nonnull)data;

- (NSString *_Nullable)releaseStage;
- (NSArray *_Nullable)notifyReleaseStages;

@end
