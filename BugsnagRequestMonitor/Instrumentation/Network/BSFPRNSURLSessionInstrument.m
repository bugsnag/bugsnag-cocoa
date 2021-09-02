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

/** NSURLSession is a class cluster and the type of class you get back from the various
 *  initialization methods might not actually be NSURLSession. Inside those methods, this class
 *  keeps track of seen NSURLSession subclasses and lazily swizzles them if they've not been seen.
 *  Consequently, swizzling needs to occur on a serial queue for thread safety.
 */

#import "BSFPRNSURLSessionInstrument.h"
#import "BSFPRNSURLSessionInstrument_Private.h"

#import "BSFPRClassInstrumentor.h"
#import "BSFPRInstrument_Private.h"
#import "BSFPRNetworkTrace.h"
#import "BSFPRProxyObjectHelper.h"
#import "BSFPRSelectorInstrumentor.h"
#import "BSFPRNSURLSessionDelegate.h"
#import "BSFPRNetworkInstrumentHelpers.h"

#import "BSGULObjectSwizzler.h"

// Declared for use in instrumentation functions below.
@interface BSFPRNSURLSessionInstrument ()

@property(nonatomic, readwrite) NetworkTraceCallback onRequestCompleted;

/** Registers an instrumentor for an NSURLSession subclass if it hasn't yet been instrumented.
 *
 *  @param aClass The class we wish to instrument.
 */
- (void)registerInstrumentorForClass:(Class)aClass;

/** Registers an instrumentor for an NSURLSession proxy object if it hasn't yet been instrumented.
 *
 *  @param proxy The proxy object we wish to instrument.
 */
- (void)registerProxyObject:(id)proxy;

@end

/** Returns the dispatch queue for all instrumentation to occur on. */
static dispatch_queue_t GetInstrumentationQueue() {
  static dispatch_queue_t queue = nil;
  static dispatch_once_t token = 0;
  dispatch_once(&token, ^{
    queue =
        dispatch_queue_create("com.bugsnag.BSFPRNSURLSessionInstrumentation", DISPATCH_QUEUE_SERIAL);
  });
  return queue;
}

// This completion handler type is commonly used throughout NSURLSession.
typedef void (^BSFPRDataTaskCompletionHandler)(NSData *_Nullable,
                                             NSURLResponse *_Nullable,
                                             NSError *_Nullable);

typedef void (^BSFPRDownloadTaskCompletionHandler)(NSURL *_Nullable location,
                                                 NSURLResponse *_Nullable response,
                                                 NSError *_Nullable error);

#pragma mark - Instrumentation Functions

/** Wraps +sharedSession.
 *
 *  @param instrument The BSFPRNSURLSessionInstrument instance.
 *  @param instrumentor The BSFPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentSharedSession(BSFPRNSURLSessionInstrument *instrument,
                             BSFPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(sharedSession);
  Class instrumentedClass = instrumentor.instrumentedClass;
  BSFPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, YES);
  __weak BSFPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session) {
    __strong BSFPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentedClass);
    }
    typedef NSURLSession *(*OriginalImp)(id, SEL);
    NSURLSession *sharedSession = ((OriginalImp)currentIMP)(session, selector);
    if ([sharedSession isProxy]) {
      [strongInstrument registerProxyObject:sharedSession];
    } else {
      [strongInstrument registerInstrumentorForClass:[sharedSession class]];
    }
    return sharedSession;
  }];
}

/** Wraps +sessionWithConfiguration:.
 *
 *  @param instrument The BSFPRNSURLSessionInstrument instance.
 *  @param instrumentor The BSFPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentSessionWithConfiguration(BSFPRNSURLSessionInstrument *instrument,
                                        BSFPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(sessionWithConfiguration:);
  Class instrumentedClass = instrumentor.instrumentedClass;
  BSFPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, YES);
  __weak BSFPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLSessionConfiguration *configuration) {
    __strong BSFPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentedClass);
    }
    typedef NSURLSession *(*OriginalImp)(id, SEL, NSURLSessionConfiguration *);
    NSURLSession *sessionInstance = ((OriginalImp)currentIMP)(session, selector, configuration);
    if ([sessionInstance isProxy]) {
      [strongInstrument registerProxyObject:sessionInstance];
    } else {
      [strongInstrument registerInstrumentorForClass:[sessionInstance class]];
    }
    return sessionInstance;
  }];
}

/** Wraps +sessionWithConfiguration:delegate:delegateQueue:.
 *
 *  @param instrument The BSFPRNSURLSessionInstrument instance.
 *  @param instrumentor The BSFPRClassInstrumentor to add the selector instrumentor to.
 *  @param delegateInstrument The BSFPRNSURLSessionDelegateInstrument that will track the delegate
 *      selectors.
 */
