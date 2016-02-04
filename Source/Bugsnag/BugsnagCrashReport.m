//
//  KSCrashReport.m
//  Bugsnag
//
//  Created by Simon Maynard on 11/26/14.
//
//

#import "Bugsnag.h"
#import "BugsnagCrashReport.h"
#import "KSSafeCollections.h"

NSMutableDictionary *BSGFormatFrame(NSDictionary *frame,
                                    NSArray *binaryImages) {
  NSMutableDictionary *formatted = [NSMutableDictionary dictionary];

  unsigned long instructionAddress =
      [frame[@"instruction_addr"] unsignedLongValue];
  unsigned long symbolAddress = [frame[@"symbol_addr"] unsignedLongValue];
  unsigned long imageAddress = [frame[@"object_addr"] unsignedLongValue];

  [formatted
      safeSetObject:[NSString stringWithFormat:@"0x%lx", instructionAddress]
             forKey:@"frameAddress"];
  [formatted safeSetObject:[NSString stringWithFormat:@"0x%lx", symbolAddress]
                    forKey:@"symbolAddress"];
  [formatted safeSetObject:[NSString stringWithFormat:@"0x%lx", imageAddress]
                    forKey:@"machoLoadAddress"];
  if (frame[@"isPC"])
    [formatted safeSetObject:frame[@"isPC"] forKey:@"isPC"];
  if (frame[@"isLR"])
    [formatted safeSetObject:frame[@"isLR"] forKey:@"isLR"];

  NSString *file = frame[@"object_name"];
  NSString *method = frame[@"symbol_name"];

  [formatted setObjectIfNotNil:file forKey:@"machoFile"];
  [formatted setObjectIfNotNil:method forKey:@"method"];

  for (NSDictionary *image in binaryImages) {
    if ([(NSNumber *)image[@"image_addr"] unsignedLongValue] == imageAddress) {
      unsigned long imageSlide = [image[@"image_vmaddr"] unsignedLongValue];

      [formatted setObjectIfNotNil:image[@"uuid"] forKey:@"machoUUID"];
      [formatted setObjectIfNotNil:image[@"name"] forKey:@"machoFile"];

      [formatted safeSetObject:[NSString stringWithFormat:@"0x%lx", imageSlide]
                        forKey:@"machoVMAddress"];

      return formatted;
    }
  }

  return nil;
}

@implementation BugsnagCrashReport

- (id)initWithKSReport:(NSDictionary *)report {
  if ((self = [super init])) {
    _ksReport = report;
  }
  return self;
}

- (NSString *)releaseStage {
  return self.config[@"releaseStage"];
}

- (NSArray *)notifyReleaseStages {
  return self.config[@"notifyReleaseStages"];
}

- (NSString *)context {
  if ([self.config[@"context"] isKindOfClass:[NSString class]]) {
    return self.config[@"context"];
  }
  // TODO:SM Get other contexts if possible
  return nil;
}

- (NSString *)appVersion {
  if ([self.config[@"appVersion"] isKindOfClass:[NSString class]]) {
    return self.config[@"appVersion"];
  }
  return nil;
}

- (NSArray *)binaryImages {
  return self.ksReport[@"binary_images"];
}

- (NSArray *)threads {
  return self.crash[@"threads"];
}

- (NSDictionary *)error {
  return self.crash[@"error"];
}

- (NSString *)errorType {
  return self.error[@"type"];
}

- (NSString *)errorClass {
  if ([self.errorType isEqualToString:@"cpp_exception"]) {
    return self.error[@"cpp_exception"][@"name"];
  } else if ([self.errorType isEqualToString:@"mach"]) {
    return self.error[@"mach"][@"exception_name"];
  } else if ([self.errorType isEqualToString:@"signal"]) {
    return self.error[@"signal"][@"name"];
  } else if ([self.errorType isEqualToString:@"nsexception"]) {
    return self.error[@"nsexception"][@"name"];
  } else if ([self.errorType isEqualToString:@"user"]) {
    return self.error[@"user_reported"][@"name"];
  }
  return @"Exception";
}

- (NSString *)errorMessage {
  if ([self.errorType isEqualToString:@"mach"]) {
    NSString *diagnosis = self.crash[@"diagnosis"];
    if (diagnosis && ![diagnosis hasPrefix:@"No diagnosis"]) {
      return [[diagnosis componentsSeparatedByString:@"\n"] firstObject];
    }
  }
  return self.error[@"reason"];
}

