//
//  BSGHashDiscardIntegrationTests.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 27/01/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BSGRemoteConfiguration.h"
#import "BSGRemoteConfigHandler.h"
#import "BSGEventDiscardRuleFactory.h"
#import "BSGHashDiscardRule.h"
#import "BSGEventDiscardProcessor.h"
#import "BSGEventDiscardRulesetSource.h"

// MARK: - BSGMockRemoteConfigHandler

/**
 * Mock remote config handler for testing that returns a fixed configuration
 */
@interface BSGMockRemoteConfigHandler : BSGRemoteConfigHandler
@property (nonatomic, strong) BSGRemoteConfiguration *mockConfiguration;
@end

@implementation BSGMockRemoteConfigHandler

- (BSGRemoteConfiguration *)currentConfiguration {
    return self.mockConfiguration;
}

- (NSDate *)lastConfigUpdateTime {
    return [NSDate date];
}

- (BOOL)hasValidConfig {
    return self.mockConfiguration != nil;
}

@end

// MARK: - BSGHashDiscardIntegrationTests

@interface BSGHashDiscardIntegrationTests : XCTestCase
@end

@implementation BSGHashDiscardIntegrationTests

#pragma mark - Helper Methods

- (NSDictionary *)jsonFromResource:(NSString *)resourceName {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:resourceName
                                      ofType:@"json"
                                 inDirectory:@"Data/RemoteConfig"];
    
    NSAssert(path != nil, @"Resource not found: %@", resourceName);
    
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:&error];
    
    NSAssert(data != nil, @"Failed to read resource %@: %@", resourceName, error);
    
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    NSAssert(json != nil && [json isKindOfClass:[NSDictionary class]],
             @"Failed to parse JSON from %@: %@", resourceName, error);
    
    return (NSDictionary *)json;
}

#pragma mark - Test Methods

- (void)testDiscardAndroidNativeCrash {
    // Load fixture
    NSDictionary *eventJson = [self jsonFromResource:@"android_native_crash"];
    NSDictionary *configJson = [self jsonFromResource:@"android_native_crash_config"];
    
    // Create remote configuration from JSON
    BSGRemoteConfiguration *config = [BSGRemoteConfiguration configFromJson:configJson
                                                                       eTag:@"etag"
                                                                 expiryDate:[NSDate dateWithTimeIntervalSinceNow:42]];
    XCTAssertNotNil(config, @"RemoteConfiguration should not be nil");
    
    // Set up the integration test components
    BSGMockRemoteConfigHandler *mockHandler = [[BSGMockRemoteConfigHandler alloc] init];
    mockHandler.mockConfiguration = config;
    
    BSGEventDiscardRuleFactory *factory = [[BSGEventDiscardRuleFactory alloc] init];
    BSGEventDiscardProcessor *processor = [[BSGEventDiscardProcessor alloc] init];
    BSGEventDiscardRulesetSource *source = [BSGEventDiscardRulesetSource sourceWithRemoteConfigHandler:mockHandler
                                                                                     discardRuleFactory:factory];
    processor.source = source;
    
    // Test that the event should be discarded
    BOOL shouldDiscard = [processor shouldDiscardEvent:eventJson];
    XCTAssertTrue(shouldDiscard, @"Expected the payload to be discarded");
}

- (void)testDiscardiOSHandledNSError {
    // Load fixture
    NSDictionary *eventJson = [self jsonFromResource:@"ios_handled_nserror"];
    NSDictionary *configJson = [self jsonFromResource:@"ios_handled_nserror_config"];
    
    // Create remote configuration from JSON
    BSGRemoteConfiguration *config = [BSGRemoteConfiguration configFromJson:configJson
                                                                       eTag:@"etag"
                                                                 expiryDate:[NSDate dateWithTimeIntervalSinceNow:42]];
    XCTAssertNotNil(config, @"RemoteConfiguration should not be nil");
    
    // Set up the integration test components
    BSGMockRemoteConfigHandler *mockHandler = [[BSGMockRemoteConfigHandler alloc] init];
    mockHandler.mockConfiguration = config;
    
    BSGEventDiscardRuleFactory *factory = [[BSGEventDiscardRuleFactory alloc] init];
    BSGEventDiscardProcessor *processor = [[BSGEventDiscardProcessor alloc] init];
    BSGEventDiscardRulesetSource *source = [BSGEventDiscardRulesetSource sourceWithRemoteConfigHandler:mockHandler
                                                                                     discardRuleFactory:factory];
    processor.source = source;
    
    // Test that the event should be discarded
    BOOL shouldDiscard = [processor shouldDiscardEvent:eventJson];
    XCTAssertTrue(shouldDiscard, @"Expected the payload to be discarded");
}

