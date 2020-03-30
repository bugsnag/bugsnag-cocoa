//
//  BugsnagConfiguration.m
//
//  Created by Conrad Irwin on 2014-10-01.
//
//  Copyright (c) 2014 Bugsnag, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "BugsnagConfiguration.h"
#import "Bugsnag.h"
#import "BugsnagClient.h"
#import "BugsnagKeys.h"
#import "BSG_RFC3339DateTool.h"
#import "BugsnagUser.h"
#import "BugsnagSessionTracker.h"
#import "BugsnagLogger.h"
#import "BSG_SSKeychain.h"
#import "BugsnagBreadcrumbs.h"

static NSString *const kHeaderApiPayloadVersion = @"Bugsnag-Payload-Version";
static NSString *const kHeaderApiKey = @"Bugsnag-Api-Key";
static NSString *const kHeaderApiSentAt = @"Bugsnag-Sent-At";
static NSString *const BSGApiKeyError = @"apiKey must be a 32-digit hexadecimal value.";
static NSString *const BSGInitError = @"Init is unavailable.  Use [[BugsnagConfiguration alloc] initWithApiKey:] instead.";
static const int BSGApiKeyLength = 32;

// User info persistence keys
NSString * const kBugsnagUserKeychainAccount = @"BugsnagUserKeychainAccount";
NSString * const kBugsnagUserEmailAddress = @"BugsnagUserEmailAddress";
NSString * const kBugsnagUserName = @"BugsnagUserName";
NSString * const kBugsnagUserUserId = @"BugsnagUserUserId";

@interface Bugsnag ()
+ (BugsnagClient *)client;
@end

@interface BugsnagClient ()
@property BugsnagSessionTracker *sessionTracker;
@end

@interface BugsnagConfiguration ()

/**
 *  Hooks for modifying crash reports before it is sent to Bugsnag
 */
@property(nonatomic, readwrite, strong) NSMutableArray *onSendBlocks;

/**
 *  Hooks for modifying sessions before they are sent to Bugsnag. Intended for internal use only by React Native/Unity.
 */
@property(nonatomic, readwrite, strong) NSMutableArray *onSessionBlocks;
@property(nonatomic, readwrite, strong) NSMutableArray *onBreadcrumbBlocks;
@property(nonatomic, readwrite, strong) NSMutableSet *plugins;
@property(readonly, retain, nullable) NSURL *notifyURL;
@property(readonly, retain, nullable) NSURL *sessionURL;

/**
 *  Additional information about the state of the app or environment at the
 *  time the report was generated
 */
@property(readwrite, retain, nullable) BugsnagMetadata *metadata;

/**
 *  Meta-information about the state of Bugsnag
 */
@property(readwrite, retain, nullable) BugsnagMetadata *config;

/**
 *  Rolling snapshots of user actions leading up to a crash report
 */
@property(readonly, strong, nullable) BugsnagBreadcrumbs *breadcrumbs;
@end

@implementation BugsnagConfiguration

// -----------------------------------------------------------------------------
// MARK: - Class Methods
// -----------------------------------------------------------------------------

/**
 * Determine the apiKey-validity of a passed-in string:
 * Exactly 32 hexadecimal digits.
 *
 * @param apiKey The API key.
 * @returns A boolean representing whether the apiKey is valid.
 */
+ (BOOL)isValidApiKey:(NSString *)apiKey {
    NSCharacterSet *chars = [[NSCharacterSet
        characterSetWithCharactersInString:@"0123456789ABCDEF"] invertedSet];
    BOOL isHex = (NSNotFound == [[apiKey uppercaseString] rangeOfCharacterFromSet:chars].location);
    return isHex && [apiKey length] == BSGApiKeyLength;
}

// -----------------------------------------------------------------------------
// MARK: - Initializers
// -----------------------------------------------------------------------------

/**
 * Should not be called, but if it _is_ then fail meaningfully rather than silently
 */
- (instancetype)init {
    @throw BSGInitError;
}

/**
 * The designated initializer.
 */
