//
//  BSGRunContext.m
//  Bugsnag
//
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#import "BSGRunContext.h"

#import "BSG_KSLogger.h"
#import "BSG_KSMach.h"
#import "BSG_KSSystemInfo.h"

#import <Foundation/Foundation.h>
#import <sys/mman.h>
#import <sys/stat.h>

#if TARGET_OS_IOS
#import "BSGUIKit.h"
#endif

#if TARGET_OS_OSX
#import "BSGAppKit.h"
#endif


#pragma mark Forward declarations

static bool BSGRunContextGetIsForeground(void);


#pragma mark - Initial setup

/// Populates `bsg_runContext`
static void BSGRunContextInitCurrent() {
    bsg_runContext->isDebuggerAttached = bsg_ksmachisBeingTraced();
    
    bsg_runContext->isLaunching = YES;
    
    // On iOS/tvOS, the app may have launched in the background due to a fetch
    // event or notification (or prewarming on iOS 15+)
    bsg_runContext->isForeground = BSGRunContextGetIsForeground();
    
    if (@available(iOS 11.0, tvOS 11.0, *)) {
        bsg_runContext->thermalState = NSProcessInfo.processInfo.thermalState;
    }
    
    // Set `structVersion` last so that BSGRunContextLoadLast() will reject data
    // that is not fully initialised.
    bsg_runContext->structVersion = BSGRUNCONTEXT_VERSION;
}

static bool BSGRunContextGetIsForeground() {
#if TARGET_OS_IOS
    //
    // Work around unreliability of -[UIApplication applicationState] which
    // always returns UIApplicationStateBackground during the launch of UIScene
    // based apps (until the first scene has been created.)
    //
    task_category_policy_data_t policy;
    mach_msg_type_number_t count = TASK_CATEGORY_POLICY_COUNT;
    boolean_t get_default = FALSE;
    // task_policy_get() is prohibited on tvOS and watchOS
    kern_return_t kr = task_policy_get(mach_task_self(), TASK_CATEGORY_POLICY,
                                       (void *)&policy, &count, &get_default);
    if (kr == KERN_SUCCESS) {
        // TASK_FOREGROUND_APPLICATION  -> normal foreground launch
        // TASK_NONUI_APPLICATION       -> background launch
        // TASK_DARWINBG_APPLICATION    -> iOS 15 prewarming launch
        // TASK_UNSPECIFIED             -> iOS 9 Simulator
        if (!get_default && policy.role == TASK_FOREGROUND_APPLICATION) {
            return true;
        }
    } else {
        bsg_log_err(@"task_policy_get failed: %s", mach_error_string(kr));
    }
#endif

#if TARGET_OS_IOS || TARGET_OS_TV
    // +sharedApplication is unavailable to app extensions
    if ([BSG_KSSystemInfo isRunningInAppExtension]) {
        // Returning "foreground" seems wrong but matches what
        // +[BSG_KSSystemInfo currentAppState] used to return
        return true;
    }

    // Using performSelector: to avoid a compile-time check that
    // +sharedApplication is not called from app extensions
    UIApplication *application = [UIAPPLICATION performSelector:
                                  @selector(sharedApplication)];

    // There will be no UIApplication if UIApplicationMain() has not yet been
    // called - e.g. from a SwiftUI app's init() function or UIKit app's main()
    if (!application) {
        return false;
    }

    __block UIApplicationState applicationState;
    if ([[NSThread currentThread] isMainThread]) {
        applicationState = [application applicationState];
    } else {
        // -[UIApplication applicationState] is a main thread-only API
        dispatch_sync(dispatch_get_main_queue(), ^{
            applicationState = [application applicationState];
        });
    }

    return applicationState != UIApplicationStateBackground;
#else
    return [[NSAPPLICATION sharedApplication] isActive];
#endif
}


#pragma mark - Observation

#if TARGET_OS_IOS || TARGET_OS_OSX

static void BSGRunContextNoteAppBackground() {
    bsg_runContext->isForeground = NO;
}

static void BSGRunContextNoteAppForeground() {
    bsg_runContext->isForeground = YES;
}

static void BSGRunContextNoteAppWillTerminate() {
    bsg_runContext->isTerminating = YES;
}

