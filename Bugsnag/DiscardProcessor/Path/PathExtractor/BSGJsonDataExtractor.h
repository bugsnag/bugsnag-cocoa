//
//  BSGJsonDataExtractor.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 20/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BSGJsonCollectionPath.h"

typedef void (^BSGJsonDataOnElementExtracedBlock)(NSString *element);

@interface BSGJsonDataExtractor: NSObject

@property (nonatomic, readonly) BSGJsonCollectionPath *path;

+ (NSString *)stringifyElement:(id)element;

- (instancetype)initWithPath:(BSGJsonCollectionPath *)path;

- (void)extractFromJSON:(NSDictionary<NSString *, id> *)json
     onElementExtracted:(BSGJsonDataOnElementExtracedBlock)onElementExtracted;
@end