- (void)testDiscardiOSUnhandledException {
    // Load fixture
    NSDictionary *eventJson = [self jsonFromResource:@"ios_unhandled_nsexception"];
    NSDictionary *configJson = [self jsonFromResource:@"ios_unhandled_nsexception_config"];
    
    // Create remote configuration from JSON
    BSGRemoteConfiguration *config = [BSGRemoteConfiguration configFromJson:configJson
                                                                       eTag:@"etag"
                                                                 expiryDate:[NSDate dateWithTimeIntervalSinceNow:42]];
    XCTAssertNotNil(config, @"RemoteConfiguration should not be nil");
    
    // Set up the integration test components
    BSGMockRemoteConfigHandler *mockHandler = [[BSGMockRemoteConfigHandler alloc] init];
    mockHandler.mockConfiguration = config;
    
    BSGEventDiscardRuleFactory *factory = [[BSGEventDiscardRuleFactory alloc] init];
    BSGEventDiscardProcessor *processor = [[BSGEventDiscardProcessor alloc] init];
    BSGEventDiscardRulesetSource *source = [BSGEventDiscardRulesetSource sourceWithRemoteConfigHandler:mockHandler
                                                                                     discardRuleFactory:factory];
    processor.source = source;
    
    // Test that the event should be discarded
    BOOL shouldDiscard = [processor shouldDiscardEvent:eventJson];
    XCTAssertTrue(shouldDiscard, @"Expected the payload to be discarded");
}

- (void)testDiscardPipelineExample1Config1 {
    // Load fixture
    NSDictionary *eventJson = [self jsonFromResource:@"pipeline_example_01"];
    NSDictionary *configJson = [self jsonFromResource:@"pipeline_example_config01"];
    
    // Create remote configuration from JSON
    BSGRemoteConfiguration *config = [BSGRemoteConfiguration configFromJson:configJson
                                                                       eTag:@"etag"
                                                                 expiryDate:[NSDate dateWithTimeIntervalSinceNow:42]];
    XCTAssertNotNil(config, @"RemoteConfiguration should not be nil");
    
    // Set up the integration test components
    BSGMockRemoteConfigHandler *mockHandler = [[BSGMockRemoteConfigHandler alloc] init];
    mockHandler.mockConfiguration = config;
    
    BSGEventDiscardRuleFactory *factory = [[BSGEventDiscardRuleFactory alloc] init];
    BSGEventDiscardProcessor *processor = [[BSGEventDiscardProcessor alloc] init];
    BSGEventDiscardRulesetSource *source = [BSGEventDiscardRulesetSource sourceWithRemoteConfigHandler:mockHandler
                                                                                     discardRuleFactory:factory];
    processor.source = source;
    
    // Test that the event should be discarded
    BOOL shouldDiscard = [processor shouldDiscardEvent:eventJson];
    XCTAssertTrue(shouldDiscard, @"Expected the payload to be discarded");
}

- (void)testDiscardPipelineExample2Config2 {
    // Load fixture
    NSDictionary *eventJson = [self jsonFromResource:@"pipeline_example_02"];
    NSDictionary *configJson = [self jsonFromResource:@"pipeline_example_config02"];
    
    // Create remote configuration from JSON
    BSGRemoteConfiguration *config = [BSGRemoteConfiguration configFromJson:configJson
                                                                       eTag:@"etag"
                                                                 expiryDate:[NSDate dateWithTimeIntervalSinceNow:42]];
    XCTAssertNotNil(config, @"RemoteConfiguration should not be nil");
    
    // Set up the integration test components
    BSGMockRemoteConfigHandler *mockHandler = [[BSGMockRemoteConfigHandler alloc] init];
    mockHandler.mockConfiguration = config;
    
    BSGEventDiscardRuleFactory *factory = [[BSGEventDiscardRuleFactory alloc] init];
    BSGEventDiscardProcessor *processor = [[BSGEventDiscardProcessor alloc] init];
    BSGEventDiscardRulesetSource *source = [BSGEventDiscardRulesetSource sourceWithRemoteConfigHandler:mockHandler
                                                                                     discardRuleFactory:factory];
    processor.source = source;
    
    // Test that the event should be discarded
    BOOL shouldDiscard = [processor shouldDiscardEvent:eventJson];
    XCTAssertTrue(shouldDiscard, @"Expected the payload to be discarded");
}

