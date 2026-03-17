//
//  BSGHttpKeys.h
//  Bugsnag
//
//  Created by Daria Bialobrzeska on 04/02/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NSString * BSGHttpKey NS_TYPED_ENUM;

/*
 * These constants are declared with static storage to prevent bloating the
 * symbol and export tables. String pooling means the compiler won't create
 * multiple copies of the same string in the output.
 */

static BSGHttpKey const BSGHttpRequest = @"request";
static BSGHttpKey const BSGHttpResponse = @"response";
static BSGHttpKey const BSGHttpBody = @"body";
static BSGHttpKey const BSGHttpHeaders = @"headers";
static BSGHttpKey const BSGHttpParams = @"params";
static BSGHttpKey const BSGHttpMethod = @"httpMethod";
static BSGHttpKey const BSGHttpVersion = @"httpVersion";
static BSGHttpKey const BSGHttpURL = @"url";
static BSGHttpKey const BSGHttpBodyLength = @"bodyLength";
static BSGHttpKey const BSGHttpStatusCode = @"statusCode";

