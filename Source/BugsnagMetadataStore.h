//
//  BugsnagMetadataStore.h
//  Bugsnag
//
//  Created by Robin Macharg on 30/03/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
* Metadata allows semi-arbitrary data to be supplied by the developer.
* It is a set of named sections containing key value pairs, where the
* values can be of any type.
*/

@protocol BugsnagMetadataStore <NSObject>

@required

- (void)addMetadata:(NSDictionary *_Nonnull)metadata
          toSection:(NSString *_Nonnull)sectionName;

- (void)addMetadata:(id _Nullable)value
            withKey:(NSString *_Nonnull)key
          toSection:(NSString *_Nonnull)sectionName;

- (NSDictionary *_Nullable)getMetadataFromSection:(NSString *_Nonnull)sectionName;

- (id _Nullable)getMetadataFromSection:(NSString *_Nonnull)sectionName
                               withKey:(NSString *_Nullable)key;

- (void)clearMetadataFromSection:(NSString *_Nonnull)sectionName;

- (void)clearMetadataFromSection:(NSString *_Nonnull)sectionName
                         withKey:(NSString *_Nonnull)key;

@end

NS_ASSUME_NONNULL_END
