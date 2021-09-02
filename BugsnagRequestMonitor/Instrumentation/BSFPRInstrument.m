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
#import "BSFPRInstrument_Private.h"

#import "BSFPRClassInstrumentor.h"
#import "BSFPRObjectInstrumentor.h"

@implementation BSFPRInstrument {
  NSMutableArray<BSFPRClassInstrumentor *> *_classInstrumentors;

  NSMutableSet<Class> *_instrumentedClasses;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _classInstrumentors = [[NSMutableArray<BSFPRClassInstrumentor *> alloc] init];
    _instrumentedClasses = [[NSMutableSet<Class> alloc] init];
  }
  return self;
}

- (NSMutableArray<BSFPRClassInstrumentor *> *)classInstrumentors {
  return _classInstrumentors;
}

- (NSMutableSet<Class> *)instrumentedClasses {
  return _instrumentedClasses;
}

- (void)registerInstrumentors {
  NSAssert(NO, @"registerInstrumentors should be implemented in a concrete subclass.");
}

- (BOOL)isObjectInstrumentable:(id)object {
  if ([object isKindOfClass:[NSOperation class]]) {
    return NO;
  }
  return YES;
}

- (BOOL)registerClassInstrumentor:(BSFPRClassInstrumentor *)instrumentor {
  @synchronized(self) {
    if ([_instrumentedClasses containsObject:instrumentor.instrumentedClass] ||
        [instrumentor.instrumentedClass instancesRespondToSelector:@selector(gul_class)]) {
      return NO;
    }
    [_instrumentedClasses addObject:instrumentor.instrumentedClass];
    [_classInstrumentors addObject:instrumentor];
    return YES;
  }
}

- (void)deregisterInstrumentors {
  @synchronized(self) {
    for (BSFPRClassInstrumentor *classInstrumentor in self.classInstrumentors) {
      [classInstrumentor unswizzle];
    }
    [_classInstrumentors removeAllObjects];
    [_instrumentedClasses removeAllObjects];
  }
}

@end
