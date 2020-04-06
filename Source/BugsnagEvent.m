//
//  BugsnagEvent.m
//  Bugsnag
//
//  Created by Simon Maynard on 11/26/14.
//
//

#if TARGET_OS_MAC || TARGET_OS_TV
#elif TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#include <sys/utsname.h>
#endif

#import "BSGSerialization.h"
#import "Bugsnag.h"
#import "BugsnagCollections.h"
#import "BugsnagHandledState.h"
#import "BugsnagLogger.h"
#import "BugsnagKeys.h"
#import "BugsnagBreadcrumb.h"
#import "BugsnagSession.h"
#import "Private.h"
#import "BSG_RFC3339DateTool.h"
#import "BugsnagKeys.h"
#import "BugsnagDeviceWithState.h"
#import "BugsnagClient.h"
#import "BugsnagStacktrace.h"
#import "BugsnagThread.h"
#import "RegisterErrorData.h"

static NSString *const DEFAULT_EXCEPTION_TYPE = @"cocoa";

// MARK: - Accessing hidden methods/properties

NSDictionary *_Nonnull BSGParseDeviceMetadata(NSDictionary *_Nonnull event);

@interface BugsnagAppWithState ()
+ (BugsnagAppWithState *)appWithDictionary:(NSDictionary *)event
                                    config:(BugsnagConfiguration *)config;
- (NSDictionary *)toDict;
+ (BugsnagAppWithState *)appWithOomData:(NSDictionary *)event;
@end

@interface BugsnagBreadcrumb ()
+ (instancetype _Nullable)breadcrumbWithBlock:
        (BSGBreadcrumbConfiguration _Nonnull)block;
+ (instancetype _Nullable)breadcrumbFromDict:(NSDictionary *_Nonnull)dict;
@end

@interface BugsnagConfiguration (BugsnagEvent)
+ (BOOL)isValidApiKey:(NSString *_Nullable)apiKey;
- (BOOL)shouldSendReports;
@property(readonly, strong, nullable) BugsnagBreadcrumbs *breadcrumbs;
@end

@interface BugsnagSession ()
@property NSUInteger unhandledCount;
@property NSUInteger handledCount;
@end

@interface Bugsnag ()
+ (BugsnagClient *)client;
@end

@interface BugsnagMetadata ()
- (NSDictionary *)toDictionary;
- (id)deepCopy;
@end

@interface BugsnagStackframe ()
+ (BugsnagStackframe *)frameFromDict:(NSDictionary *)dict
                          withImages:(NSArray *)binaryImages;
@end

@interface BugsnagStackframe ()
+ (BugsnagStackframe *)frameFromDict:(NSDictionary *)dict
                          withImages:(NSArray *)binaryImages;
@end

@interface BugsnagThread ()
@property BugsnagStacktrace *trace;
- (NSDictionary *)toDictionary;

- (instancetype)initWithThread:(NSDictionary *)thread
                  binaryImages:(NSArray *)binaryImages;

+ (NSMutableArray<BugsnagThread *> *)threadsFromArray:(NSArray *)threads
                                         binaryImages:(NSArray *)binaryImages
                                                depth:(NSUInteger)depth
                                            errorType:(NSString *)errorType;

+ (NSMutableArray *)serializeThreads:(NSArray<BugsnagThread *> *)threads;
@end

@interface BugsnagStacktrace ()
- (NSArray *)toArray;
@end

// MARK: - KSCrashReport parsing

NSString *_Nonnull BSGParseErrorClass(NSDictionary *error,
                                      NSString *errorType) {
    NSString *errorClass;

    if ([errorType isEqualToString:BSGKeyCppException]) {
        errorClass = error[BSGKeyCppException][BSGKeyName];
    } else if ([errorType isEqualToString:BSGKeyMach]) {
        errorClass = error[BSGKeyMach][BSGKeyExceptionName];
    } else if ([errorType isEqualToString:BSGKeySignal]) {
        errorClass = error[BSGKeySignal][BSGKeyName];
    } else if ([errorType isEqualToString:@"nsexception"]) {
        errorClass = error[@"nsexception"][BSGKeyName];
    } else if ([errorType isEqualToString:BSGKeyUser]) {
        errorClass = error[@"user_reported"][BSGKeyName];
    }

    if (!errorClass) { // use a default value
        errorClass = @"Exception";
    }
    return errorClass;
}

