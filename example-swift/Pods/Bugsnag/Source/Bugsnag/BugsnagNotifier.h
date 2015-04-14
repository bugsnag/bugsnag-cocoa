//
//  BugsnagMetaData.m
//
//  Created by Conrad Irwin on 2014-10-01.
//
//  Copyright (c) 2014 Bugsnag, Inc. All rights reserved.
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

#import <Foundation/Foundation.h>

#import "BugsnagConfiguration.h"



@interface BugsnagNotifier : NSObject <BugsnagMetaDataDelegate>

@property(nonatomic,readwrite,retain) BugsnagConfiguration* configuration;
@property(nonatomic,readwrite,retain) BugsnagMetaData* state;
@property(nonatomic,readwrite,retain) NSDictionary *details;
@property(nonatomic,readwrite,retain) NSLock *metaDataLock;

- (id) initWithConfiguration:(BugsnagConfiguration*) configuration;
- (void) start;

/** Notify bugsnag of an exception.
 *
 * @param exception  The NSException
 *
 * @param metaData  Any metaData to include in the report
 *
 * @param severity  The severity (default BugsnagSeverityWarning)
 *
 * @param depth  How many stack frames to remove from the report.
 */
- (void) notify:(NSException *)exception withData:(NSDictionary*)metaData atSeverity:(NSString*)severity atDepth:(NSUInteger) depth;

@end
