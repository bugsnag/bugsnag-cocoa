//
//  BSGDefines.h
//  Bugsnag
//
//  Created by Karl Stenerud on 20.04.22.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#ifndef BSGDefines_h
#define BSGDefines_h

#include <TargetConditionals.h>

// Primary capabilities (depends on OS)
#define BSG_HAVE_APPKIT                       (TARGET_OS_OSX                                                    )
#define BSG_HAVE_IDENTIFIER_FOR_VENDOR        (                 TARGET_OS_IOS || TARGET_OS_TV                   )
#define BSG_HAVE_MACH_THREADS                 (TARGET_OS_OSX || TARGET_OS_IOS || TARGET_OS_TV                   )
#define BSG_HAVE_OOM_DETECTION                (                 TARGET_OS_IOS || TARGET_OS_TV                   )
#define BSG_HAVE_REACHABILITY                 (TARGET_OS_OSX || TARGET_OS_IOS || TARGET_OS_TV                   )
#define BSG_HAVE_REACHABILITY_WWAN            (                 TARGET_OS_IOS || TARGET_OS_TV                   )
#define BSG_HAVE_SIGNAL                       (TARGET_OS_OSX || TARGET_OS_IOS || TARGET_OS_TV                   )
#define BSG_HAVE_SIGNALSTACK                  (TARGET_OS_OSX || TARGET_OS_IOS                                   )
#define BSG_HAVE_SYSCALL                      (TARGET_OS_OSX || TARGET_OS_IOS || TARGET_OS_TV                   )
#define BSG_HAVE_TABLE_VIEW                   (TARGET_OS_OSX || TARGET_OS_IOS || TARGET_OS_TV                   )
#define BSG_HAVE_TEXT_CONTROL                 (TARGET_OS_OSX || TARGET_OS_IOS                                   )
#define BSG_HAVE_UIKIT                        (                 TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH)
#define BSG_HAVE_WATCHKIT                     (                                                  TARGET_OS_WATCH)

// Derived capabilities (depends on capabilities)
#define BSG_HAVE_APP_HANG_DETECTION           (BSG_HAVE_MACH_THREADS)

#endif /* BSGDefines_h */
