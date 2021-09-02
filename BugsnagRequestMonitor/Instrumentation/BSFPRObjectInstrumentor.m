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

#import "BSFPRObjectInstrumentor.h"

#import "BSFPRInstrument_Private.h"
#import "BSFPRSelectorInstrumentor.h"

#import "BSGULObjectSwizzler.h"

@interface BSFPRObjectInstrumentor () {
  // The object swizzler instance this instrumentor will use.
  BSGULObjectSwizzler *_objectSwizzler;
}

@end

@implementation BSFPRObjectInstrumentor

- (instancetype)init {
  NSAssert(NO, @"%@: Please use the designated initializer.", NSStringFromClass([self class]));
  return nil;
}

- (instancetype)initWithObject:(id)object {
  self = [super init];
  if (self) {
    _objectSwizzler = [[BSGULObjectSwizzler alloc] initWithObject:object];
    _instrumentedObject = object;
  }
  return self;
}

- (void)copySelector:(SEL)selector fromClass:(Class)aClass isClassSelector:(BOOL)isClassSelector {
  __strong id instrumentedObject = _instrumentedObject;
  if (instrumentedObject && ![instrumentedObject respondsToSelector:selector]) {
    _hasModifications = YES;
    [_objectSwizzler copySelector:selector fromClass:aClass isClassSelector:isClassSelector];
  }
}

- (void)swizzle {
  if (_hasModifications) {
    [_objectSwizzler swizzle];
  }
}

@end
