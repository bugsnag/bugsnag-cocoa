// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "BSFPRNetworkTrace.h"

#import "BSFPRConsoleLogger.h"
#import "BSFPRDataUtils.h"

#import "BSGULObjectSwizzler.h"

NSString *const kBSFPRNetworkTracePropertyName = @"fpr_networkTrace";

@interface BSFPRNetworkTrace ()

@property(nonatomic, readwrite) NetworkTraceCallback onRequestCompleted;

/** Serial queue to manage concurrency. */
@property(nonatomic, readwrite, nonnull) dispatch_queue_t syncQueue;

@property(nonatomic, readwrite) NSURLRequest *URLRequest;

@property(nonatomic, readwrite, nullable) NSError *responseError;

/** State to know if the trace has started. */
@property(nonatomic) BOOL traceStarted;

/** State to know if the trace has completed. */
@property(nonatomic) BOOL traceCompleted;

/** Background activity tracker to know the background state of the trace. */
@property(nonatomic) BSFPRTraceBackgroundActivityTracker *backgroundActivityTracker;

/** Custom attribute managed internally. */
@property(nonatomic) NSMutableDictionary<NSString *, NSString *> *customAttributes;

@end

@implementation BSFPRNetworkTrace {
  /**
   * @brief Object containing different states of the network request. Stores the information about
   * the state of a network request (defined in BSFPRNetworkTraceCheckpointState) and the time at
   * which the event happened.
   */
  NSMutableDictionary<NSString *, NSNumber *> *_states;
}

- (nullable instancetype)initWithURLRequest:(NSURLRequest *)URLRequest completionCallback:(NetworkTraceCallback _Nonnull )onRequestCompleted{
  if (URLRequest.URL == nil) {
    BSFPRLogError(kBSFPRNetworkTraceInvalidInputs, @"Invalid URL. URL is nil.");
    return nil;
  }

  NSString *trimmedURLString = [BSFPRNetworkTrace stringByTrimmingURLString:URLRequest];
  if (!trimmedURLString || trimmedURLString.length <= 0) {
    BSFPRLogInfo(kBSFPRNetworkTraceURLLengthExceeds, @"URL length outside limits, returning nil.");
    return nil;
  }

  if (![URLRequest.URL.absoluteString isEqualToString:trimmedURLString]) {
    BSFPRLogInfo(kBSFPRNetworkTraceURLLengthTruncation,
               @"URL length exceeds limits, truncating recorded URL - %@.", trimmedURLString);
  }

  self = [super init];
  if (self) {
    _onRequestCompleted = onRequestCompleted;
    _URLRequest = URLRequest;
    _trimmedURLString = trimmedURLString;
    _states = [[NSMutableDictionary<NSString *, NSNumber *> alloc] init];
    _hasValidResponseCode = NO;
    _customAttributes = [[NSMutableDictionary<NSString *, NSString *> alloc] init];
    _syncQueue =
        dispatch_queue_create("com.bugsnag.perf.networkTrace.metric", DISPATCH_QUEUE_SERIAL);
    if (![BSFPRNetworkTrace isCompleteAndValidTrimmedURLString:_trimmedURLString
                                                  URLRequest:_URLRequest]) {
      return nil;
    };
  }
  return self;
}

- (instancetype)init {
  NSAssert(NO, @"Not a designated initializer.");
  return nil;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"{ Request: %@ (length %lld), Response: %d (length %lld)",
          _URLRequest, _requestSize, _responseCode, _responseSize];
}

- (NSDictionary<NSString *, NSNumber *> *)checkpointStates {
  __block NSDictionary<NSString *, NSNumber *> *copiedStates;
  dispatch_sync(self.syncQueue, ^{
    copiedStates = [_states copy];
  });
  return copiedStates;
}

- (void)checkpointState:(BSFPRNetworkTraceCheckpointState)state {
  if (!self.traceCompleted && self.traceStarted) {
    NSString *stateKey = @(state).stringValue;
    if (stateKey) {
      dispatch_sync(self.syncQueue, ^{
        NSNumber *existingState = _states[stateKey];

        if (existingState == nil) {
          double intervalSinceEpoch = [[NSDate date] timeIntervalSince1970];
          [_states setObject:@(intervalSinceEpoch) forKey:stateKey];
        }
      });
    } else {
      NSAssert(NO, @"stateKey wasn't created for checkpoint state %ld", (long)state);
    }
  }
}

- (void)start {
  if (!self.traceCompleted) {
    self.traceStarted = YES;
    self.backgroundActivityTracker = [[BSFPRTraceBackgroundActivityTracker alloc] init];
    [self checkpointState:BSFPRNetworkTraceCheckpointStateInitiated];
  }
}

- (BSFPRTraceState)backgroundTraceState {
  BSFPRTraceBackgroundActivityTracker *backgroundActivityTracker = self.backgroundActivityTracker;
  if (backgroundActivityTracker) {
    return backgroundActivityTracker.traceBackgroundState;
  }

  return BSFPRTraceStateUnknown;
}

- (NSTimeInterval)startTimeSinceEpoch {
  NSString *stateKey =
      [NSString stringWithFormat:@"%lu", (unsigned long)BSFPRNetworkTraceCheckpointStateInitiated];
  __block NSTimeInterval timeSinceEpoch;
  dispatch_sync(self.syncQueue, ^{
    timeSinceEpoch = [[_states objectForKey:stateKey] doubleValue];
  });
  return timeSinceEpoch;
}

#pragma mark - Overrides

- (void)setResponseCode:(int32_t)responseCode {
  _responseCode = responseCode;
  if (responseCode != 0) {
    _hasValidResponseCode = YES;
  }
}

