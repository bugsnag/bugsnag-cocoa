//
//  BSGDefines.h
//  Bugsnag
//
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#ifndef BSGDefines_h
#define BSGDefines_h

#include <TargetConditionals.h>

#ifndef TARGET_OS_VISION
    // For older Xcode that doesn't have VisionOS support...
    #define TARGET_OS_VISION 0
#endif

// Capabilities dependent upon system defines and files
#define BSG_HAVE_BATTERY                      (                 TARGET_OS_IOS                 || TARGET_OS_WATCH || TARGET_OS_VISION)
#define BSG_HAVE_MACH_EXCEPTIONS              (TARGET_OS_OSX || TARGET_OS_IOS                                   )
#define BSG_HAVE_MACH_THREADS                 (TARGET_OS_OSX || TARGET_OS_IOS || TARGET_OS_TV                    || TARGET_OS_VISION)
#define BSG_HAVE_OOM_DETECTION                (                 TARGET_OS_IOS || TARGET_OS_TV                   ) && !TARGET_OS_SIMULATOR && !TARGET_OS_MACCATALYST
#define BSG_HAVE_REACHABILITY                 (TARGET_OS_OSX || TARGET_OS_IOS || TARGET_OS_TV                    || TARGET_OS_VISION)
#define BSG_HAVE_REACHABILITY_WWAN            (                 TARGET_OS_IOS || TARGET_OS_TV                   )
#define BSG_HAVE_SIGNAL                       (TARGET_OS_OSX || TARGET_OS_IOS || TARGET_OS_TV                    || TARGET_OS_VISION)
#define BSG_HAVE_SIGALTSTACK                  (TARGET_OS_OSX || TARGET_OS_IOS                                   )
#define BSG_HAVE_SYSCALL                      (TARGET_OS_IOS || TARGET_OS_TV                   )
#define BSG_HAVE_UIDEVICE                     __has_include(<UIKit/UIDevice.h>)
#define BSG_HAVE_WINDOW                       (TARGET_OS_OSX || TARGET_OS_IOS || TARGET_OS_TV                    || TARGET_OS_VISION)

// Capabilities dependent upon previously defined capabilities
#define BSG_HAVE_APP_HANG_DETECTION           (BSG_HAVE_MACH_THREADS)

#ifdef __OBJC__

// Constructs a key path, with a compile-time check in DEBUG builds.
// https://pspdfkit.com/blog/2017/even-swiftier-objective-c/#checked-keypaths
#if defined(DEBUG) && DEBUG
#define BSG_KEYPATH(object, property) ((void)(NO && ((void)object.property, NO)), @ #property)
#else
#define BSG_KEYPATH(object, property) @ #property
#endif


#endif /* __OBJC__ */

// Reference: http://iphonedevwiki.net/index.php/CoreFoundation.framework
#define kCFCoreFoundationVersionNumber_iOS_12_0 1556.00

#endif /* BSGDefines_h */
