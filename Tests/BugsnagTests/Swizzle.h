//
//  Swizzle.h
//  BugsnagPerformance-iOS
//
//  Created by Karl Stenerud on 21.04.23.
//  Copyright © 2023 Bugsnag. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

namespace bugsnag {

class ObjCSwizzle {
public:
    /**
     * Replace a class's current method implementation with a new implementation block, returning the replaced one.
     * Returns nil if the method was not found (in the class or any superclass).
     */
    static IMP _Nullable setClassMethodImplementation(Class _Nonnull clazz, SEL _Nonnull selector, id _Nonnull implementationBlock) noexcept;

    /**
     * Replace a class's override of a method (i.e. only if this class overrides the method). No superclass implementation is replaced.
     * Returns nil if no method was replaced (either method not found, or this class doesn't overrde the method).
     */
    static IMP _Nullable replaceInstanceMethodOverride(Class _Nonnull cls, SEL _Nonnull name, id _Nonnull block) noexcept;

    /**
     * Get any classes or superclasses that implement the specified selector.
     */
    static NSArray<Class> * _Nonnull getClassesWithSelector(Class _Nullable cls, SEL _Nonnull selector) noexcept;

};

}
