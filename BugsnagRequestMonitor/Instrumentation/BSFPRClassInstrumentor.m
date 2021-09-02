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

#import "BSFPRClassInstrumentor.h"
#import "BSFPRClassInstrumentor_Private.h"

#import "BSFPRSelectorInstrumentor.h"

/** Use ivars instead of properties to reduce message sending overhead. */
@interface BSFPRClassInstrumentor () {
  // The selector instrumentors associated with this class.
  NSMutableSet<BSFPRSelectorInstrumentor *> *_selectorInstrumentors;
}

@end

@implementation BSFPRClassInstrumentor

#pragma mark - Public methods

- (instancetype)init {
  NSAssert(NO, @"%@: please use the designated initializer.", NSStringFromClass([self class]));
  return nil;
}

- (instancetype)initWithClass:(Class)aClass {
  self = [super init];
  if (self) {
    NSAssert(aClass, @"You must supply a class in order to instrument its methods");
    _instrumentedClass = aClass;
    _selectorInstrumentors = [[NSMutableSet<BSFPRSelectorInstrumentor *> alloc] init];
  }
  return self;
}

- (nullable BSFPRSelectorInstrumentor *)instrumentorForClassSelector:(SEL)selector {
  return [self buildAndAddSelectorInstrumentorForSelector:selector isClassSelector:YES];
}

- (nullable BSFPRSelectorInstrumentor *)instrumentorForInstanceSelector:(SEL)selector {
  return [self buildAndAddSelectorInstrumentorForSelector:selector isClassSelector:NO];
}

- (void)swizzle {
  for (BSFPRSelectorInstrumentor *selectorInstrumentor in _selectorInstrumentors) {
    [selectorInstrumentor swizzle];
  }
}

- (BOOL)unswizzle {
  for (BSFPRSelectorInstrumentor *selectorInstrumentor in _selectorInstrumentors) {
    [selectorInstrumentor unswizzle];
  }
  [_selectorInstrumentors removeAllObjects];
  return _selectorInstrumentors.count == 0;
}

#pragma mark - Private methods

/** Creates and adds a selector instrumentor to this class instrumentor.
 *
 *  @param selector The selector to build and add to this class instrumentor;
 *  @param isClassSelector If YES, then the selector is a class selector.
 *  @return An BSFPRSelectorInstrumentor if the class/selector combination exists, nil otherwise.
 */
- (nullable BSFPRSelectorInstrumentor *)buildAndAddSelectorInstrumentorForSelector:(SEL)selector
                                                                 isClassSelector:
                                                                     (BOOL)isClassSelector {
  BSFPRSelectorInstrumentor *selectorInstrumentor =
      [[BSFPRSelectorInstrumentor alloc] initWithSelector:selector
                                                  class:_instrumentedClass
                                        isClassSelector:isClassSelector];
  if (selectorInstrumentor) {
    [self addSelectorInstrumentor:selectorInstrumentor];
  }
  return selectorInstrumentor;
}

/** Adds a selector instrumentors to an existing running list of instrumented selectors.
 *
 *  @param selectorInstrumentor A non-nil selector instrumentor, whose SEL objects will be swizzled.
 */
- (void)addSelectorInstrumentor:(nonnull BSFPRSelectorInstrumentor *)selectorInstrumentor {
  if ([_selectorInstrumentors containsObject:selectorInstrumentor]) {
    NSAssert(NO, @"You cannot instrument the same selector (%@) twice",
              NSStringFromSelector(selectorInstrumentor.selector));
  }
  [_selectorInstrumentors addObject:selectorInstrumentor];
}

@end
