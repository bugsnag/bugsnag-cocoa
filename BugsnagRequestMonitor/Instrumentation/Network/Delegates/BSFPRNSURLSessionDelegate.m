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

#import "BSFPRNSURLSessionDelegate.h"

#import "BSFPRConsoleLogger.h"
#import "BSFPRNetworkTrace.h"

@implementation BSFPRNSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
  @try {
    BSFPRNetworkTrace *trace = [BSFPRNetworkTrace networkTraceFromObject:task];
    [trace didCompleteRequestWithResponse:task.response error:error];
    [BSFPRNetworkTrace removeNetworkTraceFromObject:task];
  } @catch (NSException *exception) {
    BSFPRLogInfo(kBSFPRNetworkTraceNotTrackable, @"Unable to track network request.");
  }
}

- (void)URLSession:(NSURLSession *)session
                        task:(NSURLSessionTask *)task
             didSendBodyData:(int64_t)bytesSent
              totalBytesSent:(int64_t)totalBytesSent
    totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
  @try {
    BSFPRNetworkTrace *trace = [BSFPRNetworkTrace networkTraceFromObject:task];
    trace.requestSize = totalBytesSent;
    if (totalBytesSent >= totalBytesExpectedToSend) {
      if ([task.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
        [trace didCompleteRequestWithResponse:response error:task.error];
        [BSFPRNetworkTrace removeNetworkTraceFromObject:task];
      }
    }
  } @catch (NSException *exception) {
    BSFPRLogInfo(kBSFPRNetworkTraceNotTrackable, @"Unable to track network request.");
  }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
  BSFPRNetworkTrace *trace = [BSFPRNetworkTrace networkTraceFromObject:dataTask];
  [trace didReceiveData:data];
  [trace checkpointState:BSFPRNetworkTraceCheckpointStateResponseReceived];
}

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
    didFinishDownloadingToURL:(NSURL *)location {
  BSFPRNetworkTrace *trace = [BSFPRNetworkTrace networkTraceFromObject:downloadTask];
  [trace didReceiveFileURL:location];
  [trace didCompleteRequestWithResponse:downloadTask.response error:downloadTask.error];
  [BSFPRNetworkTrace removeNetworkTraceFromObject:downloadTask];
}

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
                 didWriteData:(int64_t)bytesWritten
            totalBytesWritten:(int64_t)totalBytesWritten
    totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
  BSFPRNetworkTrace *trace = [BSFPRNetworkTrace networkTraceFromObject:downloadTask];
  [trace checkpointState:BSFPRNetworkTraceCheckpointStateResponseReceived];
  trace.responseSize = totalBytesWritten;
  if (totalBytesWritten >= totalBytesExpectedToWrite) {
    if ([downloadTask.response isKindOfClass:[NSHTTPURLResponse class]]) {
      NSHTTPURLResponse *response = (NSHTTPURLResponse *)downloadTask.response;
      [trace didCompleteRequestWithResponse:response error:downloadTask.error];
      [BSFPRNetworkTrace removeNetworkTraceFromObject:downloadTask];
    }
  }
}

@end