- (NSArray *)breadcrumbs {
  return self.state[@"crash"][@"breadcrumbs"];
}

- (NSString *)severity {
  return self.state[@"crash"][@"severity"];
}

- (NSString *)dsymUUID {
  return self.system[@"app_uuid"];
}

- (NSString *)deviceAppHash {
  return self.system[@"device_app_hash"];
}

- (NSUInteger)depth {
  return [self.state[@"crash"][@"depth"] unsignedIntegerValue];
}

- (NSDictionary *)metaData {
  return self.ksReport[@"user"][@"metaData"];
}

- (NSDictionary *)appStats {
  return self.system[@"application_stats"];
}

// PRIVATE
- (NSDictionary *)system {
  return self.ksReport[@"system"];
}

- (NSDictionary *)state {
  return self.ksReport[@"user"][@"state"];
}

- (NSDictionary *)config {
  return self.ksReport[@"user"][@"config"];
}

- (NSDictionary *)crash {
  return self.ksReport[@"crash"];
}

- (NSDictionary *)unityExceptionReport {
  return self.metaData[@"_bugsnag_unity_exception"];
}

- (NSDictionary *)serializableValueWithTopLevelData:
    (NSMutableDictionary *)data {
  NSMutableDictionary *event = [NSMutableDictionary dictionary];
  NSMutableDictionary *exception = [NSMutableDictionary dictionary];
  NSMutableDictionary *metaData = [[self metaData] mutableCopy];
  NSString *severity =
      [self severity].length > 0 ? [self severity] : BugsnagSeverityError;

  // Build Event
  [event safeSetObject:@[ exception ] forKey:@"exceptions"];
  [event setObjectIfNotNil:[self dsymUUID] forKey:@"dsymUUID"];
  [event safeSetObject:severity forKey:@"severity"];
  [event safeSetObject:[self breadcrumbs] forKey:@"breadcrumbs"];
  [event safeSetObject:@"2" forKey:@"payloadVersion"];
  [event safeSetObject:metaData forKey:@"metaData"];
  [event safeSetObject:[self deviceState] forKey:@"deviceState"];
  [event safeSetObject:[self device] forKey:@"device"];
  [event safeSetObject:[self appState] forKey:@"appState"];
  [event safeSetObject:[self app] forKey:@"app"];

  if ([metaData[@"context"] isKindOfClass:[NSString class]]) {
    [event safeSetObject:metaData[@"context"] forKey:@"context"];
    [metaData removeObjectForKey:@"context"];

  } else {
    [event safeSetObject:[self context] forKey:@"context"];
  }

  //  Build MetaData
  [metaData safeSetObject:[self error] forKey:@"error"];

  // Make user mutable and set the id if the user hasn't already
  NSMutableDictionary *user = [metaData[@"user"] mutableCopy];
  if (user == nil)
    user = [NSMutableDictionary dictionary];
  [metaData safeSetObject:user forKey:@"user"];

  if (!user[@"id"]) {
    [user safeSetObject:[self deviceAppHash] forKey:@"id"];
  }

  // Build Exception
  [exception safeSetObject:[self errorClass] forKey:@"errorClass"];
  [exception setObjectIfNotNil:[self errorMessage] forKey:@"message"];

  // HACK: For the Unity Notifier. We don't include ObjectiveC exceptions or
  // threads
  // if this is an exception from Unity-land.
  NSDictionary *unityReport = metaData[@"_bugsnag_unity_exception"];
  if (unityReport) {
    [data safeSetObject:unityReport[@"notifier"] forKey:@"notifier"];
    [exception safeSetObject:unityReport[@"stacktrace"] forKey:@"stacktrace"];
    [metaData removeObjectForKey:@"_bugsnag_unity_exception"];
    return event;
  }

  [event safeSetObject:[self serializeThreadsWithException:exception]
                forKey:@"threads"];
  return event;
}

