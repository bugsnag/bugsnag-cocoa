//
//  BSGURLSessionTracingDelegateTests.m
//  BugsnagNetworkRequestPlugin
//
//  Created by Nick Dowell on 22/09/2021.
//

#import "BSGURLSessionTracingDelegate.h"

#import <XCTest/XCTest.h>

@interface BSGURLSessionTracingDelegateTests : XCTestCase

@end

@implementation BSGURLSessionTracingDelegateTests

- (void)testURLStringWithoutQueryForComponents {
#define TEST(url, expected) \
XCTAssertEqualObjects([BSGURLSessionTracingDelegate URLStringWithoutQueryForComponents:[NSURLComponents componentsWithString:url]], expected)
    
    TEST(@"http://example.com",
         @"http://example.com");
    
    TEST(@"http://example.com/",
         @"http://example.com/");
    
    TEST(@"http://example.com?foo=bar",
         @"http://example.com");
    
    TEST(@"http://example.com/?foo=bar",
         @"http://example.com/");
    
    TEST(@"http://example.com/page.html?foo=bar",
         @"http://example.com/page.html");
    
    TEST(@"http://example.com/page.html?foo=bar#some-anchor",
         @"http://example.com/page.html#some-anchor");
    
    // In this example what look like query parameters are actually part of the fragment
    TEST(@"http://example.com/page.html#some-anchor?foo=bar",
         @"http://example.com/page.html#some-anchor?foo=bar");
    
#undef TEST
}

@end
