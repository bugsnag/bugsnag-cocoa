//
//  BSG_KSCrashState.c
//
//  Created by Karl Stenerud on 2012-02-05.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "BSG_KSCrashState.h"

#import "BSG_KSFile.h"
#import "BSG_KSJSONCodec.h"
#import "BSG_KSJSONCodecObjC.h"
#import "BSG_KSLogger.h"
#import "BSG_KSMach.h"
#import "BSG_KSSystemInfo.h"

#if TARGET_OS_IOS || TARGET_OS_TV
#import "BSGUIKit.h"
#endif

#if TARGET_OS_IOS
#import <mach/mach_init.h>
#import <mach/task.h>
#import <mach/task_policy.h>
#endif

#import <errno.h>
#import <fcntl.h>
#import <mach/mach_time.h>
#import <stdlib.h>
#import <unistd.h>

static bool bsg_kscrashstate_i_isInForeground(void);

// ============================================================================
#pragma mark - Constants -
// ============================================================================

#define BSG_kFormatVersion 1

#define BSG_kKeyFormatVersion "version"
#define BSG_kKeyCrashedLastLaunch "crashedLastLaunch"
#define BSG_kKeyActiveDurationSinceLastCrash "foregroundDurationSinceLastCrash"
#define BSG_kKeyBackgroundDurationSinceLastCrash                               \
    "backgroundDurationSinceLastCrash"
#define BSG_kKeyLaunchesSinceLastCrash "launchesSinceLastCrash"
#define BSG_kKeySessionsSinceLastCrash "sessionsSinceLastCrash"

// ============================================================================
#pragma mark - Globals -
// ============================================================================

/** Location where stat file is stored. */
static const char *bsg_g_stateFilePath;

/** Current state. */
static BSG_KSCrash_State *bsg_g_state;

// Avoiding static functions due to linker issues.

// ============================================================================
#pragma mark - JSON Encoding -
// ============================================================================

int bsg_kscrashstate_i_onBooleanElement(const char *const name,
                                        const bool value,
                                        void *const userData) {
    BSG_KSCrash_State *state = userData;

    if (strcmp(name, BSG_kKeyCrashedLastLaunch) == 0) {
        state->crashedLastLaunch = value;
    }

    return BSG_KSJSON_OK;
}

int bsg_kscrashstate_i_onFloatingPointElement(const char *const name,
                                              const double value,
                                              void *const userData) {
    BSG_KSCrash_State *state = userData;

    if (strcmp(name, BSG_kKeyActiveDurationSinceLastCrash) == 0) {
        state->foregroundDurationSinceLastCrash = value;
    }
    if (strcmp(name, BSG_kKeyBackgroundDurationSinceLastCrash) == 0) {
        state->backgroundDurationSinceLastCrash = value;
    }

    return BSG_KSJSON_OK;
}

int bsg_kscrashstate_i_onIntegerElement(const char *const name,
                                        const long long value,
                                        void *const userData) {
    BSG_KSCrash_State *state = userData;

    if (strcmp(name, BSG_kKeyFormatVersion) == 0) {
        if (value != BSG_kFormatVersion) {
            bsg_log_err(@"Expected version 1 but got %lld", value);
            return BSG_KSJSON_ERROR_INVALID_DATA;
        }
    } else if (strcmp(name, BSG_kKeyLaunchesSinceLastCrash) == 0) {
        state->launchesSinceLastCrash = (int)value;
    } else if (strcmp(name, BSG_kKeySessionsSinceLastCrash) == 0) {
        state->sessionsSinceLastCrash = (int)value;
    }

    // FP value might have been written as a whole number.
    return bsg_kscrashstate_i_onFloatingPointElement(name, (double)value, userData);
}

int bsg_kscrashstate_i_onNullElement(__unused const char *const name,
                                     __unused void *const userData) {
    return BSG_KSJSON_OK;
}

int bsg_kscrashstate_i_onStringElement(__unused const char *const name,
                                       __unused const char *const value,
                                       __unused void *const userData) {
    return BSG_KSJSON_OK;
}

int bsg_kscrashstate_i_onBeginObject(__unused const char *const name,
                                     __unused void *const userData) {
    return BSG_KSJSON_OK;
}

int bsg_kscrashstate_i_onBeginArray(__unused const char *const name,
                                    __unused void *const userData) {
    return BSG_KSJSON_OK;
}

int bsg_kscrashstate_i_onEndContainer(__unused void *const userData) {
    return BSG_KSJSON_OK;
}

int bsg_kscrashstate_i_onEndData(__unused void *const userData) {
    return BSG_KSJSON_OK;
}

/** Callback for adding JSON data.
 */
