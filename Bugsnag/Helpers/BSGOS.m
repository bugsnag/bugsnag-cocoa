//
//  BSGOS.m
//  Bugsnag
//
//  Created by Karl Stenerud on 22.06.22.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#import "BSGOS.h"
#import "BSG_KSSystemInfo.h"

static bool bsgos_initialized = false;
static BSGOS_Platform current_platform = BSGOS_UNKNOWN_OS;
static unsigned current_version = 0;

static inline unsigned make_version(unsigned major, unsigned minor) {
    return (major << 16) | minor;
}

void bsgos_init(void) {
    if (bsgos_initialized) {
        return;
    }

    NSDictionary *sysInfo = [BSG_KSSystemInfo systemInfo];

    const char *platform_str = [sysInfo[@BSG_KSSystemField_SystemName] UTF8String];
    if (platform_str != NULL) {
        if (strcmp(platform_str, "iOS") == 0) {
            current_platform = BSGOS_IOS;
        } else if (strcmp(platform_str, "tvOS") == 0) {
            current_platform = BSGOS_TVOS;
        } else if (strcmp(platform_str, "watchOS") == 0) {
            current_platform = BSGOS_WATCHOS;
        } else if (strcmp(platform_str, "Mac OS") == 0) {
            // [BSG_KSSystemInfo buildSystemInfoStatic] calls it "Mac OS".
            current_platform = BSGOS_MACOS;
        }
    }

    const char *version_str = [sysInfo[@BSG_KSSystemField_SystemVersion] UTF8String];
    if (version_str != NULL) {
        unsigned version_major = (unsigned)atoi(version_str);
        unsigned version_minor = 0;
        const char* dot = strchr(version_str, '.');
        if (dot != NULL) {
            version_minor = (unsigned)atoi(dot+1);
        }
        current_version = make_version(version_major, version_minor);
    }

    bsgos_initialized = true;
}

bool bsgos_available(BSGOS_Platform wanted_platform, unsigned major_version, unsigned minor_version) {
    unsigned wanted_version = make_version(major_version, minor_version);
    return (current_platform == wanted_platform && current_version >= wanted_version);
}
