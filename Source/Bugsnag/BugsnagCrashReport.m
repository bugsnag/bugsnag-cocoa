//
//  KSCrashReport.m
//  Bugsnag
//
//  Created by Simon Maynard on 11/26/14.
//
//

#import "Bugsnag.h"
#import "BugsnagCollections.h"
#import "BugsnagCrashReport.h"

NSMutableDictionary *BSGFormatFrame(NSDictionary *frame,
                                    NSArray *binaryImages) {
  NSMutableDictionary *formatted = [NSMutableDictionary dictionary];

  unsigned long instructionAddress =
      [frame[@"instruction_addr"] unsignedLongValue];
  unsigned long symbolAddress = [frame[@"symbol_addr"] unsignedLongValue];
  unsigned long imageAddress = [frame[@"object_addr"] unsignedLongValue];

  BSGDictSetSafeObject(formatted,
                       [NSString stringWithFormat:@"0x%lx", instructionAddress],
                       @"frameAddress");
  BSGDictSetSafeObject(formatted,
                       [NSString stringWithFormat:@"0x%lx", symbolAddress],
                       @"symbolAddress");
  BSGDictSetSafeObject(formatted,
                       [NSString stringWithFormat:@"0x%lx", imageAddress],
                       @"machoLoadAddress");
  BSGDictInsertIfNotNil(formatted, frame[@"isPC"], @"isPC");
  BSGDictInsertIfNotNil(formatted, frame[@"isLR"], @"isLR");

  NSString *file = frame[@"object_name"];
  NSString *method = frame[@"symbol_name"];

  BSGDictInsertIfNotNil(formatted, file, @"machoFile");
  BSGDictInsertIfNotNil(formatted, method, @"method");

  for (NSDictionary *image in binaryImages) {
    if ([(NSNumber *)image[@"image_addr"] unsignedLongValue] == imageAddress) {
      unsigned long imageSlide = [image[@"image_vmaddr"] unsignedLongValue];

      BSGDictInsertIfNotNil(formatted, image[@"uuid"], @"machoUUID");
      BSGDictInsertIfNotNil(formatted, image[@"name"], @"machoFile");
      BSGDictSetSafeObject(formatted,
                           [NSString stringWithFormat:@"0x%lx", imageSlide],
                           @"machoVMAddress");

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
  BSGDictSetSafeObject(event, @[ exception ], @"exceptions");
  BSGDictInsertIfNotNil(event, [self dsymUUID], @"dsymUUID");
  BSGDictSetSafeObject(event, severity, @"severity");
  BSGDictSetSafeObject(event, [self breadcrumbs], @"breadcrumbs");
  BSGDictSetSafeObject(event, @"2", @"payloadVersion");
  BSGDictSetSafeObject(event, metaData, @"metaData");
  BSGDictSetSafeObject(event, [self deviceState], @"deviceState");
  BSGDictSetSafeObject(event, [self device], @"device");
  BSGDictSetSafeObject(event, [self appState], @"appState");
  BSGDictSetSafeObject(event, [self app], @"app");

  if ([metaData[@"context"] isKindOfClass:[NSString class]]) {
    BSGDictSetSafeObject(event, metaData[@"context"], @"context");
    [metaData removeObjectForKey:@"context"];

  } else {
    BSGDictSetSafeObject(event, [self context], @"context");
  }

  //  Build MetaData
  BSGDictSetSafeObject(metaData, [self error], @"error");

  // Make user mutable and set the id if the user hasn't already
  NSMutableDictionary *user = [metaData[@"user"] mutableCopy];
  if (user == nil)
    user = [NSMutableDictionary dictionary];
  BSGDictSetSafeObject(metaData, user, @"user");

  if (!user[@"id"]) {
    BSGDictSetSafeObject(user, [self deviceAppHash], @"id");
  }

  // Build Exception
  BSGDictSetSafeObject(exception, [self errorClass], @"errorClass");
  BSGDictInsertIfNotNil(exception, [self errorMessage], @"message");

  // HACK: For the Unity Notifier. We don't include ObjectiveC exceptions or
  // threads
  // if this is an exception from Unity-land.
  NSDictionary *unityReport = metaData[@"_bugsnag_unity_exception"];
  if (unityReport) {
    BSGDictSetSafeObject(data, unityReport[@"notifier"], @"notifier");
    BSGDictSetSafeObject(exception, unityReport[@"stacktrace"], @"stacktrace");
    [metaData removeObjectForKey:@"_bugsnag_unity_exception"];
    return event;
  }

  BSGDictSetSafeObject(event, [self serializeThreadsWithException:exception],
                       @"threads");
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
            BSGDictSetSafeObject(mutableFrame, @YES, @"isPC");
          }
          if (seen == 2 && !stackOverflow &&
              [@[ @"signal", @"deadlock", @"mach" ]
                  containsObject:[self errorType]]) {
            BSGDictSetSafeObject(mutableFrame, @YES, @"isLR");
          }
          BSGArrayInsertIfNotNil(
              stacktrace, BSGFormatFrame(mutableFrame, [self binaryImages]));
        }
      }

      BSGDictSetSafeObject(exception, stacktrace, @"stacktrace");
    } else {
      NSMutableArray *threadStack = [NSMutableArray array];

      for (NSDictionary *frame in backtrace) {
        BSGArrayInsertIfNotNil(threadStack,
                               BSGFormatFrame(frame, [self binaryImages]));
      }

      NSMutableDictionary *threadDict = [NSMutableDictionary dictionary];
      BSGDictSetSafeObject(threadDict, thread[@"index"], @"id");
      BSGDictSetSafeObject(threadDict, threadStack, @"stacktrace");
      // only if this is enabled in KSCrash.
      if (thread[@"name"]) {
        BSGDictSetSafeObject(threadDict, thread[@"name"], @"name");
      }

      BSGArrayAddSafeObject(bugsnagThreads, threadDict);
    }
  }
  return bugsnagThreads;
}