int bsg_kscrashstate_i_addJSONData(const char *const data, const size_t length,
                                   void *const userData) {
    bool success = BSG_KSFileWrite(userData, data, length);
    return success ? BSG_KSJSON_OK : BSG_KSJSON_ERROR_CANNOT_ADD_DATA;
}

// ============================================================================
#pragma mark - Utility -
// ============================================================================

/** Load the persistent state portion of a crash context.
 *
 * @param context The context to load into.
 *
 * @param path The path to the file to read.
 *
 * @return true if the operation was successful.
 */
bool bsg_kscrashstate_i_loadState(BSG_KSCrash_State *const context,
                                  const char *const path) {
    if (path == NULL) {
        return false;
    }
    NSString *file = [NSFileManager.defaultManager stringWithFileSystemRepresentation:path length:strlen(path)];
    if (!file) {
        bsg_log_err(@"Invalid path: %s", path);
        return false;
    }
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:file options:0 error:&error];
    if (error != nil) {
        if (!(error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError)) {
            bsg_log_err(@"%s: Could not load file: %@", path, error);
        }
        return false;
    }
    id objectContext = [BSG_KSJSONCodec decode:data error:&error];
    if (error != nil) {
        bsg_log_err(@"%s: Could not load file: %@", path, error);
        return false;
    }

    context->foregroundDurationSinceLastCrash = [objectContext[@"foregroundDurationSinceLastCrash"] doubleValue];
    context->foregroundDurationSinceLaunch = [objectContext[@"foregroundDurationSinceLaunch"] doubleValue];
    context->appLaunchTime = [objectContext[@"appLaunchTime"] unsignedLongLongValue];
    context->lastUpdateDurationsTime = [objectContext[@"appStateTransitionTime"] unsignedLongLongValue];
    context->launchesSinceLastCrash = [objectContext[@"launchesSinceLastCrash"] intValue];
    context->sessionsSinceLastCrash = [objectContext[@"sessionsSinceLastCrash"] intValue];
    context->sessionsSinceLaunch = [objectContext[@"sessionsSinceLaunch"] intValue];
    context->crashedLastLaunch = [objectContext[@"crashedLastLaunch"] boolValue];
    context->crashedThisLaunch = [objectContext[@"crashedThisLaunch"] boolValue];
    context->applicationIsInForeground = [objectContext[@"applicationIsInForeground"] boolValue];
    context->backgroundDurationSinceLaunch = [objectContext[@"backgroundDurationSinceLaunch"] doubleValue];
    context->backgroundDurationSinceLastCrash = [objectContext[@"backgroundDurationSinceLastCrash"] doubleValue];

    return true;
}

/** Save the persistent state portion of a crash context.
 *
 * @param state The context to save from.
 *
 * @param path The path to the file to create.
 *
 * @return true if the operation was successful.
 */
bool bsg_kscrashstate_i_saveState(const BSG_KSCrash_State *const state,
                                  const char *const path) {
    int fd = open(path, O_RDWR | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        bsg_log_err(@"Could not open file %s for writing: %s", path, strerror(errno));
        return false;
    }

    BSG_KSFile file;
    char buffer[256];
    BSG_KSFileInit(&file, fd, buffer, sizeof(buffer) / sizeof(*buffer));

    BSG_KSJSONEncodeContext JSONContext;
    bsg_ksjsonbeginEncode(&JSONContext, false, bsg_kscrashstate_i_addJSONData,
                          &file);

    int result;
    if ((result = bsg_ksjsonbeginObject(&JSONContext, NULL)) != BSG_KSJSON_OK) {
        goto done;
    }
    if ((result = bsg_ksjsonaddIntegerElement(
             &JSONContext, BSG_kKeyFormatVersion, BSG_kFormatVersion)) !=
        BSG_KSJSON_OK) {
        goto done;
    }
    // Record this launch crashed state into "crashed last launch" field.
    if ((result = bsg_ksjsonaddBooleanElement(
             &JSONContext, BSG_kKeyCrashedLastLaunch,
             state->crashedThisLaunch)) != BSG_KSJSON_OK) {
        goto done;
    }
    if ((result = bsg_ksjsonaddFloatingPointElement(
             &JSONContext, BSG_kKeyActiveDurationSinceLastCrash,
             state->foregroundDurationSinceLastCrash)) != BSG_KSJSON_OK) {
        goto done;
    }
    if ((result = bsg_ksjsonaddFloatingPointElement(
             &JSONContext, BSG_kKeyBackgroundDurationSinceLastCrash,
             state->backgroundDurationSinceLastCrash)) != BSG_KSJSON_OK) {
        goto done;
    }
    if ((result = bsg_ksjsonaddIntegerElement(
             &JSONContext, BSG_kKeyLaunchesSinceLastCrash,
             state->launchesSinceLastCrash)) != BSG_KSJSON_OK) {
        goto done;
    }
    if ((result = bsg_ksjsonaddIntegerElement(
             &JSONContext, BSG_kKeySessionsSinceLastCrash,
             state->sessionsSinceLastCrash)) != BSG_KSJSON_OK) {
        goto done;
    }
    result = bsg_ksjsonendEncode(&JSONContext);

done:
    BSG_KSFileFlush(&file);
    close(fd);

    if (result != BSG_KSJSON_OK) {
        bsg_log_err(@"%s: %s", path, bsg_ksjsonstringForError(result));
        return false;
    }
    return true;
}

