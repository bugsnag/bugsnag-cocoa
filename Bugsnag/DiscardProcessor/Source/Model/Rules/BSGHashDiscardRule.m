//
//  BSGHashDiscardRule.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 02/01/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BSGHashDiscardRule.h"
#import "../../../Path/PathExtractor/BSGJsonDataExtractor.h"
#import <CommonCrypto/CommonDigest.h>

static NSString * const JsonKeyPaths = @"paths";
static NSString * const JsonKeyMatches = @"matches";
static NSString * const JsonKeyEvents = @"events";
static NSString * const JsonKeyHash = @"hash";
static uint8_t const HashSeparator = ';';

@interface BSGPathOutputHasher : NSObject

@property (nonatomic, assign) CC_SHA1_CTX sha1Context;
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, strong) NSString *completeHashString;

- (void)addItem:(NSString *)item;
- (NSString *)hashString;

@end

@interface BSGHashDiscardRule ()

@property (nonatomic, strong) NSArray<id> *unparsedExtractors;
@property (nonatomic, strong) NSSet<NSString *> *matches;
@property (nonatomic, strong) NSArray<BSGJsonDataExtractor *> *extractors;
@property (nonatomic, strong) BSGJsonDataExtractorFactory *extractorFactory;

@end

@implementation BSGHashDiscardRule

+ (instancetype)fromJSON:(NSDictionary<NSString *, id> *)json
        extractorFactory:(BSGJsonDataExtractorFactory *)extractorFactory {
    NSDictionary *hash = json[JsonKeyHash];
    if (![hash isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSArray *paths = hash[JsonKeyPaths];
    if (![paths isKindOfClass:[NSArray class]]) {
        return nil;
    }
    
    NSArray *matchesArray = hash[JsonKeyMatches];
    if (![matchesArray isKindOfClass:[NSArray class]]) {
        return nil;
    }
    
    NSMutableSet<NSString *> *matchesSet = [NSMutableSet set];
    for (id match in matchesArray) {
        if ([match isKindOfClass:[NSString class]]) {
            [matchesSet addObject:match];
        }
    }
    
    return [[BSGHashDiscardRule alloc] initWithUnparsedPaths:paths
                                                     matches:matchesSet
                                            extractorFactory:extractorFactory];
}


- (instancetype)initWithUnparsedPaths:(NSArray<id> *)unparsedPaths
                              matches:(NSSet<NSString *> *)matches
                     extractorFactory:(BSGJsonDataExtractorFactory *)extractorFactory {
    self = [super init];
    if (self) {
        _unparsedExtractors = unparsedPaths;
        _matches = matches;
        _extractorFactory = extractorFactory;
    }
    return self;
}

- (BOOL)shouldDiscardEvent:(NSDictionary *)eventPayload {
    @try {
        [self parseExtractorsIfNeeded];
        if ([self.extractors count] == 0) {
            return NO;
        }
        
        NSString *hashString = [self calculatePayloadHash:eventPayload];
        return [self.matches containsObject:hashString];
    } @catch (NSException *exception) {
        return NO;
    }
}

- (NSString *)calculatePayloadHash:(NSDictionary *)json {
    BSGPathOutputHasher *output = [BSGPathOutputHasher new];
    
    for (BSGJsonDataExtractor *extractor in self.extractors) {
        [extractor extractFromJSON:json onElementExtracted:^(NSString *element) {
            [output addItem:element];
        }];
    }
    
    return [output hashString];
}

- (void)parseExtractorsIfNeeded {
    @synchronized (self) {
        if (self.extractors) {
            return;
        }
        NSMutableArray<BSGJsonDataExtractor *> *parsedExtractors = [NSMutableArray array];
        
        for (id extractorJSON in self.unparsedExtractors) {
            if ([extractorJSON isKindOfClass:[NSDictionary class]]) {
                BSGJsonDataExtractor *extractor = [self.extractorFactory extractorFromJSON:extractorJSON];
                if (extractor) {
                    [parsedExtractors addObject:extractor];
                }
            }
        }
        
        self.extractors = parsedExtractors;
    }
}

@end

@implementation BSGPathOutputHasher

- (instancetype)init {
    self = [super init];
    if (self) {
        _isInitialized = NO;
        _completeHashString = nil;
    }
    return self;
}

- (void)addItem:(NSString *)item {
    BOOL wasInitialized = self.isInitialized;
    [self initializeIfNeeded];
    if (wasInitialized) {
        CC_SHA1_CTX context = self.sha1Context;
        CC_SHA1_Update(&context, &HashSeparator, 1);
        self.sha1Context = context;
    }
    
    const char *utf8String = [item UTF8String];
    if (utf8String != NULL) {
        CC_SHA1_CTX context = self.sha1Context;
        CC_SHA1_Update(&context, utf8String, (CC_LONG)strlen(utf8String));
        self.sha1Context = context;
    }
}

- (NSString *)hashString {
    if (self.completeHashString == nil) {
        unsigned char digest[CC_SHA1_DIGEST_LENGTH];
        CC_SHA1_CTX context = self.sha1Context;
        CC_SHA1_Final(digest, &context);
        
        NSMutableString *hexString = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
        for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
            [hexString appendFormat:@"%02x", digest[i]];
        }
        
        self.completeHashString = hexString;
    }
    
    return self.completeHashString;
}

- (void)initializeIfNeeded {
    @synchronized (self) {
        if (self.isInitialized) {
            return;
        }
        
        CC_SHA1_CTX context = self.sha1Context;
        CC_SHA1_Init(&context);
        self.sha1Context = context;
        self.isInitialized = YES;
    }
}

@end
