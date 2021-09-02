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

#import "BSFPRSelectorInstrumentor.h"

#import "BSGULSwizzler.h"
#ifdef UNSWIZZLE_AVAILABLE
#import "BSGULSwizzler+Unswizzle.h"
#endif

@implementation BSFPRSelectorInstrumentor {
  // The class this instrumentor operates on.
  Class _class;

  // The selector this instrumentor operates on.
  SEL _selector;

  // YES indicates the selector swizzled is a class selector, as opposed to an instance selector.
  BOOL _isClassSelector;

  // YES indicates that this selector instrumentor has been swizzled.
  BOOL _swizzled;

  // A block to replace the original implementation. Can't be used with before/after blocks.
  id _replacingBlock;
}

- (instancetype)init {
  NSAssert(NO, @"%@: Please use the designated initializer", NSStringFromClass([self class]));
  return nil;
}

- (instancetype)initWithSelector:(SEL)selector
                           class:(Class)aClass
                 isClassSelector:(BOOL)isClassSelector {
  if (![BSGULSwizzler selector:selector existsInClass:aClass isClassSelector:isClassSelector]) {
    return nil;
  }
  self = [super init];
  if (self) {
    _selector = selector;
    _class = aClass;
    _isClassSelector = isClassSelector;
    NSAssert(_selector, @"A selector to swizzle must be provided.");
    NSAssert(_class, @"You can't swizzle a class that doesn't exist");
  }
  return self;
}

- (void)setReplacingBlock:(id)block {
  _replacingBlock = [block copy];
}

- (void)swizzle {
  _swizzled = YES;
  NSAssert(_replacingBlock, @"A replacingBlock needs to be set.");

  [BSGULSwizzler swizzleClass:_class
                   selector:_selector
            isClassSelector:_isClassSelector
                  withBlock:_replacingBlock];
}

- (void)unswizzle {
  _swizzled = NO;
#ifdef UNSWIZZLE_AVAILABLE
  [BSGULSwizzler unswizzleClass:_class selector:_selector isClassSelector:_isClassSelector];
#else
  NSAssert(NO, @"Unswizzling is disabled.");
#endif
}

- (IMP)currentIMP {
  return [BSGULSwizzler currentImplementationForClass:_class
                                           selector:_selector
                                    isClassSelector:_isClassSelector];
}

- (BOOL)isEqual:(id)object {
  if ([object isKindOfClass:[BSFPRSelectorInstrumentor class]]) {
    BSFPRSelectorInstrumentor *otherObject = object;
    return otherObject->_class == _class && otherObject->_selector == _selector &&
           otherObject->_isClassSelector == _isClassSelector && otherObject->_swizzled == _swizzled;
  }
  return NO;
}

- (NSUInteger)hash {
  return [[NSString stringWithFormat:@"%@%@%d%d", NSStringFromClass(_class),
                                     NSStringFromSelector(_selector), _isClassSelector, _swizzled]
      hash];
}

@end
