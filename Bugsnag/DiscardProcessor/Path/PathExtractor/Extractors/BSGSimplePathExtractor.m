//
//  BSGSimplePathExtractor.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 20/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGSimplePathExtractor.h"

@implementation BSGSimplePathExtractor

- (void)extractFromJSON:(NSDictionary<NSString *,id> *)json onElementExtracted:(void (^)(NSString *))onElementExtracted {
    for(id element in [self.path extractFromJSON:json]) {
        if (onElementExtracted) {
            onElementExtracted([element stringValue]);
        }
    }
}

@end