#endif

static void
BSGRunContextNoteThermalStateDidChange(__unused CFNotificationCenterRef center,
                                       __unused void *observer,
                                       __unused CFNotificationName name,
                                       const void *object,
                                       __unused CFDictionaryRef userInfo) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
    bsg_runContext->thermalState = ((__bridge NSProcessInfo *)object).thermalState;
#pragma clang diagnostic pop
}

static void BSGRunContextAddObservers() {
    CFNotificationCenterRef center = CFNotificationCenterGetLocalCenter();
    
#define OBSERVE(name, function) CFNotificationCenterAddObserver(\
center, NULL, function, (__bridge CFStringRef)name, NULL, \
CFNotificationSuspensionBehaviorDeliverImmediately)
    
#if TARGET_OS_IOS
    OBSERVE(UIApplicationDidBecomeActiveNotification, BSGRunContextNoteAppForeground);
    OBSERVE(UIApplicationDidEnterBackgroundNotification, BSGRunContextNoteAppBackground);
    OBSERVE(UIApplicationWillEnterForegroundNotification, BSGRunContextNoteAppForeground);
    OBSERVE(UIApplicationWillTerminateNotification, BSGRunContextNoteAppWillTerminate);
#endif
    
#if TARGET_OS_OSX
    OBSERVE(NSApplicationDidBecomeActiveNotification, BSGRunContextNoteAppForeground);
    OBSERVE(NSApplicationDidResignActiveNotification, BSGRunContextNoteAppBackground);
    OBSERVE(NSApplicationWillTerminateNotification, BSGRunContextNoteAppWillTerminate);
#endif
    
    if (@available(iOS 11.0, tvOS 11.0, *)) {
        OBSERVE(NSProcessInfoThermalStateDidChangeNotification, BSGRunContextNoteThermalStateDidChange);
    }
}


#pragma mark - File handling & memory mapping

#define SIZEOF_STRUCT sizeof(struct BSGRunContext)

struct BSGRunContext *bsg_runContext;

const struct BSGRunContext *bsg_lastRunContext;

/// Loads the contents of the state file into memory and sets the
/// `bsg_lastRunContext` pointer if the contents are valid.
static void BSGRunContextLoadLast(int fd) {
    struct stat sb;
    // Only expose previous state if size matches...
    if (fstat(fd, &sb) == 0 && sb.st_size == SIZEOF_STRUCT) {
        static struct BSGRunContext context;
        if (read(fd, &context, SIZEOF_STRUCT) == SIZEOF_STRUCT &&
            // ...and so does the structVersion
            context.structVersion == BSGRUNCONTEXT_VERSION) {
            bsg_lastRunContext = &context;
        }
    }
}

/// Truncates or extends the file to the size of struct BSGRunContext,
/// maps it into memory, and sets the `bsg_runContext` pointer.
static void BSGRunContextResizeAndMapFile(int fd) {
    static struct BSGRunContext fallback;
    
    // Note: ftruncate fills the file with zeros when extending.
    if (ftruncate(fd, SIZEOF_STRUCT) != 0) {
        bsg_log_warn(@"ftruncate failed: %d", errno);
        goto fail;
    }
    
    const int prot = PROT_READ | PROT_WRITE;
    const int flags = MAP_FILE | MAP_SHARED;
    void *ptr = mmap(0, SIZEOF_STRUCT, prot, flags, fd, 0);
    if (ptr == MAP_FAILED) {
        bsg_log_warn(@"mmap failed: %d", errno);
        goto fail;
    }
    
    memset(ptr, 0, SIZEOF_STRUCT);
    bsg_runContext = ptr;
    return;
    
fail:
    bsg_runContext = &fallback;
}

void BSGRunContextInit(const char *path) {
    int fd = open(path, O_RDWR | O_CREAT, 0600);
    if (fd < 0) {
        bsg_log_warn(@"Could not open %s", path);
    }
    BSGRunContextLoadLast(fd);
    BSGRunContextResizeAndMapFile(fd);
    BSGRunContextInitCurrent();
    BSGRunContextAddObservers();
    if (fd > 0) {
        close(fd);
    }
}