#pragma mark - BSFPRNetworkResponseHandler methods

- (void)didCompleteRequestWithResponse:(NSURLResponse *)response error:(NSError *)error {
  if (!self.traceCompleted && self.traceStarted) {
    // Extract needed fields for the trace object.
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
      NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
      self.responseCode = (int32_t)HTTPResponse.statusCode;
    }
    self.responseError = error;
    self.responseContentType = response.MIMEType;
    [self checkpointState:BSFPRNetworkTraceCheckpointStateResponseCompleted];

    self.traceCompleted = YES;
    self.onRequestCompleted(self);
  }
}

- (void)didUploadFileWithURL:(NSURL *)URL {
  NSNumber *value = nil;
  NSError *error = nil;

  if ([URL getResourceValue:&value forKey:NSURLFileSizeKey error:&error]) {
    if (error) {
      BSFPRLogNotice(kBSFPRNetworkTraceFileError, @"Unable to determine the size of file.");
    } else {
      self.requestSize = value.unsignedIntegerValue;
    }
  }
}

- (void)didReceiveData:(NSData *)data {
  self.responseSize = data.length;
}

- (void)didReceiveFileURL:(NSURL *)URL {
  NSNumber *value = nil;
  NSError *error = nil;

  if ([URL getResourceValue:&value forKey:NSURLFileSizeKey error:&error]) {
    if (error) {
      BSFPRLogNotice(kBSFPRNetworkTraceFileError, @"Unable to determine the size of file.");
    } else {
      self.responseSize = value.unsignedIntegerValue;
    }
  }
}

- (NSTimeInterval)timeIntervalBetweenCheckpointState:(BSFPRNetworkTraceCheckpointState)startState
                                            andState:(BSFPRNetworkTraceCheckpointState)endState {
  __block NSNumber *startStateTime;
  __block NSNumber *endStateTime;
  dispatch_sync(self.syncQueue, ^{
    startStateTime = [_states objectForKey:[@(startState) stringValue]];
    endStateTime = [_states objectForKey:[@(endState) stringValue]];
  });
  // Fail fast. If any of the times do not exist, return 0.
  if (startStateTime == nil || endStateTime == nil) {
    return 0;
  }

  NSTimeInterval timeDiff = (endStateTime.doubleValue - startStateTime.doubleValue);
  return timeDiff;
}

/** Trims and validates the URL string of a given NSURLRequest.
 *
 *  @param URLRequest The NSURLRequest containing the URL string to trim.
 *  @return The trimmed string.
 */
+ (NSString *)stringByTrimmingURLString:(NSURLRequest *)URLRequest {
  NSURLComponents *components = [NSURLComponents componentsWithURL:URLRequest.URL
                                           resolvingAgainstBaseURL:NO];
  components.query = nil;
  components.fragment = nil;
  components.user = nil;
  components.password = nil;
  NSURL *trimmedURL = [components URL];
  NSString *truncatedURLString = BSFPRTruncatedURLString(trimmedURL.absoluteString);

  NSURL *truncatedURL = [NSURL URLWithString:truncatedURLString];
  if (!truncatedURL || truncatedURL.host == nil) {
    return nil;
  }
  return truncatedURLString;
}

/** Validates the trace object by checking that it's http or https, and not a denied URL.
 *
 *  @param trimmedURLString A trimmed URL string from the URLRequest.
 *  @param URLRequest The NSURLRequest that this trace will operate on.
 *  @return YES if the trace object is valid, NO otherwise.
 */
+ (BOOL)isCompleteAndValidTrimmedURLString:(NSString *)trimmedURLString
                                URLRequest:(NSURLRequest *)URLRequest {
  // Check the URL begins with http or https.
  NSURLComponents *components = [NSURLComponents componentsWithURL:URLRequest.URL
                                           resolvingAgainstBaseURL:NO];
  NSString *scheme = components.scheme;
  if (!scheme || !([scheme caseInsensitiveCompare:@"HTTP"] == NSOrderedSame ||
                   [scheme caseInsensitiveCompare:@"HTTPS"] == NSOrderedSame)) {
    BSFPRLogError(kBSFPRNetworkTraceInvalidInputs, @"Invalid URL - %@, returning nil.", URLRequest.URL);
    return NO;
  }

  return YES;
}

#pragma mark - Class methods related to object association.

+ (void)addNetworkTrace:(BSFPRNetworkTrace *)networkTrace toObject:(id)object {
  if (object != nil && networkTrace != nil) {
    [BSGULObjectSwizzler setAssociatedObject:object
                                       key:kBSFPRNetworkTracePropertyName
                                     value:networkTrace
                               association:BSGUL_ASSOCIATION_RETAIN_NONATOMIC];
  }
}

+ (BSFPRNetworkTrace *)networkTraceFromObject:(id)object {
  BSFPRNetworkTrace *networkTrace = nil;
  if (object != nil) {
    id traceObject = [BSGULObjectSwizzler getAssociatedObject:object
                                                        key:kBSFPRNetworkTracePropertyName];
    if ([traceObject isKindOfClass:[BSFPRNetworkTrace class]]) {
      networkTrace = (BSFPRNetworkTrace *)traceObject;
    }
  }

  return networkTrace;
}

+ (void)removeNetworkTraceFromObject:(id)object {
  if (object != nil) {
    [BSGULObjectSwizzler setAssociatedObject:object
                                       key:kBSFPRNetworkTracePropertyName
                                     value:nil
                               association:BSGUL_ASSOCIATION_RETAIN_NONATOMIC];
  }
}

@end