// Build all stacktraces for threads and the error
- (NSArray *)serializeThreadsWithException:(NSMutableDictionary *)exception {
  NSMutableArray *bugsnagThreads = [NSMutableArray array];
  for (NSDictionary *thread in [self threads]) {
    NSArray *backtrace = thread[@"backtrace"][@"contents"];
    BOOL stackOverflow = [thread[@"stack"][@"overflow"] boolValue];

    if ([thread[@"crashed"] boolValue]) {
      NSUInteger seen = 0;
      NSMutableArray *stacktrace = [NSMutableArray array];

      for (NSDictionary *frame in backtrace) {
        NSMutableDictionary *mutableFrame = [frame mutableCopy];
        if (seen++ >= [self depth]) {
          // Mark the frame so we know where it came from
          if (seen == 1 && !stackOverflow) {
            [mutableFrame safeSetObject:@YES forKey:@"isPC"];
          }
          if (seen == 2 && !stackOverflow &&
              [@[ @"signal", @"deadlock", @"mach" ]
                  containsObject:[self errorType]]) {
            [mutableFrame safeSetObject:@YES forKey:@"isLR"];
          }
          [stacktrace addObjectIfNotNil:BSGFormatFrame(mutableFrame,
                                                       [self binaryImages])];
        }
      }

      [exception safeSetObject:stacktrace forKey:@"stacktrace"];
    } else {
      NSMutableArray *threadStack = [NSMutableArray array];

      for (NSDictionary *frame in backtrace) {
        [threadStack
            addObjectIfNotNil:BSGFormatFrame(frame, [self binaryImages])];
      }

      NSMutableDictionary *threadDict = [NSMutableDictionary dictionary];
      [threadDict safeSetObject:thread[@"index"] forKey:@"id"];
      [threadDict safeSetObject:threadStack forKey:@"stacktrace"];
      // only if this is enabled in KSCrash.
      if (thread[@"name"]) {
        [threadDict safeSetObject:thread[@"name"] forKey:@"name"];
      }

      [bugsnagThreads safeAddObject:threadDict];
    }
  }
  return bugsnagThreads;
}

// Generates the deviceState section of the payload
- (NSDictionary *)deviceState {
  NSMutableDictionary *deviceState = [[self state][@"deviceState"] mutableCopy];
  [deviceState safeSetObject:[self system][@"memory"][@"free"]
                      forKey:@"freeMemory"];
  return deviceState;
}

// Generates the device section of the payload
- (NSDictionary *)device {
  NSMutableDictionary *device = [NSMutableDictionary dictionary];

  [device safeSetObject:@"Apple" forKey:@"manufacturer"];
  [device safeSetObject:[[NSLocale currentLocale] localeIdentifier]
                 forKey:@"locale"];
  [device safeSetObject:[self system][@"device_app_hash"] forKey:@"id"];
  [device safeSetObject:[self system][@"time_zone"] forKey:@"timezone"];
  [device safeSetObject:[self system][@"model"] forKey:@"modelNumber"];
  [device safeSetObject:[self system][@"machine"] forKey:@"model"];
  [device safeSetObject:[self system][@"system_name"] forKey:@"osName"];
  [device safeSetObject:[self system][@"system_version"] forKey:@"osVersion"];
  [device safeSetObject:[self system][@"memory"][@"usable"]
                 forKey:@"totalMemory"];

  return device;
}

// Generates the appState section of the payload
- (NSDictionary *)appState {
  NSMutableDictionary *appState = [NSMutableDictionary dictionary];
  NSInteger activeTimeSinceLaunch =
      [[self appStats][@"active_time_since_launch"] doubleValue] * 1000.0;
  NSInteger backgroundTimeSinceLaunch =
      [[self appStats][@"background_time_since_launch"] doubleValue] * 1000.0;

  [appState safeSetObject:@(activeTimeSinceLaunch)
                   forKey:@"durationInForeground"];
  [appState safeSetObject:@(activeTimeSinceLaunch + backgroundTimeSinceLaunch)
                   forKey:@"duration"];
  [appState safeSetObject:[self appStats][@"application_in_foreground"]
                   forKey:@"inForeground"];
  [appState safeSetObject:[self appStats] forKey:@"stats"];

  return appState;
}

// Generates the app section of the payload
- (NSDictionary *)app {
  NSMutableDictionary *app = [NSMutableDictionary dictionary];

  [app safeSetObject:[self system][@"CFBundleVersion"] forKey:@"bundleVersion"];
  [app safeSetObject:[self system][@"CFBundleIdentifier"] forKey:@"id"];
  [app safeSetObject:[self system][@"CFBundleExecutable"] forKey:@"name"];
  [app safeSetObject:[Bugsnag configuration].releaseStage
              forKey:@"releaseStage"];
  if ([self appVersion]) {
    [app safeSetObject:[self appVersion] forKey:@"version"];
  } else {
    [app safeSetObject:[self system][@"CFBundleShortVersionString"]
                forKey:@"version"];
  }

  return app;
}

@end
