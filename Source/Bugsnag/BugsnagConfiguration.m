//
//  BugsnagConfiguration.m
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

#import "BugsnagConfiguration.h"
#import "BugsnagBreadcrumb.h"

@implementation BugsnagConfiguration

-(id)init {
    if (self = [super init])  {
        self.metaData = [[BugsnagMetaData alloc] init];
        self.config = [[BugsnagMetaData alloc] init];
        self.apiKey = @"";
        self.autoNotify = true;
        self.notifyURL = [NSURL URLWithString:@"https://notify.bugsnag.com/"];

        self.notifyReleaseStages = nil;
        _breadcrumbs = [BugsnagBreadcrumbs new];
#if DEBUG
        self.releaseStage = @"development";
#else
        self.releaseStage = @"production";
#endif
    }
    return self;
}
-(void)setUser:(NSString*)userId withName: (NSString*) userName andEmail:(NSString*)userEmail
{
    [self.metaData addAttribute:@"id" withValue:userId toTabWithName:@"user"];
    [self.metaData addAttribute:@"name" withValue:userName toTabWithName:@"user"];
    [self.metaData addAttribute:@"email" withValue:userEmail toTabWithName:@"user"];
}

@synthesize metaData;
@synthesize config;

@synthesize notifyURL;
@synthesize apiKey;
@synthesize autoNotify;
@synthesize releaseStage;
@synthesize notifyReleaseStages;
@synthesize context;
@synthesize appVersion;

-(void) setReleaseStage:(NSString *)newReleaseStage {
    self->releaseStage = newReleaseStage;
    [self.config addAttribute:@"releaseStage" withValue:newReleaseStage toTabWithName:@"config"];
}

-(void) setContext:(NSString *)newContext
{
    self->context = newContext;
    [self.config addAttribute:@"context" withValue: newContext toTabWithName:@"config"];
}

-(void) setAppVersion:(NSString *)newVersion
{
    self->appVersion = newVersion;
    [self.config addAttribute:@"appVersion" withValue: newVersion toTabWithName:@"config"];
}
@end