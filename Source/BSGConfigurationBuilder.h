#import <Foundation/Foundation.h>

@class BugsnagConfiguration;

@interface BSGConfigurationBuilder : NSObject

/**
 * Creates a configuration, applying supported options before returning the new
 * config object. Unsupported options warn.
 *
 * @return a new BugsnagConfiguration object or nil if the a valid object could
 * not be created (including a non-empty API key)
 */
+ (BugsnagConfiguration *_Nullable)configurationFromOptions:(NSDictionary *_Nullable)options;

@end