// ============================================================================
#pragma mark - API -
// ============================================================================

bool bsg_kscrashstate_init(const char *const stateFilePath,
                           BSG_KSCrash_State *const state) {
    bsg_g_stateFilePath = stateFilePath;
    bsg_g_state = state;

    bsg_kscrashstate_i_loadState(state, stateFilePath);

    state->sessionsSinceLaunch = 1;
    state->foregroundDurationSinceLaunch = 0;
    state->backgroundDurationSinceLaunch = 0;
    if (state->crashedLastLaunch) {
        state->foregroundDurationSinceLastCrash = 0;
        state->backgroundDurationSinceLastCrash = 0;
        state->launchesSinceLastCrash = 0;
        state->sessionsSinceLastCrash = 0;
    }
    state->crashedThisLaunch = false;

    // Simulate first transition to foreground
    state->launchesSinceLastCrash++;
    state->sessionsSinceLastCrash++;

    // On iOS/tvOS, the app may have launched in the background due to a fetch
    // event or notification (or prewarming on iOS 15+)
    state->applicationIsInForeground = bsg_kscrashstate_i_isInForeground();

    return bsg_kscrashstate_i_saveState(state, stateFilePath);
}

static bool bsg_kscrashstate_i_isInForeground(void) {
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
    return true;
#endif
}

void bsg_kscrashstate_notifyAppInForeground(const bool isInForeground) {
    BSG_KSCrash_State *const state = bsg_g_state;
    const char *const stateFilePath = bsg_g_stateFilePath;

    if (state->applicationIsInForeground == isInForeground) {
        return;
    }
    state->applicationIsInForeground = isInForeground;
    uint64_t timeNow = mach_absolute_time();
    double duration = bsg_ksmachtimeDifferenceInSeconds(
        timeNow, state->lastUpdateDurationsTime);
    if (isInForeground) {
        state->backgroundDurationSinceLaunch += duration;
        state->backgroundDurationSinceLastCrash += duration;
        state->sessionsSinceLastCrash++;
        state->sessionsSinceLaunch++;
    } else {
        state->foregroundDurationSinceLaunch += duration;
        state->foregroundDurationSinceLastCrash += duration;
        bsg_kscrashstate_i_saveState(state, stateFilePath);
    }
    state->lastUpdateDurationsTime = timeNow;
}

void bsg_kscrashstate_notifyAppTerminate(void) {
    BSG_KSCrash_State *const state = bsg_g_state;
    const char *const stateFilePath = bsg_g_stateFilePath;

    const double duration = bsg_ksmachtimeDifferenceInSeconds(
        mach_absolute_time(), state->lastUpdateDurationsTime);
    state->backgroundDurationSinceLastCrash += duration;
    bsg_kscrashstate_i_saveState(state, stateFilePath);
}

void bsg_kscrashstate_notifyAppCrash(void) {
    BSG_KSCrash_State *const state = bsg_g_state;
    const char *const stateFilePath = bsg_g_stateFilePath;
    bsg_kscrashstate_updateDurationStats(state);
    state->crashedThisLaunch = YES;
    bsg_kscrashstate_i_saveState(state, stateFilePath);
}

void bsg_kscrashstate_updateDurationStats(BSG_KSCrash_State *const state) {
    uint64_t timeNow = mach_absolute_time();
    const double duration = bsg_ksmachtimeDifferenceInSeconds(
        timeNow, state->lastUpdateDurationsTime ?: state->appLaunchTime);
    if (state->applicationIsInForeground) {
        state->foregroundDurationSinceLaunch += duration;
        state->foregroundDurationSinceLastCrash += duration;
    } else {
        state->backgroundDurationSinceLaunch += duration;
        state->backgroundDurationSinceLastCrash += duration;
    }
    state->lastUpdateDurationsTime = timeNow;
}

const BSG_KSCrash_State *bsg_kscrashstate_currentState(void) {
    return bsg_g_state;
}
