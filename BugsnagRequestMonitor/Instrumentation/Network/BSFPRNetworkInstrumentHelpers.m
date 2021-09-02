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

#import "BSFPRNetworkInstrumentHelpers.h"

#import "BSFPRClassInstrumentor.h"
#import "BSFPRSelectorInstrumentor.h"

FOUNDATION_EXTERN_INLINE
void ThrowExceptionBecauseSelectorNotFoundOnClass(SEL selector, Class aClass) {
  [NSException raise:NSInternalInconsistencyException
              format:@"Selector %@ not found on class %@", NSStringFromSelector(selector),
                     NSStringFromClass(aClass)];
}

FOUNDATION_EXTERN_INLINE
void ThrowExceptionBecauseSelectorInstrumentorHasBeenDeallocated(SEL selector, Class aClass) {
  [NSException raise:NSInternalInconsistencyException
              format:@"Selector instrumentor has been deallocated: %@|%@",
                     NSStringFromSelector(selector), NSStringFromClass(aClass)];
}

FOUNDATION_EXTERN_INLINE
void ThrowExceptionBecauseInstrumentHasBeenDeallocated(SEL selector, Class aClass) {
  [NSException raise:NSInternalInconsistencyException
              format:@"The instrument has been deallocated: %@|%@", NSStringFromSelector(selector),
                     NSStringFromClass(aClass)];
}

/** Returns an BSFPRSelectorInstrumentor given a SEL and BSFPRClassInstrumentor. This is a convenience
 *  function.
 *
 *  @param selector The selector to instrument.
 *  @param instrumentor The class instrumentor to generate the selector instrumentor from.
 *  @param isClassSelector YES if the selector is a class selector, NO otherwise.
 *  @return An BSFPRSelectorInstrumentor instance if the selector is on the class.
 *  @throws An exception if the selector is NOT found on the class.
 */
FOUNDATION_EXTERN_INLINE
BSFPRSelectorInstrumentor *SelectorInstrumentor(SEL selector,
                                              BSFPRClassInstrumentor *instrumentor,
                                              BOOL isClassSelector) {
  BSFPRSelectorInstrumentor *selectorInstrumentor =
      isClassSelector ? [instrumentor instrumentorForClassSelector:selector]
                      : [instrumentor instrumentorForInstanceSelector:selector];
  if (!selectorInstrumentor) {
    ThrowExceptionBecauseSelectorNotFoundOnClass(selector, instrumentor.instrumentedClass);
  }
  return selectorInstrumentor;
}
