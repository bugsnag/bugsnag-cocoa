//
//  BSGJsonDataExtractor.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 20/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGJsonDataExtractor.h"
#import "BSGJsonCollectionPath.h"

@interface BSGJsonDataExtractor ()
@property (nonatomic, strong) BSGJsonCollectionPath *path;
@end

@implementation BSGJsonDataExtractor

- (instancetype)initWithPath:(BSGJsonCollectionPath *)path {
    self = [super init];
    if (self) {
        self.path = path;
    }
    return self;
}

- (void)extractFromJSON:(NSDictionary<NSString *, id> *)json
     onElementExtracted:(BSGJsonDataOnElementExtracedBlock)onElementExtracted {}

@end