- (void)testDiscardPipelineExample3Config3 {
    // Load fixture
    NSDictionary *eventJson = [self jsonFromResource:@"pipeline_example_03"];
    NSDictionary *configJson = [self jsonFromResource:@"pipeline_example_config03"];
    
    // Create remote configuration from JSON
    BSGRemoteConfiguration *config = [BSGRemoteConfiguration configFromJson:configJson
                                                                       eTag:@"etag"
                                                                 expiryDate:[NSDate dateWithTimeIntervalSinceNow:42]];
    XCTAssertNotNil(config, @"RemoteConfiguration should not be nil");
    
    // Set up the integration test components
    BSGMockRemoteConfigHandler *mockHandler = [[BSGMockRemoteConfigHandler alloc] init];
    mockHandler.mockConfiguration = config;
    
    BSGEventDiscardRuleFactory *factory = [[BSGEventDiscardRuleFactory alloc] init];
    BSGEventDiscardProcessor *processor = [[BSGEventDiscardProcessor alloc] init];
    BSGEventDiscardRulesetSource *source = [BSGEventDiscardRulesetSource sourceWithRemoteConfigHandler:mockHandler
                                                                                     discardRuleFactory:factory];
    processor.source = source;
    
    // Test that the event should be discarded
    BOOL shouldDiscard = [processor shouldDiscardEvent:eventJson];
    XCTAssertTrue(shouldDiscard, @"Expected the payload to be discarded");
}

- (void)testDiscardPipelineExample4Config4 {
    // Load fixture
    NSDictionary *eventJson = [self jsonFromResource:@"pipeline_example_04"];
    NSDictionary *configJson = [self jsonFromResource:@"pipeline_example_config04"];
    
    // Create remote configuration from JSON
    BSGRemoteConfiguration *config = [BSGRemoteConfiguration configFromJson:configJson
                                                                       eTag:@"etag"
                                                                 expiryDate:[NSDate dateWithTimeIntervalSinceNow:42]];
    XCTAssertNotNil(config, @"RemoteConfiguration should not be nil");
    
    // Set up the integration test components
    BSGMockRemoteConfigHandler *mockHandler = [[BSGMockRemoteConfigHandler alloc] init];
    mockHandler.mockConfiguration = config;
    
    BSGEventDiscardRuleFactory *factory = [[BSGEventDiscardRuleFactory alloc] init];
    BSGEventDiscardProcessor *processor = [[BSGEventDiscardProcessor alloc] init];
    BSGEventDiscardRulesetSource *source = [BSGEventDiscardRulesetSource sourceWithRemoteConfigHandler:mockHandler
                                                                                     discardRuleFactory:factory];
    processor.source = source;
    
    // Test that the event should be discarded
    BOOL shouldDiscard = [processor shouldDiscardEvent:eventJson];
    XCTAssertTrue(shouldDiscard, @"Expected the payload to be discarded");
}

- (void)testDiscardPipelineExample4Config1 {
    // Load fixture
    NSDictionary *eventJson = [self jsonFromResource:@"pipeline_example_04"];
    NSDictionary *configJson = [self jsonFromResource:@"pipeline_example_config01"];
    
    // Create remote configuration from JSON
    BSGRemoteConfiguration *config = [BSGRemoteConfiguration configFromJson:configJson
                                                                       eTag:@"etag"
                                                                 expiryDate:[NSDate dateWithTimeIntervalSinceNow:42]];
    XCTAssertNotNil(config, @"RemoteConfiguration should not be nil");
    
    // Set up the integration test components
    BSGMockRemoteConfigHandler *mockHandler = [[BSGMockRemoteConfigHandler alloc] init];
    mockHandler.mockConfiguration = config;
    
    BSGEventDiscardRuleFactory *factory = [[BSGEventDiscardRuleFactory alloc] init];
    BSGEventDiscardProcessor *processor = [[BSGEventDiscardProcessor alloc] init];
    BSGEventDiscardRulesetSource *source = [BSGEventDiscardRulesetSource sourceWithRemoteConfigHandler:mockHandler
                                                                                     discardRuleFactory:factory];
    processor.source = source;
    
    // Test that the event should be discarded
    BOOL shouldDiscard = [processor shouldDiscardEvent:eventJson];
    XCTAssertTrue(shouldDiscard, @"Expected the payload to be discarded");
}