- (instancetype _Nonnull)initWithApiKey:(NSString *_Nonnull)apiKey
{
    if (![BugsnagConfiguration isValidApiKey:apiKey]) {
        bsg_log_err(@"Invalid configuration. apiKey should be a 32-character hexademical string, got \"%@\"", apiKey);
    }
    
    self = [super init];
    
    _metadata = [[BugsnagMetadata alloc] init];
    _config = [[BugsnagMetadata alloc] init];
    _apiKey = apiKey;
    _sessionURL = [NSURL URLWithString:@"https://sessions.bugsnag.com"];
    _autoDetectErrors = YES;
    _notifyURL = [NSURL URLWithString:BSGDefaultNotifyUrl];
    _onSendBlocks = [NSMutableArray new];
    _onSessionBlocks = [NSMutableArray new];
    _onBreadcrumbBlocks = [NSMutableArray new];
    _plugins = [NSMutableSet new];
    _enabledReleaseStages = nil;
    _breadcrumbs = [BugsnagBreadcrumbs new];
    _autoTrackSessions = YES;
    // Default to recording all error types
    _enabledErrorTypes = BSGErrorTypesCPP
                       | BSGErrorTypesMach
                       | BSGErrorTypesSignals
                       | BSGErrorTypesNSExceptions;

    // Enabling OOM detection only happens in release builds, to avoid triggering
    // the heuristic when killing/restarting an app in Xcode or similar.
    _persistUser = YES;
    // Only gets persisted user data if there is any, otherwise nil
    // persistUser isn't settable until post-init.
    _user = [self getPersistedUserData];
    [self setUserMetadataFromUser:_user];
    
    #if !DEBUG
        _enabledErrorTypes |= BSGErrorTypesOOMs;
    #endif

    if ([NSURLSession class]) {
        _session = [NSURLSession
            sessionWithConfiguration:[NSURLSessionConfiguration
                                         defaultSessionConfiguration]];
    }
    #if DEBUG
        _releaseStage = BSGKeyDevelopment;
    #else
        _releaseStage = BSGKeyProduction;
    #endif
    
    return self;
}

// -----------------------------------------------------------------------------
// MARK: - Instance Methods
// -----------------------------------------------------------------------------

/**
 *  Whether reports should be sent, based on release stage options
 *
 *  @return YES if reports should be sent based on this configuration
 */
- (BOOL)shouldSendReports {
    return self.enabledReleaseStages.count == 0 ||
           [self.enabledReleaseStages containsObject:self.releaseStage];
}

- (void)setUser:(NSString *_Nullable)userId
      withEmail:(NSString *_Nullable)email
        andName:(NSString *_Nullable)name {
    _user = [[BugsnagUser alloc] initWithUserId:userId name:name emailAddress:email];

    // Persist the user
    if (_persistUser)
        [self persistUserData];
    
    // Add user info to the metadata
    [self setUserMetadataFromUser:self.user];
}

/**
 * Add user data to the Configuration metadata
 *
 * @param user A BugsnagUser object containing data to be added to the configuration metadata.
 */
- (void)setUserMetadataFromUser:(BugsnagUser *)user {
    [self.metadata addAttribute:BSGKeyId    withValue:user.userId    toTabWithName:BSGKeyUser];
    [self.metadata addAttribute:BSGKeyName  withValue:user.name  toTabWithName:BSGKeyUser];
    [self.metadata addAttribute:BSGKeyEmail withValue:user.emailAddress toTabWithName:BSGKeyUser];
}

// =============================================================================
// MARK: - onSendBlock
// =============================================================================

- (void)addOnSendBlock:(BugsnagOnSendBlock)block {
    [(NSMutableArray *)self.onSendBlocks addObject:[block copy]];
}

- (void)removeOnSendBlock:(BugsnagOnSendBlock _Nonnull )block
{
    [(NSMutableArray *)self.onSendBlocks removeObject:block];
}

// =============================================================================
// MARK: - onSessionBlock
// =============================================================================

- (void)addOnSessionBlock:(BugsnagOnSessionBlock)block {
    [(NSMutableArray *)self.onSessionBlocks addObject:[block copy]];
}

- (void)removeOnSessionBlock:(BugsnagOnSessionBlock)block {
    [(NSMutableArray *)self.onSessionBlocks removeObject:block];
}

// =============================================================================
// MARK: - onBreadcrumbBlock
// =============================================================================

- (void)addOnBreadcrumbBlock:(BugsnagOnBreadcrumbBlock _Nonnull)block {
    [(NSMutableArray *)self.onBreadcrumbBlocks addObject:[block copy]];
}

- (void)removeOnBreadcrumbBlock:(BugsnagOnBreadcrumbBlock _Nonnull)block {
    [(NSMutableArray *)self.onBreadcrumbBlocks removeObject:block];
}

- (NSDictionary *)errorApiHeaders {
    return @{
             kHeaderApiPayloadVersion: @"4.0",
             kHeaderApiKey: self.apiKey,
             kHeaderApiSentAt: [BSG_RFC3339DateTool stringFromDate:[NSDate new]]
    };
}

- (NSDictionary *)sessionApiHeaders {
    return @{
             kHeaderApiPayloadVersion: @"1.0",
             kHeaderApiKey: self.apiKey,
             kHeaderApiSentAt: [BSG_RFC3339DateTool stringFromDate:[NSDate new]]
             };
}

