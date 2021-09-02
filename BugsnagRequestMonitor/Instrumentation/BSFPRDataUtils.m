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

#import "BSFPRDataUtils.h"

#import "BSFPRConsoleLogger.h"

#pragma mark - Public functions

int const kBSFPRMaxURLLength = 2000;

NSString *BSFPRTruncatedURLString(NSString *URLString) {
  NSString *truncatedURLString = URLString;
  NSString *pathSeparator = @"/";
  if (truncatedURLString.length > kBSFPRMaxURLLength) {
    NSString *truncationCharacter =
        [truncatedURLString substringWithRange:NSMakeRange(kBSFPRMaxURLLength, 1)];

    truncatedURLString = [URLString substringToIndex:kBSFPRMaxURLLength];
    if (![pathSeparator isEqual:truncationCharacter]) {
      NSRange rangeOfTruncation = [truncatedURLString rangeOfString:pathSeparator
                                                            options:NSBackwardsSearch];
      truncatedURLString = [URLString substringToIndex:rangeOfTruncation.location];
    }

    BSFPRLogWarning(kBSFPRClientNameTruncated, @"URL exceeds %d characters. Truncated url: %@",
                  kBSFPRMaxURLLength, truncatedURLString);
  }
  return truncatedURLString;
}