FOUNDATION_STATIC_INLINE
void InstrumentSessionWithConfigurationDelegateDelegateQueue(
    BSFPRNSURLSessionInstrument *instrument,
    BSFPRClassInstrumentor *instrumentor,
    BSFPRNSURLSessionDelegateInstrument *delegateInstrument) {
  SEL selector = @selector(sessionWithConfiguration:delegate:delegateQueue:);
  Class instrumentedClass = instrumentor.instrumentedClass;
  BSFPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, YES);
  __weak BSFPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor
      setReplacingBlock:^(id session, NSURLSessionConfiguration *configuration,
                          id<NSURLSessionDelegate> delegate, NSOperationQueue *queue) {
        __strong BSFPRNSURLSessionInstrument *strongInstrument = weakInstrument;
        if (!strongInstrument) {
          ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentedClass);
        }
        if (delegate) {
          [delegateInstrument registerClass:[delegate class]];
          [delegateInstrument registerObject:delegate];

        } else {
          delegate = [[BSFPRNSURLSessionDelegate alloc] init];
        }
        typedef NSURLSession *(*OriginalImp)(id, SEL, NSURLSessionConfiguration *,
                                             id<NSURLSessionDelegate>, NSOperationQueue *);
        NSURLSession *sessionInstance =
            ((OriginalImp)currentIMP)([session class], selector, configuration, delegate, queue);
        if ([sessionInstance isProxy]) {
          [strongInstrument registerProxyObject:sessionInstance];
        } else {
          [strongInstrument registerInstrumentorForClass:[sessionInstance class]];
        }
        return sessionInstance;
      }];
}

/** Wraps -dataTaskWithURL:.
 *
 *  @param instrument The BSFPRNSURLSessionInstrument instance.
 *  @param instrumentor The BSFPRClassInstrumentor to add the selector instrumentor to.
 */

FOUNDATION_STATIC_INLINE
void InstrumentDataTaskWithURL(BSFPRNSURLSessionInstrument *instrument,
                               BSFPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(dataTaskWithURL:);
  BSFPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak BSFPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURL *url) {
    __strong BSFPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentor.instrumentedClass);
    }
    typedef NSURLSessionDataTask *(*OriginalImp)(id, SEL, NSURL *);
    NSURLSessionDataTask *dataTask = ((OriginalImp)currentIMP)(session, selector, url);
    if (dataTask.originalRequest) {
      BSFPRNetworkTrace *trace =
          [[BSFPRNetworkTrace alloc] initWithURLRequest:dataTask.originalRequest completionCallback:weakInstrument.onRequestCompleted];
      [trace start];
      [trace checkpointState:BSFPRNetworkTraceCheckpointStateInitiated];
      [BSFPRNetworkTrace addNetworkTrace:trace toObject:dataTask];
    }

    return dataTask;
  }];
}