- (void)setEndpointsForNotify:(NSString *_Nonnull)notify sessions:(NSString *_Nonnull)sessions {
    _notifyURL = [NSURL URLWithString:notify];
    _sessionURL = [NSURL URLWithString:sessions];

    NSAssert([self isValidUrl:_notifyURL], @"Invalid URL supplied for notify endpoint");

    if (![self isValidUrl:_sessionURL]) {
        _sessionURL = nil;
    }
}

- (BOOL)isValidUrl:(NSURL *)url {
    return url != nil && url.scheme != nil && url.host != nil;
}

// MARK: - User Persistence

@synthesize persistUser = _persistUser;

- (BOOL)persistUser {
    @synchronized (self) {
        return _persistUser;
    }
}

- (void)setPersistUser:(BOOL)persistUser {
    @synchronized (self) {
        _persistUser = persistUser;
        if (persistUser) {
            [self persistUserData];
        }
        else {
            [self deletePersistedUserData];
        }
    }
}

/**
 * Retrieve a persisted user, if we have any valid, persisted fields, or nil otherwise
 */
- (BugsnagUser *)getPersistedUserData {
    @synchronized(self) {
        NSString *email = [BSG_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount];
        NSString *name = [BSG_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount];
        NSString *userId = [BSG_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount];

        if (email || name || userId) {
            return [[BugsnagUser alloc] initWithUserId:userId name:name emailAddress:email];
        } else {
            return [[BugsnagUser alloc] initWithUserId:nil name:nil emailAddress:nil];
        }
    }
}

/**
 * Store user data in a secure location (i.e. the keychain) that persists between application runs
 * 'storing' nil values deletes them.
 */
- (void)persistUserData {
    @synchronized(self) {
        if (_user) {
            // Email
            if (_user.emailAddress) {
                [BSG_SSKeychain setPassword:_user.emailAddress
                             forService:kBugsnagUserEmailAddress
                                account:kBugsnagUserKeychainAccount];
            }
            else {
                [BSG_SSKeychain deletePasswordForService:kBugsnagUserEmailAddress
                                             account:kBugsnagUserKeychainAccount];
            }

            // Name
            if (_user.name) {
                [BSG_SSKeychain setPassword:_user.name
                             forService:kBugsnagUserName
                                account:kBugsnagUserKeychainAccount];
            }
            else {
                [BSG_SSKeychain deletePasswordForService:kBugsnagUserName
                                             account:kBugsnagUserKeychainAccount];
            }
            
            // UserId
            if (_user.userId) {
                [BSG_SSKeychain setPassword:_user.userId
                             forService:kBugsnagUserUserId
                                account:kBugsnagUserKeychainAccount];
            }
            else {
                [BSG_SSKeychain deletePasswordForService:kBugsnagUserUserId
                                             account:kBugsnagUserKeychainAccount];
            }
        }
    }
}

/**
 * Delete any persisted user data
 */
-(void)deletePersistedUserData {
    @synchronized(self) {
        [BSG_SSKeychain deletePasswordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount];
        [BSG_SSKeychain deletePasswordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount];
        [BSG_SSKeychain deletePasswordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount];
    }
}

// -----------------------------------------------------------------------------
// MARK: - Properties: Getters and Setters
// -----------------------------------------------------------------------------

- (NSUInteger)maxBreadcrumbs {
    return self.breadcrumbs.capacity;
}

- (void)setMaxBreadcrumbs:(NSUInteger)capacity {
    self.breadcrumbs.capacity = capacity;
}

/**
 * Specific types of breadcrumb should be recorded if either enabledBreadcrumbTypes
 * is None, or contains the type.
 *
 * @param type The breadcrumb type to test
 * @returns Whether to record the breadcrumb
 */
- (BOOL)shouldRecordBreadcrumbType:(BSGBreadcrumbType)type {
    // enabledBreadcrumbTypes is BSGEnabledBreadcrumbTypeNone
    if (!self.enabledBreadcrumbTypes) {
        return YES;
    }
    
    switch (type) {
        case BSGBreadcrumbTypeManual:
            return YES;
        case BSGBreadcrumbTypeError :
            return self.enabledBreadcrumbTypes & BSGEnabledBreadcrumbTypeError;
        case BSGBreadcrumbTypeLog:
            return self.enabledBreadcrumbTypes & BSGEnabledBreadcrumbTypeLog;
        case BSGBreadcrumbTypeNavigation:
            return self.enabledBreadcrumbTypes & BSGEnabledBreadcrumbTypeNavigation;
        case BSGBreadcrumbTypeProcess:
            return self.enabledBreadcrumbTypes & BSGEnabledBreadcrumbTypeProcess;
        case BSGBreadcrumbTypeRequest:
            return self.enabledBreadcrumbTypes & BSGEnabledBreadcrumbTypeRequest;
        case BSGBreadcrumbTypeState:
            return self.enabledBreadcrumbTypes & BSGEnabledBreadcrumbTypeState;
        case BSGBreadcrumbTypeUser:
            return self.enabledBreadcrumbTypes & BSGEnabledBreadcrumbTypeUser;
    }
    return NO;
}

