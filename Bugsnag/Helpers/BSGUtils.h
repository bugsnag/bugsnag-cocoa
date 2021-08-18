//
//  BSGUtils.h
//  Bugsnag
//
//  Created by Nick Dowell on 18/06/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

__BEGIN_DECLS

NS_ASSUME_NONNULL_BEGIN

dispatch_queue_t BSGGetFileSystemQueue(void);

API_AVAILABLE(ios(11.0), tvos(11.0))
NSString *_Nullable BSGStringFromThermalState(NSProcessInfoThermalState thermalState);

NS_ASSUME_NONNULL_END

__END_DECLS
