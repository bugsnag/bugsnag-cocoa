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

#import "BSFPRInstrument.h"
#import "BSFPRNetworkTrace.h"

NS_ASSUME_NONNULL_BEGIN


/** This class instruments the NSURLSession class cluster. As new classes are discovered, they will
 *  be swizzled on a shared queue. Completion blocks and delegate methods are also wrapped.
 */
@interface BSFPRNSURLSessionInstrument : BSFPRInstrument

- (instancetype)initWithTraceCallback:(NetworkTraceCallback _Nonnull)onRequestCompleted NS_DESIGNATED_INITIALIZER;

- (nullable instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
