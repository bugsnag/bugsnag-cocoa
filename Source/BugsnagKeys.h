//
//  BugsnagKeys.h
//  Bugsnag
//
//  Created by Jamie Lynch on 24/10/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#ifndef BugsnagKeys_h
#define BugsnagKeys_h

static NSString *const BSGDefaultNotifyUrl = @"https://notify.bugsnag.com/";

static NSString *const BSGKeyException = @"exception";
static NSString *const BSGKeyMessage = @"message";
static NSString *const BSGKeyName = @"name";
static NSString *const BSGKeyTimestamp = @"timestamp";
static NSString *const BSGKeyType = @"type";
static NSString *const BSGKeyMetaData = @"metaData";

static NSString *const BSGKeyExecutableName = @"CFBundleExecutable";
static NSString *const BSGKeyHwModel = @"hw.model";
static NSString *const BSGKeyHwMachine = @"hw.machine";

#define BSGKeyDefaultMacName "en0"

#endif /* BugsnagKeys_h */