- (void)testDiscardPipelineExample4Config2 {
    // Load fixture
    NSDictionary *eventJson = [self jsonFromResource:@"pipeline_example_04"];
    NSDictionary *configJson = [self jsonFromResource:@"pipeline_example_config02"];
    
    // Create remote configuration from JSON
    BSGRemoteConfiguration *config = [BSGRemoteConfiguration configFromJson:configJson
                                                                       eTag:@"etag"
                                                                 expiryDate:[NSDate dateWithTimeIntervalSinceNow:42]];
    XCTAssertNotNil(config, @"RemoteConfiguration should not be nil");
    
    // Set up the integration test components
    BSGMockRemoteConfigHandler *mockHandler = [[BSGMockRemoteConfigHandler alloc] init];
    mockHandler.mockConfiguration = config;
    
    BSGEventDiscardRuleFactory *factory = [[BSGEventDiscardRuleFactory alloc] init];
    BSGEventDiscardProcessor *processor = [[BSGEventDiscardProcessor alloc] init];
    BSGEventDiscardRulesetSource *source = [BSGEventDiscardRulesetSource sourceWithRemoteConfigHandler:mockHandler
                                                                                     discardRuleFactory:factory];
    processor.source = source;
    
    // Test that the event should be discarded
    BOOL shouldDiscard = [processor shouldDiscardEvent:eventJson];
    XCTAssertTrue(shouldDiscard, @"Expected the payload to be discarded");
}

- (void)testDiscardPipelineExample4Config3 {
    // Load fixture
    NSDictionary *eventJson = [self jsonFromResource:@"pipeline_example_04"];
    NSDictionary *configJson = [self jsonFromResource:@"pipeline_example_config03"];
    
    // Create remote configuration from JSON
    BSGRemoteConfiguration *config = [BSGRemoteConfiguration configFromJson:configJson
                                                                       eTag:@"etag"
                                                                 expiryDate:[NSDate dateWithTimeIntervalSinceNow:42]];
    XCTAssertNotNil(config, @"RemoteConfiguration should not be nil");
    
    // Set up the integration test components
    BSGMockRemoteConfigHandler *mockHandler = [[BSGMockRemoteConfigHandler alloc] init];
    mockHandler.mockConfiguration = config;
    
    BSGEventDiscardRuleFactory *factory = [[BSGEventDiscardRuleFactory alloc] init];
    BSGEventDiscardProcessor *processor = [[BSGEventDiscardProcessor alloc] init];
    BSGEventDiscardRulesetSource *source = [BSGEventDiscardRulesetSource sourceWithRemoteConfigHandler:mockHandler
                                                                                     discardRuleFactory:factory];
    processor.source = source;
    
    // Test that the event should be discarded
    BOOL shouldDiscard = [processor shouldDiscardEvent:eventJson];
    XCTAssertTrue(shouldDiscard, @"Expected the payload to be discarded");
}

- (void)testDiscardPipelineMultipleMatchers {
    // Load fixture
    NSDictionary *eventJson = [self jsonFromResource:@"multiple_matchers"];
    NSDictionary *configJson = [self jsonFromResource:@"multiple_matchers_config"];
    
    // Create remote configuration from JSON
    BSGRemoteConfiguration *config = [BSGRemoteConfiguration configFromJson:configJson
                                                                       eTag:@"etag"
                                                                 expiryDate:[NSDate dateWithTimeIntervalSinceNow:42]];
    XCTAssertNotNil(config, @"RemoteConfiguration should not be nil");
    
    // Set up the integration test components
    BSGMockRemoteConfigHandler *mockHandler = [[BSGMockRemoteConfigHandler alloc] init];
    mockHandler.mockConfiguration = config;
    
    BSGEventDiscardRuleFactory *factory = [[BSGEventDiscardRuleFactory alloc] init];
    BSGEventDiscardProcessor *processor = [[BSGEventDiscardProcessor alloc] init];
    BSGEventDiscardRulesetSource *source = [BSGEventDiscardRulesetSource sourceWithRemoteConfigHandler:mockHandler
                                                                                     discardRuleFactory:factory];
    processor.source = source;
    
    // Test that the event should be discarded
    BOOL shouldDiscard = [processor shouldDiscardEvent:eventJson];
    XCTAssertTrue(shouldDiscard, @"Expected the payload to be discarded");
}