// Generates the deviceState section of the payload
- (NSDictionary *)deviceState {
  NSMutableDictionary *deviceState = [[self state][@"deviceState"] mutableCopy];
  BSGDictSetSafeObject(deviceState, [self system][@"memory"][@"free"],
                       @"freeMemory");
  return deviceState;
}

// Generates the device section of the payload
- (NSDictionary *)device {
  NSMutableDictionary *device = [NSMutableDictionary dictionary];

  BSGDictSetSafeObject(device, @"Apple", @"manufacturer");
  BSGDictSetSafeObject(device, [[NSLocale currentLocale] localeIdentifier],
                       @"locale");
  BSGDictSetSafeObject(device, [self system][@"device_app_hash"], @"id");
  BSGDictSetSafeObject(device, [self system][@"time_zone"], @"timezone");
  BSGDictSetSafeObject(device, [self system][@"model"], @"modelNumber");
  BSGDictSetSafeObject(device, [self system][@"machine"], @"model");
  BSGDictSetSafeObject(device, [self system][@"system_name"], @"osName");
  BSGDictSetSafeObject(device, [self system][@"system_version"], @"osVersion");
  BSGDictSetSafeObject(device, [self system][@"memory"][@"usable"],
                       @"totalMemory");

  return device;
}

// Generates the appState section of the payload
- (NSDictionary *)appState {
  NSMutableDictionary *appState = [NSMutableDictionary dictionary];
  NSInteger activeTimeSinceLaunch =
      [[self appStats][@"active_time_since_launch"] doubleValue] * 1000.0;
  NSInteger backgroundTimeSinceLaunch =
      [[self appStats][@"background_time_since_launch"] doubleValue] * 1000.0;

  BSGDictSetSafeObject(appState, @(activeTimeSinceLaunch),
                       @"durationInForeground");
  BSGDictSetSafeObject(appState,
                       @(activeTimeSinceLaunch + backgroundTimeSinceLaunch),
                       @"duration");
  BSGDictSetSafeObject(appState, [self appStats][@"application_in_foreground"],
                       @"inForeground");
  BSGDictSetSafeObject(appState, [self appStats], @"stats");

  return appState;
}

// Generates the app section of the payload
- (NSDictionary *)app {
  NSMutableDictionary *app = [NSMutableDictionary dictionary];

  BSGDictSetSafeObject(app, [self system][@"CFBundleVersion"],
                       @"bundleVersion");
  BSGDictSetSafeObject(app, [self system][@"CFBundleIdentifier"], @"id");
  BSGDictSetSafeObject(app, [self system][@"CFBundleExecutable"], @"name");
  BSGDictSetSafeObject(app, [Bugsnag configuration].releaseStage,
                       @"releaseStage");
  if ([self appVersion]) {
    BSGDictSetSafeObject(app, [self appVersion], @"version");
  } else {
    BSGDictSetSafeObject(app, [self system][@"CFBundleShortVersionString"],
                         @"version");
  }

  return app;
}

@end