/** Instruments -dataTaskWithURL:completionHandler:.
 *
 *  @param instrument The BSFPRNSURLSessionInstrument instance.
 *  @param instrumentor The BSFPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentDataTaskWithURLCompletionHandler(BSFPRNSURLSessionInstrument *instrument,
                                                BSFPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(dataTaskWithURL:completionHandler:);
  BSFPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak BSFPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURL *URL,
                                            BSFPRDataTaskCompletionHandler completionHandler) {
    __block NSURLSessionDataTask *task = nil;
    BSFPRDataTaskCompletionHandler wrappedCompletionHandler = nil;
    if (completionHandler) {
      wrappedCompletionHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
        BSFPRNetworkTrace *trace = [BSFPRNetworkTrace networkTraceFromObject:task];
        [trace didReceiveData:data];
        [trace didCompleteRequestWithResponse:response error:error];
        [BSFPRNetworkTrace removeNetworkTraceFromObject:task];
        completionHandler(data, response, error);
      };
    }
    typedef NSURLSessionDataTask *(*OriginalImp)(id, SEL, NSURL *, BSFPRDataTaskCompletionHandler);
    task = ((OriginalImp)currentIMP)(session, selector, URL, wrappedCompletionHandler);

    // Add the network trace object only when the trace object is not added to the task object.
    if ([BSFPRNetworkTrace networkTraceFromObject:task] == nil) {
      BSFPRNetworkTrace *trace = [[BSFPRNetworkTrace alloc] initWithURLRequest:task.originalRequest completionCallback:weakInstrument.onRequestCompleted];
      [trace start];
      [trace checkpointState:BSFPRNetworkTraceCheckpointStateInitiated];
      [BSFPRNetworkTrace addNetworkTrace:trace toObject:task];
    }
    return task;
  }];
}

/** Wraps -dataTaskWithRequest:.
 *
 *  @param instrument The BSFPRNSURLSessionInstrument instance.
 *  @param instrumentor The BSFPRClassInstrumentor to add the selector instrumentor to.
 */

FOUNDATION_STATIC_INLINE
void InstrumentDataTaskWithRequest(BSFPRNSURLSessionInstrument *instrument,
                                   BSFPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(dataTaskWithRequest:);
  BSFPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak BSFPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request) {
    __strong BSFPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentor.instrumentedClass);
    }
    typedef NSURLSessionDataTask *(*OriginalImp)(id, SEL, NSURLRequest *);
    NSURLSessionDataTask *dataTask = ((OriginalImp)currentIMP)(session, selector, request);
    if (dataTask.originalRequest) {
      BSFPRNetworkTrace *trace =
          [[BSFPRNetworkTrace alloc] initWithURLRequest:dataTask.originalRequest completionCallback:weakInstrument.onRequestCompleted];
      [trace start];
      [trace checkpointState:BSFPRNetworkTraceCheckpointStateInitiated];
      [BSFPRNetworkTrace addNetworkTrace:trace toObject:dataTask];
    }

    return dataTask;
  }];
}