// MARK: -

@synthesize releaseStage = _releaseStage;

- (NSString *)releaseStage {
    @synchronized (self) {
        return _releaseStage;
    }
}

- (void)setReleaseStage:(NSString *)newReleaseStage {
    @synchronized (self) {
        NSString *key = NSStringFromSelector(@selector(releaseStage));
        [self willChangeValueForKey:key];
        _releaseStage = newReleaseStage;
        [self didChangeValueForKey:key];
        [self.config addAttribute:BSGKeyReleaseStage
                        withValue:newReleaseStage
                    toTabWithName:BSGKeyConfig];
    }
}

// MARK: -

@synthesize autoDetectErrors = _autoDetectErrors;

- (BOOL)autoDetectErrors {
    return _autoDetectErrors;
}

- (void)setAutoDetectErrors:(BOOL)autoDetectErrors {
    if (autoDetectErrors == _autoDetectErrors) {
        return;
    }
    [self willChangeValueForKey:NSStringFromSelector(@selector(autoDetectErrors))];
    _autoDetectErrors = autoDetectErrors;
    [[Bugsnag client] updateCrashDetectionSettings];
    [self didChangeValueForKey:NSStringFromSelector(@selector(autoDetectErrors))];
}

- (BOOL)autoNotify {
    return self.autoDetectErrors;
}

- (void)setAutoNotify:(BOOL)autoNotify {
    self.autoDetectErrors = autoNotify;
}

// MARK: -

@synthesize enabledReleaseStages = _enabledReleaseStages;

- (NSArray *)enabledReleaseStages {
    @synchronized (self) {
        return _enabledReleaseStages;
    }
}

- (void)setEnabledReleaseStages:(NSArray *)newReleaseStages;
{
    @synchronized (self) {
        NSArray *releaseStagesCopy = [newReleaseStages copy];
        _enabledReleaseStages = releaseStagesCopy;
        [self.config addAttribute:BSGKeyEnabledReleaseStages
                        withValue:releaseStagesCopy
                    toTabWithName:BSGKeyConfig];
    }
}

// MARK: -

- (void)setShouldAutoCaptureSessions:(BOOL)shouldAutoCaptureSessions {
    self.autoTrackSessions = shouldAutoCaptureSessions;
}

- (BOOL)shouldAutoCaptureSessions {
    return self.autoTrackSessions;
}

// MARK: - enabledBreadcrumbTypes

- (BSGEnabledBreadcrumbType)enabledBreadcrumbTypes {
    return self.breadcrumbs.enabledBreadcrumbTypes;
}

- (void)setEnabledBreadcrumbTypes:(BSGEnabledBreadcrumbType)enabledBreadcrumbTypes {
    self.breadcrumbs.enabledBreadcrumbTypes = enabledBreadcrumbTypes;
}

// MARK: -

@synthesize context = _context;

- (NSString *)context {
    @synchronized (self) {
        return _context;
    }
}

- (void)setContext:(NSString *)newContext {
    @synchronized (self) {
        _context = newContext;
        [self.config addAttribute:BSGKeyContext
                        withValue:newContext
                    toTabWithName:BSGKeyConfig];
    }
}

// MARK: -

@synthesize appVersion = _appVersion;

- (NSString *)appVersion {
    @synchronized (self) {
        return _appVersion;
    }
}

- (void)setAppVersion:(NSString *)newVersion {
    @synchronized (self) {
        _appVersion = newVersion;
        [self.config addAttribute:BSGKeyAppVersion
                        withValue:newVersion
                    toTabWithName:BSGKeyConfig];
    }
}

// MARK: -

@synthesize apiKey = _apiKey;

- (NSString *)apiKey {
    return _apiKey;
}

- (void)setApiKey:(NSString *)apiKey {
    if ([BugsnagConfiguration isValidApiKey:apiKey]) {
        [self willChangeValueForKey:NSStringFromSelector(@selector(apiKey))];
        _apiKey = apiKey;
        [self didChangeValueForKey:NSStringFromSelector(@selector(apiKey))];
    } else {
        @throw BSGApiKeyError;
    }
}

- (void)addPlugin:(id<BugsnagPlugin> _Nonnull)plugin {
    [_plugins addObject:plugin];
}

@end
