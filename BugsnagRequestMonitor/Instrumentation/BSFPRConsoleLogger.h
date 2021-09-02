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

//#import ""FirebaseCore/Sources/Private/BSFIRLogger.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define BSFPRLogDebug(messageCode, ...) NSLog(__VA_ARGS__)
#define BSFPRLogError(messageCode, ...) NSLog(__VA_ARGS__)
#define BSFPRLogInfo(messageCode, ...) NSLog(__VA_ARGS__)
#define BSFPRLogNotice(messageCode, ...) NSLog(__VA_ARGS__)
#define BSFPRLogWarning(messageCode, ...) NSLog(__VA_ARGS__)

// BSFPR Client message codes.
FOUNDATION_EXTERN NSString* const kBSFPRClientInitialize;
FOUNDATION_EXTERN NSString* const kBSFPRClientTempDirectory;
FOUNDATION_EXTERN NSString* const kBSFPRClientCreateWorkingDirectory;
FOUNDATION_EXTERN NSString* const kBSFPRClientClearcutUpload;
FOUNDATION_EXTERN NSString* const kBSFPRClientInstanceIDNotAvailable;
FOUNDATION_EXTERN NSString* const kBSFPRClientNameTruncated;
FOUNDATION_EXTERN NSString* const kBSFPRClientNameReserved;
FOUNDATION_EXTERN NSString* const kBSFPRClientInvalidTrace;
FOUNDATION_EXTERN NSString* const kBSFPRClientMetricLogged;
FOUNDATION_EXTERN NSString* const kBSFPRClientDataUpload;
FOUNDATION_EXTERN NSString* const kBSFPRClientNameLengthCheckFailed;
FOUNDATION_EXTERN NSString* const kBSFPRClientPerfNotConfigured;
FOUNDATION_EXTERN NSString* const kBSFPRClientSDKDisabled;

// BSFPR Trace message codes.
FOUNDATION_EXTERN NSString* const kBSFPRTraceNoName;
FOUNDATION_EXTERN NSString* const kBSFPRTraceAlreadyStopped;
FOUNDATION_EXTERN NSString* const kBSFPRTraceNotStarted;
FOUNDATION_EXTERN NSString* const kBSFPRTraceDisabled;
FOUNDATION_EXTERN NSString* const kBSFPRTraceEmptyName;
FOUNDATION_EXTERN NSString* const kBSFPRTraceStartedNotStopped;
FOUNDATION_EXTERN NSString* const kBSFPRTraceNotCreated;
FOUNDATION_EXTERN NSString* const kBSFPRTraceInvalidName;

// BSFPR NetworkTrace message codes.
FOUNDATION_EXTERN NSString* const kBSFPRNetworkTraceFileError;
FOUNDATION_EXTERN NSString* const kBSFPRNetworkTraceInvalidInputs;
FOUNDATION_EXTERN NSString* const kBSFPRNetworkTraceURLLengthExceeds;
FOUNDATION_EXTERN NSString* const kBSFPRNetworkTraceURLLengthTruncation;
FOUNDATION_EXTERN NSString* const kBSFPRNetworkTraceNotTrackable;

// BSFPR LogSampler message codes.
FOUNDATION_EXTERN NSString* const kBSFPRSamplerInvalidConfigs;

// BSFPR attributes message codes.
FOUNDATION_EXTERN NSString* const kBSFPRAttributeNoName;
FOUNDATION_EXTERN NSString* const kBSFPRAttributeNoValue;
FOUNDATION_EXTERN NSString* const kBSFPRMaxAttributesReached;
FOUNDATION_EXTERN NSString* const kBSFPRAttributeNameIllegalCharacters;

// Manual network instrumentation codes.
FOUNDATION_EXTERN NSString* const kBSFPRInstrumentationInvalidInputs;
FOUNDATION_EXTERN NSString* const kBSFPRInstrumentationDisabledAfterConfigure;

// BSFPR diagnostic message codes.
FOUNDATION_EXTERN NSString* const kBSFPRDiagnosticInfo;
FOUNDATION_EXTERN NSString* const kBSFPRDiagnosticFailure;
FOUNDATION_EXTERN NSString* const kBSFPRDiagnosticLog;

// BSFPR Configuration related error codes.
FOUNDATION_EXTERN NSString* const kBSFPRConfigurationFetchFailure;

// BSFPR URL filtering message codes.
FOUNDATION_EXTERN NSString* const kBSFPRURLAllowlistingEnabled;

// BSFPR Gauge manager codes.
FOUNDATION_EXTERN NSString* const kBSFPRGaugeManagerDataCollected;
FOUNDATION_EXTERN NSString* const kBSFPRSessionId;
FOUNDATION_EXTERN NSString* const kBSFPRCPUCollection;
FOUNDATION_EXTERN NSString* const kBSFPRMemoryCollection;

// BSFPRSDKConfiguration message codes.
FOUNDATION_EXTERN NSString* const kBSFPRSDKFeaturesBlock;

NS_ASSUME_NONNULL_END
