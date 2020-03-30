//
//  BugsnagMetaData.h
//
//  Created by Conrad Irwin on 2014-10-01.
//
//  Copyright (c) 2014 Bugsnag, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <Foundation/Foundation.h>

@interface BugsnagMetadata : NSObject <NSMutableCopying>

- (instancetype _Nonnull)initWithDictionary:(NSMutableDictionary *_Nonnull)dict;

// MARK: - Metadata

/**
 * Merge supplied and existing metadata.
 *
 * - Non-null values will replace existing values for identical keys.
 
 * - Null values will remove the existing key/value pair if the key exists.
 *   Where null-valued keys do not exist they will not be set.  (Since ObjC
 *   dicts can't store 'nil' directly we assume [NSNUll null])
 *
 * - Tabs are only created if at least one value is valid.
 *
 * - Invalid values (i.e. unserializable to JSON) are logged and ignored.
 *
 * @param section The name of the metadata section
 *
 * @param values A dictionary of string -> id key/value pairs.
 *               Values should be serializable to JSON.
 */
- (void)addMetadata:(NSDictionary *_Nullable)values
          toSection:(NSString *_Nonnull)section;

- (void)addMetadata:(id _Nullable)metadata
            withKey:(NSString *_Nonnull)key
          toSection:(NSString *_Nonnull)section;

/**
 * Get a named metadata section
 *
 * @param sectionName The name of the section
 * @returns The mutable dictionary representing the metadata section, if it
 *          exists, or nil if not.
 */
- (NSMutableDictionary *_Nullable)getMetadataFromSection:(NSString *_Nonnull)sectionName
    NS_SWIFT_NAME(getMetadata(_:));

/**
* Get a keyed value from a named metadata section
*
* @param sectionName The name of the section
* @param key The key
* @returns The value if it exists, or nil if not.
*/
- (id _Nullable)getMetadataFromSection:(NSString *_Nonnull)sectionName
                               withKey:(NSString *_Nonnull)key;

/**
* Remove a named metadata section, if it exists.
*
* @param sectionName The section name
*/
- (void)clearMetadataFromSection:(NSString *_Nonnull)sectionName
    NS_SWIFT_NAME(clearMetadata(section:));

/**
 * Remove a specific value for a specific key in a specific metadata section.
 * If either section or key do not exist no action is taken.
 *
 * @param section The section name
 * @param key the metadata key
 */
- (void)clearMetadataFromSection:(NSString *_Nonnull)section
                         withKey:(NSString *_Nonnull)key
    NS_SWIFT_NAME(clearMetadata(section:key:));

@end

@protocol BugsnagMetadataDelegate <NSObject>
- (void)metadataChanged:(BugsnagMetadata *_Nonnull)metadata;
@end
