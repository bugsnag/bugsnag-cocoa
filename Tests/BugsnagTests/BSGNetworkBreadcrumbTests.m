//
//  BSGNetworkBreadcrumbTests.m
//  Bugsnag
//
//  Created by Nick Dowell on 22/09/2021.
//

#import "BSGTestCase.h"

#import "BSGNetworkBreadcrumb.h"
#import "BugsnagInternals.h"
#import <objc/runtime.h>

@interface BSGNetworkBreadcrumbTests : BSGTestCase

@end

@implementation BSGNetworkBreadcrumbTests

- (void)withNilQueryName:(void (^)(NSString *url))test {
    NSString *url = @"https://example.com/?category=books&__nil_name__=ignored&=empty-name&category=music&flag";
    NSURLQueryItem *sample = [NSURLComponents componentsWithString:url].queryItems.firstObject;
    Method method = class_getInstanceMethod(sample.class, @selector(name));
    IMP original = method_getImplementation(method);
    // Foundation may normalize a nil initializer argument to an empty name.
    // Inject nil at the getter to exercise both production parsing paths.
    IMP replacement = imp_implementationWithBlock(^NSString *(NSURLQueryItem *item) {
        NSString *name = ((NSString *(*)(id, SEL))original)(item, @selector(name));
        return [name isEqualToString:@"__nil_name__"] ? nil : name;
    });
    method_setImplementation(method, replacement);
    @try {
        test(url);
    } @finally {
        method_setImplementation(method, original);
        imp_removeBlock(replacement);
    }
}

- (void)testUrlParamsSkipsNilNames {
    [self withNilQueryName:^(NSString *url) {
        NSArray<NSURLQueryItem *> *items = [NSURLComponents componentsWithString:url].queryItems;
        XCTAssertNil(items[1].name);
        NSDictionary *breadcrumbParams = BSGURLParamsForQueryItems(items);
        NSDictionary *expectedBreadcrumbParams = @{
            @"category": @[@"books", @"music"],
            @"": @"empty-name",
            @"flag": [NSNull null]
        };
        XCTAssertEqualObjects(breadcrumbParams, expectedBreadcrumbParams);
    }];
}

- (void)testRequestParamsSkipsNilNames {
    [self withNilQueryName:^(NSString *url) {
        XCTAssertNil([NSURLComponents componentsWithString:url].queryItems[1].name);
        BugsnagHttpRequest *request = [BugsnagHttpRequest new];
        [request setNewUrl:url];
        // Request payloads retain their existing last-value-wins and nil-value behavior.
        NSDictionary *expectedRequestParams = @{@"category": @"music", @"": @"empty-name"};
        XCTAssertEqualObjects(request.params, expectedRequestParams);
        XCTAssertEqualObjects(request.url, @"https://example.com/");
    }];
}

- (void)testUrlParamsForQueryItems {
#define TEST(url, expected) \
XCTAssertEqualObjects(BSGURLParamsForQueryItems([NSURLComponents componentsWithString:url].queryItems), expected)
    
    TEST(@"http://example.com", nil);
    
    TEST(@"http://example.com?", @{});
    
    TEST(@"http://example.com?foo=bar", @{@"foo": @"bar"});
    
    TEST(@"http://example.com?foo=bar&bar=baz", (@{@"foo": @"bar", @"bar": @"baz"}));
    
    // Multiple query items with the same name should be represented as arrays.
    TEST(@"http://example.com?foo=bar&foo=baz", (@{@"foo": @[@"bar", @"baz"]}));
    
    // Query items with no value should be represented as empty string.
    TEST(@"http://example.com?foo=bar&foo=baz&foo=&sort=name", (@{@"foo": @[@"bar", @"baz", @""], @"sort": @"name"}));
    
    TEST(@"http://example.com?foo", @{@"foo": [NSNull null]});
    
    TEST(@"http://example.com?=bar", @{@"": @"bar"});
    
    TEST(@"http://example.com?foo=bar&", (@{@"foo": @"bar", @"": [NSNull null]}));
    
    TEST(@"http://example.com?foo=bar&baz", (@{@"foo": @"bar", @"baz": [NSNull null]}));
    
    TEST(@"http://example.com?foo=bar&baz&baz", (@{@"foo": @"bar", @"baz": @[[NSNull null], [NSNull null]]}));
    
#undef TEST
}

- (void)testURLStringWithoutQueryForComponents {
#define TEST(url, expected) \
XCTAssertEqualObjects(BSGURLStringForComponents([NSURLComponents componentsWithString:url]), expected)
    
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