/** Instruments -dataTaskWithRequest:completionHandler:.
 *
 *  @param instrument The BSFPRNSURLSessionInstrument instance.
 *  @param instrumentor The BSFPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentDataTaskWithRequestCompletionHandler(BSFPRNSURLSessionInstrument *instrument,
                                                    BSFPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(dataTaskWithRequest:completionHandler:);
  BSFPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak BSFPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request,
                                            BSFPRDataTaskCompletionHandler completionHandler) {
    __block NSURLSessionDataTask *task = nil;
    BSFPRDataTaskCompletionHandler wrappedCompletionHandler = nil;
    if (completionHandler) {
      wrappedCompletionHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
        BSFPRNetworkTrace *trace = [BSFPRNetworkTrace networkTraceFromObject:task];
        [trace didReceiveData:data];
        [trace didCompleteRequestWithResponse:response error:error];
        [BSFPRNetworkTrace removeNetworkTraceFromObject:task];
        completionHandler(data, response, error);
      };
    }
    typedef NSURLSessionDataTask *(*OriginalImp)(id, SEL, NSURLRequest *,
                                                 BSFPRDataTaskCompletionHandler);
    task = ((OriginalImp)currentIMP)(session, selector, request, wrappedCompletionHandler);

    // Add the network trace object only when the trace object is not added to the task object.
    if ([BSFPRNetworkTrace networkTraceFromObject:task] == nil) {
      BSFPRNetworkTrace *trace = [[BSFPRNetworkTrace alloc] initWithURLRequest:task.originalRequest completionCallback:weakInstrument.onRequestCompleted];
      [trace start];
      [trace checkpointState:BSFPRNetworkTraceCheckpointStateInitiated];
      [BSFPRNetworkTrace addNetworkTrace:trace toObject:task];
    }
    return task;
  }];
}

/** Instruments -uploadTaskWithRequest:fromFile:.
 *
 *  @param instrument The BSFPRNSURLSessionInstrument instance.
 *  @param instrumentor The BSFPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentUploadTaskWithRequestFromFile(BSFPRNSURLSessionInstrument *instrument,
                                             BSFPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(uploadTaskWithRequest:fromFile:);
  BSFPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak BSFPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request, NSURL *fileURL) {
    __strong BSFPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentor.instrumentedClass);
    }
    typedef NSURLSessionUploadTask *(*OriginalImp)(id, SEL, NSURLRequest *, NSURL *);
    NSURLSessionUploadTask *uploadTask =
        ((OriginalImp)currentIMP)(session, selector, request, fileURL);
    if (uploadTask.originalRequest) {
      BSFPRNetworkTrace *trace =
          [[BSFPRNetworkTrace alloc] initWithURLRequest:uploadTask.originalRequest completionCallback:weakInstrument.onRequestCompleted];
      [trace start];
      [trace checkpointState:BSFPRNetworkTraceCheckpointStateInitiated];
      [BSFPRNetworkTrace addNetworkTrace:trace toObject:uploadTask];
    }
    return uploadTask;
  }];
}

/** Instruments -uploadTaskWithRequest:fromFile:completionHandler:.
 *
 *  @param instrument The BSFPRNSURLSessionInstrument instance.
 *  @param instrumentor The BSFPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentUploadTaskWithRequestFromFileCompletionHandler(BSFPRNSURLSessionInstrument *instrument,
                                                              BSFPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(uploadTaskWithRequest:fromFile:completionHandler:);
  BSFPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak BSFPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request, NSURL *fileURL,
                                            BSFPRDataTaskCompletionHandler completionHandler) {
    BSFPRNetworkTrace *trace = [[BSFPRNetworkTrace alloc] initWithURLRequest:request completionCallback:weakInstrument.onRequestCompleted];
    [trace start];
    [trace checkpointState:BSFPRNetworkTraceCheckpointStateInitiated];
    [trace didUploadFileWithURL:fileURL];
    BSFPRDataTaskCompletionHandler wrappedCompletionHandler = nil;
    if (completionHandler) {
      wrappedCompletionHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
        [trace didReceiveData:data];
        [trace didCompleteRequestWithResponse:response error:error];
        completionHandler(data, response, error);
      };
    }
    typedef NSURLSessionUploadTask *(*OriginalImp)(id, SEL, NSURLRequest *, NSURL *,
                                                   BSFPRDataTaskCompletionHandler);
    return ((OriginalImp)currentIMP)(session, selector, request, fileURL, wrappedCompletionHandler);
  }];
}

/** Instruments -uploadTaskWithRequest:fromData:.
 *
 *  @param instrument The BSFPRNSURLSessionInstrument instance.
 *  @param instrumentor The BSFPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentUploadTaskWithRequestFromData(BSFPRNSURLSessionInstrument *instrument,
                                             BSFPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(uploadTaskWithRequest:fromData:);
  BSFPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak BSFPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request, NSData *bodyData) {
    __strong BSFPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentor.instrumentedClass);
    }
    typedef NSURLSessionUploadTask *(*OriginalImp)(id, SEL, NSURLRequest *, NSData *);
    NSURLSessionUploadTask *uploadTask =
        ((OriginalImp)currentIMP)(session, selector, request, bodyData);
    if (uploadTask.originalRequest) {
      BSFPRNetworkTrace *trace =
          [[BSFPRNetworkTrace alloc] initWithURLRequest:uploadTask.originalRequest completionCallback:weakInstrument.onRequestCompleted];
      [trace start];
      trace.requestSize = bodyData.length;
      [trace checkpointState:BSFPRNetworkTraceCheckpointStateInitiated];
      [BSFPRNetworkTrace addNetworkTrace:trace toObject:uploadTask];
    }
    return uploadTask;
  }];
}

/** Instruments -uploadTaskWithRequest:fromData:completionHandler:.
 *
 *  @param instrument The BSFPRNSURLSessionInstrument instance.
 *  @param instrumentor The BSFPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentUploadTaskWithRequestFromDataCompletionHandler(BSFPRNSURLSessionInstrument *instrument,
                                                              BSFPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(uploadTaskWithRequest:fromData:completionHandler:);
  BSFPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak BSFPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request, NSData *bodyData,
                                            BSFPRDataTaskCompletionHandler completionHandler) {
    BSFPRNetworkTrace *trace = [[BSFPRNetworkTrace alloc] initWithURLRequest:request completionCallback:weakInstrument.onRequestCompleted];
    [trace start];
    trace.requestSize = bodyData.length;
    [trace checkpointState:BSFPRNetworkTraceCheckpointStateInitiated];
    BSFPRDataTaskCompletionHandler wrappedCompletionHandler = nil;
    if (completionHandler) {
      wrappedCompletionHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
        [trace didReceiveData:data];
        [trace didCompleteRequestWithResponse:response error:error];
        completionHandler(data, response, error);
      };
    }
    typedef NSURLSessionUploadTask *(*OriginalImp)(id, SEL, NSURLRequest *, NSData *,
                                                   BSFPRDataTaskCompletionHandler);
    return ((OriginalImp)currentIMP)(session, selector, request, bodyData,
                                     wrappedCompletionHandler);
  }];
}

/** Instruments -uploadTaskWithStreamedRequest:.
 *
 *  @param instrument The BSFPRNSURLSessionInstrument instance.
 *  @param instrumentor The BSFPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentUploadTaskWithStreamedRequest(BSFPRNSURLSessionInstrument *instrument,
                                             BSFPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(uploadTaskWithStreamedRequest:);
  BSFPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak BSFPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request) {
    __strong BSFPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentor.instrumentedClass);
    }
    typedef NSURLSessionUploadTask *(*OriginalImp)(id, SEL, NSURLRequest *);
    NSURLSessionUploadTask *uploadTask = ((OriginalImp)currentIMP)(session, selector, request);
    if (uploadTask.originalRequest) {
      BSFPRNetworkTrace *trace =
          [[BSFPRNetworkTrace alloc] initWithURLRequest:uploadTask.originalRequest completionCallback:weakInstrument.onRequestCompleted];
      [trace start];
      [trace checkpointState:BSFPRNetworkTraceCheckpointStateInitiated];
      [BSFPRNetworkTrace addNetworkTrace:trace toObject:uploadTask];
    }
    return uploadTask;
  }];
}

/** Instruments -downloadTaskWithURL:.
 *
 *  @param instrument The BSFPRNSURLSessionInstrument instance.
 *  @param instrumentor The BSFPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentDownloadTaskWithURL(BSFPRNSURLSessionInstrument *instrument,
                                   BSFPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(downloadTaskWithURL:);
  BSFPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak BSFPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURL *url) {
    __strong BSFPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentor.instrumentedClass);
    }
    typedef NSURLSessionDownloadTask *(*OriginalImp)(id, SEL, NSURL *);
    NSURLSessionDownloadTask *downloadTask = ((OriginalImp)currentIMP)(session, selector, url);
    if (downloadTask.originalRequest) {
      BSFPRNetworkTrace *trace =
          [[BSFPRNetworkTrace alloc] initWithURLRequest:downloadTask.originalRequest completionCallback:weakInstrument.onRequestCompleted];
      [trace start];
      [trace checkpointState:BSFPRNetworkTraceCheckpointStateInitiated];
      [BSFPRNetworkTrace addNetworkTrace:trace toObject:downloadTask];
    }
    return downloadTask;
  }];
}

/** Instruments -downloadTaskWithURL:completionHandler:.
 *
 *  @param instrument The BSFPRNSURLSessionInstrument instance.
 *  @param instrumentor The BSFPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentDownloadTaskWithURLCompletionHandler(BSFPRNSURLSessionInstrument *instrument,
                                                    BSFPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(downloadTaskWithURL:completionHandler:);
  BSFPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak BSFPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURL *URL,
                                            BSFPRDownloadTaskCompletionHandler completionHandler) {
    __block NSURLSessionDownloadTask *downloadTask = nil;
    BSFPRDownloadTaskCompletionHandler wrappedCompletionHandler = nil;
    if (completionHandler) {
      wrappedCompletionHandler = ^(NSURL *location, NSURLResponse *response, NSError *error) {
        BSFPRNetworkTrace *trace = [BSFPRNetworkTrace networkTraceFromObject:downloadTask];
        [trace didReceiveFileURL:location];
        [trace didCompleteRequestWithResponse:response error:error];
        completionHandler(location, response, error);
      };
    }
    typedef NSURLSessionDownloadTask *(*OriginalImp)(id, SEL, NSURL *,
                                                     BSFPRDownloadTaskCompletionHandler);
    downloadTask = ((OriginalImp)currentIMP)(session, selector, URL, wrappedCompletionHandler);

    // Add the network trace object only when the trace object is not added to the task object.
    if ([BSFPRNetworkTrace networkTraceFromObject:downloadTask] == nil) {
      BSFPRNetworkTrace *trace =
          [[BSFPRNetworkTrace alloc] initWithURLRequest:downloadTask.originalRequest completionCallback:weakInstrument.onRequestCompleted];
      [trace start];
      [trace checkpointState:BSFPRNetworkTraceCheckpointStateInitiated];
      [BSFPRNetworkTrace addNetworkTrace:trace toObject:downloadTask];
    }
    return downloadTask;
  }];
}

/** Instruments -downloadTaskWithRequest:.
 *
 *  @param instrument The BSFPRNSURLSessionInstrument instance.
 *  @param instrumentor The BSFPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentDownloadTaskWithRequest(BSFPRNSURLSessionInstrument *instrument,
                                       BSFPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(downloadTaskWithRequest:);
  BSFPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak BSFPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request) {
    __strong BSFPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentor.instrumentedClass);
    }
    typedef NSURLSessionDownloadTask *(*OriginalImp)(id, SEL, NSURLRequest *);
    NSURLSessionDownloadTask *downloadTask = ((OriginalImp)currentIMP)(session, selector, request);
    if (downloadTask.originalRequest) {
      BSFPRNetworkTrace *trace =
          [[BSFPRNetworkTrace alloc] initWithURLRequest:downloadTask.originalRequest completionCallback:weakInstrument.onRequestCompleted];
      [trace start];
      [trace checkpointState:BSFPRNetworkTraceCheckpointStateInitiated];
      [BSFPRNetworkTrace addNetworkTrace:trace toObject:downloadTask];
    }
    return downloadTask;
  }];
}

/** Instruments -downloadTaskWithRequest:completionHandler:.
 *
 *  @param instrument The BSFPRNSURLSessionInstrument instance.
 *  @param instrumentor The BSFPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentDownloadTaskWithRequestCompletionHandler(BSFPRNSURLSessionInstrument *instrument,
                                                        BSFPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(downloadTaskWithRequest:completionHandler:);
  BSFPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak BSFPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request,
                                            BSFPRDownloadTaskCompletionHandler completionHandler) {
    __block NSURLSessionDownloadTask *downloadTask = nil;
    BSFPRDownloadTaskCompletionHandler wrappedCompletionHandler = nil;

    if (completionHandler) {
      wrappedCompletionHandler = ^(NSURL *location, NSURLResponse *response, NSError *error) {
        BSFPRNetworkTrace *trace = [BSFPRNetworkTrace networkTraceFromObject:downloadTask];
        [trace didReceiveFileURL:location];
        [trace didCompleteRequestWithResponse:response error:error];
        completionHandler(location, response, error);
      };
    }
    typedef NSURLSessionDownloadTask *(*OriginalImp)(id, SEL, NSURLRequest *,
                                                     BSFPRDownloadTaskCompletionHandler);
    downloadTask = ((OriginalImp)currentIMP)(session, selector, request, wrappedCompletionHandler);

    // Add the network trace object only when the trace object is not added to the task object.
    if ([BSFPRNetworkTrace networkTraceFromObject:downloadTask] == nil) {
      BSFPRNetworkTrace *trace =
          [[BSFPRNetworkTrace alloc] initWithURLRequest:downloadTask.originalRequest completionCallback:weakInstrument.onRequestCompleted];
      [trace start];
      [trace checkpointState:BSFPRNetworkTraceCheckpointStateInitiated];
      [BSFPRNetworkTrace addNetworkTrace:trace toObject:downloadTask];
    }
    return downloadTask;
  }];
}

#pragma mark - BSFPRNSURLSessionInstrument

@implementation BSFPRNSURLSessionInstrument

- (instancetype)initWithTraceCallback:(NetworkTraceCallback)onRequestCompleted {
    self = [super init];
    if (self) {
      self.onRequestCompleted = onRequestCompleted;
      _delegateInstrument = [[BSFPRNSURLSessionDelegateInstrument alloc] init];
      [_delegateInstrument registerInstrumentors];
    }
    return self;
}

- (instancetype)init {
  NSAssert(NO, @"Not a designated initializer.");
  return nil;
}

- (void)registerInstrumentors {
  [self registerInstrumentorForClass:[NSURLSession class]];
}

- (void)deregisterInstrumentors {
  [_delegateInstrument deregisterInstrumentors];
  [super deregisterInstrumentors];
}

- (void)registerInstrumentorForClass:(Class)aClass {
  dispatch_sync(GetInstrumentationQueue(), ^{
    NSAssert([aClass isSubclassOfClass:[NSURLSession class]],
              @"Class %@ is not a subclass of "
               "NSURLSession",
              aClass);
    // If this class has already been instrumented, just return.
    BSFPRClassInstrumentor *instrumentor = [[BSFPRClassInstrumentor alloc] initWithClass:aClass];
    if (![self registerClassInstrumentor:instrumentor]) {
      return;
    }

    InstrumentSharedSession(self, instrumentor);

    InstrumentSessionWithConfiguration(self, instrumentor);
    InstrumentSessionWithConfigurationDelegateDelegateQueue(self, instrumentor,
                                                            _delegateInstrument);

    InstrumentDataTaskWithURL(self, instrumentor);
    InstrumentDataTaskWithURLCompletionHandler(self, instrumentor);
    InstrumentDataTaskWithRequest(self, instrumentor);
    InstrumentDataTaskWithRequestCompletionHandler(self, instrumentor);

    InstrumentUploadTaskWithRequestFromFile(self, instrumentor);
    InstrumentUploadTaskWithRequestFromFileCompletionHandler(self, instrumentor);
    InstrumentUploadTaskWithRequestFromData(self, instrumentor);
    InstrumentUploadTaskWithRequestFromDataCompletionHandler(self, instrumentor);
    InstrumentUploadTaskWithStreamedRequest(self, instrumentor);

    InstrumentDownloadTaskWithURL(self, instrumentor);
    InstrumentDownloadTaskWithURLCompletionHandler(self, instrumentor);
    InstrumentDownloadTaskWithRequest(self, instrumentor);
    InstrumentDownloadTaskWithRequestCompletionHandler(self, instrumentor);

    [instrumentor swizzle];
  });
}

- (void)registerProxyObject:(id)proxy {
  [BSFPRProxyObjectHelper registerProxyObject:proxy
                              forSuperclass:[NSURLSession class]
                            varFoundHandler:^(id ivar) {
                              [self registerInstrumentorForClass:[ivar class]];
                            }];
}

@end
