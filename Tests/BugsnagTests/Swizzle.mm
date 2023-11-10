//
//  Swizzle.mm
//  Bugsnag
//
//  Created by Karl Stenerud on 21.04.23.
//  Copyright © 2023 Bugsnag. All rights reserved.
//

#import "Swizzle.h"
#import <objc/runtime.h>

namespace bugsnag {

IMP ObjCSwizzle::setClassMethodImplementation(Class _Nonnull clazz, SEL selector, id _Nonnull implementationBlock) noexcept {
    Method method = class_getClassMethod(clazz, selector);
    if (method) {
        return method_setImplementation(method, imp_implementationWithBlock(implementationBlock));
    } else {
        NSLog(@"Could not set IMP for selector %s on class %@", sel_getName(selector), clazz);
        return nil;
    }
}

IMP ObjCSwizzle::replaceInstanceMethodOverride(Class clazz, SEL selector, id block) noexcept {
    Method method = nullptr;

    // Not using class_getInstanceMethod because we don't want to modify the
    // superclass's implementation.
    auto methodCount = 0U;
    Method *methods = class_copyMethodList(clazz, &methodCount);
    if (methods) {
        for (auto i = 0U; i < methodCount; i++) {
            if (sel_isEqual(method_getName(methods[i]), selector)) {
                method = methods[i];
                break;
            }
        }
        free(methods);
    }

    if (!method) {
        // This is not considered an error.
        return nil;
    }

    return method_setImplementation(method, imp_implementationWithBlock(block));
}

NSArray<Class> *ObjCSwizzle::getClassesWithSelector(Class cls, SEL selector) noexcept {
    NSMutableArray<Class> *result = [NSMutableArray new];
    for (; class_getInstanceMethod(cls, selector); cls = [cls superclass]) {
        if (!cls) {
            break;
        }
        Class superCls = [cls superclass];
        Method classMethod = class_getInstanceMethod(cls, selector);
        Method superMethod = class_getInstanceMethod(superCls, selector);
        IMP classIMP = classMethod ? method_getImplementation(classMethod) : nil;
        IMP superIMP = superMethod ? method_getImplementation(superMethod) : nil;
        if (classIMP != superIMP) {
            [result addObject:(Class _Nonnull)cls];
        }
    }
    return result;
};


}
