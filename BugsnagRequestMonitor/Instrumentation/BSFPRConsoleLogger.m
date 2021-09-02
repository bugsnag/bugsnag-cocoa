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

#import "BSFPRConsoleLogger.h"

// BSFPR Client message codes.
NSString* const kBSFPRClientInitialize = @"I-PRF100001";
NSString* const kBSFPRClientTempDirectory = @"I-PRF100002";
NSString* const kBSFPRClientCreateWorkingDirectory = @"I-PRF100003";
NSString* const kBSFPRClientClearcutUpload = @"I-PRF100004";
NSString* const kBSFPRClientInstanceIDNotAvailable = @"I-PRF100005";
NSString* const kBSFPRClientNameTruncated = @"I-PRF100006";
NSString* const kBSFPRClientNameReserved = @"I-PRF100007";
NSString* const kBSFPRClientInvalidTrace = @"I-PRF100008";
NSString* const kBSFPRClientMetricLogged = @"I-PRF100009";
NSString* const kBSFPRClientDataUpload = @"I-PRF100010";
NSString* const kBSFPRClientNameLengthCheckFailed = @"I-PRF100012";
NSString* const kBSFPRClientPerfNotConfigured = @"I-PRF100013";
NSString* const kBSFPRClientSDKDisabled = @"I-PRF100014";

// BSFPR Trace message codes.
NSString* const kBSFPRTraceNoName = @"I-PRF200001";
NSString* const kBSFPRTraceAlreadyStopped = @"I-PRF200002";
NSString* const kBSFPRTraceNotStarted = @"I-PRF200003";
NSString* const kBSFPRTraceDisabled = @"I-PRF200004";
NSString* const kBSFPRTraceEmptyName = @"I-PRF200005";
NSString* const kBSFPRTraceStartedNotStopped = @"I-PRF200006";
NSString* const kBSFPRTraceNotCreated = @"I-PRF200007";
NSString* const kBSFPRTraceInvalidName = @"I-PRF200008";

// BSFPR NetworkTrace message codes.
NSString* const kBSFPRNetworkTraceFileError = @"I-PRF300001";
NSString* const kBSFPRNetworkTraceInvalidInputs = @"I-PRF300002";
NSString* const kBSFPRNetworkTraceURLLengthExceeds = @"I-PRF300003";
NSString* const kBSFPRNetworkTraceNotTrackable = @"I-PRF300004";
NSString* const kBSFPRNetworkTraceURLLengthTruncation = @"I-PRF300005";

// BSFPR LogSampler message codes.
NSString* const kBSFPRSamplerInvalidConfigs = @"I-PRF400001";

// BSFPR Attributes message codes.
NSString* const kBSFPRAttributeNoName = @"I-PRF500001";
NSString* const kBSFPRAttributeNoValue = @"I-PRF500002";
NSString* const kBSFPRMaxAttributesReached = @"I-PRF500003";
NSString* const kBSFPRAttributeNameIllegalCharacters = @"I-PRF500004";

// Manual network instrumentation codes.
NSString* const kBSFPRInstrumentationInvalidInputs = @"I-PRF600001";
NSString* const kBSFPRInstrumentationDisabledAfterConfigure = @"I-PRF600002";

// BSFPR diagnostic message codes.
NSString* const kBSFPRDiagnosticInfo = @"I-PRF700001";
NSString* const kBSFPRDiagnosticFailure = @"I-PRF700002";
NSString* const kBSFPRDiagnosticLog = @"I-PRF700003";

// BSFPR Configuration related error codes.
NSString* const kBSFPRConfigurationFetchFailure = @"I-PRF710001";

// BSFPR URL filtering message codes.
NSString* const kBSFPRURLAllowlistingEnabled = @"I-PRF800001";

// BSFPR Gauge manager codes.
NSString* const kBSFPRGaugeManagerDataCollected = @"I-PRF900001";
NSString* const kBSFPRSessionId = @"I-PRF900002";
NSString* const kBSFPRCPUCollection = @"I-PRF900003";
NSString* const kBSFPRMemoryCollection = @"I-PRF900004";

// BSFPRSDKConfiguration message codes.
NSString* const kBSFPRSDKFeaturesBlock = @"I-PRF910001";
