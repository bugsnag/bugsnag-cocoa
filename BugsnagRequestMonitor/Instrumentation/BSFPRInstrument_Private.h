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

NS_ASSUME_NONNULL_BEGIN

@interface BSFPRInstrument ()

/** Registers an instrumentor for a class. Should be called by subclasses.
 *
 *  @param instrumentor The instrumentor to register.
 *  @return NO if the class has already been instrumented, YES otherwise.
 */
- (BOOL)registerClassInstrumentor:(BSFPRClassInstrumentor *)instrumentor;

@end

NS_ASSUME_NONNULL_END