NSString *BSGParseErrorMessage(NSDictionary *report, NSDictionary *error,
                               NSString *errorType) {
    if ([errorType isEqualToString:BSGKeyMach] || error[BSGKeyReason] == nil) {
        NSString *diagnosis = [report valueForKeyPath:@"crash.diagnosis"];
        if (diagnosis && ![diagnosis hasPrefix:@"No diagnosis"]) {
            return [[diagnosis componentsSeparatedByString:@"\n"] firstObject];
        }
    }
    return error[BSGKeyReason] ?: @"";
}

id BSGLoadConfigValue(NSDictionary *report, NSString *valueName) {
    NSString *keypath = [NSString stringWithFormat:@"user.config.%@", valueName];
    NSString *fallbackKeypath = [NSString stringWithFormat:@"user.config.config.%@", valueName];

    return [report valueForKeyPath:keypath]
    ?: [report valueForKeyPath:fallbackKeypath]; // some custom values are nested
}

/**
 * Attempt to find a context (within which the event is being reported)
 * This can be found in user-set metadata of varying specificity or the global
 * configuration.  Returns nil if no context can be found.
 *
 * @param report A dictionary of report data
 * @returns A string context if found, or nil
 */
NSString *BSGParseContext(NSDictionary *report) {
    id context = [report valueForKeyPath:@"user.overrides.context"];
    if ([context isKindOfClass:[NSString class]]) {
        return context;
    }
    context = BSGLoadConfigValue(report, @"context");
    if ([context isKindOfClass:[NSString class]]) {
        return context;
    }
    return nil;
}

NSString *BSGParseGroupingHash(NSDictionary *report) {
    id groupingHash = [report valueForKeyPath:@"user.overrides.groupingHash"];
    if (groupingHash)
        return groupingHash;
    return nil;
}

/** 
 * Find the breadcrumb cache for the event within the report object.
 *
 * By default, crumbs are present in the `user.state.crash` object, which is
 * the location of user data within crash and notify reports. However, this
 * location can be overridden in the case that a callback modifies breadcrumbs
 * or that breadcrumbs are persisted separately (such as in an out-of-memory
 * event).
 */