- (void)testDiscardPipelineNegativeIndex {
    // Load fixture
    NSDictionary *eventJson = [self jsonFromResource:@"negative_index"];
    NSDictionary *configJson = [self jsonFromResource:@"negative_index_config"];
    
    // Create remote configuration from JSON
    BSGRemoteConfiguration *config = [BSGRemoteConfiguration configFromJson:configJson
                                                                       eTag:@"etag"
                                                                 expiryDate:[NSDate dateWithTimeIntervalSinceNow:42]];
    XCTAssertNotNil(config, @"RemoteConfiguration should not be nil");
    
    // Set up the integration test components
    BSGMockRemoteConfigHandler *mockHandler = [[BSGMockRemoteConfigHandler alloc] init];
    mockHandler.mockConfiguration = config;
    
    BSGEventDiscardRuleFactory *factory = [[BSGEventDiscardRuleFactory alloc] init];
    BSGEventDiscardProcessor *processor = [[BSGEventDiscardProcessor alloc] init];
    BSGEventDiscardRulesetSource *source = [BSGEventDiscardRulesetSource sourceWithRemoteConfigHandler:mockHandler
                                                                                     discardRuleFactory:factory];
    processor.source = source;
    
    // Test that the event should be discarded
    BOOL shouldDiscard = [processor shouldDiscardEvent:eventJson];
    XCTAssertTrue(shouldDiscard, @"Expected the payload to be discarded");
}

- (void)testDiscardPipelinePositiveIndex {
    // Load fixture
    NSDictionary *eventJson = [self jsonFromResource:@"positive_index"];
    NSDictionary *configJson = [self jsonFromResource:@"positive_index_config"];
    
    // Create remote configuration from JSON
    BSGRemoteConfiguration *config = [BSGRemoteConfiguration configFromJson:configJson
                                                                       eTag:@"etag"
                                                                 expiryDate:[NSDate dateWithTimeIntervalSinceNow:42]];
    XCTAssertNotNil(config, @"RemoteConfiguration should not be nil");
    
    // Set up the integration test components
    BSGMockRemoteConfigHandler *mockHandler = [[BSGMockRemoteConfigHandler alloc] init];
    mockHandler.mockConfiguration = config;
    
    BSGEventDiscardRuleFactory *factory = [[BSGEventDiscardRuleFactory alloc] init];
    BSGEventDiscardProcessor *processor = [[BSGEventDiscardProcessor alloc] init];
    BSGEventDiscardRulesetSource *source = [BSGEventDiscardRulesetSource sourceWithRemoteConfigHandler:mockHandler
                                                                                     discardRuleFactory:factory];
    processor.source = source;
    
    // Test that the event should be discarded
    BOOL shouldDiscard = [processor shouldDiscardEvent:eventJson];
    XCTAssertTrue(shouldDiscard, @"Expected the payload to be discarded");
}

- (void)testDiscardPipelineRegularRegex {
    // Load fixture
    NSDictionary *eventJson = [self jsonFromResource:@"regular_regex"];
    NSDictionary *configJson = [self jsonFromResource:@"regular_regex_config"];
    
    // Create remote configuration from JSON
    BSGRemoteConfiguration *config = [BSGRemoteConfiguration configFromJson:configJson
                                                                       eTag:@"etag"
                                                                 expiryDate:[NSDate dateWithTimeIntervalSinceNow:42]];
    XCTAssertNotNil(config, @"RemoteConfiguration should not be nil");
    
    // Set up the integration test components
    BSGMockRemoteConfigHandler *mockHandler = [[BSGMockRemoteConfigHandler alloc] init];
    mockHandler.mockConfiguration = config;
    
    BSGEventDiscardRuleFactory *factory = [[BSGEventDiscardRuleFactory alloc] init];
    BSGEventDiscardProcessor *processor = [[BSGEventDiscardProcessor alloc] init];
    BSGEventDiscardRulesetSource *source = [BSGEventDiscardRulesetSource sourceWithRemoteConfigHandler:mockHandler
                                                                                     discardRuleFactory:factory];
    processor.source = source;
    
    // Test that the event should be discarded
    BOOL shouldDiscard = [processor shouldDiscardEvent:eventJson];
    XCTAssertTrue(shouldDiscard, @"Expected the payload to be discarded");
}

@end

