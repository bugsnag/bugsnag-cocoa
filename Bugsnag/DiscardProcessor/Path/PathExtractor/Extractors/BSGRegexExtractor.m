//
//  BSGRegexExtractor.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 20/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BSGRegexExtractor.h"

@interface BSGRegexExtractor ()

@property (nonatomic, strong) NSRegularExpression *regex;

@end

@implementation BSGRegexExtractor

- (instancetype)initWithPath:(BSGJsonCollectionPath *)path regex:(NSString *)regex {
    self = [super initWithPath:path];
    if (self) {
        self.regex = [NSRegularExpression regularExpressionWithPattern:regex options:0 error:nil];;
    }
    return self;
}

- (void)extractFromJSON:(NSDictionary<NSString *,id> *)json onElementExtracted:(void (^)(NSString *))onElementExtracted {
    if (!self.regex) {
        return;
    }
    
    for (id element in [self.path extractFromJSON:json]) {
        NSString *stringElement = [[self class] stringifyElement:element];
        if (!stringElement) {
            continue;
        }
        
        // We *find* any match within the source string rather than require a full match
        NSTextCheckingResult *match = [self.regex firstMatchInString:stringElement
                                                             options:0
                                                               range:NSMakeRange(0, stringElement.length)];
        
        if (match.numberOfRanges > 0) {
            NSString *output = [self extractMatcherOutput:stringElement match:match];
            onElementExtracted(output);
        }
    }
}

- (NSString *)extractMatcherOutput:(NSString *)source match:(NSTextCheckingResult *)match {
    NSUInteger numberOfGroups = match.numberOfRanges - 1; // Subtract 1 because range 0 is the full match
    
    if (numberOfGroups > 0) {
        // The regex groups are joined together with a ',' separator
        NSMutableString *groups = [NSMutableString stringWithCapacity:source.length];
        
        // Start with group 1 (group 0 is the entire match)
        NSRange firstGroupRange = [match rangeAtIndex:1];
        if (firstGroupRange.location != NSNotFound) {
            [groups appendString:[source substringWithRange:firstGroupRange]];
        }
        
        // Append remaining groups with comma separator
        for (NSUInteger groupIndex = 2; groupIndex <= numberOfGroups; groupIndex++) {
            [groups appendString:@","];
            NSRange groupRange = [match rangeAtIndex:groupIndex];
            if (groupRange.location != NSNotFound) {
                [groups appendString:[source substringWithRange:groupRange]];
            }
        }
        
        return groups;
    }
    
    return source;
}

@end