NSArray <BugsnagBreadcrumb *> *BSGParseBreadcrumbs(NSDictionary *report) {
    // default to overwritten breadcrumbs from callback
    NSArray *cache = [report valueForKeyPath:@"user.overrides.breadcrumbs"]
        // then cached breadcrumbs from an OOM event
        ?: [report valueForKeyPath:@"user.state.oom.breadcrumbs"]
        // then cached breadcrumbs from a regular event
        ?: [report valueForKeyPath:@"user.state.crash.breadcrumbs"];
    NSMutableArray *breadcrumbs = [NSMutableArray arrayWithCapacity:cache.count];
    for (NSDictionary *data in cache) {
        if (![data isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        BugsnagBreadcrumb *crumb = [BugsnagBreadcrumb breadcrumbFromDict:data];
        if (crumb) {
            [breadcrumbs addObject:crumb];
        }
    }
    return breadcrumbs;
}

NSString *BSGParseReleaseStage(NSDictionary *report) {
    return [report valueForKeyPath:@"user.overrides.releaseStage"]
               ?: BSGLoadConfigValue(report, @"releaseStage");
}

NSDictionary *BSGParseCustomException(NSDictionary *report,
                                      NSString *errorClass, NSString *message) {
    id frames =
        [report valueForKeyPath:@"user.overrides.customStacktraceFrames"];
    id type = [report valueForKeyPath:@"user.overrides.customStacktraceType"];
    if (type && frames) {
        return @{
            BSGKeyStacktrace : frames,
            BSGKeyType : type,
            BSGKeyErrorClass : errorClass,
            BSGKeyMessage : message
        };
    }

    return nil;
}

// MARK: - BugsnagEvent implementation

@interface NSDictionary (BSGKSMerge)
- (NSDictionary *)BSG_mergedInto:(NSDictionary *)dest;
@end


@interface BugsnagDeviceWithState ()
- (NSDictionary *)toDictionary;
+ (BugsnagDeviceWithState *)deviceWithDictionary:(NSDictionary *)event;
+ (BugsnagDeviceWithState *)deviceWithOomData:(NSDictionary *)data;
@end

@interface BugsnagEvent ()

/**
 *  The type of the error, such as `mach` or `user`
 */
@property(nonatomic, readwrite, copy, nullable) NSString *errorType;
/**
 *  A unique hash identifying this device for the application or vendor
 */
@property(nonatomic, readonly, copy, nullable) NSString *deviceAppHash;
/**
 *  User-provided exception metadata
 */
@property(nonatomic, readwrite, copy, nullable) NSDictionary *customException;
@property(nonatomic, strong) BugsnagSession *session;

/**
 *  The event state (whether the error is handled/unhandled)
 */
@property(readonly, nonnull) BugsnagHandledState *handledState;

- (NSDictionary *_Nonnull)toJson;

/**
 *  Whether this report should be sent, based on release stage information
 *  cached at crash time and within the application currently
 *
 *  @return YES if the report should be sent
 */
- (BOOL)shouldBeSent;

/**
 *  The release stages used to notify at the time this report is captured
 */
@property(readwrite, copy, nullable) NSArray *enabledReleaseStages;

/**
 *  Property overrides
 */
@property(readonly, copy, nonnull) NSDictionary *overrides;

/**
 *  Number of frames to discard at the top of the generated stacktrace.
 *  Stacktraces from raised exceptions are unaffected.
 */
@property(readwrite) NSUInteger depth;

@property (nonatomic, strong) BugsnagMetadata *metadata;

/**
 *  Raw error data
 */
@property(readwrite, copy, nullable) NSDictionary *error;

/**
 *  The release stage of the application
 */
@property(readwrite, copy, nullable) NSString *releaseStage;
@end

@implementation BugsnagEvent

- (instancetype)initWithKSReport:(NSDictionary *)report
                    fileMetadata:(NSString *)metadata {
    return [self initWithKSReport:report];
}

- (instancetype)initWithKSReport:(NSDictionary *)report {
    if (report.count == 0) {
        return nil; // report is empty
    }

    if (self = [super init]) {
        BugsnagConfiguration *config = [Bugsnag configuration];

        _error = [report valueForKeyPath:@"crash.error"];
        _errorType = _error[BSGKeyType];
        if ([[report valueForKeyPath:@"user.state.didOOM"] boolValue]) {
            _errorClass = BSGParseErrorClass(_error, _errorType);
            _errorMessage = BSGParseErrorMessage(report, _error, _errorType);
            _breadcrumbs = BSGParseBreadcrumbs(report);
            _app = [BugsnagAppWithState appWithOomData:[report valueForKeyPath:@"user.state.oom.app"]];
            _device = [BugsnagDeviceWithState deviceWithOomData:[report valueForKeyPath:@"user.state.oom.device"]];
            _releaseStage = [report valueForKeyPath:@"user.state.oom.app.releaseStage"];
            _handledState = [BugsnagHandledState handledStateWithSeverityReason:LikelyOutOfMemory];
            _deviceAppHash = [report valueForKeyPath:@"user.state.oom.device.id"];

            // no threads or metadata captured for OOMs
            _threads = [NSMutableArray new];
            self.metadata = [BugsnagMetadata new];

            NSDictionary *sessionData = [report valueForKeyPath:@"user.state.oom.session"];
            if (sessionData) {
                _session = [[BugsnagSession alloc] initWithDictionary:sessionData];
                _session.unhandledCount += 1; // include own event
                if (_session.user) {
                    self.metadata = [[BugsnagMetadata alloc] initWithDictionary:@{@"user": [_session.user toJson]}];
                }
            }
        } else {
            _enabledReleaseStages = BSGLoadConfigValue(report, BSGKeyEnabledReleaseStages);
            _releaseStage = BSGParseReleaseStage(report);
            NSArray *binaryImages = report[@"binary_images"];
            NSArray *threadDict = [report valueForKeyPath:@"crash.threads"];

            RegisterErrorData *data = [RegisterErrorData errorDataFromThreads:threadDict];
            if (data) {
                _errorClass = data.errorClass ;
                _errorMessage = data.errorMessage;
            } else {
                _errorClass = BSGParseErrorClass(_error, _errorType);
                _errorMessage = BSGParseErrorMessage(report, _error, _errorType);
            }
            _breadcrumbs = BSGParseBreadcrumbs(report);
            _deviceAppHash = [report valueForKeyPath:@"system.device_app_hash"];

            id userMetadata = [report valueForKeyPath:@"user.metaData"];
            if ([userMetadata isKindOfClass:[NSDictionary class]]) {
                self.metadata = [[BugsnagMetadata alloc] initWithDictionary:userMetadata];
            }
            else {
                self.metadata = [BugsnagMetadata new];
            }

            NSDictionary *deviceMetadata = BSGParseDeviceMetadata(report);
            [self.metadata addMetadata:deviceMetadata toSection:@"device"];

            _context = BSGParseContext(report);
            _device = [BugsnagDeviceWithState deviceWithDictionary:report];
            _app = [BugsnagAppWithState appWithDictionary:report config:config];
            _groupingHash = BSGParseGroupingHash(report);
            _overrides = [report valueForKeyPath:@"user.overrides"];
            _customException = BSGParseCustomException(report, [_errorClass copy], [_errorMessage copy]);

            NSDictionary *recordedState = [report valueForKeyPath:@"user.handledState"];

            if (recordedState) {
                _handledState =
                    [[BugsnagHandledState alloc] initWithDictionary:recordedState];

                // only makes sense to use serialised value for handled exceptions
                _depth = [[report valueForKeyPath:@"user.depth"]
                        unsignedIntegerValue];
            }

            // the event was unhandled.
            else {
                BOOL isSignal = [BSGKeySignal isEqualToString:_errorType];
                SeverityReasonType severityReason = isSignal ? Signal : UnhandledException;
                _handledState = [BugsnagHandledState
                    handledStateWithSeverityReason:severityReason
                                          severity:BSGSeverityError
                                         attrValue:_errorClass];
                _depth = 0;
            }
            _severity = _handledState.currentSeverity;

            if (report[@"user"][@"id"]) {
                _session = [[BugsnagSession alloc] initWithDictionary:report[@"user"]];
            }

            // generate threads last, relies on depth/errorType properties being calculated first
            _threads = [BugsnagThread threadsFromArray:threadDict
                                          binaryImages:binaryImages
                                                 depth:self.depth
                                             errorType:self.errorType];
        }
    }
    return self;
}

- (instancetype _Nonnull)initWithErrorName:(NSString *_Nonnull)name
                              errorMessage:(NSString *_Nonnull)message
                             configuration:(BugsnagConfiguration *_Nonnull)config
                                  metadata:(BugsnagMetadata *_Nullable)metadata
                              handledState:(BugsnagHandledState *_Nonnull)handledState
                                   session:(BugsnagSession *_Nullable)session
{
    if (self = [super init]) {
        _errorClass = name;
        _errorMessage = message;
        _overrides = [NSDictionary new];
        _device = [BugsnagDeviceWithState new];
        self.metadata = [metadata deepCopy] ?: [BugsnagMetadata new];

        // calling self sets the override property for releaseStage so it is persisted in KSCrash reports
        self.releaseStage = config.releaseStage;
        _enabledReleaseStages = config.enabledReleaseStages;
        // Set context based on current values.  May be nil.
        _context = [[Bugsnag configuration] context];
        NSMutableArray *crumbs = [NSMutableArray new];
        NSUInteger count = config.breadcrumbs.count;
        for (NSUInteger i = 0; i < count; i++) {
            [crumbs addObject:config.breadcrumbs[i]];
        }
        self.breadcrumbs = [crumbs copy];

        _handledState = handledState;
        _severity = handledState.currentSeverity;
        _session = session;
        _threads = [NSMutableArray new];
    }
    return self;
}

// MARK: - apiKey

@synthesize apiKey = _apiKey;

- (NSString *)apiKey {
    if (! _apiKey) {
        _apiKey = Bugsnag.configuration.apiKey;
    }
    return _apiKey;
}


- (void)setApiKey:(NSString *)apiKey {
    if ([BugsnagConfiguration isValidApiKey:apiKey]) {
        _apiKey = apiKey;
    }
    
    // A malformed apiKey should not cause an error: the fallback global value
    // in BugsnagConfiguration will do to get the event reported.
    else {
        bsg_log_warn(@"Attempted to set an invalid Event API key.");
    }
}

- (BOOL)shouldBeSent {
    return [self.enabledReleaseStages containsObject:self.releaseStage] ||
           (self.enabledReleaseStages.count == 0 &&
            [[Bugsnag configuration] shouldSendReports]);
}

@synthesize context = _context;

- (NSString *)context {
    @synchronized (self) {
        return _context;
    }
}

- (void)setContext:(NSString *)context {
    [self setOverrideProperty:BSGKeyContext value:context];
    @synchronized (self) {
        _context = context;
    }
}

@synthesize groupingHash = _groupingHash;

- (NSString *)groupingHash {
    @synchronized (self) {
        return _groupingHash;
    }
}

- (void)setGroupingHash:(NSString *)groupingHash {
    [self setOverrideProperty:BSGKeyGroupingHash value:groupingHash];
    @synchronized (self) {
        _groupingHash = groupingHash;
    }
}

- (NSArray *)serializeBreadcrumbs {
    return [[self breadcrumbs] valueForKeyPath:NSStringFromSelector(@selector(objectValue))];;
}

@synthesize releaseStage = _releaseStage;

- (NSString *)releaseStage {
    @synchronized (self) {
        return _releaseStage;
    }
}

- (void)setReleaseStage:(NSString *)releaseStage {
    [self setOverrideProperty:BSGKeyReleaseStage value:releaseStage];
    @synchronized (self) {
        _releaseStage = releaseStage;
    }
}

- (void)attachCustomStacktrace:(NSArray *)frames withType:(NSString *)type {
    [self setOverrideProperty:@"customStacktraceFrames" value:frames];
    [self setOverrideProperty:@"customStacktraceType" value:type];
}

@synthesize severity = _severity;

- (BSGSeverity)severity {
    @synchronized (self) {
        return _severity;
    }
}

- (void)setSeverity:(BSGSeverity)severity {
    @synchronized (self) {
        _severity = severity;
        _handledState.currentSeverity = severity;
    }
}

// MARK: - Callback overrides

@synthesize overrides = _overrides;

- (NSDictionary *)overrides {
    NSMutableDictionary *values = [_overrides mutableCopy] ?: [NSMutableDictionary new];
    values[BSGKeyBreadcrumbs] = [self serializeBreadcrumbs];
    return values;
}

- (void)setOverrides:(NSDictionary * _Nonnull)overrides {
    _overrides = overrides;
}

- (void)setOverrideProperty:(NSString *)key value:(id)value {
    @synchronized (self) {
        NSMutableDictionary *metadata = [self.overrides mutableCopy];
        if (value) {
            metadata[key] = value;
        } else {
            [metadata removeObjectForKey:key];
        }
        _overrides = metadata;
    }
}

- (NSDictionary *)toJson {
    NSMutableDictionary *event = [NSMutableDictionary dictionary];
    NSMutableDictionary *metadata = [[[self metadata] toDictionary] mutableCopy];

    if (self.customException) {
        BSGDictSetSafeObject(event, @[ self.customException ], BSGKeyExceptions);
    } else {
        NSMutableDictionary *exception = [NSMutableDictionary dictionary];
        BSGDictSetSafeObject(exception, [self errorClass], BSGKeyErrorClass);
        BSGDictInsertIfNotNil(exception, [self errorMessage], BSGKeyMessage);
        BSGDictInsertIfNotNil(exception, DEFAULT_EXCEPTION_TYPE, BSGKeyType);
        BSGDictSetSafeObject(event, @[ exception ], BSGKeyExceptions);

        // set the stacktrace for the exception from the threads
        for (BugsnagThread *thread in self.threads) {
            if (thread.errorReportingThread) {
                BSGDictSetSafeObject(exception, [thread.trace toArray], BSGKeyStacktrace);
            }
        }
    }

    BSGDictSetSafeObject(event, [BugsnagThread serializeThreads:self.threads], BSGKeyThreads);

    // Build Event
    BSGDictSetSafeObject(event, BSGFormatSeverity(self.severity), BSGKeySeverity);
    BSGDictSetSafeObject(event, [self serializeBreadcrumbs], BSGKeyBreadcrumbs);
    BSGDictSetSafeObject(event, metadata, BSGKeyMetadata);

    BSGDictSetSafeObject(event, [self.device toDictionary], BSGKeyDevice);
    BSGDictSetSafeObject(event, [self.app toDict], BSGKeyApp);
    
    BSGDictSetSafeObject(event, [self context], BSGKeyContext);
    BSGDictInsertIfNotNil(event, self.groupingHash, BSGKeyGroupingHash);
    

    BSGDictSetSafeObject(event, @(self.handledState.unhandled), BSGKeyUnhandled);

    // serialize handled/unhandled into payload
    NSMutableDictionary *severityReason = [NSMutableDictionary new];
    NSString *reasonType = [BugsnagHandledState
        stringFromSeverityReason:self.handledState.calculateSeverityReasonType];
    severityReason[BSGKeyType] = reasonType;

    if (self.handledState.attrKey && self.handledState.attrValue) {
        severityReason[BSGKeyAttributes] =
            @{self.handledState.attrKey : self.handledState.attrValue};
    }

    BSGDictSetSafeObject(event, severityReason, BSGKeySeverityReason);

    //  Inserted into `context` property
    [metadata removeObjectForKey:BSGKeyContext];
    // Build metadata
    BSGDictSetSafeObject(metadata, [self error], BSGKeyError);

    // Make user mutable and set the id if the user hasn't already
    NSMutableDictionary *user = [metadata[BSGKeyUser] mutableCopy];
    if (user == nil) {
        user = [NSMutableDictionary dictionary];
    }
    BSGDictInsertIfNotNil(event, user, BSGKeyUser);

    if (!user[BSGKeyId] && self.device.id) { // if device id is null, don't set user id to default
        BSGDictSetSafeObject(user, [self deviceAppHash], BSGKeyId);
    }

    if (self.session) {
        BSGDictSetSafeObject(event, [self generateSessionDict], BSGKeySession);
    }
    return event;
}

- (NSDictionary *)generateSessionDict {
    NSDictionary *events = @{
            @"handled": @(self.session.handledCount),
            @"unhandled": @(self.session.unhandledCount)
    };

    NSDictionary *sessionJson = @{
            BSGKeyId: self.session.sessionId,
            @"startedAt": [BSG_RFC3339DateTool stringFromDate:self.session.startedAt],
            @"events": events
    };
    return sessionJson;
}

- (BOOL)unhandled {
    return self.handledState.unhandled;
}

// MARK: - <BugsnagMetadataStore>

- (void)addMetadata:(NSDictionary *_Nonnull)metadata
          toSection:(NSString *_Nonnull)sectionName
{
    [self.metadata addMetadata:metadata toSection:sectionName];
}

- (void)addMetadata:(id _Nullable)metadata
            withKey:(NSString *_Nonnull)key
          toSection:(NSString *_Nonnull)sectionName
{
    [self.metadata addMetadata:metadata withKey:key toSection:sectionName];
}

- (id _Nullable)getMetadataFromSection:(NSString *_Nonnull)sectionName
                               withKey:(NSString *_Nonnull)key
{
    return [self.metadata getMetadataFromSection:sectionName withKey:key];
}

- (NSMutableDictionary *_Nullable)getMetadataFromSection:(NSString *_Nonnull)sectionName
{
    return [self.metadata getMetadataFromSection:sectionName];
}

- (void)clearMetadataFromSection:(NSString *_Nonnull)sectionName
{
    [self.metadata clearMetadataFromSection:sectionName];
}

- (void)clearMetadataFromSection:(NSString *_Nonnull)sectionName
                       withKey:(NSString *_Nonnull)key
{
    [self.metadata clearMetadataFromSection:sectionName withKey:key];
}

@end
